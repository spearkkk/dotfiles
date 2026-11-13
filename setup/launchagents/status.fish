#!/usr/bin/env fish

if test (uname) != Darwin
    echo "[ERROR] LaunchAgents are supported on macOS only." >&2
    exit 1
end

set uid (id -u)
source (dirname (status -f))/helpers.fish
set labels \
    dev.spearkkk.sketchybar.media-daemon \
    dev.spearkkk.sketchybar.calendar-daemon \
    dev.spearkkk.sketchibar
set log_files \
    /tmp/dev.spearkkk.sketchybar.media-daemon.log \
    /tmp/dev.spearkkk.sketchybar.calendar-daemon.log \
    /tmp/dev.spearkkk.sketchibar.log
set error_log_files \
    /tmp/dev.spearkkk.sketchybar.media-daemon.err.log \
    /tmp/dev.spearkkk.sketchybar.calendar-daemon.err.log \
    /tmp/dev.spearkkk.sketchibar.err.log
set stopped 0

for index in (seq (count $labels))
    set label $labels[$index]
    launchagent_query "gui/$uid/$label"
    switch $status
        case 0
            if test "$launchagent_state" = running; and test -n "$launchagent_pid"
                echo "running: $label (pid=$launchagent_pid)"
            else
                echo "loaded: $label (state=$launchagent_state, pid=$launchagent_pid, last_exit=$launchagent_last_exit)"
                set stopped 1
            end
        case 113
            echo "stopped: $label"
            set stopped 1
        case '*'
            echo "unknown: $label"
            set stopped 1
    end

    echo "  stdout: $log_files[$index]"
    echo "  stderr: $error_log_files[$index]"
end

exit $stopped
