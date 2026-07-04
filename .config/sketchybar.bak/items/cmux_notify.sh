sketchybar --add item lua.cmux_notify left \
           --set lua.cmux_notify \
                 icon="󰂚" \
                 icon.font.size="$PILL_ICON_SIZE" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$OUTER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label="notify: -" \
                 label.color="$PILL_LABEL_COLOR" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.padding_left="$INNER_PADDING" \
                 label.padding_right="$OUTER_PADDING" \
                 label.max_chars=24 \
                 label.y_offset=0 \
                 background.color="$PILL_BG_COLOR" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width="$PILL_BORDER_WIDTH" \
                 background.border_color="$PILL_BORDER_COLOR" \
                 background.y_offset="$PILL_Y_OFFSET" \
                 background.drawing=on \
                 script="$CONFIG_DIR/plugins/cmux_notify.lua" \
                 click_script="$CONFIG_DIR/plugins/cmux_notify.lua --toggle-popup" \
                 update_freq=5 \
           --subscribe lua.cmux_notify system_woke aerospace_workspace_change

sketchybar --add item lua.cmux_notify.line1 popup.lua.cmux_notify \
           --set lua.cmux_notify.line1 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.cmux_notify.line2 popup.lua.cmux_notify \
           --set lua.cmux_notify.line2 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.cmux_notify.line3 popup.lua.cmux_notify \
           --set lua.cmux_notify.line3 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.cmux_notify.line4 popup.lua.cmux_notify \
           --set lua.cmux_notify.line4 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.cmux_notify.line5 popup.lua.cmux_notify \
           --set lua.cmux_notify.line5 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.cmux_notify.line6 popup.lua.cmux_notify \
           --set lua.cmux_notify.line6 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.cmux_notify.line7 popup.lua.cmux_notify \
           --set lua.cmux_notify.line7 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.cmux_notify.line8 popup.lua.cmux_notify \
           --set lua.cmux_notify.line8 icon.drawing=off label="-" label.max_chars=52 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
