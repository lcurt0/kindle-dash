#!/bin/sh
# Detiene el dashboard y devuelve el Kindle a su interfaz normal.
pkill -f dashboard/dash.sh
lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null
if [ -x /etc/init.d/framework ]; then
  /etc/init.d/framework start
else
  start lab126_gui 2>/dev/null || start framework 2>/dev/null
fi
