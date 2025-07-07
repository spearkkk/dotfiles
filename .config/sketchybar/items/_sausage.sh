#!/bin/bash

APP=(
  icon.drawing=off
  label.drawing=off
  image.drawing=on
  background.drawing=on
  background.image.scale=0.5
  background.color=0x00000000
  update_freq=1
  script="$PLUGIN_DIR/sausage.sh"
)
sketchybar --add item _sausage e \
           --set _sausage "${APP[@]}"