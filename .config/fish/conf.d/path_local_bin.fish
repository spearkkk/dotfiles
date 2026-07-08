set -l local_bin "$HOME/.local/bin"

if test -d "$local_bin"
    if not contains -- "$local_bin" $fish_user_paths
        fish_add_path -m "$local_bin"
    end
end
