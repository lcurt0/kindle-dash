#!/bin/sh
# Vuelve a la versión anterior a la última autoactualización.
# Se usa desde KUAL después de reiniciar el Kindle (botón 40 s).
# Para que no se vuelva a actualizar sola hasta que haya un arreglo,
# deja una marca que update.sh respeta mientras la versión publicada no cambie.
DIR="$(cd "$(dirname "$0")" && pwd)"
[ -d "$DIR/.backup" ] || { echo "No hay versión anterior guardada"; exit 1; }
bad=$(cat "$DIR/version.txt" 2>/dev/null)
cp -R "$DIR/.backup/." "$DIR/"
echo "$bad" >"$DIR/.skip-version"
sync
mkdir -p "$DIR/logs"
echo "$(date '+%F %T') Restaurada la versión anterior (se omite $bad)" >>"$DIR/logs/dash.log"
eips 1 1 " Version anterior restaurada "
