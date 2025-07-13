#!/bin/bash

source "$CONFIG_DIR/colors.sh"

COUNT=$(osascript <<EOF
tell application "Things3"
  set todayCount to count of to dos of list "Today"
  set inboxCount to count of to dos of list "Inbox"
end tell
return todayCount + inboxCount
EOF
)

if [ "$COUNT" -lt 5 ]; then
  COLOR="$BRIGHT_BLUE"
elif [ "$COUNT" -lt 10 ]; then
  COLOR="$BRIGHT_GREEN"
elif [ "$COUNT" -lt 20 ]; then
  COLOR="$BRIGHT_YELLOW" #
else
  COLOR="$BRIGHT_RED"
fi

sketchybar --set "$NAME" label="$COUNT" icon.color="$COLOR" label.color="$COLOR"