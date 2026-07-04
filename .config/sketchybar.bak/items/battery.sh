sketchybar --add item lua.battery right \
           --set lua.battery \
                 icon.font.size="$PILL_ICON_SIZE" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$INNER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label.drawing=off \
                 background.drawing=off \
                 display="$MAIN_DISPLAY_ID" \
                 update_freq=120 \
                 script="$CONFIG_DIR/plugins/battery.lua" \
                 click_script="$CONFIG_DIR/plugins/battery.lua --toggle-popup" \
           --subscribe lua.battery system_woke power_source_change

sketchybar --add item lua.battery.popup popup.lua.battery \
           --set lua.battery.popup \
                 icon.drawing=off \
                 label="--" \
                 label.color="$PILL_LABEL_COLOR" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.padding_left="$OUTER_PADDING" \
                 label.padding_right="$OUTER_PADDING" \
                 background.color="$PILL_BG_COLOR" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width=2 \
                 background.border_color="$(set_alpha "$BRIGHT_BLACK" 95)" \
                 background.y_offset="$PILL_Y_OFFSET" \
                 background.drawing=on
