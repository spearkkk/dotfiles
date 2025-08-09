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

    # Install GNU Stow for symlink management
    echo "[INFO] Installing GNU Stow for dotfile symlink management..."
    echo "       Stow creates symbolic links from dotfiles to your home directory"
    brew install stow

    # Configure dotfiles with GNU Stow
    DOTFILES_DIR="$HOME/.dotfiles"
    if [ -d "$DOTFILES_DIR" ]; then
        echo "[INFO] Creating symbolic links for dotfiles..."
        echo "       This will link configuration files from $DOTFILES_DIR to your home directory"
        echo "       Files like .gitconfig, .config/*, etc. will be symlinked"
        
        cd "$DOTFILES_DIR"
        
        # Use stow with proper options:
        # --ignore: Skip .DS_Store files and resources directory
        # --verbose: Show detailed output of what's being linked
        # --restow: Remove existing links and recreate them (safe update)
        # --target: Explicitly set target directory to home
        echo "[INFO] Running: stow --ignore='(\.DS_Store$)|resources' --verbose --restow --target=$HOME ."
        stow --ignore='(\.DS_Store$)|resources' --verbose --restow --target="$HOME" .
        
        if [ $? -eq 0 ]; then
            echo "[✅ SUCCESS] Dotfiles have been successfully symlinked to your home directory"
            echo "             You can now edit files in $DOTFILES_DIR and changes will be reflected immediately"
        else
            echo "[❌ ERROR] Failed to create symlinks. Please check for conflicts and try again"
            echo "           You may need to backup existing config files first"
            echo "           Common conflicts: ~/.gitconfig, ~/.config/ directories"
        fi
    else
        echo "[WARN] Dotfiles directory not found at $DOTFILES_DIR"
        echo "       Please ensure this script is run from within the dotfiles repository"
    fi

    # Install iTerm2
    echo "[INFO] Installing iTerm2..."
    brew install --cask iterm2

    # Apply iTerm2 preferences from dotfiles
    echo "[INFO] Setting iTerm2 preferences from dotfiles..."
    ITERM_CONFIG_DIR="$HOME/.config/iterm2"
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM_CONFIG_DIR"
    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

    # To enable to move window with three figners without click
    defaults write -g NSWindowShouldDragOnGesture -bool true

    echo
    echo "[✅ SETUP COMPLETE] Restart your terminal or open iTerm2."
    echo "[👉 NEXT STEP] Inside the new fish shell, run:"
    echo "    fish ~/.dotfiles/bootstrap.fish"
    echo
fi
