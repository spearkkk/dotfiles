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

function __cw_context_helper
    if set -q CW_CONTEXT_HELPER
        echo "$CW_CONTEXT_HELPER"
    else
        echo "$HOME/.local/libexec/tmux-pane-context"
    end
end

function __cw_session
    if set -q TMUX_PANE
        tmux display-message -p -t "$TMUX_PANE" '#S'
        return
    end

    tmux list-sessions -F '#S' 2>/dev/null | head -n 1
end

function __cw_instance
    printf 'ctx-%s-%s-%s\n' (date +%s) %self (random)
end

function __cw_descriptor --argument-names instance id slot environment alert
    jq -cn \
        --arg instance "$instance" \
        --arg id "$id" \
        --arg slot "$slot" \
        --arg environment "$environment" \
        --argjson alert "$alert" \
        '{instance:$instance,id:$id,slot:$slot,environment:$environment,alert:$alert,state:"connecting"}'
end

function __cw_eject_record --argument-names pane instance id slot
    set -l helper (__cw_context_helper)
    set -l spec (__cw_context "$id" 2>/dev/null)
    if test $status -eq 0
        set -l eject (__cw_get eject $spec)
        if test -n "$eject"
            if not functions -q "$eject"
                echo "cw eject function not found: $eject" >&2
                return 1
            end
            $eject "$pane" "$instance" $spec
            or return 1
        end
    end
    "$helper" eject "$pane" "$slot" "$instance"
end

function __cw_apply_one --argument-names pane context
    set -l helper (__cw_context_helper)
    set -l spec (__cw_context "$context")
    or return 1
    set -l slot (__cw_get type $spec)
    set -l name (__cw_get name $spec)
    test -n "$name"; or set name "$context"
    set -l environment (__cw_get env $spec)
    test -n "$environment"; or set environment unknown
    set -l alert (__cw_get alert $spec)
    if test -z "$alert"
        if test "$environment" = prod
            set alert true
        else
            set alert false
        end
    else if test "$alert" = 1
        set alert true
    else
        set alert false
    end

    set -l old ("$helper" list "$pane" | jq -r --arg slot "$slot" \
        '.contexts[] | select(.slot == $slot) | [.instance,.id,.slot] | @tsv')
    if test (count $old) -gt 0
        set -l fields (string split \t -- "$old[1]")
        __cw_eject_record "$pane" "$fields[1]" "$fields[2]" "$fields[3]"
        or return 1
    end

    set -l instance (__cw_instance)
    set -l descriptor (__cw_descriptor "$instance" "$name" "$slot" "$environment" "$alert")
    or return 1
    "$helper" inject "$pane" "$descriptor"
    or return 1

    set -l inject (__cw_get inject $spec)
    if test -z "$inject"; or not functions -q "$inject"
        echo "cw inject function not found for context: $context" >&2
        "$helper" state "$pane" "$instance" error
        return 1
    end

    if not $inject "$pane" "$instance" $spec
        "$helper" state "$pane" "$instance" error
        return 1
    end

    set -l managed_state (__cw_get managed_state $spec)
    if test "$managed_state" != 1
        "$helper" state "$pane" "$instance" active
    end
end

function __cw_apply_context --argument-names pane
    set -l contexts $argv[2..-1]
    for deferred_pass in 0 1
        for context in $contexts
            set -l spec (__cw_context "$context")
            or return 1
            set -l deferred (__cw_get deferred $spec)
            test -n "$deferred"; or set deferred 0
            test "$deferred" = "$deferred_pass"; or continue
            __cw_apply_one "$pane" "$context"
            or return 1
        end
    end
end

function __cw_restore_contexts --argument-names pane
    set -l helper (__cw_context_helper)
    set -l rows ("$helper" list "$pane" | jq -r '.contexts[] | [.instance,.id] | @tsv')
    for row in $rows
        set -l fields (string split \t -- "$row")
        set -l spec (__cw_context "$fields[2]" 2>/dev/null)
        or continue
        set -l restore (__cw_get restore $spec)
        test -n "$restore"; or continue
        if not functions -q "$restore"
            echo "cw restore function not found: $restore" >&2
            return 1
        end
        $restore "$pane" "$fields[1]" $spec
        or return 1
    end
end

