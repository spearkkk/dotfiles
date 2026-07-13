function cpath --description 'Copy an absolute path to the clipboard'
    if test (count $argv) -gt 1
        __dot_style --color white --background red --styles=bold " ERROR "
        __dot_style --color red --styles=italic "Usage: cpath [path]"
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
        __dot_style --color white --background red --styles=bold " ERROR "
        __dot_style --color red --styles=italic "File or path not found: $target"
        return 1
    end

    if test -z "$full_path"
        set full_path (realpath -- "$target")
    end

    printf "%s" "$full_path" | pbcopy
    __dot_style --color white --background green --styles=bold " COPIED "
    __dot_style --color green --styles=italic "$full_path"
end
