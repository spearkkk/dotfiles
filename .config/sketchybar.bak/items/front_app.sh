sketchybar --add item lua.front_app q \
           --set lua.front_app \
                 icon.drawing=off \
                 label.color="$PILL_LABEL_COLOR" \
                 label.font.style="Italic" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.align=left \
                 label.y_offset=0 \
                 label.max_chars="$FRONT_APP_MAX_CHARS" \
                 label.padding_left=10 \
                 label.padding_right=10 \
                 background.padding_left=6 \
                 background.padding_right=6 \
                 background.color="$PILL_BG_COLOR" \
                 background.height="$DEFAULT_BG_HEIGHT" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width=3 \
                 background.border_color="$(set_alpha "$BRIGHT_BLACK" 90)" \
                 background.y_offset="$PILL_Y_OFFSET" \
                 background.drawing=on \
                 display=all \
                 update_freq=0 \
                 script="$CONFIG_DIR/plugins/front_app.lua" \
                 click_script="open -a 'Mission Control'" \
           --subscribe lua.front_app front_app_switched display_change aerospace_workspace_change system_woke
