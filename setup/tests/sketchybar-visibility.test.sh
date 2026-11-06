#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
lua=${LUA_BIN:-lua}
# A live probe without the separate global-update acknowledgement must fail
# before touching IPC, even when --live was provided.
status=0
sh "$base/setup/tests/sketchybar-bridge-smoke.sh" --live "$base" >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ] || { echo 'FAIL: live smoke approval gate' >&2; exit 1; }
python3 "$base/setup/tests/sketchybar-bounded-query.test.py" "$base"
"$lua" "$base/setup/tests/sketchybar-bounded-query.test.lua" "$base"
/usr/bin/perl "$base/setup/tests/sketchybar-display-snapshot.test.pl" "$base"
"$lua" "$base/setup/tests/sketchybar-display.test.lua" "$base"
"$lua" "$base/setup/tests/sketchybar-widget-visibility.test.lua" "$base"
LUA_BIN="$lua" sh "$base/setup/tests/sketchybar-profile.test.sh"
if [ "$#" -gt 0 ]; then
  "$lua" "$1/share/tests/sketchybar-mosaic.test.lua" "$1" "$base"
fi
printf '%s\n' 'PASS: SketchyBar visibility regression suite'
