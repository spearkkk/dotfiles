sketchybar --add item lua.volume right \
           --set lua.volume \
                 icon="􀊩" \
                 icon.font.size="$PILL_ICON_SIZE" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$INNER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label.drawing=off \
                 background.drawing=off \
                 display="$MAIN_DISPLAY_ID" \
                 script="$CONFIG_DIR/plugins/volume.lua" \
                 click_script="$CONFIG_DIR/plugins/volume.lua --toggle" \
           --subscribe lua.volume volume_change system_woke
