#!/bin/sh
# Lanza el dashboard como proceso independiente.
# KUAL corre dentro de la interfaz del Kindle: si el dashboard quedara como
# hijo de KUAL, moriría al apagar la interfaz. setsid lo saca de ese árbol.
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/logs"
. "$DIR/local/env.sh"
chmod +x "$DIR"/*.sh "$DIR"/local/*.sh 2>/dev/null

if [ "$DEBUG" = true ]; then
  exec "$DIR/dash.sh"
fi

if command -v setsid >/dev/null 2>&1; then
  setsid /bin/sh "$DIR/dash.sh" </dev/null >>"$DIR/logs/dash.log" 2>&1 &
else
  nohup /bin/sh "$DIR/dash.sh" </dev/null >>"$DIR/logs/dash.log" 2>&1 &
fi
