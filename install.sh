#!/bin/bash

# Referred from: https://github.com/Masstronaut/dotfiles

if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "[INFO] Detected macOS. Starting setup..."

    # Check for Xcode CLI Tools
    if ! xcode-select -p &> /dev/null; then
        echo "[WARN] Xcode Command Line Tools not found. Please install manually:"
        echo "→ Run: xcode-select --install"
    fi

    # Check and install Homebrew
    if ! command -v brew &> /dev/null; then
        echo "[INFO] Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zprofile
        export PATH="/opt/homebrew/bin:$PATH"
    fi

    # Install fish shell
    echo "[INFO] Installing fish shell via Homebrew..."
    brew install fish

    # Add fish to /etc/shells if not already present
    FISH_PATH=$(command -v fish)
    if ! grep -q "$FISH_PATH" /etc/shells; then
        echo "$FISH_PATH" | sudo tee -a /etc/shells
    else
        echo "[INFO] Fish already present in /etc/shells"
    fi

    # Set fish as default shell
    echo "[INFO] Changing default shell to fish..."
    chsh -s "$FISH_PATH"
    echo "[DONE] Fish is now your default shell. Please restart your terminal."

    # Install stow
    echo "[INFO] Installing stow for dotfile symlinks..."
    brew install stow

    # Run stow to symlink all directories inside ~/.dotfiles
    # cd ~/.dotfiles/; stow --ignore='(\.DS_Store$)' -v -R .
    DOTFILES_DIR="$HOME/.dotfiles"
    if [ -d "$DOTFILES_DIR" ]; then
        echo "[INFO] Symlinking dotfiles from $DOTFILES_DIR..."
        cd "$DOTFILES_DIR"
        stow -v -R .
    else
        echo "[WARN] Dotfiles directory not found at $DOTFILES_DIR"
    fi

    # Install iTerm2
    echo "[INFO] Installing iTerm2..."
    brew install --cask iterm2

    # Apply iTerm2 preferences from dotfiles
    echo "[INFO] Setting iTerm2 preferences from dotfiles..."
    ITERM_CONFIG_DIR="$HOME/.config/iterm2"
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM_CONFIG_DIR"
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

    echo
    echo "[✅ SETUP COMPLETE] Restart your terminal or open iTerm2."
    echo "[👉 NEXT STEP] Inside the new fish shell, run:"
    echo "    fish ~/.dotfiles/bootstrap.fish"
    echo
fi