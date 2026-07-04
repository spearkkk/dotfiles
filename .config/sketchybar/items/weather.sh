sketchybar --add item lua.weather right \
           --set lua.weather \
                 icon="􀇃" \
                 icon.font.size="$PILL_ICON_SIZE" \
                 script="$CONFIG_DIR/plugins/weather.lua" \
                 update_freq="$LAZY_FREQUENCY" \
                 icon.padding_left="$OUTER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label.color="$PILL_LABEL_COLOR" \
                 label.padding_left="$INNER_PADDING" \
                 label.padding_right="$OUTER_PADDING" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.y_offset=0 \
                 background.padding_left=0 \
                 background.padding_right=0 \
                 background.color="$PILL_BG_COLOR" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width="$PILL_BORDER_WIDTH" \
                 background.border_color="$PILL_BORDER_COLOR" \
                 background.y_offset="$PILL_Y_OFFSET" \
                 background.drawing=on
