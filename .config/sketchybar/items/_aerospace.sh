#!/bin/bash

sketchybar --add event aerospace_workspace_change
sketchybar --add event aerospace_monitor_change

for monitor_idx in $(aerospace list-monitors | awk '{print $1}'); do
  for workspace_idx in $(aerospace list-workspaces --monitor "$monitor_idx"); do
    space_id=$workspace_idx

    space=(
      space="$space_id"
      icon="$(sf_symbol_for "$space_id")"
      icon.highlight_color="$TEXT_DEFAULT"
      icon.padding_left=10
      icon.padding_right=4
      icon.font.size=16
      icon.y_offset=-1
      label.font.family="sketchybar-app-font-bg"
      label.font.style="Regular"
      label.font.size=18
      label.y_offset=-2
      label.padding_left=0
      label.padding_right=0
      label.highlight_color="$TEXT_DEFAULT"
      label.color="$TEXT_DEFAULT"
      drawing=on
      background.drawing=off
      background.padding_left=0
      background.padding_right=0
      display="$monitor_idx"
      script="$PLUGIN_DIR/aerospace.sh $space_id"
      click_script="~/.config/aerospace/workspace_change.sh $space_id"
    )
    sketchybar -m --add space space."$space_id" left \
               --set space."$space_id" "${space[@]}" \
               --subscribe space."$space_id" aerospace_workspace_change aerospace_monitor_change
  done
  for i in $(aerospace list-workspaces --monitor "$monitor_idx" --empty); do
    sketchybar --set space."$i" icon.drawing=off label.drawing=off background.drawing=off
  done
done

sketchybar --add bracket _aerospace '/space\..*/' \
           --set _aerospace drawing=on \
                 background.drawing=on \
                 background.corner_radius=4 \
                 background.border_width=0 \
                 background.y_offset=0