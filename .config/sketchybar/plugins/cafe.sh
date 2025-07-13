#!/bin/bash

source "$CONFIG_DIR/colors.sh"

CAFFEINATE_PID=$(pgrep -x caffeinate)

OFF_ICON="􀸘"  # OFF 상태 이모지
ON_ICON="􀸙"   # ON 상태 이모지

# 상태 갱신용 실행
if [ -z "$BUTTON" ]; then
  if [ -z "$CAFFEINATE_PID" ]; then
    sketchybar --set "$NAME" icon="$OFF_ICON" icon.color="$BACKGROUND_DARKEST"
  else
    sketchybar --set "$NAME" icon="$ON_ICON" icon.color="$PINK"
  fi
  exit 0
fi

# 클릭 토글 동작
if [ -z "$CAFFEINATE_PID" ]; then
  nohup caffeinate -dimsu > /dev/null 2>&1 &
  sketchybar --set "$NAME" icon="$ON_ICON" icon.color="$PINK"
else
  kill "$CAFFEINATE_PID"
  sketchybar --set "$NAME" icon="$OFF_ICON" icon.color="$BACKGROUND_DARKEST"
fi