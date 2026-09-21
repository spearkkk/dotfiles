#!/usr/bin/env fish

set script_dir (cd (dirname (status -f)); and pwd)
set uid (id -u)

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon

set launchagent_dir "$HOME/Library/LaunchAgents"
set media_plist "$launchagent_dir/$media_label.plist"
set calendar_plist "$launchagent_dir/$calendar_label.plist"

function unload_label
    set label "$argv[1]"

    launchctl bootout "gui/$uid/$label" >/dev/null 2>&1; or true

    for attempt in (seq 1 100)
        if not launchctl print "gui/$uid/$label" >/dev/null 2>&1
            return 0
        end

        sleep 0.2
    end

    echo "[ERROR] Timed out while unloading $label" >&2
    return 1
end

if test (uname) != Darwin
    echo "[ERROR] LaunchAgents are supported on macOS only." >&2
    exit 1
end

for plist in "$media_plist" "$calendar_plist"
    if not test -f "$plist"
        echo "[ERROR] LaunchAgent plist is missing: $plist" >&2
        echo "        Run: make -C $script_dir install" >&2
        exit 1
    end
end

for label in $media_label $calendar_label
    if not unload_label "$label"
        exit 1
    end
end

set cache_dir "$HOME/.cache/sketchybar"
if set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"
    set cache_dir "$XDG_CACHE_HOME/sketchybar"
end
rm -f "$cache_dir/media.pid" "$cache_dir/calendar.pid"

for plist in "$media_plist" "$calendar_plist"
    if not launchctl bootstrap "gui/$uid" "$plist"
        echo "[ERROR] Failed to bootstrap $plist" >&2
        exit 1
    end
end

for label in $media_label $calendar_label
    if not launchctl kickstart "gui/$uid/$label"
        echo "[ERROR] Failed to start $label" >&2
        exit 1
    end
end

command fish "$script_dir/status.fish"
