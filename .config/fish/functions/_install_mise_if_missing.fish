#!/usr/bin/env fish

function _install_mise_if_missing \
    --description "Install mise tool if missing. Usage: _install_mise_if_missing <tool> [version]"

    set -l tool $argv[1]
    set -l version ""
    if count $argv > 1
        set version $argv[2]
    end

    if test -z "$tool"
        log_warn "Missing tool name for mise install. Skipping."
        return 1
    end

    if not type -q mise
        log_error "Mise not found. Please install mise first."
        return 1
    end

    if not functions -q log_info
        echo "[INFO ] Checking mise tool: $tool"
    else
        log_info "Checking mise tool: $tool"
    end

    # Check if tool is already installed
    if mise list $tool 2>/dev/null | grep -q "$tool"
        log_info "Mise tool $tool is already installed. Skipping."
        return 0
    end

    log_info "Installing $tool via mise..."
    
    if test -n "$version"
        mise install "$tool@$version"
        if test $status -eq 0
            mise use -g "$tool@$version"
        end
    else
        mise install $tool
        if test $status -eq 0
            mise use -g $tool
        end
    end

    if test $status -eq 0
        log_success "$tool installed successfully via mise."
    else
        log_error "Failed to install $tool via mise."
        return 1
    end
end