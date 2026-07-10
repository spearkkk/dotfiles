#!/usr/bin/env fish

set uid (id -u)

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon

for label in $media_label $calendar_label
    launchctl bootout "gui/$uid/$label" >/dev/null 2>&1
    launchctl disable "gui/$uid/$label" >/dev/null 2>&1
    launchctl remove "$label" >/dev/null 2>&1
end

rm -f /tmp/sketchybar_media_daemon.pid /tmp/sketchybar_todays_daemon.pid

launchctl print "gui/$uid" 2>/dev/null | rg 'dev\.spearkkk\.sketchybar\.(media|calendar)-daemon' -n -S || echo "(disabled)"
