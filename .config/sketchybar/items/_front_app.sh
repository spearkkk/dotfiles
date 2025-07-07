#!/bin/sh
# https://github.com/forteleaf/sketkchybar-with-aerospace
APP=(
  icon.font.family="sketchybar-app-font-bg"
  icon.font.style="Regular"
  icon.font.size=18
  icon.y_offset=-2
  icon.color="$YELLOW"
  icon.padding_left=8
  label.padding_left=10
  label.padding_right=16
  label.color="$YELLOW"
  label.font.style="Regular"
  background.color="$(set_alpha $BLACK 90)"
  background.border_color="$(set_alpha $YELLOW 90)"
  background.border_width=2
  script="$PLUGIN_DIR/front_app.sh"
  click_script="open -a 'Mission Control'"
)
sketchybar --add item _front_app q         \
           --set _front_app "${APP[@]}" \
           --subscribe _front_app front_app_switched
