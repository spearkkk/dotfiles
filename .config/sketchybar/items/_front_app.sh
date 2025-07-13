#!/bin/bash

FRONT_APP=(
  --add item _front_app q
  --set _front_app
  icon.drawing=off
  label.padding_left=10
  label.padding_right=10
  label.color="$(set_alpha $YELLOW 100)"
  label.font.style="Italic"
  background.corner_radius=2
  background.border_width=1
  background.border_color="$(set_alpha $YELLOW 100)"
  background.color="$(set_alpha $BLACK 80)"
  display="active"
  script="$PLUGIN_DIR/front_app.sh"
  click_script="open -a 'Mission Control'"
  --subscribe _front_app front_app_switched
)

render_front_app() {
  sketchybar "${FRONT_APP[@]}"
}