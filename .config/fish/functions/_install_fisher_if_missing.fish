#!/usr/bin/env fish

function _install_fisher_if_missing \
    --description "Install fisher plugin if missing. Usage: _install_fisher_if_missing <plugin>"

    set -l plugin $argv[1]

    if test -z "$plugin"
        log_warn "Missing plugin name for fisher install. Skipping."
        return 1
    end

    if not functions -q log_info
        echo "[INFO ] Checking fisher plugin: $plugin"
    else
        log_info "Checking fisher plugin: $plugin"
    end

    # Install fisher if not present
    if not type -q fisher
        log_info "Installing fisher..."
        curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher
        if test $status -ne 0
            log_error "Failed to install fisher."
            return 1
        end
    end

    # Check if plugin is already installed
    if fisher list | grep -q "$plugin"
        log_info "Fisher plugin $plugin is already installed. Skipping."
        return 0
    end

    log_info "Installing fisher plugin: $plugin"
    fisher install $plugin

    if test $status -eq 0
        log_success "Fisher plugin $plugin installed successfully."
    else
        log_error "Failed to install fisher plugin $plugin."
        return 1
    end
end