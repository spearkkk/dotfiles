#!/usr/bin/env fish

if test (uname) != Darwin
    echo "[ERROR] LaunchAgents are supported on macOS only." >&2
    exit 1
end

set uid (id -u)
set labels \
    dev.spearkkk.sketchybar.media-daemon \
    dev.spearkkk.sketchybar.calendar-daemon
set log_files \
    /tmp/dev.spearkkk.sketchybar.media-daemon.log \
    /tmp/dev.spearkkk.sketchybar.calendar-daemon.log
set error_log_files \
    /tmp/dev.spearkkk.sketchybar.media-daemon.err.log \
    /tmp/dev.spearkkk.sketchybar.calendar-daemon.err.log
set stopped 0

for index in (seq (count $labels))
    set label $labels[$index]
    if launchctl print "gui/$uid/$label" >/dev/null 2>&1
        echo "running: $label"
    else
        echo "stopped: $label"
        set stopped 1
    end

    echo "  stdout: $log_files[$index]"
    echo "  stderr: $error_log_files[$index]"
end

exit $stopped
