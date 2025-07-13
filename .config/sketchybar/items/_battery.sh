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
    click_script='open "btt://trigger_named/?trigger_name=sketchybar-control-center-trigger"'
    --subscribe _battery system_woke power_source_change
)

sketchybar "${BATTERY[@]}"
