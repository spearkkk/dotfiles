#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERROR] This installer supports macOS only." >&2
  exit 1
fi

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

echo "[INFO] Setting up dotfiles from $REPO_DIR"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "[WARN] Xcode Command Line Tools are required by Homebrew."
  echo "       Run: xcode-select --install"
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "[INFO] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if command -v brew >/dev/null 2>&1; then
  BREW_BIN="$(command -v brew)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN=/opt/homebrew/bin/brew
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_BIN=/usr/local/bin/brew
else
  echo "[ERROR] Homebrew installation completed but brew was not found." >&2
  exit 1
fi

eval "$("$BREW_BIN" shellenv)"

BREW_SHELLENV_LINE="eval \"\$($BREW_BIN shellenv)\""
ZPROFILE="$HOME/.zprofile"
if ! grep -Fqx "$BREW_SHELLENV_LINE" "$ZPROFILE" 2>/dev/null; then
  printf '%s\n' "$BREW_SHELLENV_LINE" >> "$ZPROFILE"
  echo "[INFO] Added Homebrew shell environment to $ZPROFILE"
fi

echo "[INFO] Installing Fish and GNU Stow..."
brew install fish stow

echo "[INFO] Creating dotfile symbolic links..."
stow --verbose --restow --target="$HOME" --dir="$REPO_DIR" .

echo
echo "[DONE] Dotfiles are linked."
echo "[NEXT] Install common tools: fish \"$REPO_DIR/bootstrap.fish\""
echo "[OPTIONAL] Change login shell to Fish: chsh -s \"$(command -v fish)\""
echo "[OPTIONAL] Apply macOS defaults: bash \"$REPO_DIR/macos-defaults.sh\""
