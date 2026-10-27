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
    set -l contexts
    set -l session
    set -l expecting_session 0
    set -l list_only 0
    set -l current_pane 0
    set -l clear_only 0

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
            case -P --pane current-pane
                set current_pane 1
            case clear
                set clear_only 1
            case -h --help
                echo "Usage: cw CONTEXT... [-s|--session SESSION]"
                echo "       cw CONTEXT... --pane"
                echo "       cw clear [--pane]"
                echo "       cw --list"
                echo
                echo "CONTEXT values and init hooks are provided by the active profile."
                echo "If a context provides a default session, pass -s to override it."
                return
            case '*'
                set -a contexts $arg
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

    if test $clear_only -eq 1
        if test (count $contexts) -gt 0
            echo "Usage: cw clear [--pane]" >&2
            return 1
        end
        if not set -q TMUX_PANE
            echo "cw clear requires running inside tmux" >&2
            return 1
        end

        set -l context_label
        set -l reset_target
        set -l reset_key
        if test $current_pane -eq 1
            set context_label (tmux show-options -p -v -t "$TMUX_PANE" @cw_context 2>/dev/null)
            set reset_target (tmux display-message -p -t "$TMUX_PANE" '#W')
            set reset_key pane_reset
        else
            set reset_target (tmux display-message -p -t "$TMUX_PANE" '#S:#W')
            set context_label (tmux show-options -w -v -t "$reset_target" @cw_context 2>/dev/null)
            set reset_key reset
        end

        set -l reset_hooks
        for context in (string split ' | ' -- "$context_label")
            test -z "$context"; and continue
            set -l spec (__cw_context "$context")
            or return 1
            set -l reset (__cw_get "$reset_key" $spec)
            if test -n "$reset"; and not contains -- "$reset" $reset_hooks
                set -a reset_hooks "$reset"
            end
        end

        for reset in $reset_hooks
            if not functions -q "$reset"
                echo "cw $reset_key function not found: $reset" >&2
                return 1
            end
            $reset "$reset_target"
            or return 1
        end

        if test $current_pane -eq 1
            tmux set-option -p -t "$TMUX_PANE" @cw_context "" 2>/dev/null
            tmux set-option -p -t "$TMUX_PANE" @cw_context_prod 0 2>/dev/null
        else
            tmux set-option -w -u -t "$reset_target" @cw_context 2>/dev/null
            tmux set-option -w -u -t "$reset_target" @cw_context_prod 2>/dev/null
        end
        return 0
    end

    if test (count $contexts) -eq 0
        echo "Usage: cw CONTEXT... [-s|--session SESSION]" >&2
        return 1
    end

    set -l types
    set -l titles
    set -l reset_hooks
    set -l pane_reset_hooks
    set -l cwd
    set -l default_session
    set -l is_prod 0

    for context in $contexts
        set -l spec (__cw_context "$context")
        or return 1
        set -l type (__cw_get type $spec)

        if test -z "$type"
            echo "context type not found: $context" >&2
            return 1
        end
        if not contains -- "$type" kubernetes object-storage pulsar hadoop
            echo "unsupported context type: $type" >&2
            return 1
        end
        if contains -- "$type" $types
            echo "context type already selected: $type" >&2
            return 1
        end
        set -a types "$type"

        set -l context_title (__cw_get title $spec)
        test -z "$context_title"; and set context_title "$context"
        set -a titles "$context_title"

        test -z "$cwd"; and set cwd (__cw_get cwd $spec)
        test -z "$default_session"; and set default_session (__cw_get session $spec)

        set -l reset (__cw_get reset $spec)
        if test -n "$reset"; and not contains -- "$reset" $reset_hooks
            set -a reset_hooks "$reset"
        end
        set -l pane_reset (__cw_get pane_reset $spec)
        if test -n "$pane_reset"; and not contains -- "$pane_reset" $pane_reset_hooks
            set -a pane_reset_hooks "$pane_reset"
        end

        if test (__cw_get env $spec) = prod
            set is_prod 1
        end
    end

    set -l title (string join + -- $titles)
    set -l context_label (string join ' | ' -- $contexts)
    test -z "$cwd"; and set cwd ~

    if test $current_pane -eq 1
        if not set -q TMUX_PANE
            echo "cw --pane requires running inside tmux" >&2
            return 1
        end
        for pane_reset in $pane_reset_hooks
            if not functions -q "$pane_reset"
                echo "cw pane reset function not found: $pane_reset" >&2
                return 1
            end
            $pane_reset "$title"
            or return 1
        end

        tmux set-option -p -t "$TMUX_PANE" @cw_context "$context_label" 2>/dev/null
        tmux set-option -p -t "$TMUX_PANE" @cw_context_prod "$is_prod" 2>/dev/null

        for deferred_pass in 0 1
            for context in $contexts
                set -l spec (__cw_context "$context")
                or return 1
                set -l deferred (__cw_get deferred $spec)
                test -z "$deferred"; and set deferred 0
                if test "$deferred" != "$deferred_pass"
                    continue
                end

                set -l pane_init (__cw_get pane_init $spec)
                if test -z "$pane_init"; or not functions -q "$pane_init"
                    echo "cw --pane is not supported for context: $context" >&2
                    return 1
                end
                $pane_init $spec
                or return 1
            end
        end
        return 0
    end

    test -z "$session"; and set session "$default_session"
    test -z "$session"; and set session (__cw_session)

    if test -z "$session"
        echo "tmux session not found; pass --session SESSION" >&2
        return 1
    end

    if not tmux has-session -t "$session" 2>/dev/null
        echo "tmux session not found: $session" >&2
        echo "Create it with: tmux new -s $session" >&2
        echo "Or target another existing session with: cw $context -s SESSION" >&2
        return 1
    end

    set -l target "$session:$title"
    set -l window_exists 1

    if not tmux list-windows -t "$session" -F '#W' | string match -q -- "$title"
        set window_exists 0
        tmux new-window -d -t "$session" -n "$title" -c "$cwd"
    end

    if test $window_exists -eq 1
        for context in $contexts
            set -l spec (__cw_context "$context")
            or return 1
            set -l reuse_guard (__cw_get reuse_guard $spec)
            if test -z "$reuse_guard"
                continue
            end
            if not functions -q "$reuse_guard"
                echo "cw reuse guard function not found: $reuse_guard" >&2
                return 1
            end
            if $reuse_guard "$target" $spec
                tmux switch-client -t "$target" 2>/dev/null; or tmux attach-session -t "$target"
                return $status
            end
        end
    end

    for reset in $reset_hooks
        if not functions -q "$reset"
            echo "cw reset function not found: $reset" >&2
            return 1
        end
        $reset "$target"
        or return 1
    end

    tmux set-option -w -t "$target" @cw_context "$context_label" 2>/dev/null
    tmux set-option -w -t "$target" @cw_context_prod "$is_prod" 2>/dev/null

    for deferred_pass in 0 1
        for context in $contexts
            set -l spec (__cw_context "$context")
            or return 1
            set -l deferred (__cw_get deferred $spec)
            test -z "$deferred"; and set deferred 0
            if test "$deferred" != "$deferred_pass"
                continue
            end

            set -l init (__cw_get init $spec)
            if test -z "$init"
                continue
            end
            if not functions -q "$init"
                echo "cw init function not found: $init" >&2
                return 1
            end
            $init "$target" $spec
            or return 1
        end
    end

    tmux switch-client -t "$target" 2>/dev/null; or tmux attach-session -t "$target"
end
