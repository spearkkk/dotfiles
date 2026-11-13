#!/usr/bin/env fish

set script_dir (cd (dirname (status -f)); and pwd)
set uid (id -u)
source "$script_dir/helpers.fish"

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon
set detail_label dev.spearkkk.sketchibar

set launchagent_dir "$HOME/Library/LaunchAgents"
set media_plist "$launchagent_dir/$media_label.plist"
set calendar_plist "$launchagent_dir/$calendar_label.plist"
set detail_plist "$launchagent_dir/$detail_label.plist"

if test (uname) != Darwin
    echo "[ERROR] LaunchAgents are supported on macOS only." >&2
    exit 1
end

for plist in "$media_plist" "$calendar_plist" "$detail_plist"
    if not test -f "$plist"
        echo "[ERROR] LaunchAgent plist is missing: $plist" >&2
        echo "        Run: make -C $script_dir install" >&2
        exit 1
    end
end

set cache_dir "$HOME/.cache/sketchybar"
if set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"
    set cache_dir "$XDG_CACHE_HOME/sketchybar"
end
# Do not enable or load any agent until all previous processes have exited.
launchagent_stop "gui/$uid/$media_label" "$cache_dir/media.pid"; or exit 1
launchagent_stop "gui/$uid/$calendar_label" "$cache_dir/calendar.pid"; or exit 1
launchagent_stop "gui/$uid/$detail_label" "$cache_dir/sketchibar.pid"; or exit 1

# teardown persists disabled state in launchd; bootstrap must undo it explicitly.
for label in $media_label $calendar_label $detail_label
    if not launchctl enable "gui/$uid/$label"
        echo "[ERROR] Failed to enable $label" >&2
        exit 1
    end
end

for plist in "$media_plist" "$calendar_plist" "$detail_plist"
    if not launchctl bootstrap "gui/$uid" "$plist"
        echo "[ERROR] Failed to bootstrap $plist" >&2
        exit 1
    end
end

for label in $media_label $calendar_label $detail_label
    if not launchctl kickstart "gui/$uid/$label"
        echo "[ERROR] Failed to start $label" >&2
        exit 1
    end
end

# kickstart may return before launchd publishes the running state/PID.
for attempt in (seq 1 100)
    if command fish "$script_dir/status.fish" >/dev/null 2>&1
        command fish "$script_dir/status.fish"
        exit $status
    end
    sleep 0.2
end
echo "[ERROR] Timed out while waiting for LaunchAgents to start" >&2
command fish "$script_dir/status.fish"
exit 1
