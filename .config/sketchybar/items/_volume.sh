VOLUME=(
  --add item _volume right
  --set _volume
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$INNER_PADDING"
  label.drawing=off
  background.drawing=off
  script="$PLUGIN_DIR/volume.sh"
  --subscribe _volume volume_change
)

sketchybar "${VOLUME[@]}"