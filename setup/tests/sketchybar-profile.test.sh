#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/sketchybar-profile.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
lua_bin=${LUA_BIN:-lua}

HOME="$tmp" "$lua_bin" "$repo_root/setup/tests/sketchybar-profile.test.lua" "$repo_root" no-profile
mkdir -p "$tmp/.config/sketchybar/profile"
printf '%s\n' '_G.__profile_loaded = true' > "$tmp/.config/sketchybar/profile/init.lua"
HOME="$tmp" "$lua_bin" "$repo_root/setup/tests/sketchybar-profile.test.lua" "$repo_root" profile
printf 'PASS: sketchybar-profile\n'
