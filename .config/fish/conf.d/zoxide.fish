#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q zoxide
        log_info "Activating zoxide..."
        zoxide init fish | source
        log_success "zoxide activated"
    else
        log_warn "zoxide not installed. Skipping activation."
    end
end