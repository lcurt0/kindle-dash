#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$DIR/logs"
. "$DIR/local/env.sh"
chmod +x "$DIR"/*.sh "$DIR"/local/*.sh 2>/dev/null
if [ "$DEBUG" = true ]; then
  "$DIR/dash.sh"
else
  "$DIR/dash.sh" >>"$DIR/logs/dash.log" 2>&1 &
fi
