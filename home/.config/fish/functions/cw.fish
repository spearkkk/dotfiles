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
        echo "$HOME/.local/libexec/tmux-manage-pane-context"
    end
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

function __cw_restore_slot --argument-names pane slot snapshot expected_instance
    set -l helper (__cw_context_helper)
    set -l current ("$helper" list "$pane")
    or return 1
    set -l current_record (printf '%s' "$current" | jq -c --arg slot "$slot" \
        '.contexts[] | select(.slot == $slot)')
    or return 1
    set -l original_record (printf '%s' "$snapshot" | jq -c --arg slot "$slot" \
        '.contexts[] | select(.slot == $slot)')

    if test (count $current_record) -gt 0; and test (count $original_record) -gt 0
        if test "$current_record[1]" = "$original_record[1]"
            return 0
        end
    end

    if test (count $current_record) -gt 0
        set -l current_fields (string split \t -- (printf '%s' "$current_record[1]" | jq -r \
            '[.instance,.id,.slot] | @tsv'))
        if test "$current_fields[1]" != "$expected_instance"
            echo "cw conflict: slot changed; refusing rollback: $slot" >&2
            return 1
        end
        if not __cw_eject_record "$pane" "$current_fields[1]" "$current_fields[2]" "$current_fields[3]"
            "$helper" state "$pane" "$current_fields[1]" error
            return 1
        end
    end

    if test (count $original_record) -eq 0
        return 0
    end

    "$helper" inject "$pane" "$original_record[1]" ""
    or return 1
    set -l original_fields (string split \t -- (printf '%s' "$original_record[1]" | jq -r \
        '[.instance,.id] | @tsv'))
    set -l original_spec (__cw_context "$original_fields[2]")
    or return 1
    set -l restore (__cw_get restore $original_spec)
    if test -z "$restore"; or not functions -q "$restore"
        return 1
    end
    if not $restore "$pane" "$original_fields[1]" $original_spec
        "$helper" state "$pane" "$original_fields[1]" error
        return 1
    end
end

function __cw_apply_one --argument-names pane context instance
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

    set -l inject (__cw_get inject $spec)
    set -l eject (__cw_get eject $spec)
    for hook in "$inject" "$eject"
        if test -z "$hook"; or not functions -q "$hook"
            echo "cw provider function not found for context: $context" >&2
            return 1
        end
    end

    set -l current ("$helper" list "$pane")
    or return 1
    set -l old_record (printf '%s' "$current" | jq -c --arg slot "$slot" \
        '.contexts[] | select(.slot == $slot)')
    or return 1
    if test (count $old_record) -gt 0
        set -l fields (string split \t -- (printf '%s' "$old_record[1]" | jq -r '[.instance,.id,.slot] | @tsv'))
        set -l old_spec (__cw_context "$fields[2]")
        or begin
            echo "cw cannot replace unrestorable context: $fields[2]" >&2
            return 1
        end
        for old_hook in restore eject
            set -l old_function (__cw_get "$old_hook" $old_spec)
            if test -z "$old_function"; or not functions -q "$old_function"
                echo "cw cannot replace unrestorable context: $fields[2]" >&2
                return 1
            end
        end
        if not __cw_eject_record "$pane" "$fields[1]" "$fields[2]" "$fields[3]"
            # Ejection can fail after changing shell state, without deleting
            # the descriptor. Equality of JSON alone does not prove recovery.
            echo "cw error: failed to eject previous context: $fields[2]" >&2
            set -l old_restore (__cw_get restore $old_spec)
            if not $old_restore "$pane" "$fields[1]" $old_spec
                "$helper" state "$pane" "$fields[1]" error
                echo "cw error: failed to restore previous context: $fields[2]" >&2
            end
            return 1
        end
    end

    test -n "$instance"; or set instance (__cw_instance)
    set -l descriptor (__cw_descriptor "$instance" "$name" "$slot" "$environment" "$alert")
    or return 1
    if not "$helper" inject "$pane" "$descriptor" ""
        if test (count $old_record) -gt 0
            set -l old_snapshot (printf '%s' "$old_record[1]" | jq -c '{contexts:[.]}')
            __cw_restore_slot "$pane" "$slot" "$old_snapshot" "$instance"
            or echo "cw error: failed to restore previous context in slot: $slot" >&2
        end
        return 1
    end

    if not $inject "$pane" "$instance" $spec
        if test (count $old_record) -gt 0
            set -l old_snapshot (printf '%s' "$old_record[1]" | jq -c '{contexts:[.]}')
            __cw_restore_slot "$pane" "$slot" "$old_snapshot" "$instance"
            or echo "cw error: failed to restore previous context in slot: $slot" >&2
        else
            "$helper" state "$pane" "$instance" error
        end
        return 1
    end

    set -l managed_state (__cw_get managed_state $spec)
    if test "$managed_state" != 1
        if not "$helper" state "$pane" "$instance" active
            if test (count $old_record) -gt 0
                set -l old_snapshot (printf '%s' "$old_record[1]" | jq -c '{contexts:[.]}')
                __cw_restore_slot "$pane" "$slot" "$old_snapshot" "$instance"
                or echo "cw error: failed to restore previous context in slot: $slot" >&2
            end
            return 1
        end
    end
end

