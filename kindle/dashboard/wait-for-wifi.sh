#!/bin/sh
# Espera hasta 30 s a que vuelva el Wi-Fi después de despertar.
ip=${1:-1.1.1.1}
i=0
until ping -c 1 -W 2 "$ip" >/dev/null 2>&1; do
  i=$((i + 1))
  [ $i -ge 30 ] && echo "Sin Wi-Fi" && exit 1
  sleep 1
done
echo "Wi-Fi conectado"
