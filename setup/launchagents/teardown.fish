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
set detail_label dev.spearkkk.sketchibar

set cache_dir "$HOME/.cache/sketchybar"
if set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"
    set cache_dir "$XDG_CACHE_HOME/sketchybar"
end

set failed 0
launchagent_stop "gui/$uid/$media_label" "$cache_dir/media.pid" --disable; or set failed 1
launchagent_stop "gui/$uid/$calendar_label" "$cache_dir/calendar.pid" --disable; or set failed 1
launchagent_stop "gui/$uid/$detail_label" "$cache_dir/sketchibar.pid" --disable; or set failed 1
exit $failed
