#!/bin/bash

# Battery item configuration
BATTERY=(
    --add item _battery right
    --set _battery
    icon.padding_left="$INNER_PADDING"
    icon.padding_right="$OUTER_PADDING"
    label.drawing=off
    background.drawing=off
    update_freq=120
    script="$PLUGIN_DIR/battery.sh"
    --subscribe _battery system_woke power_source_change
)

sketchybar "${BATTERY[@]}"
