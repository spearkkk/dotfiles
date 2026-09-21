#!/usr/bin/env fish

if status is-interactive
    # Homebrew's vendor mise config runs after user conf.d files. Disable its
    # auto-activation so mise is initialized only once from this repo.
    set -gx MISE_FISH_AUTO_ACTIVATE 0

    if type -q mise
        mise activate fish | source
    else if functions -q log_warn
        log_warn "mise not installed. Skipping activation."
    else
        echo "[WARN] mise not installed. Skipping activation."
    end
end
