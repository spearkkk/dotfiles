CAFE=(
  --add item _cafe right
  --set _cafe
  icon.padding_left="$INNER_PADDING"
  icon.padding_right="$INNER_PADDING"
  label.drawing=off
  background.drawing=off
  update_freq=10
  script="$CONFIG_DIR/plugins/cafe.sh" \
  click_script="$CONFIG_DIR/plugins/cafe.sh"
)

sketchybar "${CAFE[@]}"
