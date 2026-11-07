#!/usr/bin/env sh
# Versión adaptada de pascalw/kindle-dash (MIT) para Paperwhite 7ª gen / firmware 5.16.
# Se lanza con start.sh (que carga local/env.sh). Para salir: mantener
# apretado el botón de encendido ~30 s; el Kindle reinicia normal.
# Cambios respecto al original:
#  - Detiene la interfaz con el comando que exista (init.d, upstart o lab126_gui).
#  - Programa el despertador con la RTC que exista (mxc_rtc o /sys/class/rtc/rtcN).
#  - Log con fecha en /mnt/us/dashboard/logs/dash.log, legible por USB sin SSH.
DEBUG=${DEBUG:-false}
[ "$DEBUG" = true ] && set -x

DIR="$(dirname "$0")"
DASH_PNG="$DIR/dash.png"
FETCH_DASHBOARD_CMD="$DIR/local/fetch-dashboard.sh"
LOW_BATTERY_CMD="$DIR/local/low-battery.sh"
LOG="$DIR/logs/dash.log"   # start.sh ya redirige la salida acá

REFRESH_SCHEDULE=${REFRESH_SCHEDULE:-"15 7-23 * * *"}
FULL_DISPLAY_REFRESH_RATE=${FULL_DISPLAY_REFRESH_RATE:-4}
SLEEP_SCREEN_INTERVAL=${SLEEP_SCREEN_INTERVAL:-3600}
LOW_BATTERY_REPORTING=${LOW_BATTERY_REPORTING:-false}
LOW_BATTERY_THRESHOLD_PERCENT=${LOW_BATTERY_THRESHOLD_PERCENT:-10}

num_refresh=0

log() { echo "$(date '+%F %T') $*"; }

# Mantener el log chico (últimas 300 líneas) para no llenar la memoria.
[ -f "$LOG" ] && tail -n 300 "$LOG" >"$LOG.tmp" && cat "$LOG.tmp" >"$LOG" && rm -f "$LOG.tmp"

stop_ui() {
  if [ -x /etc/init.d/framework ]; then
    /etc/init.d/framework stop
  elif command -v stop >/dev/null 2>&1; then
    stop lab126_gui 2>/dev/null || stop framework 2>/dev/null
  else
    initctl stop lab126_gui 2>/dev/null || initctl stop framework 2>/dev/null
  fi
  initctl stop webreader >/dev/null 2>&1
}

init() {
  if [ -z "$TIMEZONE" ] || [ -z "$REFRESH_SCHEDULE" ]; then
    log "Falta configuración: TIMEZONE=${TIMEZONE:-?} REFRESH_SCHEDULE=${REFRESH_SCHEDULE:-?}"
    exit 1
  fi
  log "Iniciando dashboard ($REFRESH_SCHEDULE, $TIMEZONE)"
  stop_ui
  echo powersave >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
  lipc-set-prop com.lab126.powerd preventScreenSaver 1
}

prepare_sleep() {
  log "Modo noche"
  /usr/sbin/eips -f -g "$DIR/sleeping.png"
  sleep 2
  num_refresh=$FULL_DISPLAY_REFRESH_RATE
}

refresh_dashboard() {
  "$DIR/wait-for-wifi.sh" "$WIFI_TEST_IP"
  if ! "$FETCH_DASHBOARD_CMD" "$DASH_PNG"; then
    log "No se pudo descargar; queda la imagen anterior"
    return 1
  fi
  if [ "$num_refresh" -ge "$FULL_DISPLAY_REFRESH_RATE" ]; then
    num_refresh=0
    /usr/sbin/eips -f -g "$DASH_PNG"   # refresco completo: limpia el ghosting
  else
    /usr/sbin/eips -g "$DASH_PNG"
  fi
  num_refresh=$((num_refresh + 1))
  log "Pantalla actualizada"
}

log_battery_stats() {
  battery_level=$(gasgauge-info -c)
  log "Batería: $battery_level"
  if [ "$LOW_BATTERY_REPORTING" = true ]; then
    n=${battery_level%?}
    [ "$n" -le "$LOW_BATTERY_THRESHOLD_PERCENT" ] && "$LOW_BATTERY_CMD" "$n"
  fi
}

rtc_sleep() {
  duration=$1
  if [ "$DEBUG" = true ]; then sleep "$duration"; return; fi

  if [ -e /sys/devices/platform/mxc_rtc.0/wakeup_enable ]; then
    RTC=/sys/devices/platform/mxc_rtc.0/wakeup_enable
    [ "$(cat "$RTC")" -eq 0 ] && echo -n "$duration" >"$RTC"
  else
    for r in /sys/class/rtc/rtc1/wakealarm /sys/class/rtc/rtc0/wakealarm; do
      if [ -e "$r" ]; then
        echo 0 >"$r"
        echo "+$duration" >"$r"
        break
      fi
    done
  fi
  echo "mem" >/sys/power/state
}

main_loop() {
  while true; do
    log_battery_stats
    next=$("$DIR/next-wakeup" --schedule="$REFRESH_SCHEDULE" --timezone="$TIMEZONE")
    if [ "$next" -gt "$SLEEP_SCREEN_INTERVAL" ]; then
      action="dormir"; prepare_sleep
    else
      action="suspender"; refresh_dashboard
    fi
    # 10 s de margen para poder cortarlo (ver README: cómo salir)
    sleep 10
    log "A $action, próximo despertar en ${next}s"
    rtc_sleep "$next"
  done
}

init
main_loop
