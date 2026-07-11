#!/usr/bin/env fish

set script_dir (cd (dirname (status -f)); and pwd)
set repo_root (dirname "$script_dir")
set uid (id -u)

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon

set media_plist "$HOME/Library/LaunchAgents/$media_label.plist"
set calendar_plist "$HOME/Library/LaunchAgents/$calendar_label.plist"

cd "$repo_root"
stow -t "$HOME" --ignore='^bootstrap\.fish$' --ignore='^teardown\.fish$' launchagents

for label in $media_label $calendar_label
    launchctl bootout "gui/$uid/$label" >/dev/null 2>&1
end

rm -f /tmp/sketchybar_media_daemon.pid /tmp/sketchybar_todays_daemon.pid

launchctl bootstrap "gui/$uid" "$media_plist"
launchctl bootstrap "gui/$uid" "$calendar_plist"

launchctl kickstart "gui/$uid/$media_label"
launchctl kickstart "gui/$uid/$calendar_label"

launchctl list | rg 'dev\.spearkkk\.sketchybar\.(media|calendar)-daemon'
