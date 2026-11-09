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
