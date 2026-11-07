#!/bin/sh
# Dashboard e-ink para Kindle Paperwhite 7ª gen (firmware 5.16).
# Basado en pascalw/kindle-dash (MIT), sin binarios externos:
#  - descarga con el curl del Kindle (local/fetch-dashboard.sh)
#  - calcula el próximo despertar en shell (next-wakeup.sh)
#  - detiene la interfaz con el comando que exista (init.d o upstart)
#  - programa el despertador con la RTC que exista (mxc_rtc o /sys/class/rtc)
#  - avisa en pantalla cuando la batería baja de LOW_BATTERY
# Se lanza con start.sh. Para salir: KUAL → Detener, o mantener el botón
# de encendido ~30 s (reinicia normal).
DEBUG=${DEBUG:-false}
[ "$DEBUG" = true ] && set -x

DIR="$(cd "$(dirname "$0")" && pwd)"
DASH_PNG="$DIR/dash.png"
LOG="$DIR/logs/dash.log"
FULL_DISPLAY_REFRESH_RATE=${FULL_DISPLAY_REFRESH_RATE:-4}
SLEEP_SCREEN_INTERVAL=${SLEEP_SCREEN_INTERVAL:-3900}
LOW_BATTERY=${LOW_BATTERY:-15}
num_refresh=$FULL_DISPLAY_REFRESH_RATE   # el primer dibujo siempre es completo

log() { echo "$(date '+%F %T') $*"; }

# Mantener el log chico (últimas 300 líneas).
[ -f "$LOG" ] && tail -n 300 "$LOG" >"$LOG.tmp" && cat "$LOG.tmp" >"$LOG" && rm -f "$LOG.tmp"

stop_ui() {
  if [ -x /etc/init.d/framework ]; then
    /etc/init.d/framework stop
  else
    stop lab126_gui 2>/dev/null || stop framework 2>/dev/null
  fi
  initctl stop webreader >/dev/null 2>&1
}

battery() { gasgauge-info -c 2>/dev/null | tr -dc '0-9'; }

draw() {
  if [ "$num_refresh" -ge "$FULL_DISPLAY_REFRESH_RATE" ]; then
    num_refresh=0
    eips -f -g "$1"        # refresco completo: limpia restos de e-ink
  else
    eips -g "$1"
  fi
  num_refresh=$((num_refresh + 1))
  b=$(battery)
  if [ -n "$b" ] && [ "$b" -le "$LOW_BATTERY" ]; then
    eips 1 1 " Bateria $b% - cargame "
  fi
}

refresh_dashboard() {
  "$DIR/wait-for-wifi.sh" "$WIFI_TEST_IP"
  if "$DIR/local/fetch-dashboard.sh" "$DASH_PNG"; then
    draw "$DASH_PNG"
    log "Pantalla actualizada (batería $(battery)%)"
  else
    log "No se pudo descargar; queda la imagen anterior"
  fi
}

rtc_sleep() {
  duration=$1
  if [ "$DEBUG" = true ]; then sleep "$duration"; return; fi
  if [ -e /sys/devices/platform/mxc_rtc.0/wakeup_enable ]; then
    rtc=/sys/devices/platform/mxc_rtc.0/wakeup_enable
    [ "$(cat "$rtc")" -eq 0 ] && echo -n "$duration" >"$rtc"
  else
    for r in /sys/class/rtc/rtc1/wakealarm /sys/class/rtc/rtc0/wakealarm; do
      if [ -e "$r" ]; then echo 0 >"$r"; echo "+$duration" >"$r"; log "RTC: $r"; break; fi
    done
  fi
  echo mem >/sys/power/state
}

log "Iniciando ($WAKE_MINUTES min, $WAKE_FROM–$WAKE_TO h)"
stop_ui
echo powersave >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
lipc-set-prop com.lab126.powerd preventScreenSaver 1

while true; do
  next=$("$DIR/next-wakeup.sh")
  if [ "$next" -gt "$SLEEP_SCREEN_INTERVAL" ]; then
    log "Modo noche"
    draw "$DIR/sleeping.png"
    num_refresh=$FULL_DISPLAY_REFRESH_RATE
  else
    refresh_dashboard
  fi
  sleep 10   # margen para poder detenerlo desde KUAL
  log "Durmiendo ${next}s"
  rtc_sleep "$next"
done
