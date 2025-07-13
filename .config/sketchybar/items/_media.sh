MEDIA_APP=(
  --add item _media right
  --set _media
#  label.max_chars=50
  script="$PLUGIN_DIR/media.sh"
  width=100
  --subscribe _media media_change
)

sketchybar "${MEDIA_APP[@]}"