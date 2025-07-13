WEATHER=(
  --add item _weather right
  --set _weather
  script="$PLUGIN_DIR/weather.sh"
  update_freq="$LAZY_FREQUENCY"
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$INNER_PADDING"
  icon.y_offset=0
  icon.drawing=on
  label.padding_right="$OUTER_PADDING"
  label.font.size=10
  label.y_offset=-2
  background.padding_left=0
  background.padding_right=0
  background.drawing=off
)

sketchybar "${WEATHER[@]}"