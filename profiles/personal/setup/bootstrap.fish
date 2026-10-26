#!/usr/bin/env fish

set -l profile_dir (cd (dirname (status --current-filename)); and pwd)
set -l profile_brewfile "$profile_dir/Brewfile"
set -l github_key "$HOME/.ssh/id_ed25519_github"

if test -f "$profile_brewfile"
    if not type -q brew
        echo "[WARN] Homebrew is required to install personal dependencies: $profile_brewfile"
    else if not env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --file "$profile_brewfile"
        echo "[WARN] Personal Homebrew dependencies could not be installed: $profile_brewfile"
    end
end

if not test -f "$github_key"
    echo "[WARN] Missing personal GitHub SSH key: $github_key"
    echo "       Generate it with: ssh-keygen -t ed25519 -a 100 -f $github_key"
end
