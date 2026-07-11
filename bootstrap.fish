#!/usr/bin/env fish

# Safe source helpers (silent fallback)
if test -f ~/.config/fish/conf.d/colors.fish
    source ~/.config/fish/conf.d/colors.fish
end

if test -f ~/.config/fish/conf.d/logger.fish
    source ~/.config/fish/conf.d/logger.fish
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
set install_launchagents false
set -l dotfiles_dir (cd (dirname (status --current-filename)); and pwd)

for arg in $argv
    switch $arg
        case --personal
            set install_personal true
        case --work
            set install_work true
        case --launchagents
            set install_launchagents true
        case '*'
            log_warn "Unknown argument: $arg"
    end
end

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
        case "fisher"
            # Format: fisher:plugin_name
            _install_fisher_if_missing "$name"
            return $status
            
        case "mas"
            # Format: mas:app_id
            _install_mas_if_missing "$name"
            return $status
            
        case '*'
            log_warn "Unknown package manager: $manager for $name"
            return 1
    end
end

function install_brew_bundle
    set -l label $argv[1]
    set -l brewfile $argv[2]

    if not type -q brew
        log_error "Homebrew is required to install $label."
        return 1
    end

    if not test -f "$brewfile"
        log_error "Brewfile not found: $brewfile"
        return 1
    end

    log_info "Installing $label from $brewfile..."
    if brew bundle install --file "$brewfile"
        log_success "✅ $label installation complete!"
        return 0
    end

    log_error "$label installation failed."
    return 1
end

function install_group
    set -l label $argv[1]
    set -l entries $argv[2..-1]
    set -l failures

    for entry in $entries
        if not install_package "$entry"
            set -a failures "$entry"
        end
    end

    if test (count $failures) -gt 0
        log_error "$label installation failed:"
        for entry in $failures
            log_error "  $entry"
        end
        return 1
    end

    log_success "✅ $label installation complete!"
    return 0
end

log_info "🔧 Bootstrapping dotfiles environment..."

set -l core_tools \
    "fisher:PatrickF1/fzf.fish" \
    "mas:553245401" \    # Friendly Streaming
    "mas:1398373917" \   # UpNote
    "mas:904280696"      # Things

set -l personal_tools
set -l failed_groups

if not install_brew_bundle "Core Homebrew packages" "$dotfiles_dir/Brewfile"
    set -a failed_groups "Core Homebrew packages"
end

if not install_group "Core non-Homebrew tools" $core_tools
    set -a failed_groups "Core non-Homebrew tools"
end

# -------------------------
#  Personal Tools (Optional)
# -------------------------
if $install_personal
    log_info "🎨 Installing personal tools..."
    if not install_group "Personal tools" $personal_tools
        set -a failed_groups "Personal tools"
    end
end

# -------------------------
#  Work Tools (Optional)
# -------------------------
if $install_work
    log_info "💼 Installing work tools..."
    if not install_brew_bundle "Work Homebrew packages" "$dotfiles_dir/Brewfile.work"
        set -a failed_groups "Work Homebrew packages"
    end
end

# -------------------------
#  Generate fish colors from Simhae palette
# -------------------------
set -l fish_color_gen "$dotfiles_dir/simhae/generate_fish_colors.sh"

if test -x "$fish_color_gen"
    if command bash "$fish_color_gen"
        log_success "🎨 Generated fish colors from simhae-pelagic palette"
    else
        log_warn "Failed to generate fish colors: $fish_color_gen"
        set -a failed_groups "Fish color generation"
    end
else
    log_warn "Fish color generator not found or not executable: $fish_color_gen"
    set -a failed_groups "Fish color generation"
end

if test (count $failed_groups) -gt 0
    log_error "Bootstrap completed with failures: "(string join ", " $failed_groups)
    exit 1
end

if $install_launchagents
    set -l launchagents_bootstrap "$dotfiles_dir/launchagents/bootstrap.fish"
    if not test -x "$launchagents_bootstrap"
        log_error "LaunchAgent bootstrap script is missing or not executable: $launchagents_bootstrap"
        exit 1
    end

    log_info "Registering SketchyBar LaunchAgents..."
    if not command fish "$launchagents_bootstrap"
        log_error "Failed to register SketchyBar LaunchAgents."
        exit 1
    end
end

log_success "✅ Bootstrap completed successfully!"

# Exit quietly if non-interactive shell.
status is-interactive; or exit 0
