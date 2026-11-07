#!/usr/bin/env sh
# ── Configuración del Kindle ─────────────────────────────────

# URL de la imagen que publica GitHub Pages.
# Cambiá USUARIO y REPO si usás otros nombres.
export DASH_URL=${DASH_URL:-"https://lcurt0.github.io/kindle-dash/dash.png"}

export WIFI_TEST_IP=${WIFI_TEST_IP:-1.1.1.1}

# Cuándo despertarse (formato cron, hora local).
# "15 7-23 * * *" = a las y cuarto, de 7:15 a 23:15. Una vez por hora.
# Para cada 30 min: "15,45 7-23 * * *" (gasta el doble de batería).
export REFRESH_SCHEDULE=${REFRESH_SCHEDULE:-"15 7-23 * * *"}
export TIMEZONE=${TIMEZONE:-"Europe/Madrid"}

# Cada cuántos refrescos parciales hacer uno completo (limpia restos de e-ink).
export FULL_DISPLAY_REFRESH_RATE=${FULL_DISPLAY_REFRESH_RATE:-4}

# Si falta más de esto (segundos) para el próximo despertar, muestra la
# pantalla de noche en lugar del dashboard. Con el horario de arriba,
# a las 23:15 muestra "descansando" hasta las 7:15.
export SLEEP_SCREEN_INTERVAL=3600

export LOW_BATTERY_REPORTING=${LOW_BATTERY_REPORTING:-false}
export LOW_BATTERY_THRESHOLD_PERCENT=10
