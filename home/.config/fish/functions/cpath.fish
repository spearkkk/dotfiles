function cpath --description 'Copy an absolute path to the clipboard'
    if test (count $argv) -gt 1
        if functions -q log_error
            log_error "Usage: cpath [path]"
        else
            echo "Usage: cpath [path]" >&2
        end
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
        if functions -q log_error
            log_error "File or path not found: $target"
        else
            echo "File or path not found: $target" >&2
        end
        return 1
    end

    if test -z "$full_path"
        set full_path (realpath -- "$target")
    end

    printf "%s" "$full_path" | pbcopy

    if type -q gum
        set -l success_color green
        set -l text_color white

        if set -q __COLOR_SUCCESS
            set success_color "#$__COLOR_SUCCESS"
        end

        if set -q __COLOR_FG
            set text_color "#$__COLOR_FG"
        end

        printf "%s" "$full_path" | gum style \
            --border rounded \
            --border-foreground "$success_color" \
            --foreground "$text_color" \
            --padding "0 1"
    else if functions -q log_success
        log_success "Copied: $full_path"
    else
        echo "COPIED $full_path"
    end
end
