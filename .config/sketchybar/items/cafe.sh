sketchybar --add item lua.cafe right \
           --set lua.cafe \
                 icon="􀸘" \
                 icon.font.size="$PILL_ICON_SIZE" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$INNER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label.drawing=off \
                 background.drawing=off \
                 display="$MAIN_DISPLAY_ID" \
                 update_freq=10 \
                 script="$CONFIG_DIR/plugins/cafe.lua" \
                 click_script="$CONFIG_DIR/plugins/cafe.lua"
