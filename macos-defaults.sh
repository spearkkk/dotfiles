#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERROR] This script supports macOS only." >&2
  exit 1
fi

# Global UI: allow dragging windows by holding modifier keys.
defaults write -g NSWindowShouldDragOnGesture -bool true
# Global UI: make window resizing animations nearly instant.
defaults write -g NSWindowResizeTime -float 0.001
# Global UI: disable automatic window animations.
defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
# Global UI: show tooltips immediately.
defaults write -g NSInitialToolTipDelay -integer 0
# Keyboard: use the fastest key repeat rate.
defaults write -g KeyRepeat -int 1
# Keyboard: reduce the delay before key repeat starts.
defaults write -g InitialKeyRepeat -int 15
# Text input: disable automatic spelling correction.
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
# Text input: disable automatic capitalization.
defaults write -g NSAutomaticCapitalizationEnabled -bool false
# Text input: disable smart quote substitution.
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false

# Finder/global: always show file extensions.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Dock: enable auto-hide.
defaults write com.apple.dock autohide -bool true
# Dock: remove the delay before showing the Dock.
defaults write com.apple.dock autohide-delay -float 0
# Dock: speed up the auto-hide animation.
defaults write com.apple.dock autohide-time-modifier -float 0.2
# Dock: disable app launch animations.
defaults write com.apple.dock launchanim -bool false
# Dock: hide recent applications.
defaults write com.apple.dock show-recents -bool false

# Finder: disable Finder window animations.
defaults write com.apple.finder DisableAllAnimations -bool true
# Finder: show the path bar.
defaults write com.apple.finder ShowPathbar -bool true
# Finder: show the status bar.
defaults write com.apple.finder ShowStatusBar -bool true
# Finder: use list view by default.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Finder: show hidden files.
defaults write com.apple.finder AppleShowAllFiles -bool true

# Spaces: use one shared Space across displays.
defaults write com.apple.spaces spans-displays -bool true
# Crash Reporter: disable crash report dialogs.
defaults write com.apple.CrashReporter DialogType none

# Restart affected services so most settings apply immediately.
killall Dock >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

echo "[DONE] Applied macOS defaults."
echo "[NEXT] Log out and log back in for 'Displays have separate Spaces' to take effect."
