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

if test -f ~/.config/fish/functions/_install_mise_if_missing.fish
    source ~/.config/fish/functions/_install_mise_if_missing.fish
end

if test -f ~/.config/fish/functions/_install_fisher_if_missing.fish
    source ~/.config/fish/functions/_install_fisher_if_missing.fish
end

if test -f ~/.config/fish/functions/_install_mas_if_missing.fish
    source ~/.config/fish/functions/_install_mas_if_missing.fish
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
#  Function: Unified package installer
# -------------------------
function install_package
    set -l entry $argv[1]
    set -l parts (string split ":" $entry)
    
    if test (count $parts) -lt 2
        log_warn "Invalid entry format: $entry (expected: manager:name:extra_args...)"
        return 1
    end

    set -l manager $parts[1]
    set -l name $parts[2]
    
    switch $manager
        case "brew"
            # Format: brew:name:is_cask:tap
            set -l is_cask false
            set -l tap ""
            if test (count $parts) -ge 3; set is_cask $parts[3]; end
            if test (count $parts) -ge 4; set tap $parts[4]; end
            _install_if_missing brew $name $is_cask $tap
            
        case "mise"
            # Format: mise:name:version (version optional)
            set -l version ""
            if test (count $parts) -ge 3; set version $parts[3]; end
            _install_mise_if_missing $name $version
            
        case "fisher"
            # Format: fisher:plugin_name
            _install_fisher_if_missing $name
            
        case "mas"
            # Format: mas:app_id
            _install_mas_if_missing $name
            
        case '*'
            log_warn "Unknown package manager: $manager for $name"
            return 1
    end
end

log_info "🔧 Bootstrapping dotfiles environment..."

# Define core tools with format: manager:name:extra_args
set -l core_tools \
    "brew:mise:false:" \
    "brew:fd:false:" \
    "brew:ripgrep:false:" \
    "brew:starship:false:" \
    "brew:zoxide:false:" \
    "brew:font-hack-nerd-font:true:" \
    "brew:mas:false:" \
    "brew:aerospace:true:nikitabobko/tap" \
    "brew:sketchybar:false:felixkratz/formulae" \
    "brew:sf-symbols:true:" \
    "brew:borders:false:felixkratz/formulae" \
    "brew:eza:false:" \
    "brew:bat:false:" \
    "brew:deepl:true:" \
    "brew:wakatime:true:" \
    "brew:uutils-coreutils:false:" \
    "brew:macism:false:laishulu/homebrew" \
    "brew:lua:false:" \
    "brew:lazygit:false:" \
    "brew:yazi:false:" \
    "brew:ffmpeg:false:" \
    "brew:sevenzip:false:" \
    "brew:jq:false:" \
    "brew:poppler:false:" \
    "brew:imagemagick:false:" \
    "brew:resvg:false:" \
    "brew:font-symbols-only-nerd-font:true:" \
    "brew:neovim:false:" \
    "brew:tree:false:" \
    "brew:tinty:false:tinted-theming/tinted" \
    "brew:btop:false:" \
    "brew:duf:false:" \
    "brew:k9s:false:" \
    "brew:1password:true:" \
    "brew:1password-cli:true:" \
    "brew:alfred:true:" \
    "brew:appcleaner:true:" \
    "brew:bettertouchtool:true:" \
    "brew:contexts:true:" \
    "brew:font-sf-pro:true:" \
    "brew:google-chrome:true:" \
    "brew:keka:true:" \
    "brew:monitorcontrol:true:" \
    "brew:obsidian:true:" \
    "brew:sublime-text:true:" \
    "fisher:PatrickF1/fzf.fish" \
    "mas:553245401" \    # Friendly Streaming
    "mas:1398373917" \   # UpNote
    "mas:904280696"      # Things

set -l work_tools \
    "brew:lens:true:" \
    "brew:miro:true:" \
    "brew:slack:true:" \
    "brew:git-lfs:false:" 

set -l personal_tools 

for entry in $core_tools
    install_package $entry
end

log_success "✅ Core tools installation complete!"

# -------------------------
#  Personal Tools (Optional)
# -------------------------
if $install_personal
    log_info "🎨 Installing personal tools..."
    for entry in $personal_tools
        install_package $entry
    end
    log_success "✅ Personal tools installation complete!"
end

# -------------------------
#  Work Tools (Optional)
# -------------------------
if $install_work
    log_info "💼 Installing work tools..."
    for entry in $work_tools
        install_package $entry
    end
    log_success "✅ Work tools installation complete!"
end

# Exit quietly if non-interactive shell
status is-interactive; or exit
