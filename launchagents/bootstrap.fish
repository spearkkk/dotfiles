#!/usr/bin/env fish

set script_dir (cd (dirname (status -f)); and pwd)
set repo_root (dirname "$script_dir")
set uid (id -u)

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon

set media_plist "$HOME/Library/LaunchAgents/$media_label.plist"
set calendar_plist "$HOME/Library/LaunchAgents/$calendar_label.plist"

if test (uname) != Darwin
    echo "[ERROR] LaunchAgents are supported on macOS only." >&2
    exit 1
end

if not type -q stow
    echo "[ERROR] GNU Stow is required to install LaunchAgent plists." >&2
    exit 1
end

cd "$repo_root"
if not stow -t "$HOME" --ignore='^bootstrap\.fish$' --ignore='^teardown\.fish$' launchagents
    echo "[ERROR] Failed to link LaunchAgent plists." >&2
    exit 1
end

for plist in "$media_plist" "$calendar_plist"
    if not test -f "$plist"
        echo "[ERROR] LaunchAgent plist is missing: $plist" >&2
        exit 1
    end
end

for label in $media_label $calendar_label
    launchctl bootout "gui/$uid/$label" >/dev/null 2>&1
end

rm -f /tmp/sketchybar_media_daemon.pid /tmp/sketchybar_todays_daemon.pid

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
