function __cpath_theme_color --argument-names color fallback
    if test -n "$color"
        echo "#$color"
    else
        echo "$fallback"
    end
end

function __cpath_box --argument-names message border_color text_color stream
    if not type -q gum
        return 1
    end

    if test "$stream" = stderr
        printf "%s" "$message" | gum style \
            --border rounded \
            --border-foreground "$border_color" \
            --foreground "$text_color" \
            --padding "0 1" >&2
    else
        printf "%s" "$message" | gum style \
            --border rounded \
            --border-foreground "$border_color" \
            --foreground "$text_color" \
            --padding "0 1"
    end
end

function __cpath_error --argument-names message
    set -l error_color (__cpath_theme_color "$__COLOR_ERROR" red)
    set -l text_color (__cpath_theme_color "$__COLOR_FG" white)

    if __cpath_box "$message" "$error_color" "$text_color" stderr
        return
    else if functions -q log_error
        log_error "$message"
    else
        echo "$message" >&2
    end
end

function cpath --description 'Copy an absolute path to the clipboard'
    if test (count $argv) -gt 1
        __cpath_error "Usage: cpath [path]"
        return 1
    end

    set -l target
    set -l full_path

    if test (count $argv) -eq 0
        set full_path (command pwd)
    else
        set target $argv[1]
    end

    if test -z "$full_path"; and not test -e "$target"
        __cpath_error "File or path not found: $target"
        return 1
    end

    if test -z "$full_path"
        set full_path (realpath -- "$target")
    end

    printf "%s" "$full_path" | pbcopy

    set -l success_color (__cpath_theme_color "$__COLOR_SUCCESS" green)
    set -l text_color (__cpath_theme_color "$__COLOR_FG" white)

    if not __cpath_box "$full_path" "$success_color" "$text_color" stdout
        if functions -q log_success
            log_success "Copied: $full_path"
        else
            echo "COPIED $full_path"
        end
    end
end
