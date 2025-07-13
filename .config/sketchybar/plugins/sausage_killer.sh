#!/bin/bash

DIR="$HOME/.sausages"
PID_FILE="$DIR/.anim_pid"
SAUSAGES="$PLUGIN_DIR/sausage.sh"
ITEM_NAME="_sausage"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm "$PID_FILE"
    exit 0
  fi
fi