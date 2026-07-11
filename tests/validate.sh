#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command fish
require_command bash
require_command plutil
require_command stow
require_command brew
require_command rg
require_command luac

cd "$REPO_DIR"

while IFS= read -r file; do
  fish --no-execute "$file"
done < <(rg --files -g '*.fish')

while IFS= read -r file; do
  bash -n "$file"
done < <(rg -l '^#!.*\b(bash|sh)\b' -g '!**/.git/**')

while IFS= read -r file; do
  luac -p "$file"
done < <(rg --files -g '*.lua')

plutil -lint launchagents/Library/LaunchAgents/*.plist
mkdir -p "$TMP_DIR/home"
stow --simulate --verbose --target="$TMP_DIR/home" --dir="$REPO_DIR" .
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --all --file Brewfile >/dev/null
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --all --file Brewfile.work >/dev/null

secret_pattern='\b(api[_-]?key|secret|token|password|passwd|authorization)\b\s*[:=]\s*[^[:space:]]{8,}|\bBearer\s+[A-Za-z0-9._~+/=-]{16,}|BEGIN [A-Z ]*PRIVATE'
if rg -n -i --hidden \
  -g '!**/.git/**' \
  -g '!**/alfred/**' \
  -g '!**/*.png' \
  -g '!**/*.gif' \
  -g '!**/*.icns' \
  -g '!**/*.pdf' \
  "$secret_pattern" \
  .config .local launchagents bootstrap.fish install.sh macos-defaults.sh Brewfile Brewfile.work; then
  echo "Potential secret found in tracked configuration." >&2
  exit 1
fi

if [[ "${RUN_NVIM_INTEGRATION:-0}" == "1" ]]; then
  require_command nvim
  export XDG_CACHE_HOME="$TMP_DIR/cache"
  export XDG_DATA_HOME="$TMP_DIR/data"
  export XDG_STATE_HOME="$TMP_DIR/state"
  if ! nvim -i NONE --headless \
    '+Lazy! sync' \
    '+lua if vim.fn.exists(":NvimTreeToggle") ~= 2 then vim.cmd("cquit 1") end' \
    '+NvimTreeToggle' \
    '+qa!' >"$TMP_DIR/nvim.log" 2>&1; then
    cat "$TMP_DIR/nvim.log" >&2
    exit 1
  fi
fi

echo "Validation passed."
