#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    if type -q mise
        mise activate fish | source
    else
        log_warn "mise not installed. Skipping activation."
    end
end
