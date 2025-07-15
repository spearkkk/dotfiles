function pwd
    if test (count $argv) -eq 0
        command pwd
        return
    end

    set -l arg $argv[1]
    set -l base_dir (command pwd)

    switch $arg
        case "."
            set full_path $base_dir
        case ".."
            set full_path (realpath ..)
        case "*"
            set full_path "$base_dir/$arg"
    end

    if test -e $full_path
        set -l ftype (file --brief --mime-type -- $full_path)
        set -l fsize (stat -f%z -- $full_path)
        set -l is_dir (test -d $full_path; and echo "yes"; or echo "no")

        echo
        _c --color white --background green --styles=bold " SUCCESS "
        _c --color green --styles=italic "Path has been copied to clipboard."

        echo -n "$full_path" | pbcopy
    else
        echo
        _c --color white --background red --styles=bold " ERROR "
        _c --color red --styles=italic "File or path not found."
        return 1
    end
end