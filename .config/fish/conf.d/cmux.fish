if not status is-interactive
    return
end

set -l cmux_app_bin "/Applications/cmux.app/Contents/Resources/bin/cmux"
set -l local_bin "$HOME/.local/bin"
set -l cmux_link "$local_bin/cmux"

if test -x "$cmux_app_bin"
    if not contains -- "$local_bin" $fish_user_paths
        fish_add_path "$local_bin"
    end

    command mkdir -p "$local_bin"

    if not test -L "$cmux_link"
        command ln -sf "$cmux_app_bin" "$cmux_link"
    else
        set -l current_target (command readlink "$cmux_link" 2>/dev/null)
        if test "$current_target" != "$cmux_app_bin"
            command ln -sf "$cmux_app_bin" "$cmux_link"
        end
    end
end
