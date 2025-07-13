TRANSPARENT=(
  background.color="$(set_alpha $BLACK 80)"
  background.padding_left=2
  background.padding_right=2
  background.drawing=on
  background.height=22
  display="active"
)

render() {
sketchybar --add item _transparent."$1" right \
           --set _transparent."$1" "${TRANSPARENT[@]}"
}
