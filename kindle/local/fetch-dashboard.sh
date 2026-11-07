#!/usr/bin/env sh
# Descarga la imagen del dashboard en "$1".
# Primero a un archivo temporal: si la descarga falla o llega vacía,
# la imagen anterior queda intacta.
. "$(dirname "$0")/env.sh"
tmp="$1.part"
"$(dirname "$0")/../xh" --follow -d -q -o "$tmp" get "$DASH_URL" || { rm -f "$tmp"; exit 1; }
[ -s "$tmp" ] || { rm -f "$tmp"; exit 1; }
mv "$tmp" "$1"
