#!/usr/bin/env fish

source ~/.config/fish/conf.d/logger.fish

if status is-interactive
    # Homebrew's vendor mise config runs after user conf.d files. Disable its
    # auto-activation so mise is initialized only once from this repo.
    set -gx MISE_FISH_AUTO_ACTIVATE 0

    if type -q mise
        mise activate fish | source
    else
        log_warn "mise not installed. Skipping activation."
    end
end
