#!/bin/bash

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

# get_current_front_app() {
#     lsappinfo info -only name `lsappinfo front` | cut -d'"' -f4
# }

get_current_front_app() {
    local app_name
    app_name=$(lsappinfo info -only name $(lsappinfo front) | cut -d'"' -f4 | xargs)

    if [ -z "$app_name" ]; then
        app_name=$(lsappinfo list | rg "in front" | awk -F'"' '{print $2}' | xargs)
    fi

    echo "$app_name"
}

sketchybar --set "$NAME" label="$(get_current_front_app)"
