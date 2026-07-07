#!/bin/bash

# Use explicit trigger + switch to avoid callback race/desync behavior.
CURRENT_WORKSPACE="$(aerospace list-workspaces --focused 2>/dev/null | head -n1 | xargs)"
NEXT_WORKSPACE="$1"

if [ "$NEXT_WORKSPACE" = "WS_BACKTICK" ]; then
  NEXT_WORKSPACE='`'
fi

if [ -z "$NEXT_WORKSPACE" ]; then
  exit 0
fi

if [ "$CURRENT_WORKSPACE" != "$NEXT_WORKSPACE" ]; then
  sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE="$NEXT_WORKSPACE" PREV_WORKSPACE="$CURRENT_WORKSPACE"
  aerospace workspace "$NEXT_WORKSPACE"
fi
