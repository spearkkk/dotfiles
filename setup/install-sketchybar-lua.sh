#!/usr/bin/env bash
# Install the pinned Lua 5.4 bridge without starting or reloading SketchyBar.
set -euo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check_only=no
case "${1:-}" in
  '') [[ $# -eq 0 ]] || exit 2 ;;
  --check) [[ $# -eq 1 ]] || exit 2; check_only=yes ;;
  --help|-h)
    echo 'Usage: bash setup/install-sketchybar-lua.sh [--check]'
    echo '--check validates the installed bridge without downloading or installing.'
    exit 0 ;;
  *) echo 'Usage: bash setup/install-sketchybar-lua.sh [--check]' >&2; exit 2 ;;
esac

fail() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || fail 'SketchyBar requires macOS.'
arch="$(uname -m)"
case "$arch" in arm64|x86_64) ;; *) fail "Unsupported architecture: $arch" ;; esac
for tool in mise jq shasum lipo; do
  command -v "$tool" >/dev/null || fail "Required tool not found: $tool"
done

lock="$script_dir/sketchybar-lua.lock.json"
url="$(jq -er '.url' "$lock")"
revision="$(jq -er '.revision' "$lock")"
source_sha="$(jq -er '.sha256' "$lock")"
lua_version="$(jq -er '.lua' "$lock")"
[[ "$revision" =~ ^[0-9a-f]{40}$ && "$source_sha" =~ ^[0-9a-f]{64}$ ]] || fail 'Invalid source pin.'
[[ "$url" == https://*/"$revision" && "$lua_version" == 5.4 ]] || fail 'Expected a pinned HTTPS source and Lua 5.4.'

if ! lua_dir="$(mise where "lua@$lua_version" 2>/dev/null)"; then
  [[ "$check_only" == no ]] || fail 'Lua 5.4 is not installed through mise.'
  mise install "lua@$lua_version"
  lua_dir="$(mise where "lua@$lua_version")"
fi
lua_bin="$lua_dir/bin/lua"
[[ -x "$lua_bin" ]] || fail "Lua executable not found: $lua_bin"
[[ "$("$lua_bin" -E -e 'io.write(_VERSION)')" == "Lua $lua_version" ]] || fail 'Unexpected Lua ABI.'
lipo -verify_arch "$arch" "$lua_bin" || fail 'Lua architecture does not match this shell.'

install_dir="$HOME/.local/share/sketchybar_lua"
target="$install_dir/sketchybar.so"
receipt="$install_dir/install.json"
identity="$(jq -cn --slurpfile source "$lock" --arg arch "$arch" \
  '{source: $source[0], architecture: $arch}')"

validate_module() {
  lipo -verify_arch "$arch" "$1" || return 1
  "$lua_bin" -E "$script_dir/check-sketchybar-lua.lua" "$1"
}

installed_matches() {
  [[ -f "$target" && -f "$receipt" ]] || return 1
  local digest
  digest="$(shasum -a 256 "$target" | awk '{print $1}')" || return 1
  jq -se --argjson identity "$identity" --arg sha256 "$digest" \
    'length == 1 and (.[0] | type == "object" and .identity == $identity and .sha256 == $sha256)' \
    "$receipt" >/dev/null || return 1
  validate_module "$target"
}

if installed_matches >/dev/null 2>&1; then
  printf '[OK] Pinned SketchyBar Lua bridge is valid (%s, %s).\n' "$revision" "$arch"
  exit 0
fi
[[ "$check_only" == no ]] || fail 'Installed bridge is missing, changed, or incompatible; rerun without --check to build the pinned version.'
[[ ! -d "$target" && ! -d "$receipt" ]] || fail 'Bridge or receipt path is a directory; refusing to replace it.'
for tool in curl tar make clang; do
  command -v "$tool" >/dev/null || fail "Required build tool not found: $tool"
done
xcode-select -p >/dev/null || fail 'Install Xcode Command Line Tools first: xcode-select --install'

# Same filesystem as the destination: publish a complete binary with one rename.
mkdir -p "$install_dir"
stage="$(mktemp -d "$install_dir/.install.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
  --connect-timeout 10 --max-time 60 --output "$stage/source.tar.gz" "$url"
actual_sha="$(shasum -a 256 "$stage/source.tar.gz" | awk '{print $1}')"
[[ "$actual_sha" == "$source_sha" ]] || fail 'Source archive checksum mismatch; existing bridge was not changed.'
mkdir "$stage/source"
tar -xzf "$stage/source.tar.gz" -C "$stage/source" --strip-components=1
# Upstream builds its bundled Lua 5.4.7; validate the result with mise's Lua 5.4.
# Do not use `make install`, which would replace the working library too early.
make -C "$stage/source" "ARCH=-arch $arch" bin/sketchybar.so
candidate="$stage/source/bin/sketchybar.so"
validate_module "$candidate" || fail 'Candidate bridge validation failed; existing bridge was not changed.'
chmod 755 "$candidate"
digest="$(shasum -a 256 "$candidate" | awk '{print $1}')"
jq -n --argjson identity "$identity" --arg sha256 "$digest" \
  '{identity: $identity, sha256: $sha256}' > "$stage/install.json"

# Publish metadata first. If the final rename fails, the old binary is intact;
# the digest mismatch prevents a stale receipt from being accepted on retry.
mv -f "$stage/install.json" "$receipt"
mv -f "$candidate" "$target"
printf '[DONE] Installed pinned SketchyBar Lua bridge: %s\n' "$target"
