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

set install_personal false
set install_work false

for arg in $argv
    switch $arg
        case --personal
            set install_personal true
        case --work
            set install_work true
        case '*'
            log_warn "Unknown argument: $arg"
    end
end

# -------------------------
#  Function: Ensure fisher plugin
# -------------------------
function ensure_fisher_plugin
    set plugin $argv[1]

    if not type -q fisher
        log_info "Installing fisher..."
        curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
    end

    if not fisher list | grep -q "$plugin"
        log_info "Installing fisher plugin: $plugin"
        fisher install $plugin
        log_success "$plugin installed!"
    else
        log_info "Fisher plugin already installed: $plugin"
    end
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
    "deepl:true:" \
    "wakatime:true:" \
    "uutils-coreutils:false:" \
    "macism:false:laishulu/homebrew" \
    "lua:false:" \
    # yazi
    "yazi:false:" \
    "ffmpeg:false:" \
    "sevenzip:false:" \
    "jq:false:" \
    "poppler:false:" \
    "imagemagick:false:" \
    "resvg:false:" \
    "font-symbols-only-nerd-font:true:" \
    "neovim:false:" \
    "tree:false:" \
    "tinty:false:tinted-theming/tinted"

set -l work_tools 

set -l personal_tools 

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

ensure_fisher_plugin PatrickF1/fzf.fish

log_success "✅ Core tools installation complete!"

# -------------------------
#  Personal Tools (Optional)
# -------------------------
if $install_personal

    log_info "🎨 Installing personal tools..."
    for entry in $personal_tools
        set -l parts (string split ":" $entry)
        set -l name $parts[1]
        set -l is_cask $parts[2]
        set -l tap ""
        if test (count $parts) -ge 3
            set tap $parts[3]
        end
        _install_if_missing $name $is_cask $tap
    end
    log_success "✅ Personal tools installation complete!"
end

# -------------------------
#  Work Tools (Optional)
# -------------------------
if $install_work

    log_info "💼 Installing work tools..."
    for entry in $work_tools
        set -l parts (string split ":" $entry)
        set -l name $parts[1]
        set -l is_cask $parts[2]
        set -l tap ""
        if test (count $parts) -ge 3
            set tap $parts[3]
        end
        _install_if_missing $name $is_cask $tap
    end
    log_success "✅ Work tools installation complete!"
end

# Exit quietly if non-interactive shell
status is-interactive; or exit
