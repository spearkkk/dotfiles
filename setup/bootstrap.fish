#!/usr/bin/env fish

set script_dir (cd (dirname (status --current-filename)); and pwd)
set layout_root (dirname "$script_dir")
set brewfile "$layout_root/setup/Brewfile"
set common_home "$layout_root/home"
set theme_colors "$common_home/.config/fish/conf.d/0010-theme-colors.fish"
set logger "$common_home/.config/fish/conf.d/0011-logger.fish"
set selected_profiles
set requested_steps
set all_steps brew sketchybar-lua sketchybar-fonts theme stow macos launchagents profiles

function usage
    echo "Usage: fish setup/bootstrap.fish [--only <step>]... [--profile <name>]..."
    echo
    echo "Without --only, run all base steps and any requested profiles."
    echo "--only <step>  Run only selected steps, once each in the order below."
    echo "--list-steps   List step names without changing anything."
    echo "Steps: brew, sketchybar-lua, sketchybar-fonts, theme, stow, macos, launchagents, profiles"
    echo "Dependencies are not run automatically; required tools must already be available."
    echo "With --only, --profile requires selecting the profiles step explicitly."
end

set index 1
while test $index -le (count $argv)
    set arg "$argv[$index]"

    switch "$arg"
        case '--profile=*'
            set value (string replace --regex '^--profile=' '' -- "$arg")
            set --append selected_profiles "$value"
        case '--only=*'
            set value (string replace --regex '^--only=' '' -- "$arg")
            set --append requested_steps "$value"
        case '--profile' '--only'
            set index (math $index + 1)
            if test $index -gt (count $argv)
                echo "[ERROR] $arg requires a value" >&2
                exit 2
            end
            if test "$arg" = --profile
                set --append selected_profiles "$argv[$index]"
            else
                set --append requested_steps "$argv[$index]"
            end
        case '--list-steps'
            printf '%s\n' $all_steps
            exit 0
        case '-h' '--help'
            usage
            exit 0
        case '*'
            echo "[ERROR] Unexpected argument: $arg" >&2
            usage >&2
            exit 2
    end

    set index (math $index + 1)
end

# Reject invalid selections before installing packages or changing any files.
for step in $requested_steps
    if not contains -- "$step" $all_steps
        echo "[ERROR] Unknown bootstrap step: '$step'. Use --list-steps." >&2
        exit 2
    end
end

for profile in $selected_profiles
    if not string match -qr '^[A-Za-z0-9_-]+$' -- "$profile"
        echo "[ERROR] Invalid profile name: '$profile'" >&2
        exit 2
    end
    if not test -d "$layout_root/profiles/$profile"
        echo "[ERROR] Profile directory not found: $layout_root/profiles/$profile" >&2
        exit 2
    end
end

set selected_steps
if test (count $requested_steps) -eq 0
    set selected_steps $all_steps[1..-2]
    if test (count $selected_profiles) -gt 0
        set --append selected_steps profiles
    end
else
    if contains -- profiles $requested_steps
        if test (count $selected_profiles) -eq 0
            echo "[ERROR] --only profiles requires --profile <name>." >&2
            exit 2
        end
    else if test (count $selected_profiles) -gt 0
        echo "[ERROR] --profile requires --only profiles when selecting steps." >&2
        exit 2
    end
    for step in $all_steps
        if contains -- "$step" $requested_steps
            set --append selected_steps "$step"
        end
    end
end

# Use the repo-local logger because bootstrap may run before dotfiles are stowed.
if test -f "$theme_colors"
    source "$theme_colors"
end

if test -f "$logger"
    source "$logger"
else
    function log_section
        echo
        echo "== $argv =="
    end

    function log_step
        echo "[STEP] $argv"
    end

    function log_info
        echo "[INFO] $argv"
    end

    function log_success
        echo "[ OK ] $argv"
    end

    function log_done
        echo "[DONE] $argv"
    end

    function log_warn
        echo "[WARN] $argv"
    end

    function log_error
        echo "[ERR ] $argv" >&2
    end
end

log_section "Bootstrap"
log_info "Selected steps: "(string join ', ' -- $selected_steps)

