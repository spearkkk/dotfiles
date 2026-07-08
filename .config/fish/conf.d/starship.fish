#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q starship
        starship init fish | source
    else
        log_warn "starship not installed. Skipping activation."
    end
end
