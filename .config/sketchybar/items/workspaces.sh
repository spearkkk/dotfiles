source "$CONFIG_DIR/icons.sh"

WORKSPACE_ORDER=('`' M E W Q 9 3 2 1)
FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused 2>/dev/null | head -n1 | tr '[:lower:]' '[:upper:]' | xargs)"
WORKSPACE_ITEMS=()
WS_ICON_SIZE_NORMAL="$(awk "BEGIN { printf \"%.2f\", $PILL_ICON_SIZE * 1.2 }")"
WS_ICON_SIZE_ACTIVE="$(awk "BEGIN { printf \"%.2f\", $PILL_ICON_SIZE * 1.5 }")"

sketchybar --add item lua.workspace.pad_r right \
           --set lua.workspace.pad_r \
                 drawing=on \
                 display="$MAIN_DISPLAY_ID" \
                 icon=" " \
                 icon.drawing=on \
                 icon.color=0x00000000 \
                 icon.padding_left=6 \
                 icon.padding_right=0 \
                 label=" " \
                 label.drawing=off \
                 label.color=0x00000000 \
                 label.padding_left=0 \
                 label.padding_right=0 \
                 background.drawing=off

for ws in "${WORKSPACE_ORDER[@]}"; do
  ws_id="$ws"
  ws_icon_key="$ws"
  if [[ "$ws_id" =~ [A-Z] ]]; then
    ws_display="$(printf '%s' "$ws_id" | tr '[:upper:]' '[:lower:]')"
  else
    ws_display="$ws_id"
  fi
  if [[ "$ws_id" == '`' ]]; then
    key="backtick"
  else
    key="$(printf "%s" "$ws_display" | tr -c 'a-z0-9_-' '_')"
  fi

  item="lua.workspace.$key"
  icon="$(sf_symbol_for "$ws_icon_key")"
  ws_quoted="$(printf '%q' "$ws_id")"

  icon_color="$PILL_LABEL_COLOR"
  active_icon_color="$BRIGHT_YELLOW"
  if [[ "$(printf '%s' "$ws_id" | tr '[:lower:]' '[:upper:]')" == "$FOCUSED_WORKSPACE" ]]; then
    icon_color="$BRIGHT_YELLOW"
  fi

  WORKSPACE_ITEMS+=("$item")

  sketchybar --add item "$item" right \
             --set "$item" \
                   drawing=on \
                   display="$MAIN_DISPLAY_ID" \
                   icon.drawing=on \
                   icon="$icon" \
                   icon.font.size="$WS_ICON_SIZE_NORMAL" \
                   icon.color="$icon_color" \
                   icon.background.drawing=off \
                   icon.padding_left=1 \
                   icon.padding_right=1 \
                   label.drawing=off \
                   background.drawing=off \
                   script="AEROSPACE_WORKSPACE_ID=$ws_quoted AEROSPACE_WORKSPACE_BASE_COLOR=$PILL_LABEL_COLOR AEROSPACE_WORKSPACE_ACTIVE_COLOR=$active_icon_color AEROSPACE_WORKSPACE_ICON_SIZE=$WS_ICON_SIZE_NORMAL AEROSPACE_WORKSPACE_ACTIVE_ICON_SIZE=$WS_ICON_SIZE_ACTIVE $CONFIG_DIR/plugins/aerospace_workspace.lua" \
                   click_script="aerospace workspace $ws_quoted" \
             --subscribe "$item" front_app_switched aerospace_workspace_change display_change system_woke mouse.clicked mouse.entered.global
done

sketchybar --add item lua.workspace.pad_l right \
           --set lua.workspace.pad_l \
                 drawing=on \
                 display="$MAIN_DISPLAY_ID" \
                 icon=" " \
                 icon.drawing=on \
                 icon.color=0x00000000 \
                 icon.padding_left=0 \
                 icon.padding_right=6 \
                 label=" " \
                 label.drawing=off \
                 label.color=0x00000000 \
                 label.padding_left=0 \
                 label.padding_right=0 \
                 background.drawing=off

if [[ ${#WORKSPACE_ITEMS[@]} -gt 0 ]]; then
  sketchybar --add bracket lua.workspace_group lua.workspace.pad_r "${WORKSPACE_ITEMS[@]}" lua.workspace.pad_l \
             --set lua.workspace_group \
                   drawing=on \
                   display="$MAIN_DISPLAY_ID" \
                   padding_left="$OUTER_PADDING" \
                   padding_right="$OUTER_PADDING" \
                   background.drawing=on \
                   background.color="$PILL_BG_COLOR" \
                   background.corner_radius="$PILL_CORNER_RADIUS" \
                   background.border_width=2 \
                   background.border_color="$BRIGHT_YELLOW" \
                   background.y_offset=-2

  sketchybar --set lua.workspace.pad_r display="$MAIN_DISPLAY_ID"
  for item in "${WORKSPACE_ITEMS[@]}"; do
    sketchybar --set "$item" display="$MAIN_DISPLAY_ID"
  done
  sketchybar --set lua.workspace.pad_l display="$MAIN_DISPLAY_ID"
  sketchybar --set lua.workspace_group display="$MAIN_DISPLAY_ID"
fi
