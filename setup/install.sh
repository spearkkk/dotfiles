#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERROR] This installer supports macOS only." >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[INFO] Setting up base macOS tools for dotfiles from $LAYOUT_ROOT"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "[WARN] Xcode Command Line Tools are required by Homebrew and git."
  echo "       Run: xcode-select --install"
  exit 1
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

# Keep repeat runs fast and deterministic. Run `brew update` manually when needed.
export HOMEBREW_NO_AUTO_UPDATE=1

BREW_SHELLENV_LINE="eval \"\$($BREW_BIN shellenv)\""
ZPROFILE="$HOME/.zprofile"
if ! grep -Fqx "$BREW_SHELLENV_LINE" "$ZPROFILE" 2>/dev/null; then
  printf '%s\n' "$BREW_SHELLENV_LINE" >> "$ZPROFILE"
  echo "[INFO] Added Homebrew shell environment to $ZPROFILE"
fi

echo "[INFO] Installing fish shell..."
brew install fish

BREW_PREFIX="$($BREW_BIN --prefix)"
FISH_BIN="$BREW_PREFIX/bin/fish"

if [[ ! -x "$FISH_BIN" ]]; then
  echo "[ERROR] fish installation completed but Homebrew fish was not found: $FISH_BIN" >&2
  exit 1
fi

if ! grep -qxF "$FISH_BIN" /etc/shells; then
  echo "[INFO] Adding fish to /etc/shells: $FISH_BIN"
  echo "$FISH_BIN" | sudo tee -a /etc/shells >/dev/null
fi

USER_RECORD="/Users/$(id -un)"
CURRENT_USER_SHELL="$(dscl . -read "$USER_RECORD" UserShell 2>/dev/null | awk '{print $2}' || true)"

if [[ "$CURRENT_USER_SHELL" == "$FISH_BIN" ]]; then
  echo "[INFO] Login shell is already fish: $FISH_BIN"
else
  echo "[INFO] Changing login shell to fish: $FISH_BIN"
  chsh -s "$FISH_BIN"
fi

echo "[INFO] Installing Ghostty..."
brew install --cask ghostty

FISH_CONF_D="$HOME/.config/fish/conf.d"
FISH_BREW_CONF="$FISH_CONF_D/0000-bootstrap-homebrew.fish"

mkdir -p "$FISH_CONF_D"

if [[ -f "$FISH_BREW_CONF" ]]; then
  echo "[INFO] Fish Homebrew config already exists: $FISH_BREW_CONF"
else
  echo "[INFO] Creating Fish Homebrew config: $FISH_BREW_CONF"
  cat > "$FISH_BREW_CONF" <<EOF_FISH
#!/usr/bin/env fish

# Managed by setup/install.sh bootstrap phase.
# Minimal Homebrew environment for Fish before full dotfiles setup.
set -l brew_bin "$BREW_PREFIX/bin/brew"

if test -x "\$brew_bin"
    eval ("\$brew_bin" shellenv)
else if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
else if test -x /usr/local/bin/brew
    eval (/usr/local/bin/brew shellenv)
end
EOF_FISH
fi

echo
echo "[DONE] Base tools are ready."
echo "[NEXT] Sign in to the Mac App Store before installing MAS apps."
echo "       Open App Store → Account → Sign In."
echo "[NEXT] Open Ghostty and continue dotfiles setup from fish."
echo "[OPTIONAL] Apply macOS defaults: bash \"$SCRIPT_DIR/set-macos.sh\""
