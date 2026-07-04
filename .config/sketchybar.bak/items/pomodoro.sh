
sketchybar --add item lua.pomodoro_break right \
           --set lua.pomodoro_break \
                 icon="􀼙" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$INNER_PADDING" \
                 icon.padding_right="$OUTER_PADDING" \
                 icon.y_offset=0 \
                 label="" \
                 label.color="$PILL_LABEL_COLOR" \
                 label.drawing=off \
                 label.padding_left="$INNER_PADDING" \
                 label.padding_right="$INNER_PADDING" \
                 label.y_offset=0 \
                 drawing=off \
                 display="$MAIN_DISPLAY_ID" \
                 background.drawing=off \
                 click_script="$CONFIG_DIR/plugins/pomodoro.lua lua.pomodoro_break lua.pomodoro_work lua.pomodoro_break"

sketchybar --add item lua.pomodoro_work right \
           --set lua.pomodoro_work \
                 icon="􀠸" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$INNER_PADDING" \
                 icon.padding_right="$OUTER_PADDING" \
                 icon.y_offset=0 \
                 label="" \
                 label.color="$PILL_LABEL_COLOR" \
                 label.drawing=off \
                 label.padding_left="$INNER_PADDING" \
                 label.padding_right="$INNER_PADDING" \
                 label.y_offset=0 \
                 drawing=on \
                 display="$MAIN_DISPLAY_ID" \
                 background.drawing=off \
                 click_script="$CONFIG_DIR/plugins/pomodoro.lua lua.pomodoro_break lua.pomodoro_work lua.pomodoro_work"

sketchybar --add bracket lua.pomodoro lua.pomodoro_break lua.pomodoro_work \
           --set lua.pomodoro \
                 drawing=on \
                 display="$MAIN_DISPLAY_ID" \
                 padding_left="$OUTER_PADDING" \
                 padding_right="$OUTER_PADDING" \
                 background.drawing=on \
                 background.color="$PILL_BG_COLOR" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width="$PILL_BORDER_WIDTH" \
                 background.border_color="$PILL_BORDER_COLOR" \
                 background.y_offset="$PILL_Y_OFFSET"
