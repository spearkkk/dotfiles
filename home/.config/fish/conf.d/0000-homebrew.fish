#!/usr/bin/env fish

# Load Homebrew env early so fish can find brew-installed tools.
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
else if test -x /usr/local/bin/brew
    eval (/usr/local/bin/brew shellenv)
else if status is-interactive
    echo "[WARN] Homebrew not found. PATH may be incomplete."
end
