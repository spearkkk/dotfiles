#!/usr/bin/env fish

if status is-interactive
    if type -q starship
        starship init fish | source
    else if functions -q log_warn
        log_warn "starship not installed. Skipping activation."
    else
        echo "[WARN] starship not installed. Skipping activation."
    end
end
