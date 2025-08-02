#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q starship
        log_info "Activating starship..."
        starship init fish | source
        log_success "starship activated"
    else
        log_warn "starship not installed. Skipping activation."
    end
end