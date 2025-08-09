# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a macOS dotfiles repository that manages system configuration using GNU Stow for symlink management. The setup focuses on a modern terminal environment with tiling window management and a customizable status bar.

## Setup Commands

### Initial Installation
```bash
# Make install script executable and run
chmod +x ./install.sh
./install.sh
```

### Bootstrap Environment
```bash
# Bootstrap with tool installation (use --work or --personal for specific profiles)
./bootstrap.fish
```

### Apply Dotfiles
```bash
# Use stow to create symlinks (recommended method)
stow --ignore='(\.DS_Store$)|resources' --verbose --restow --target="$HOME" .

# Alternative with short flags
stow --ignore='(\.DS_Store$)|resources' -v -R -t "$HOME" .
```

### Post-Setup Commands
```bash
# Make sketchybar plugins executable
chmod +x ~/.config/sketchybar/plugins/*

# Start Aerospace window manager
open -a Aerospace

# Reload sketchybar
sketchybar --reload
```

## Architecture Overview

### Core Components

1. **Shell Environment (Fish Shell)**
   - Configuration in `.config/fish/`
   - Custom functions for common tasks (`_c.fish`, `ctx.fish`, `pomo.fish`)
   - Package management helpers (`_install_if_missing.fish`, `_tap_if_missing.fish`)
   - Integration with starship prompt, zoxide, and fzf

2. **Window Management (Aerospace)**
   - Configuration in `.aerospace.toml`
   - Tiling window manager with vim-like keybindings
   - Workspace-specific app assignments
   - Integration with sketchybar for workspace display

3. **Status Bar (Sketchybar)**
   - Modular configuration in `.config/sketchybar/`
   - Items include aerospace workspaces, battery, media, pomodoro timer, weather
   - Custom plugins for dynamic content updates
   - Icon mapping system for app-specific icons

4. **Terminal Environment**
   - Neovim configuration with Lua-based plugin management
   - Starship prompt with custom theming
   - Git configuration with work/personal profile switching

### Key Configuration Files

- `.gitconfig`: Git settings with conditional work profile inclusion
- `starship.toml`: Starship prompt configuration with custom theme
- `.aerospace.toml`: Window manager keybindings and app rules
- `.config/fish/`: Shell functions and environment setup
- `.config/sketchybar/sketchybarrc`: Status bar main configuration
- `.config/nvim/init.lua`: Neovim entry point

### Tool Installation System

The bootstrap system uses Fish shell functions to:
- Install Homebrew packages and casks
- Manage tap repositories
- Handle both core tools and optional work/personal tool sets
- Configure fisher plugins for Fish shell

### Symlink Management

Uses GNU Stow to create symlinks from the dotfiles directory to the home directory, with exclusions for macOS-specific files and resource directories.