function __cw_clear_pane --argument-names pane
    set -l helper (__cw_context_helper)
    set -l rows ("$helper" list "$pane" | jq -r '.contexts[] | [.instance,.id,.slot] | @tsv')
    for row in $rows
        set -l fields (string split \t -- "$row")
        __cw_eject_record "$pane" "$fields[1]" "$fields[2]" "$fields[3]"
        or return 1
    end
    "$helper" clear "$pane"
end

function __cw_find_exact_pane --argument-names session expected
    for row in (tmux list-panes -s -t "$session" -F '#{pane_id}|#{@contexts}' 2>/dev/null)
        set -l fields (string split -m1 '|' -- "$row")
        test (count $fields) -eq 2; or continue
        test -n "$fields[2]"; or continue
        set -l actual (printf '%s' "$fields[2]" | jq -r '.contexts[].id' 2>/dev/null | sort | string join ',')
        if test "$actual" = "$expected"
            echo "$fields[1]"
            return 0
        end
    end
    return 1
end

function __cw_focus_pane --argument-names pane session
    tmux switch-client -t "$pane" 2>/dev/null
    or tmux attach-session -t "$session"
end

function cw --description 'Create or reuse a tmux pane with profile contexts'
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
                echo 'Usage: cw CONTEXT... [-s|--session SESSION]'
                echo '       cw CONTEXT... --pane'
                echo '       cw clear [--pane]'
                echo '       cw --list'
                echo
                echo 'Contexts are always applied to exactly one tmux pane.'
                return
            case '*'
                set -a contexts $arg
        end
    end

    if not functions -q __cw_context
        echo 'cw profile resolver not found: define __cw_context in a profile' >&2
        return 1
    end

    if test $list_only -eq 1
        __cw_context --list
        return
    end

    if test $clear_only -eq 1
        if test (count $contexts) -gt 0
            echo 'Usage: cw clear [--pane]' >&2
            return 1
        end
        if not set -q TMUX_PANE
            echo 'cw clear requires running inside tmux' >&2
            return 1
        end
        __cw_clear_pane "$TMUX_PANE"
        return
    end

    if test (count $contexts) -eq 0
        echo 'Usage: cw CONTEXT... [-s|--session SESSION]' >&2
        return 1
    end

    set -l slots
    set -l canonical_contexts
    set -l titles
    set -l cwd
    set -l default_session
    for context in $contexts
        set -l spec (__cw_context "$context")
        or return 1
        set -l slot (__cw_get type $spec)
        if test -z "$slot"
            echo "context slot not found: $context" >&2
            return 1
        end
        if contains -- "$slot" $slots
            echo "context slot already selected: $slot" >&2
            return 1
        end
        set -a slots "$slot"
        set -l canonical (__cw_get name $spec)
        test -n "$canonical"; or set canonical "$context"
        set -a canonical_contexts "$canonical"

        for hook in inject restore eject
            set -l function_name (__cw_get "$hook" $spec)
            if test -z "$function_name"; or not functions -q "$function_name"
                echo "cw $hook function not found for context: $context" >&2
                return 1
            end
        end

        set -l title (__cw_get title $spec)
        test -n "$title"; or set title "$context"
        set -a titles "$title"
        test -n "$cwd"; or set cwd (__cw_get cwd $spec)
        test -n "$default_session"; or set default_session (__cw_get session $spec)
    end

    set -l title (string join + -- $titles)
    test -n "$cwd"; or set cwd ~

    if test $current_pane -eq 1
        if not set -q TMUX_PANE
            echo 'cw --pane requires running inside tmux' >&2
            return 1
        end
        __cw_apply_context "$TMUX_PANE" $contexts
        return
    end

    test -n "$session"; or set session "$default_session"
    test -n "$session"; or set session (__cw_session)
    if test -z "$session"
        echo 'tmux session not found; pass --session SESSION' >&2
        return 1
    end
    if not tmux has-session -t "$session" 2>/dev/null
        echo "tmux session not found: $session" >&2
        return 1
    end

    set -l expected (printf '%s\n' $canonical_contexts | sort | string join ',')
    set -l pane (__cw_find_exact_pane "$session" "$expected")
    if test -n "$pane"
        __cw_focus_pane "$pane" "$session"
        return
    end

    set pane (tmux new-window -d -P -F '#{pane_id}' -t "$session" -n "$title" -c "$cwd")
    or return 1
    set -l command '__cw_apply_context '(string escape -- "$pane" $contexts)
    tmux send-keys -t "$pane" "$command" C-m
    or return 1
    __cw_focus_pane "$pane" "$session"
end
