#!/bin/bash

if [[ "$SENDER" == "aerospace_monitor_change" ]]; then
  sketchybar --set space."$(aerospace list-workspaces --focused)" display="$TARGET_MONITOR"
  exit 0
fi

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icon_map.sh"

HIGHLIGHTED=(
  icon.highlight=on
  label.highlight=on
  background.color="$(set_alpha $BLACK 60)"
#  background.border_color="$(set_alpha $YELLOW 60)"
#  background.border_width=2
)
NOT_HIGHLIGHTED=(
  icon.highlight=off
  label.highlight=off
  background.color="0x00000000"
#  background.border_width=0
#  background.border_color="0x00000000"
)

FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused)"
apps=$(aerospace list-windows --workspace "$FOCUSED_WORKSPACE" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

#label="hello"
#if [ "${apps}" != "" ]; then
#  while read -r app
#  do
#    label+=" $(get_app_icon "$app")"
#  done <<< "${apps}"
#fi

for monitor_idx in $(aerospace list-monitors | awk '{print $1}'); do
  for workspace_idx in $(aerospace list-workspaces --monitor "$monitor_idx"); do
    space_id=$workspace_idx
    apps=$(aerospace list-windows --workspace "$space_id" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

    label=""
    if [ "${apps}" != "" ]; then
      while read -r app
      do
        label+=" $(get_app_icon "$app")"
      done <<< "${apps}"
    fi

    if [[ -n "$label" ]]; then
      sketchybar --set space."$space_id" icon.padding_right=4
      sketchybar --set space."$space_id" label.padding_right=16
      sketchybar --set space."$space_id" icon.drawing=on label.drawing=on background.drawing=on
    else
      sketchybar --set space."$space_id" icon.padding_right=10
      sketchybar --set space."$space_id" label.padding_right=0
    fi

    sketchybar --set space."$space_id" label="$label"

    if [[ "$workspace_idx" == "$FOCUSED_WORKSPACE" ]]; then
      sketchybar --set space."$workspace_idx" "${HIGHLIGHTED[@]}"
    else
      sketchybar --set space."$workspace_idx" "${NOT_HIGHLIGHTED[@]}"
    fi
  done
  for i in $(aerospace list-workspaces --monitor "$monitor_idx" --empty); do
      sketchybar --set space."$i" icon.drawing=off label.drawing=off background.drawing=off
  done
done
