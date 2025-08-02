#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q fzf
        log_info "Activating fzf..."
        fzf --fish | source
        log_success "fzf activated"
    else
        log_warn "fzf not installed. Skipping activation."
    end
end
