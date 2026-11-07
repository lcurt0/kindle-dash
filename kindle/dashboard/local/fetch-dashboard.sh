#!/bin/sh
# Descarga la imagen en "$1" usando el curl del propio Kindle, con verificación
# de certificado. Baja primero a un temporal: si falla o llega vacía, la
# imagen anterior queda intacta.
tmp="$1.part"
rm -f "$tmp"
curl -fsSL --max-time 60 -o "$tmp" "$DASH_URL"
code=$?
[ $code -eq 0 ] && [ -s "$tmp" ] || { echo "Descarga falló (curl $code)"; rm -f "$tmp"; exit 1; }
mv "$tmp" "$1"
