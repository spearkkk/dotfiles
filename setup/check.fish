#!/usr/bin/env fish

set script_dir (cd (dirname (status --current-filename)); and pwd)
set repo_root (dirname "$script_dir")
set theme_colors "$repo_root/home/.config/fish/conf.d/0010-theme-colors.fish"
set logger "$repo_root/home/.config/fish/conf.d/0011-logger.fish"

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
    function log_warn; echo "[WARN] $argv"; end
    function log_error; echo "[ERR ] $argv" >&2; end
end

function usage
    echo "Usage: fish setup/check.fish"
    echo
    echo "Runs syntax checks, LaunchAgent plist validation, stow simulations, and a high-signal secret scan."
end

for arg in $argv
    switch "$arg"
        case '-h' '--help'
            usage
            exit 0
        case '*'
            log_error "Unexpected argument: $arg"
            usage
            exit 2
    end
end

set failures 0
set temp_parent /tmp
if set -q TMPDIR; and test -n "$TMPDIR"
    set temp_parent "$TMPDIR"
end

function mark_fail --argument-names message
    log_error "$message"
    set --global failures (math $failures + 1)
end

function require_command --argument-names command_name
    if not type -q "$command_name"
        mark_fail "Missing required command: $command_name"
        return 1
    end
    return 0
end

function check_files --argument-names label command_name flag
    set dirs $argv[4..-1]
    set files

    for dir in $dirs
        if test -d "$dir"
            set --append files (find "$dir" -type f -name "*.$label" -print)
        end
    end

    if test (count $files) -eq 0
        log_info "No .$label files found."
        return 0
    end

    log_info "Checking "(count $files)" .$label files."

    for file in $files
        if not command "$command_name" "$flag" "$file"
            mark_fail "$label syntax failed: $file"
        end
    end
end

function stow_base_simulate --argument-names target_dir
    log_info "Base source: $repo_root/home"
    if not stow --simulate --verbose --restow --no-folding --target="$target_dir" --dir="$repo_root/home" . >/dev/null 2>&1 2>&1
        mark_fail "Stow simulation failed: base"
    end
end

function stow_profile_simulate --argument-names profile source_dir
    if not test -d "$source_dir"
        log_info "Skip missing profile package: $profile ($source_dir)"
        return 0
    end

    set target_dir (mktemp -d "$temp_parent/dotfiles-check-profile.XXXXXX")
    if test -z "$target_dir"
        mark_fail "Failed to create temporary stow target for profile: $profile"
        return 1
    end

    stow --no-folding --target="$target_dir" --dir="$repo_root/home" . >/dev/null 2>&1
    set base_status $status
    if test $base_status -ne 0
        rm -rf "$target_dir"
        mark_fail "Failed to stage base dotfiles for profile simulation: $profile"
        return 1
    end

    log_info "Profile source: $source_dir"
    if not stow --simulate --verbose --restow --no-folding --target="$target_dir" --dir="$source_dir" . >/dev/null 2>&1
        mark_fail "Stow simulation failed: $profile"
    end

    rm -rf "$target_dir"
end

log_section "Dotfiles check"

log_step "Check required tools"
require_command fish
require_command bash
require_command find
require_command stow
if test (uname) = Darwin
    require_command plutil
end
if not type -q luac
    log_warn "luac not found; Lua syntax checks will be skipped."
end
if not type -q rg
    log_warn "ripgrep not found; secret scan will be skipped."
end

log_step "Fish syntax"
check_files fish fish -n \
    "$repo_root/setup" \
    "$repo_root/home" \
    "$repo_root/profiles"

log_step "Shell syntax"
check_files sh bash -n \
    "$repo_root/setup" \
    "$repo_root/home" \
    "$repo_root/profiles"

if type -q luac
    log_step "Lua syntax"
    check_files lua luac -p \
        "$repo_root/home" \
        "$repo_root/profiles"
end

if test (uname) = Darwin
    log_step "LaunchAgent plist validation"
    if test -f "$repo_root/setup/launchagents/Makefile"
        if not make -C "$repo_root/setup/launchagents" validate
            mark_fail "LaunchAgent validation failed."
        end
    else
        mark_fail "LaunchAgent Makefile is missing."
    end
end

log_step "Stow simulation: base"
set base_stow_target (mktemp -d "$temp_parent/dotfiles-check-base.XXXXXX")
if test -z "$base_stow_target"
    mark_fail "Failed to create temporary stow target for base."
else
    stow_base_simulate "$base_stow_target"
    rm -rf "$base_stow_target"
end

log_step "Stow simulation: profiles"
for profile_dir in "$repo_root"/profiles/*
    if test -d "$profile_dir/home"
        stow_profile_simulate (basename "$profile_dir") "$profile_dir/home"
    end
end

if type -q rg
    log_step "Secret scan"
    set scan_paths
    for path in AGENTS.md CLAUDE.md README.md home setup share profiles/personal .gitignore
        if test -e "$repo_root/$path"
            set --append scan_paths "$repo_root/$path"
        end
    end

    set secret_pattern '(AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{36,}|glpat-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|Authorization:[[:space:]]*Bearer[[:space:]]+[A-Za-z0-9._-]{20,}|(?i:(api|access|refresh|secret|private|auth)[_-]?(key|token))[[:space:]]*=[[:space:]]*["'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\''][^"'\'']+["'\''])'

    if test (count $scan_paths) -gt 0
        rg -n --hidden --glob '!profiles/work/**' --glob '!.git/**' --glob '!*.png' --glob '!*.jpg' --glob '!*.jpeg' --glob '!*.gif' --glob '!*.svg' --glob '!*.pdf' --pcre2 "$secret_pattern" $scan_paths
        set rg_status $status

        switch $rg_status
            case 0
                mark_fail "Potential secret pattern found. Review the matches above."
            case 1
                log_success "No high-signal secret patterns found."
            case '*'
                mark_fail "Secret scan failed with rg status $rg_status."
        end
    else
        log_info "No paths found for secret scan."
    end
end

if test $failures -gt 0
    log_error "$failures check(s) failed."
    exit 1
end

log_done "All checks passed."
