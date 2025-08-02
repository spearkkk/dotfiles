#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q mise
        log_info "Activating mise..."
        mise activate fish | source
        log_success "mise activated"
    else
        log_warn "mise not installed. Skipping activation."
    end
end