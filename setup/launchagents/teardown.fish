#!/usr/bin/env fish

set uid (id -u)
set script_dir (cd (dirname (status -f)); and pwd)

set media_label dev.spearkkk.sketchybar.media-daemon
set calendar_label dev.spearkkk.sketchybar.calendar-daemon

for label in $media_label $calendar_label
    launchctl bootout "gui/$uid/$label" >/dev/null 2>&1
    launchctl disable "gui/$uid/$label" >/dev/null 2>&1
    launchctl remove "$label" >/dev/null 2>&1
end

set cache_dir "$HOME/.cache/sketchybar"
if set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"
    set cache_dir "$XDG_CACHE_HOME/sketchybar"
end
rm -f "$cache_dir/media.pid" "$cache_dir/calendar.pid"

command fish "$script_dir/status.fish"; or true
