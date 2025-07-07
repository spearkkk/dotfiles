#!/bin/bash

# Directory containing sausage frames
DIR="$CONFIG_DIR/sausages"

# State file to keep track of current frame
STATE_FILE="$DIR/.frame_index"

# Initialize frame index if not exists
if [ ! -f "$STATE_FILE" ]; then
  echo 0 > "$STATE_FILE"
fi

# Read and increment index
INDEX=$(cat "$STATE_FILE")
INDEX=$(( (INDEX + 1) % 5 ))
echo "$INDEX" > "$STATE_FILE"

# Set icon
sketchybar --set "$NAME" background.image="${DIR}/sausage-page-${INDEX}_Normal.png"