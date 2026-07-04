sketchybar --add item lua.cmux_workspace left \
           --set lua.cmux_workspace \
                 icon="" \
                 icon.font.size="$PILL_ICON_SIZE" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$OUTER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label="cmux: -" \
                 label.color="$PILL_LABEL_COLOR" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.padding_left="$INNER_PADDING" \
                 label.padding_right="$OUTER_PADDING" \
                 label.max_chars=28 \
                 label.y_offset=0 \
                 background.color="$PILL_BG_COLOR" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width="$PILL_BORDER_WIDTH" \
                 background.border_color="$PILL_BORDER_COLOR" \
                 background.y_offset="$PILL_Y_OFFSET" \
                 background.drawing=on \
                 script="$CONFIG_DIR/plugins/cmux_workspace.lua" \
                 update_freq=2 \
           --subscribe lua.cmux_workspace system_woke mouse.clicked aerospace_workspace_change
