#!/bin/bash

#STATE="$(echo "$INFO" | jq -r '.state')"
#if [ "$STATE" = "playing" ]; then
#  MEDIA="$(echo "$INFO" | jq -r '.title + " - " + .artist')"
#  sketchybar --set $NAME label="$MEDIA" drawing=on
#else
#  sketchybar --set $NAME drawing=off
#fi

TITLE=$(osascript -e 'tell application "BetterTouchTool" to get_string_variable "NowPlayingTitle"')
ARTIST=$(osascript -e 'tell application "BetterTouchTool" to get_string_variable "NowPlayingArtist"')

echo "Title: $TITLE"
echo "Artist: $ARTIST"
#sketchybar --set media_item label="$TITLE - $ARTIST"
#sketchybar --set $NAME label="$INFO hey" drawing=on