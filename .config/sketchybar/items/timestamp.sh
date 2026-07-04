TIMESTAMP_SCRIPT="TIMESTAMP_DATE_ITEM=lua.timestamp.date TIMESTAMP_TIME_ITEM=lua.timestamp.time TIMESTAMP_BASE_LABEL_COLOR=$PILL_LABEL_COLOR TIMESTAMP_BASE_ICON_COLOR=$BRIGHT_YELLOW TIMESTAMP_BASE_LABEL_SIZE=$PILL_LABEL_SIZE $CONFIG_DIR/plugins/timestamp.lua"

sketchybar --add item lua.timestamp.time right \
           --set lua.timestamp.time \
                 icon.drawing=off \
                 script="$TIMESTAMP_SCRIPT" \
                 click_script='open "btt://trigger_named/?trigger_name=sketchybar-notification-center-trigger"' \
                 update_freq="$EAGER_FREQUENCY" \
                 label.color="$PILL_LABEL_COLOR" \
                 label.padding_left="$OUTER_PADDING" \
                 label.padding_right="$INNER_PADDING" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.y_offset=0 \
                 background.drawing=off \
                 padding_left=0 \
                 padding_right=0

sketchybar --add item lua.timestamp.date right \
           --set lua.timestamp.date \
                 icon="􀉉" \
                 icon.color="$BRIGHT_YELLOW" \
                 icon.font.size="$PILL_ICON_SIZE" \
                 script="$TIMESTAMP_SCRIPT" \
                 click_script='open "btt://trigger_named/?trigger_name=sketchybar-notification-center-trigger"' \
                 update_freq="$EAGER_FREQUENCY" \
                 icon.padding_left="$INNER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label.color="$PILL_LABEL_COLOR" \
                 label.padding_left="$INNER_PADDING" \
                 label.padding_right="$OUTER_PADDING" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.y_offset=0 \
                 background.drawing=off \
                 padding_left=0 \
                 padding_right=0

sketchybar --add bracket lua.timestamp_group \
                  lua.timestamp.time \
                  lua.timestamp.date \
           --set lua.timestamp_group \
                 drawing=on \
                 background.drawing=on \
                 background.color="$PILL_BG_COLOR" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width="$PILL_BORDER_WIDTH" \
                 background.border_color="$PILL_BORDER_COLOR" \
                 background.y_offset="$PILL_Y_OFFSET" \
                 padding_left=0 \
                 padding_right=0
