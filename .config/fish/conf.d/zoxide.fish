#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q zoxide
        zoxide init fish | source
    else
        log_warn "zoxide not installed. Skipping activation."
    end
end
