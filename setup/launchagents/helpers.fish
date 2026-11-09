# launchctl print uses one tab for service fields; nested coalition fields
# (notably state = active) must not override the service's own state.
# Returns 0 for registered, 113 for absent, 2 for an unknown/error state.
function launchagent_query --argument-names target
    set -g launchagent_state
    set -g launchagent_pid
    set -g launchagent_last_exit
    set -l output (LC_ALL=C launchctl print "$target" 2>&1)
    set -l code $status
    switch $code
        case 0
            set -g launchagent_state (string match -rg '^\tstate = (.+)$' -- $output)
            set -g launchagent_pid (string match -rg '^\tpid = ([1-9][0-9]*)$' -- $output)
            set -g launchagent_last_exit (string match -rg '^\tlast exit code = (.+)$' -- $output)
            if test (count $launchagent_state) -eq 1; and test (count $launchagent_pid) -le 1
                return 0
            end
            echo "[ERROR] Unrecognized launchctl state for $target" >&2
        case 113
            return 113
        case '*'
            echo "[ERROR] Failed to query $target (exit $code): $output" >&2
    end
    return 2
end

# Never signal a PID read from a file: it may belong to an unrelated process.
# ps distinguishes absence (exit 1 with no output) from a failed probe.
function launchagent_pid_alive --argument-names pid
    set -l output (LC_ALL=C command ps -p "$pid" -o pid= 2>&1)
    set -l code $status
    if test $code -eq 0
        return 0
    else if test $code -eq 1; and test (count $output) -eq 0
        return 1
    end
    echo "[ERROR] Failed to check PID $pid: $output" >&2
    return 2
end

# Shared stop/cleanup path. Only teardown passes --disable; restart preserves
# the enabled state until both agents have been confirmed stopped.
function launchagent_stop --argument-names target pid_file disable
    set -l label (string split / -- "$target")[-1]
    set -l saved_pid
    if test -e "$pid_file"
        set saved_pid (cat "$pid_file")
        if test $status -ne 0; or test (count $saved_pid) -ne 1; or not string match -qr '^[1-9][0-9]*$' -- "$saved_pid"
            echo "[ERROR] Invalid or unreadable PID file: $pid_file" >&2
            return 1
        end
    end

    launchagent_query "$target"
    set -l query_status $status
    if test $query_status -ne 0; and test $query_status -ne 113
        return 1
    end
    set -l pids $saved_pid $launchagent_pid

    if test "$disable" = --disable
        if not launchctl disable "$target"
            echo "[ERROR] Failed to disable $label" >&2
            return 1
        end
    end
    if test $query_status -eq 0
        set -l bootout_output (launchctl bootout "$target" 2>&1)
        if test $status -ne 0
            # Another caller may already have unloaded it. Only confirmed
            # absence is safe; do not hide permission or launchd failures.
            launchagent_query "$target"
            if test $status -ne 113
                echo "[ERROR] Failed to unload $label: $bootout_output" >&2
                return 1
            end
        end
    end

    # Deregistration can precede process exit. Allow bounded collector work
    # to finish, checking both launchd's PID and the daemon's PID file.
    for attempt in (seq 1 100)
        launchagent_query "$target"
        set query_status $status
        if test $query_status -ne 0; and test $query_status -ne 113
            return 1
        end
        if test -n "$launchagent_pid"; and not contains -- "$launchagent_pid" $pids
            set -a pids $launchagent_pid
        end
        set -l alive 0
        for pid in $pids
            launchagent_pid_alive "$pid"
            switch $status
                case 0
                    set alive 1
                case 1
                case '*'
                    return 1
            end
        end
        if test $query_status -eq 113; and test $alive -eq 0
            if test -e "$pid_file"
                set -l current_pid (cat "$pid_file")
                if test $status -ne 0; or test "$current_pid" != "$saved_pid"
                    echo "[ERROR] PID file changed while stopping $label; preserving $pid_file" >&2
                    return 1
                end
                if not rm -f "$pid_file"
                    echo "[ERROR] Failed to remove $pid_file" >&2
                    return 1
                end
            end
            echo "stopped: $label"
            return 0
        end
        sleep 0.2
    end
    echo "[ERROR] Timed out while stopping $label; preserving $pid_file" >&2
    return 1
end
