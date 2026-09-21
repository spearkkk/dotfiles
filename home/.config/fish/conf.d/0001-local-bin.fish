#!/usr/bin/env fish

# Add user-local executables to PATH.
set -l local_bin "$HOME/.local/bin"

if test -d "$local_bin"
    fish_add_path --move --path "$local_bin"
end
