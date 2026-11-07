#!/bin/sh
# Imprime los segundos hasta el próximo despertar según WAKE_MINUTES,
# WAKE_FROM y WAKE_TO (hora local según TZ). Reemplaza al binario
# next-wakeup del kindle-dash original.
# Para probar: NOW="23 20 00" ./next-wakeup.sh

if [ -n "$NOW" ]; then
  set -- $NOW
else
  set -- $(date +"%H %M %S")
fi
h=$(echo "$1" | sed 's/^0//'); m=$(echo "$2" | sed 's/^0//'); s=$(echo "$3" | sed 's/^0//')
now=$((h * 3600 + m * 60 + s))

best=""
hour=$WAKE_FROM
while [ "$hour" -le "$WAKE_TO" ]; do
  for wm in $WAKE_MINUTES; do
    t=$((hour * 3600 + wm * 60))
    # 30 s de margen para no reprogramar el mismo minuto en el que despertó.
    if [ $t -gt $((now + 30)) ]; then
      [ -z "$best" ] || [ $t -lt "$best" ] && best=$t
    fi
  done
  hour=$((hour + 1))
done

if [ -n "$best" ]; then
  echo $((best - now))
else
  first=""
  for wm in $WAKE_MINUTES; do
    [ -z "$first" ] || [ "$wm" -lt "$first" ] && first=$wm
  done
  echo $((86400 - now + WAKE_FROM * 3600 + first * 60))
fi
