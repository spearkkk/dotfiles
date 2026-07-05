#!/usr/bin/env bash

VOLUME_ITEM="lua.volume"
VOLUME_POPUP_PREFIX="lua.volume.device"

ICON_WIDTH="$(lua "$PLUGIN_DIR/calc_icon_width.lua" --min 27 --max 45 --ratio 0.02025 --fallback 33 2>/dev/null || echo 33)"

sketchybar \
  --add item "$VOLUME_ITEM" right \
  --set "$VOLUME_ITEM" \
    icon="􀊩" \
    icon.width="$ICON_WIDTH" \
    label.drawing=off \
    background.drawing=off \
    click_script="$PLUGIN_DIR/volume.lua --toggle-popup" \
    script="$PLUGIN_DIR/volume.lua --refresh" \
    update_freq=0 \
  --subscribe "$VOLUME_ITEM" volume_change system_woke

for i in 1 2 3 4 5 6 7 8; do
  name="$VOLUME_POPUP_PREFIX.$i"
  sketchybar \
    --add item "$name" popup."$VOLUME_ITEM" \
    --set "$name" \
      drawing=off \
      icon.drawing=off \
      label="" \
      label.padding_left=0 \
      label.padding_right=0 \
      background.drawing=off \
      click_script="$PLUGIN_DIR/volume.lua --select __EMPTY__"
done

sketchybar --set "$VOLUME_ITEM" \
  popup.align=right \
  popup.height=22 \
  popup.background.drawing=on \
  popup.background.color="$(set_alpha "$BACKGROUND_ALT" 80)" \
  popup.background.border_width=0 \
  popup.background.corner_radius=4
