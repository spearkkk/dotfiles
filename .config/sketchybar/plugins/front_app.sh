#!/bin/bash

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

source "$CONFIG_DIR/icon_map.sh"
LABEL="$(get_app_icon "$INFO")"

if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set "$NAME" icon="$LABEL" label="$INFO"
fi