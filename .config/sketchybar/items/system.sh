# system group: cafe + volume + battery
sketchybar --add bracket lua.system_group lua.cafe lua.volume lua.battery \
           --set lua.system_group \
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
