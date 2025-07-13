#!/bin/bash

IMG_DIR="$CONFIG_DIR/sausages"
FRAME_COUNT=5
DIR="$HOME/.sausages"
STATE_FILE="$DIR/.frame_index"
PID_FILE="$DIR/.anim_pid"

mkdir -p "$DIR"

# Initialize frame index
if [ ! -f "$STATE_FILE" ]; then
  echo 0 > "$STATE_FILE"
fi

# Save PID
echo $$ > "$PID_FILE"

# Animate
while true; do
  INDEX=$(cat "$STATE_FILE")
  INDEX=$(( (INDEX + 1) % FRAME_COUNT ))
  echo "$INDEX" > "$STATE_FILE"

  sketchybar --set "$NAME" background.image="${IMG_DIR}/sausage-page-${INDEX}_Normal.png"
  sleep 0.1
done