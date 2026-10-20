#!/usr/bin/env fish

set -l github_key "$HOME/.ssh/id_ed25519_github"

if not test -f "$github_key"
    echo "[WARN] Missing personal GitHub SSH key: $github_key"
    echo "       Generate it with: ssh-keygen -t ed25519 -a 100 -f $github_key"
end
