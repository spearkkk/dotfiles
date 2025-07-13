#!/bin/bash

APP=(
  --add item _sausage e
  --set _sausage
  icon.drawing=off
  label.drawing=off
  image.drawing=on
  background.drawing=on
  background.image.scale=0.5
  background.color=0x00000000
  padding_left=50
  script="$PLUGIN_DIR/sausage.sh"
  click_script="$PLUGIN_DIR/sausage_killer.sh"
)
sketchybar  "${APP[@]}"