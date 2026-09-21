#!/usr/bin/env fish

if status is-interactive
    if type -q zoxide
        zoxide init fish | source
    else if functions -q log_warn
        log_warn "zoxide not installed. Skipping activation."
    else
        echo "[WARN] zoxide not installed. Skipping activation."
    end
end
