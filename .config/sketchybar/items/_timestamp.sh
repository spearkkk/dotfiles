TIMESTAMP=(
  icon="$(sf_symbol_for cal)"
  script="$PLUGIN_DIR/timestamp.sh"
  update_freq="$EAGER_FREQUENCY"
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$INNER_PADDING"
  label.padding_left="$INNER_PADDING"
  label.padding_right="$OUTER_PADDING"
)

sketchybar --add item _timestamp center \
           --set _timestamp "${TIMESTAMP[@]}"