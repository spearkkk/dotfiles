THINGS=(
  --add item _things right
  --set _things
  icon="􀈤"
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$INNER_PADDING"
  label.padding_left=0
  label.padding_right="$INNER_PADDING"
  label.font.size=10
  label.y_offset=-2
  background.drawing=off
  update_freq=300
  script="$CONFIG_DIR/plugins/things.sh"
  click_script="open 'things:///show?id=today'"
)

sketchybar "${THINGS[@]}"