function __cw_apply_context --argument-names pane
    set -l contexts $argv[2..-1]
    set -l transactional 0
    set -l snapshot
    set -l attempted_slots
    set -l attempted_instances
    if test (count $contexts) -gt 1
        set transactional 1
        set -l helper (__cw_context_helper)
        set snapshot ("$helper" list "$pane")
        or return 1
    end

    for deferred_pass in 0 1
        for context in $contexts
            set -l spec (__cw_context "$context")
            or return 1
            set -l deferred (__cw_get deferred $spec)
            test -n "$deferred"; or set deferred 0
            test "$deferred" = "$deferred_pass"; or continue
            set -a attempted_slots (__cw_get type $spec)
            set -l instance (__cw_instance)
            set -a attempted_instances "$instance"
            if not __cw_apply_one "$pane" "$context" "$instance"
                if test $transactional -eq 1
                    set -l rollback_failed 0
                    for index in (seq (count $attempted_slots) -1 1)
                        __cw_restore_slot "$pane" "$attempted_slots[$index]" "$snapshot" "$attempted_instances[$index]"
                        or set rollback_failed 1
                    end
                    if test $rollback_failed -eq 1
                        echo 'cw error: failed to restore the original context set' >&2
                    end
                end
                return 1
            end
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

function __cw_focus_pane --argument-names pane session
    tmux switch-client -t "$pane" 2>/dev/null
    or tmux attach-session -t "$session"
end

function cw --description 'Apply contexts to the current pane or a new split'
    set -l contexts
    set -l session
    set -l expecting_session 0
    set -l list_only 0
    set -l new_pane 0
    set -l bottom 0
    set -l clear_only 0

    for arg in $argv
        if test $expecting_session -eq 1
            if test -z "$arg"; or string match -q -- '-*' "$arg"
                echo 'cw --session requires a session name' >&2
                return 1
            end
            set session $arg
            set expecting_session 0
            continue
        end

        switch $arg
            case -s --session
                set expecting_session 1
                set new_pane 1
            case -l --list list
                set list_only 1
            case -P --pane
                set new_pane 1
            case --bottom
                set bottom 1
            case clear
                set clear_only 1
            case -h --help
                echo 'Usage: cw CONTEXT... [--pane | -s|--session SESSION] [--bottom]'
                echo '       cw clear'
                echo '       cw --list'
                echo
                echo 'Default: apply to the current pane (requires tmux).'
                echo '--pane/-P: create a new pane to the right of the current pane.'
                echo '--session/-s: create a new pane beside that session\'s active pane.'
                echo '--bottom: split below instead; requires --pane or --session.'
                echo 'New panes are always created, never reused. The session must exist.'
                return
            case '-*'
                echo "cw unknown option: $arg" >&2
                return 1
            case '*'
                set -a contexts $arg
        end
    end

    if test $expecting_session -eq 1
        echo 'cw --session requires a session name' >&2
        return 1
    end
    if test $bottom -eq 1; and test $new_pane -eq 0
        echo 'cw --bottom requires --pane or --session' >&2
        return 1
    end
    if test $clear_only -eq 1; or test $list_only -eq 1
        if test $new_pane -eq 1; or test $bottom -eq 1; or test (count $contexts) -gt 0; or test (math $clear_only + $list_only) -gt 1
            echo 'Usage: cw clear | cw --list (without pane options or contexts)' >&2
            return 1
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
        if not set -q TMUX_PANE
            echo 'cw clear requires running inside tmux' >&2
            return 1
        end
        __cw_clear_pane "$TMUX_PANE"
        return
    end

    if test (count $contexts) -eq 0
        echo 'Usage: cw CONTEXT... [--pane | --session SESSION] [--bottom]' >&2
        return 1
    end

    set -l slots
    set -l cwd
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

        for hook in inject restore eject
            set -l function_name (__cw_get "$hook" $spec)
            if test -z "$function_name"; or not functions -q "$function_name"
                echo "cw $hook function not found for context: $context" >&2
                return 1
            end
        end

        test -n "$cwd"; or set cwd (__cw_get cwd $spec)
    end

    test -n "$cwd"; or set cwd ~

    if test $new_pane -eq 0
        if not set -q TMUX_PANE
            echo 'cw requires running inside tmux; use --session SESSION from outside' >&2
            return 1
        end
        __cw_apply_context "$TMUX_PANE" $contexts
        return
    end

    set -l target
    if test -n "$session"
        if not tmux has-session -t "=$session" 2>/dev/null
            echo "tmux session not found: $session" >&2
            return 1
        end
        set target (tmux display-message -p -t "=$session:" '#{pane_id}')
        or return 1
    else
        if not set -q TMUX_PANE
            echo 'cw --pane requires running inside tmux; use --session SESSION from outside' >&2
            return 1
        end
        set target "$TMUX_PANE"
        set session (tmux display-message -p -t "$target" '#S')
        or return 1
    end

    set -l direction -h
    test $bottom -eq 0; or set direction -v
    set -l pane (tmux split-window $direction -d -P -F '#{pane_id}' -t "$target" -c "$cwd")
    or return 1
    # Use the public entrypoint so fish autoloads it in the new shell, too.
    set -l command 'cw '(string join ' ' -- (string escape -- $contexts))
    tmux send-keys -t "$pane" "$command" C-m
    or return 1
    __cw_focus_pane "$pane" "$session"
end
