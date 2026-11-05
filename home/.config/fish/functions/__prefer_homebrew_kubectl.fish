function __prefer_homebrew_kubectl --description 'Prefer only Homebrew kubectl, preserving other tool priorities'
    # Call after the Rancher Desktop managed block in local config.fish.
    set -l override_dir "$HOME/.local/libexec/homebrew-kubectl"
    if test -x /opt/homebrew/bin/kubectl; and test -x "$override_dir/kubectl"
        fish_add_path --move --path "$override_dir"
    end
end
