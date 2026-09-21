#!/usr/bin/env fish

if status is-interactive
    if type -q fzf
        fzf --fish | source
    else if functions -q log_warn
        log_warn "fzf not installed. Skipping activation."
    else
        echo "[WARN] fzf not installed. Skipping activation."
    end
end
