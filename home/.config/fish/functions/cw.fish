function __cw_get --argument-names key
    set -l spec $argv[2..-1]

    for item in $spec
        set -l pair (string split -m1 = -- $item)
        if test "$pair[1]" = "$key"
            echo $pair[2]
            return
        end
    end

    return 1
end

function __cw_session
    if set -q TMUX_PANE
        tmux display-message -p -t "$TMUX_PANE" '#S'
        return
    end

    tmux list-sessions -F '#S' 2>/dev/null | head -n 1
end

function cw --description 'Create/reuse a tmux window with a profile context'
    set -l context
    set -l session
    set -l expecting_session 0
    set -l list_only 0

    for arg in $argv
        if test $expecting_session -eq 1
            set session $arg
            set expecting_session 0
            continue
        end

        switch $arg
            case -s --session
                set expecting_session 1
            case -l --list list
                set list_only 1
            case -h --help
                echo "Usage: cw CONTEXT [-s|--session SESSION]"
                echo "       cw --list"
                echo
                echo "CONTEXT values and init hooks are provided by the active profile."
                return
            case '*'
                if test -z "$context"
                    set context $arg
                else
                    echo "unexpected argument: $arg" >&2
                    return 1
                end
        end
    end

    if not functions -q __cw_context
        echo "cw profile resolver not found: define __cw_context in a profile" >&2
        return 1
    end

    if test $list_only -eq 1
        __cw_context --list
        return
    end

    if test -z "$context"
        echo "Usage: cw CONTEXT [-s|--session SESSION]" >&2
        return 1
    end

    set -l spec (__cw_context "$context")
    or return 1

    set -l title (__cw_get title $spec)
    set -l cwd (__cw_get cwd $spec)
    set -l init (__cw_get init $spec)
    set -l default_session (__cw_get session $spec)

    test -z "$title"; and set title "$context"
    test -z "$cwd"; and set cwd ~
    test -z "$session"; and set session "$default_session"
    test -z "$session"; and set session (__cw_session)

    if test -z "$session"
        echo "tmux session not found; pass --session SESSION" >&2
        return 1
    end

    if not tmux has-session -t "$session" 2>/dev/null
        echo "tmux session not found: $session" >&2
        return 1
    end

    set -l target "$session:$title"

    if not tmux list-windows -t "$session" -F '#W' | string match -q -- "$title"
        tmux new-window -d -t "$session" -n "$title" -c "$cwd"
    end

    tmux set-option -w -t "$target" @cw_context "$context" 2>/dev/null

    if test -n "$init"
        if not functions -q "$init"
            echo "cw init function not found: $init" >&2
            return 1
        end

        $init "$target" $spec
        or return 1
    end

    tmux switch-client -t "$target" 2>/dev/null; or tmux attach-session -t "$target"
end
