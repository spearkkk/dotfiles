#!/usr/bin/env fish

set script_dir (cd (dirname (status --current-filename)); and pwd)
set layout_root (dirname "$script_dir")
set theme_colors "$layout_root/home/.config/fish/conf.d/0010-theme-colors.fish"
set logger "$layout_root/home/.config/fish/conf.d/0011-logger.fish"

if test -f "$theme_colors"
    source "$theme_colors"
end

if test -f "$logger"
    source "$logger"
else
    function log_section; echo; echo "== $argv =="; end
    function log_step; echo "[STEP] $argv"; end
    function log_info; echo "[INFO] $argv"; end
    function log_success; echo "[ OK ] $argv"; end
    function log_done; echo "[DONE] $argv"; end
    function log_error; echo "[ERR ] $argv" >&2; end
end

function usage
    echo "Usage: fish setup/profile.fish [--remove] <profile>"
    echo
    echo "Applying a profile removes other known profile overlays first."
    echo
    echo "Available profiles:"
    for dir in "$layout_root"/profiles/*
        if test -d "$dir"
            echo "  "(basename "$dir")
        end
    end
end

set remove_only no
set profile

for arg in $argv
    switch "$arg"
        case '--remove'
            set remove_only yes
        case '-h' '--help'
            usage
            exit 0
        case '*'
            if test -z "$profile"
                set profile "$arg"
            else
                log_error "Unexpected argument: $arg"
                usage
                exit 2
            end
    end
end

if test -z "$profile"
    usage
    exit 2
end

if string match -qr '[^A-Za-z0-9_-]' -- "$profile"
    log_error "Invalid profile name: $profile"
    exit 2
end

set profile_dir "$layout_root/profiles/$profile"
set profile_home "$profile_dir/home"
set profile_setup "$profile_dir/setup/bootstrap.fish"

if not test -d "$profile_dir"
    log_error "Unknown profile: $profile"
    usage
    exit 1
end

if not type -q stow
    log_error "GNU Stow is required to apply profiles."
    exit 1
end

function unstow_profile --argument-names name home_dir
    if not test -d "$home_dir"
        return 0
    end

    log_step "Remove profile overlay: $name"
    if not stow --verbose --delete --no-folding --target="$HOME" --dir="$home_dir" .
        log_error "Failed to remove profile overlay: $name"
        return 1
    end
end

log_section "Profile: $profile"

if test "$remove_only" = yes
    unstow_profile "$profile" "$profile_home"; or exit 1
    log_done "Profile removed: $profile"
    exit 0
end

# Profiles are overlays with potentially conflicting files such as ~/.gitconfig.
# Remove other known overlays first so applying a profile behaves like switching.
for dir in "$layout_root"/profiles/*
    if not test -d "$dir"
        continue
    end

    set other (basename "$dir")
    if test "$other" = "$profile"
        continue
    end

    unstow_profile "$other" "$dir/home"; or exit 1
end

if test -d "$profile_home"
    log_step "Link profile dotfiles"
    log_info "Source: $profile_home"
    log_info "Target: $HOME"

    if not stow --verbose --restow --no-folding --target="$HOME" --dir="$profile_home" .
        log_error "Failed to stow profile: $profile"
        exit 1
    end

    log_success "Profile dotfiles linked."
else
    log_info "No profile home directory: $profile_home"
end

if test -x "$profile_setup"
    log_step "Run profile setup"
    if not fish "$profile_setup"
        log_error "Profile setup script failed: $profile_setup"
        exit 1
    end
end

log_done "Profile complete: $profile"
