#!/usr/bin/env fish

# Rancher is a fallback for its bundled Docker tools, never the first PATH.
if test -d "$HOME/.rd/bin"
    fish_add_path --move --append --path "$HOME/.rd/bin"
end

# Official mise shims also work without interactive prompt hooks.
if test -d "$HOME/.local/share/mise/shims"
    fish_add_path --move --path "$HOME/.local/share/mise/shims"
end

# Add user-local executables to PATH.
set -l local_bin "$HOME/.local/bin"

if test -d "$local_bin"
    fish_add_path --move --path "$local_bin"
end