if contains -- brew $selected_steps
    # Make sure Homebrew is available even before full dotfiles are stowed.
    if not type -q brew
        if test -x /opt/homebrew/bin/brew
            eval (/opt/homebrew/bin/brew shellenv)
        else if test -x /usr/local/bin/brew
            eval (/usr/local/bin/brew shellenv)
        end
    end

    if not type -q brew
        log_error "Homebrew is required. Run: bash $script_dir/install.sh"
        exit 1
    end

    if not test -f "$brewfile"
        log_error "Brewfile not found: $brewfile"
        exit 1
    end

    log_warn "Make sure you are signed in to the Mac App Store before installing MAS apps."

    log_step "Install Brewfile"
    log_info "Source: $brewfile"
    log_info "Homebrew auto-update is disabled for repeatable bootstrap runs. Run `brew update` manually when needed."

    if not env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --file "$brewfile"
        log_error "Brewfile installation failed."
        exit 1
    end

    log_success "Brewfile installation complete."
end

if contains -- sketchybar-lua $selected_steps
    log_step "Install pinned SketchyBar Lua bridge"
    if not bash "$script_dir/install-sketchybar-lua.sh"
        log_error "SketchyBar Lua setup failed."
        exit 1
    end
end

if contains -- sketchybar-fonts $selected_steps
    log_step "Install pinned SketchyBar icon font"
    if not bash "$script_dir/install-sketchybar-fonts.sh"
        log_error "SketchyBar font setup failed."
        exit 1
    end
end

if contains -- theme $selected_steps
    log_step "Generate theme files"
    if test -x "$script_dir/set-theme.sh"
        if not bash "$script_dir/set-theme.sh"
            log_error "Theme generation failed."
            exit 1
        end

        if test -f "$theme_colors"
            source "$theme_colors"
        end

        log_success "Theme files generated."
    else
        log_error "Theme setup script is missing or not executable: $script_dir/set-theme.sh"
        exit 1
    end
end

if contains -- stow $selected_steps
    log_step "Link base dotfiles"
    if not type -q stow
        log_error "GNU Stow is required for the stow step. Install it first or include --only brew."
        exit 1
    end

    if not test -d "$common_home"
        log_error "Base home directory not found: $common_home"
        exit 1
    end

    log_info "Source: $common_home"
    log_info "Target: $HOME"

    if not bash "$script_dir/prepare-zprofile.sh"
        log_error "Could not prepare .zprofile for Stow."
        exit 1
    end

    if not stow --verbose --restow --no-folding --target="$HOME" --dir="$common_home" .
        log_error "Failed to stow common dotfiles."
        exit 1
    end

    log_success "Base dotfiles linked."

    set bootstrap_brew "$HOME/.config/fish/conf.d/0000-bootstrap-homebrew.fish"
    set managed_brew "$HOME/.config/fish/conf.d/0000-homebrew.fish"

    if test -f "$bootstrap_brew"
        if test -e "$managed_brew"; and grep -q "Managed by setup/install.sh bootstrap phase." "$bootstrap_brew"
            log_step "Remove bootstrap Homebrew fish config"
            rm "$bootstrap_brew"
            log_success "Removed: $bootstrap_brew"
        else
            log_info "Keeping bootstrap Homebrew fish config until managed 0000-homebrew.fish is linked."
        end
    end
end

if contains -- macos $selected_steps
    log_step "Apply macOS defaults"
    if test -x "$script_dir/set-macos.sh"
        if not bash "$script_dir/set-macos.sh"
            log_error "macOS defaults failed."
            exit 1
        end

        log_success "macOS defaults applied."
    else
        log_error "macOS setup script is missing or not executable: $script_dir/set-macos.sh"
        exit 1
    end
end

if contains -- launchagents $selected_steps
    log_step "Install and restart LaunchAgents"
    if test -f "$script_dir/launchagents/Makefile"
        if not make -C "$script_dir/launchagents" bootstrap
            log_error "LaunchAgent bootstrap failed."
            exit 1
        end

        log_success "LaunchAgents ready."
    else
        log_error "LaunchAgent Makefile is missing: $script_dir/launchagents/Makefile"
        exit 1
    end
end

if contains -- profiles $selected_steps
    for profile in $selected_profiles
        log_step "Apply profile: $profile"
        if not fish "$script_dir/profile.fish" "$profile"
            log_error "Profile setup failed: $profile"
            exit 1
        end
    end
end

log_section "Next steps"
log_info "Optional profile switch: fish $script_dir/profile.fish personal|work"
log_info "Update Homebrew metadata when wanted: brew update"
log_done "Bootstrap complete."
