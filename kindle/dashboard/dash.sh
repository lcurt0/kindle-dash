#!/bin/sh
# Dashboard e-ink para Kindle Paperwhite 7ª gen (firmware 5.16).
# Basado en pascalw/kindle-dash (MIT), sin binarios externos:
#  - descarga con el curl del Kindle (local/fetch-dashboard.sh)
#  - calcula el próximo despertar en shell (next-wakeup.sh)
#  - detiene la interfaz con el comando que exista (init.d o upstart)
#  - programa el despertador con la RTC que exista (mxc_rtc o /sys/class/rtc)
#  - avisa en pantalla cuando la batería baja de LOW_BATTERY
#  - un clic al botón de encendido prende la luz y descarga la imagen más
#    reciente; de noche, al apagarse la luz vuelve la pantalla de noche
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
trap '' HUP

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
  log "Esperando Wi-Fi"
  /bin/sh "$DIR/wait-for-wifi.sh" "$WIFI_TEST_IP"
  log "Descargando"
  if /bin/sh "$DIR/local/fetch-dashboard.sh" "$DASH_PNG"; then
    draw "$DASH_PNG"
    log "Pantalla actualizada (batería $(battery)%)"
  else
    log "No se pudo descargar; queda la imagen anterior"
  fi
}

light() {
  lipc-set-prop com.lab126.powerd flIntensity "$1" 2>/dev/null \
    || for bl in /sys/class/backlight/*/brightness; do echo "$1" >"$bl"; done
}

set_alarm() {
  if [ -e /sys/devices/platform/mxc_rtc.0/wakeup_enable ]; then
    rtc=/sys/devices/platform/mxc_rtc.0/wakeup_enable
    [ "$(cat "$rtc")" -eq 0 ] && echo -n "$1" >"$rtc"
  else
    for r in /sys/class/rtc/rtc1/wakealarm /sys/class/rtc/rtc0/wakealarm; do
      if [ -e "$r" ]; then echo 0 >"$r"; echo "+$1" >"$r"; break; fi
    done
  fi
}

# Duerme $1 segundos. Si se despierta antes de tiempo, fue el botón de
# encendido: prende la luz TAP_LIGHT_SECONDS y actualiza, la apaga
# y sigue durmiendo lo que faltaba. Así se puede leer de noche sin gastar batería el resto del tiempo.
rtc_sleep() {
  remaining=$1
  if [ "$DEBUG" = true ]; then sleep "$remaining"; return; fi
  while [ "$remaining" -gt 30 ]; do
    set_alarm "$remaining"
    t0=$(date +%s)
    echo mem >/sys/power/state
    slept=$(( $(date +%s) - t0 ))

    if [ "$slept" -lt 2 ]; then
      # La suspensión no se produjo: esperar despierto para no entrar en bucle.
      log "Suspensión falló; espero despierto ${remaining}s"
      sleep "$remaining"; return
    fi

    if [ "$slept" -lt $((remaining - 60)) ]; then
      log "Botón: luz ${TAP_LIGHT_SECONDS}s"
      light "$TAP_LIGHT"
      t1=$(date +%s)
      refresh_dashboard        # el clic siempre trae la imagen más reciente
      busy=$(( $(date +%s) - t1 ))
      [ "$busy" -lt "$TAP_LIGHT_SECONDS" ] && sleep $((TAP_LIGHT_SECONDS - busy))
      light "$FRONTLIGHT"
      # De noche, al apagarse la luz vuelve la pantalla de "Fuera de horario".
      if [ "$current_png" != "$DASH_PNG" ]; then
        num_refresh=$FULL_DISPLAY_REFRESH_RATE
        draw "$current_png"
      fi
      remaining=$((remaining - slept - $(date +%s) + t1))
    else
      remaining=0
    fi
  done
  [ "$remaining" -gt 0 ] && sleep "$remaining"
}

log "Iniciando (min $WAKE_MINUTES, de $WAKE_FROM a $WAKE_TO h, pid $$)"
sleep 3   # deja que KUAL termine de cerrar su menú
log "Apagando interfaz"
stop_ui
log "Interfaz apagada"
echo powersave >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null
lipc-set-prop com.lab126.powerd preventScreenSaver 1
FRONTLIGHT=${FRONTLIGHT:-0}
TAP_LIGHT=${TAP_LIGHT:-12}
TAP_LIGHT_SECONDS=${TAP_LIGHT_SECONDS:-20}
light "$FRONTLIGHT"
current_png="$DASH_PNG"

while true; do
  next=$(/bin/sh "$DIR/next-wakeup.sh")
  log "Próximo despertar en ${next}s"
  if [ "$next" -gt "$SLEEP_SCREEN_INTERVAL" ]; then
    log "Modo noche"
    draw "$DIR/sleeping.png"
    current_png="$DIR/sleeping.png"
    num_refresh=$FULL_DISPLAY_REFRESH_RATE
  else
    refresh_dashboard
    current_png="$DASH_PNG"
  fi
  sleep 10   # margen antes de suspender
  log "Durmiendo ${next}s"
  rtc_sleep "$next"
done
