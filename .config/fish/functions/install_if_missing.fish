#!/usr/bin/env fish

function install_if_missing \
    --description "Install package if missing. Usage: install_if_missing <type> <name> <is_cask> [tap_name]"

    set -l type $argv[1]
    set -l name $argv[2]
    set -l is_cask $argv[3]
    set -l tap_name ""
    if count $argv > 3
        set tap_name $argv[4]
    end

    if test -z "$type" -o -z "$name"
        log_warn "Missing arguments for install_if_missing. Skipping."
        return
    end

    if not functions -q log_info
        echo "[INFO ] Checking $type package: $name"
    else
        log_info "Checking $type package: $name"
    end

    if test "$type" = "brew"
        if not type -q brew
            log_error "Homebrew not found. Aborting."
            return 1
        end

        if test -n "$tap_name"
            tap_if_missing $tap_name
        end

        set -l found 1
        if test "$is_cask" = "true"
            brew list --cask --versions | rg -q "^$name\\b"
            set found $status
        else
            brew list --versions | rg -q "^$name\\b"
            set found $status
        end

        if test $found -ne 0
            log_warn "$name not found. Installing via brew..."
            if test "$is_cask" = "true"
                brew install --cask $name
            else
                brew install $name
            end
            if test $status -eq 0
                log_success "$name installed successfully."
            else
                log_error "Failed to install $name."
            end
        else
            log_info "$name is already installed. Skipping."
        end
    else
        log_warn "Install type '$type' is not supported. Skipping '$name'."
    end
end