#!/bin/bash

source "$HOME/.config/sketchybar/colors.sh"

POMO_DIR="$HOME/.config/sketchybar/pomodoro"
HISTORY_FILE="$POMO_DIR/.pomodoro_history"
today=$(date '+%Y-%m-%d')

output=""

if [ -f "$HISTORY_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "$today"* ]]; then
            if [[ "$line" == *"[WORK]"* ]]; then
                output+="🍅"
            elif [[ "$line" == *"[REST]"* ]]; then
                output+="☕️"
            fi
        fi
    done < "$HISTORY_FILE"
fi

if [ -z "$output" ]; then
    output="No Pomo"
fi

sketchybar --set pomo_history label="$output" label.color="$YELLOW"