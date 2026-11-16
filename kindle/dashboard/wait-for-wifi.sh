#!/bin/sh
# Espera hasta $2 segundos (30 por defecto) a que vuelva el Wi-Fi después de despertar.
ip=${1:-1.1.1.1}
max=${2:-30}
i=0
until ping -c 1 -W 2 "$ip" >/dev/null 2>&1; do
  i=$((i + 1))
  [ $i -ge "$max" ] && echo "Sin Wi-Fi" && exit 1
  sleep 1
done
echo "Wi-Fi conectado"
