#!/bin/bash

#STATE="$(echo "$INFO" | jq -r '.state')"
#if [ "$STATE" = "playing" ]; then
#  MEDIA="$(echo "$INFO" | jq -r '.title + " - " + .artist')"
#  sketchybar --set $NAME label="$MEDIA" drawing=on
#else
#  sketchybar --set $NAME drawing=off
#fi

sketchybar --set $NAME label="$INFO hey" drawing=on