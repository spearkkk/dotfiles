#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERROR] This script supports macOS only." >&2
  exit 1
fi

defaults write -g NSWindowShouldDragOnGesture -bool true
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 2.0
defaults write com.apple.dock autohide-time-modifier -float 0.5
defaults write com.apple.spaces spans-displays -bool true

killall Dock
killall SystemUIServer

echo "[DONE] Applied macOS window-drag, Dock, and shared-display Space preferences."
echo "[NEXT] Log out and log back in for 'Displays have separate Spaces' to take effect."
