TIMESTAMP=(
  icon="$(sf_symbol_for cal)"
  icon.color="$ORANGE"
  script="$PLUGIN_DIR/timestamp.sh"
  update_freq="$EAGER_FREQUENCY"
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$INNER_PADDING"
  label.padding_left="$INNER_PADDING"
  label.padding_right="$OUTER_PADDING"
  label.font.size=10
  label.y_offset=-2
  background.padding_left=0
  background.padding_right=0
  background.drawing=off
)

sketchybar --add item _timestamp right \
           --set _timestamp "${TIMESTAMP[@]}"