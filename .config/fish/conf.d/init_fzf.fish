#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q fzf
        fzf --fish | source
    else
        log_warn "fzf not installed. Skipping activation."
    end
end
