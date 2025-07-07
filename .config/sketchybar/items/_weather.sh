WEATHER=(
  script="$PLUGIN_DIR/weather.sh"
  update_freq="$LAZY_FREQUENCY"
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$INNER_PADDING"
  icon.font.size=24
  icon.y_offset=-1
  icon.drawing=on
  label.padding_right="$OUTER_PADDING"
)

sketchybar --add item _weather right \
           --set _weather "${WEATHER[@]}"