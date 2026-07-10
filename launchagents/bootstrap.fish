#!/usr/bin/env fish

set repo_root (cd (dirname (status -f)); and pwd; and cd ..; and pwd)
set uid (id -u)

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon

set media_plist "$HOME/Library/LaunchAgents/$media_label.plist"
set calendar_plist "$HOME/Library/LaunchAgents/$calendar_label.plist"

cd "$repo_root"
stow -t "$HOME" launchagents

for label in $media_label $calendar_label
    launchctl bootout "gui/$uid/$label" >/dev/null 2>&1
end

launchctl bootstrap "gui/$uid" "$media_plist"
launchctl bootstrap "gui/$uid" "$calendar_plist"

launchctl kickstart -k "gui/$uid/$media_label"
launchctl kickstart -k "gui/$uid/$calendar_label"

launchctl list | rg 'dev\.spearkkk\.sketchybar\.(media|calendar)-daemon'
