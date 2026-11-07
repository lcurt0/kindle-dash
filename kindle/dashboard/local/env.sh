#!/bin/sh
# ── Configuración del Kindle ─────────────────────────────────

# Imagen publicada por GitHub Pages.
export DASH_URL="https://lcurt0.github.io/kindle-dash/dash.png"

# Horario: se despierta a los WAKE_MINUTE de cada hora, de WAKE_FROM a WAKE_TO.
# Por defecto 7:15, 8:15 … 23:15. Para cada 30 min poné WAKE_MINUTES="15 45".
export WAKE_MINUTES="15"
export WAKE_FROM=7
export WAKE_TO=23

# Zona horaria en formato POSIX (Madrid, con horario de verano).
export TZ="CET-1CEST,M3.5.0,M10.5.0/3"

# Si falta más de esto (segundos) para el próximo despertar, muestra la
# pantalla de noche. Una hora + 5 min de margen, porque la RTC a veces
# despierta unos segundos antes. Con el horario de arriba: última
# actualización 22:15, pantalla de noche de 23:15 a 7:15.
export SLEEP_SCREEN_INTERVAL=3900

# Cada cuántos refrescos parciales hacer uno completo (limpia restos de e-ink).
export FULL_DISPLAY_REFRESH_RATE=4

# Luz frontal mientras corre el dashboard (0 = apagada, hasta 24).
# Es lo que más batería gasta; con luz ambiente no hace falta.
export FRONTLIGHT=0

# Un clic al botón de encendido prende la luz a TAP_LIGHT (0–24)
# durante TAP_LIGHT_SECONDS y después vuelve a FRONTLIGHT.
export TAP_LIGHT=12
export TAP_LIGHT_SECONDS=20

# IP para comprobar que hay Wi-Fi después de despertar.
export WIFI_TEST_IP=1.1.1.1
