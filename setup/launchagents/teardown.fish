#!/usr/bin/env fish

if test (uname) != Darwin
    echo "[ERROR] LaunchAgents are supported on macOS only." >&2
    exit 1
end

set uid (id -u)
set script_dir (cd (dirname (status -f)); and pwd)
source "$script_dir/helpers.fish"

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon

set cache_dir "$HOME/.cache/sketchybar"
if set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"
    set cache_dir "$XDG_CACHE_HOME/sketchybar"
end
function stop_agent --argument-names label pid_file
    set -l target "gui/$uid/$label"
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

    if not launchctl disable "$target"
        echo "[ERROR] Failed to disable $label" >&2
        return 1
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

set failed 0
stop_agent "$media_label" "$cache_dir/media.pid"; or set failed 1
stop_agent "$calendar_label" "$cache_dir/calendar.pid"; or set failed 1
exit $failed
