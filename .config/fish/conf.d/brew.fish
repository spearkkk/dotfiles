#!/usr/bin/env fish

# Always load brew env (even in non-interactive shells)
if test -f /opt/homebrew/bin/brew
    eval "$(/opt/homebrew/bin/brew shellenv)"
else if test -f /usr/local/bin/brew
    eval "$(/usr/local/bin/brew shellenv)"
else
    echo "[WARN ] Homebrew not found. PATH may be incomplete."
end