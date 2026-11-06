#!/bin/sh
# Explicit opt-in: never reloads, but the installed bridge event_loop sends a
# GLOBAL --update once. This can invoke existing widgets' external queries.
set -eu
if [ "$#" -ne 3 ] || [ "${1:-}" != --live ] || [ "${2:-}" != --allow-global-update ]; then
  echo 'Usage: LUA_BIN=/absolute/lua sh sketchybar-bridge-smoke.sh --live --allow-global-update BASE_ROOT' >&2
  echo 'Requires explicit approval: bridge startup forces ALL existing widgets to update.' >&2
  exit 2
fi
base=$3
echo 'WARNING: bridge startup will force existing widgets to update once.' >&2
lua=${LUA_BIN:-lua}
bar=$(command -v sketchybar)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-bridge.XXXXXX")
name="dotfiles.probe.$$"
pid=
cleanup() {
  "$bar" --remove "$name" >/dev/null 2>&1 || true
  if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
cat > "$tmp/probe.lua" <<'LUA'
local base, name, result_file = assert(arg[1]), assert(arg[2]), assert(arg[3])
package.path = base .. "/home/.config/sketchybar/?.lua;" .. package.path
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.local/share/sketchybar_lua/?.so"
local sbar = require("sketchybar")
local count, success, failure = 0, false, false
local function finish()
  if count >= 3 and success and failure then
    local file = assert(io.open(result_file, "w"))
    file:write("PASS: real bridge JSON/exit callbacks and hidden timer\n")
    file:close()
    os.exit(0)
  end
end
local item = sbar.add("item", name, {drawing=false, updates="on", update_freq=1})
item:subscribe("routine", function()
  count = count+1
  finish()
end)
sbar.exec("/usr/bin/printf '%s' '{\"ok\":true}'", function(result, code)
  success = code==0 and type(result)=="table" and result.ok==true
  finish()
end)
sbar.exec("/usr/bin/false", function(_, code)
  failure = code~=0
  finish()
end)
sbar.event_loop()
LUA
"$lua" "$tmp/probe.lua" "$base" "$name" "$tmp/result" >"$tmp/stdout" 2>"$tmp/stderr" &
pid=$!
i=0
while [ "$i" -lt 10 ]; do
  if [ -f "$tmp/result" ]; then cat "$tmp/result"; exit 0; fi
  if ! kill -0 "$pid" 2>/dev/null; then break; fi
  sleep 1
  i=$((i+1))
done
echo 'FAIL: real bridge smoke did not complete within 10s' >&2
cat "$tmp/stderr" >&2
exit 1
