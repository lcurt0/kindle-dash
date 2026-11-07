#!/bin/sh
# Autoactualización de los scripts del Kindle desde GitHub Pages.
# Códigos de salida: 0 = sin cambios, 10 = actualizado, 1 = error (no se tocó nada).
#
# 1. Compara version.txt local con el publicado.
# 2. Baja todo a .update/ y verifica que esté completo y sin errores de sintaxis.
# 3. Guarda la versión actual en .backup/ (KUAL → Restaurar versión anterior).
# 4. Mueve los archivos nuevos a su lugar. mv crea archivos nuevos, así el
#    dash.sh que está corriendo sigue leyendo su copia vieja sin romperse.
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/local/env.sh"
BASE="${DASH_URL%/*}/kindle"
FILES="dash.sh start.sh stop.sh next-wakeup.sh wait-for-wifi.sh update.sh restore.sh sleeping.png local/env.sh local/fetch-dashboard.sh"

get() {  # get URL DESTINO — siempre con verificación de certificado:
         # son scripts que se van a ejecutar, nunca se aceptan sin verificar.
  curl -fsSL --proto =https --max-time 30 -o "$2" "$1"
}

stage="$DIR/.update"
rm -rf "$stage"; mkdir -p "$stage/local"

get "$BASE/version.txt" "$stage/version.txt" || { echo "Update: sin respuesta"; exit 1; }
remote=$(tr -dc 'a-f0-9' <"$stage/version.txt")
local_v=$( { tr -dc 'a-f0-9' <"$DIR/version.txt"; } 2>/dev/null)
[ -n "$remote" ] || { echo "Update: versión vacía"; exit 1; }
[ "$remote" = "$local_v" ] && { rm -rf "$stage"; exit 0; }
# Si restauraste a mano una versión anterior, no volver a instalar la misma rota.
skip=$( { tr -dc 'a-f0-9' <"$DIR/.skip-version"; } 2>/dev/null)
[ -n "$skip" ] && [ "$remote" = "$skip" ] && { rm -rf "$stage"; exit 0; }

for f in $FILES; do
  get "$BASE/$f" "$stage/$f" && [ -s "$stage/$f" ] || { echo "Update: falló $f"; rm -rf "$stage"; exit 1; }
done
for f in $FILES; do
  case "$f" in *.sh) sh -n "$stage/$f" || { echo "Update: error de sintaxis en $f"; rm -rf "$stage"; exit 1; } ;; esac
done

rm -rf "$DIR/.backup"; mkdir -p "$DIR/.backup/local"
for f in $FILES version.txt; do [ -f "$DIR/$f" ] && cp "$DIR/$f" "$DIR/.backup/$f"; done

for f in $FILES; do mv -f "$stage/$f" "$DIR/$f"; done
mv -f "$stage/version.txt" "$DIR/version.txt"
rm -rf "$stage"
echo "Update: $local_v -> $remote"
exit 10
