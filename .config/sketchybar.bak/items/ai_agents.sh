sketchybar --add item lua.ai_agents left \
           --set lua.ai_agents \
                 icon="󱙺" \
                 icon.font.size="$PILL_ICON_SIZE" \
                 icon.color="$PILL_LABEL_COLOR" \
                 icon.padding_left="$OUTER_PADDING" \
                 icon.padding_right="$INNER_PADDING" \
                 icon.y_offset=0 \
                 label="ai: -" \
                 label.color="$PILL_LABEL_COLOR" \
                 label.font.size="$PILL_LABEL_SIZE" \
                 label.padding_left="$INNER_PADDING" \
                 label.padding_right="$OUTER_PADDING" \
                 label.max_chars=36 \
                 label.y_offset=0 \
                 background.color="$PILL_BG_COLOR" \
                 background.corner_radius="$PILL_CORNER_RADIUS" \
                 background.border_width="$PILL_BORDER_WIDTH" \
                 background.border_color="$PILL_BORDER_COLOR" \
                 background.y_offset="$PILL_Y_OFFSET" \
                 background.drawing=on \
                 script="$CONFIG_DIR/plugins/ai_agents.lua" \
                 click_script="$CONFIG_DIR/plugins/ai_agents.lua --toggle-popup" \
                 update_freq=4 \
           --subscribe lua.ai_agents system_woke aerospace_workspace_change

sketchybar --add item lua.ai_agents.line1 popup.lua.ai_agents \
           --set lua.ai_agents.line1 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.ai_agents.line2 popup.lua.ai_agents \
           --set lua.ai_agents.line2 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.ai_agents.line3 popup.lua.ai_agents \
           --set lua.ai_agents.line3 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.ai_agents.line4 popup.lua.ai_agents \
           --set lua.ai_agents.line4 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.ai_agents.line5 popup.lua.ai_agents \
           --set lua.ai_agents.line5 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.ai_agents.line6 popup.lua.ai_agents \
           --set lua.ai_agents.line6 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.ai_agents.line7 popup.lua.ai_agents \
           --set lua.ai_agents.line7 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
sketchybar --add item lua.ai_agents.line8 popup.lua.ai_agents \
           --set lua.ai_agents.line8 icon.drawing=off label="-" label.max_chars=64 label.color="$PILL_LABEL_COLOR" label.font.size="$PILL_LABEL_SIZE" label.padding_left="$OUTER_PADDING" label.padding_right="$OUTER_PADDING" background.color="$PILL_BG_COLOR" background.corner_radius="$PILL_CORNER_RADIUS" background.border_width="$PILL_BORDER_WIDTH" background.border_color="$PILL_BORDER_COLOR" background.y_offset="$PILL_Y_OFFSET" background.drawing=on drawing=off
