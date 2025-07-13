POMODORO=(
  --add item _pomodoro_break right
  --set _pomodoro_break
  icon="􀼙"
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$OUTER_PADDING"
  drawing=off
  background.drawing=off
  click_script="$PLUGIN_DIR/pomodoro.sh _pomodoro_break _pomodoro_work _pomodoro_break"
  --add item _pomodoro_work right
  --set _pomodoro_work
  icon="􀠸"
  icon.padding_left="$OUTER_PADDING"
  icon.padding_right="$OUTER_PADDING"
  drawing=on
  background.drawing=off
  click_script="$PLUGIN_DIR/pomodoro.sh _pomodoro_break _pomodoro_work _pomodoro_work"
  --add bracket _pomodoro _pomodoro_break _pomodoro_work
  --set _pomodoro
    drawing=on
    padding_left=100
    background.drawing=on
    background.corner_radius=4
    background.border_width=0
    background.y_offset=0
)

sketchybar "${POMODORO[@]}"