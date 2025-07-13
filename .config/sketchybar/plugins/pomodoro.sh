#!/bin/bash
source "$CONFIG_DIR/colors.sh"

WORK_MIN=25
BREAK_MIN=5

if [ -n "$4" ]; then
  WORK_MIN="$4"
fi
if [ -n "$5" ]; then
  BREAK_MIN="$5"
fi

POMO_DIR="$HOME/.pomodoro"
MODE_FILE="$POMO_DIR/pomo_mode"
PID_FILE="$POMO_DIR/pomo_timer.pid"
HISTORY_FILE="$POMO_DIR/pomodoro_history"

mkdir -p "$POMO_DIR"

start_timer() {
    local duration="$1"
    local button_id="$2"

    local START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    (
      TIME_LEFT=$((duration * 60))
      while [ $TIME_LEFT -ge 58 ]; do
          MINUTES=$((TIME_LEFT / 60))
          SECONDS=$((TIME_LEFT % 60))
          TIME_STR=$(printf "%02d:%02d" $MINUTES $SECONDS)
          sketchybar --set "$button_id" label="$TIME_STR" drawing=on label.padding_right=10 label.font.size=10 label.y_offset=-2
          if [ "$button_id" = "$WORK_ID" ]; then
              sketchybar --set "$BREAK_ID" drawing=off
              sketchybar --set "$button_id" icon.color="$BRIGHT_RED"
          elif [ "$button_id" = "$BREAK_ID" ]; then
              sketchybar --set "$WORK_ID" drawing=off
              sketchybar --set "$button_id" icon.color="$BRIGHT_BLUE"
          fi
          sleep 1
          TIME_LEFT=$((TIME_LEFT - 1))
      done

      local END_TIME=$(date '+%Y-%m-%d %H:%M:%S')  # Save end time now
      # Clean up PID file after timer naturally ends
      rm -f "$PID_FILE"
      echo "none" > "$MODE_FILE"

      # Send macOS notification after timer ends
      if [ "$button_id" = "$WORK_ID" ]; then
          terminal-notifier \
            -title 'Pomodoro'\
			    -message 'Work Timer is up! Take a Break 🍅'\
			    -sound Funk
          echo "$START_TIME  $END_TIME  [WORK]  $WORK_MIN mins" >> "$HISTORY_FILE"

          afplay -v 1.5 "/System/Library/Sounds/Basso.aiff" &
          sketchybar --set $BREAK_ID drawing=on \
                     --set $WORK_ID drawing=off label="" icon.color="$TEXT_DEFAULT" label.padding_right=0
          exec "$0" "$BREAK_ID" "$WORK_ID" "$BREAK_ID" "$WORK_MIN" "$BREAK_MIN" &

      elif [ "$button_id" = "$BREAK_ID" ]; then
          terminal-notifier \
            -title 'Pomodoro'\
            -message 'Break is over! Get back to work ☕️'\
			      -sound Funk
          echo "$START_TIME  $END_TIME  [REST]  $BREAK_MIN mins" >> "$HISTORY_FILE"

          afplay -v 5 "/System/Library/Sounds/Blow.aiff" &
          sketchybar --set $WORK_ID drawing=on
          sketchybar --set $BREAK_ID drawing=off label="" icon.color="$TEXT_DEFAULT" label.padding_right=0
      fi
    ) &
    echo $! > "$PID_FILE"
}

stop_timer() {
    local button_id="$1"
    # Stop and clean up timer process
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi
    echo "none" > "$MODE_FILE"
    sketchybar --set $button_id drawing=on label="" icon.color="$TEXT_DEFAULT" label.padding_right=0
}

BREAK_ID=$1
WORK_ID=$2
ID=$3

case "$ID" in
  "$WORK_ID")
    current_mode=$(cat "$MODE_FILE" 2>/dev/null)
    if [ "$current_mode" = "$WORK_ID" ]; then
        stop_timer $WORK_ID
    else
        stop_timer $WORK_ID
        echo "$WORK_ID" > "$MODE_FILE"
        # 片方オだけオフにすると一度アイコンが真ん中に移動し、start_timerでアイコンの位置が変わりチラつく
        # そのチラつきへの対策で、一度全てオフにすることでチラつきを減らしている。
        sketchybar --set $BREAK_ID drawing=off \
                   --set $WORK_ID drawing=off
        start_timer $WORK_MIN $WORK_ID
    fi
    ;;
  "$BREAK_ID")
    current_mode=$(cat "$MODE_FILE" 2>/dev/null)
    if [ "$current_mode" = "$BREAK_ID" ]; then
        stop_timer $BREAK_ID
    else
        stop_timer $BREAK_ID
        echo "$BREAK_ID" > "$MODE_FILE"
        # 片方オだけオフにすると一度アイコンが真ん中に移動し、start_timerでアイコンの位置が変わりチラつく
        # そのチラつきへの対策で、一度全てオフにすることでチラつきを減らしている。
        sketchybar --set $BREAK_ID drawing=off \
                   --set $WORK_ID drawing=off
        start_timer $BREAK_MIN "$BREAK_ID"
    fi
    ;;
  *)
    ;;
esac