#!/usr/bin/env fish

# Safe source helpers (silent fallback)
if test -f ~/.config/fish/conf.d/colors.fish
    source ~/.config/fish/conf.d/colors.fish
end

if test -f ~/.config/fish/conf.d/logger.fish
    source ~/.config/fish/conf.d/logger.fish
end

if test -f ~/.config/fish/functions/_install_if_missing.fish
    source ~/.config/fish/functions/_install_if_missing.fish
end

if test -f ~/.config/fish/functions/_tap_if_missing.fish
    source ~/.config/fish/functions/_tap_if_missing.fish
end

# Fallback log functions (if logger.fish didn't define them)
if not functions -q log_info
    function log_info; echo "[INFO ] $argv"; end
end
if not functions -q log_warn
    function log_warn; echo "[WARN ] $argv"; end
end
if not functions -q log_success
    function log_success; echo "[ OK  ] $argv"; end
end
if not functions -q log_error
    function log_error; echo "[ERROR] $argv"; end
end

log_info "🔧 Bootstrapping dotfiles environment..."

# Define core tools: name:is_cask:optional_tap
set -l core_tools \
    "mise:false:" \
    "fd:false:" \
    "ripgrep:false:" \
    "starship:false:" \
    "zoxide:false:" \
    "font-hack-nerd-font:true:" \
    "mas:false:" \
    "aerospace:true:nikitabobko/tap" \
    "sketchybar:false:felixkratz/formulae" \
    "sf-symbols:true:" \
    "borders:false:felixkratz/formulae" \
    "eza:false:" \
    "bat:false:" \
    "deepl:true:"

for entry in $core_tools
    set -l parts (string split ":" $entry)

    if test (count $parts) -lt 2
        log_warn "Invalid entry in core_tools: $entry. Skipping."
        continue
    end

    set -l name $parts[1]
    set -l is_cask $parts[2]
    set -l tap ""

    if test (count $parts) -ge 3
        set tap $parts[3]
    end

    _install_if_missing brew $name $is_cask $tap
end

log_success "✅ Core tools installation complete!"

# Exit quietly if non-interactive shell
status is-interactive; or exit