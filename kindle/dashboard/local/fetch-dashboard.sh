#!/bin/sh
# Descarga la imagen en "$1" usando el curl del propio Kindle.
# Baja primero a un temporal: si falla o llega vacía, la anterior queda intacta.
tmp="$1.part"
rm -f "$tmp"

curl -fsSL --max-time 60 -o "$tmp" "$DASH_URL"
code=$?

# 60/77 = el Kindle no reconoce el certificado (almacén de CAs viejo).
# Es una imagen pública, así que reintentamos sin verificar y lo dejamos anotado.
if [ $code -eq 60 ] || [ $code -eq 77 ]; then
  echo "Certificado no verificado, reintento sin validar"
  curl -fsSLk --max-time 60 -o "$tmp" "$DASH_URL"
  code=$?
fi

[ $code -eq 0 ] && [ -s "$tmp" ] || { echo "Descarga falló (curl $code)"; rm -f "$tmp"; exit 1; }
mv "$tmp" "$1"
