#!/usr/bin/env bash

set -u

CACHE_FILE="/tmp/sketchybar_todays.cache"
PID_FILE="/tmp/sketchybar_todays_daemon.pid"
REQUEST_FILE="/tmp/sketchybar_todays_refresh_request"
NORMAL_INTERVAL=60
NEAR_INTERVAL=20

cleanup() {
  if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then
    rm -f "$PID_FILE"
  fi
}

trap cleanup EXIT INT TERM

if [ -f "$PID_FILE" ]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    kill "$old_pid" 2>/dev/null || exit 0
    for _ in 1 2 3 4 5; do
      kill -0 "$old_pid" 2>/dev/null || break
      sleep 0.1
    done
  fi
fi

printf '%s\n' "$$" > "$PID_FILE"

collect_today_events() {
  icalBuddy \
    -nrd \
    -npn \
    -ea \
    -tf '%H:%M' \
    -iep 'datetime,title,calendar' \
    -po 'datetime,title,calendar' \
    -ps '|	|	|\n|' \
    eventsToday 2>/dev/null || true
}

to_minutes() {
  local hhmm="$1"
  local hh="${hhmm%%:*}"
  local mm="${hhmm##*:}"
  printf '%d' $((10#$hh * 60 + 10#$mm))
}

to_hhmm() {
  local hm="$1"
  local h="${hm%%:*}"
  local m="${hm##*:}"
  printf '%02d:%02d' "$((10#$h))" "$((10#$m))"
}

normalize_events() {
  local raw="$1"
  local start end clean_title clean_cal times
  while IFS=$'\t' read -r datetime title cal; do
    [ -n "${datetime:-}" ] || continue
    times="$(printf '%s\n' "$datetime" | grep -oE '[0-9]{1,2}:[0-9]{2}' | head -n2 | tr '\n' ' ' || true)"
    set -- $times
    if [ "$#" -ge 2 ]; then
      start="$(to_hhmm "$1")"
      end="$(to_hhmm "$2")"
      clean_title="$(printf '%s' "${title:-}" | tr '\t\r\n' '   ' | sed 's/  */ /g; s/^ //; s/ $//')"
      clean_cal="$(printf '%s' "${cal:-}" | tr '\t\r\n' '   ' | sed 's/  */ /g; s/^ //; s/ $//')"
      [ -n "$clean_title" ] || continue
      printf '%s\t%s\t%s\t%s\n' "$start" "$end" "$clean_title" "$clean_cal"
    fi
  done < <(printf '%s\n' "$raw")
}

last_key=""
TAB="$(printf '\t')"

while true; do
  rm -f "$REQUEST_FILE"

  raw="$(collect_today_events)"
  events="$(normalize_events "$raw" | awk 'NF' | sort -t "$TAB" -k1,1)"
  now_min=$((10#$(date +%H) * 60 + 10#$(date +%M)))
  updated_at="$(date +%s)"

  ok=true
  next_start=""
  next_end=""
  next_title=""

  while IFS=$'\t' read -r start_hhmm end_hhmm title _cal; do
    [ -n "${start_hhmm:-}" ] || continue
    end_min="$(to_minutes "$end_hhmm")"
    if [ "$end_min" -gt "$now_min" ]; then
      next_start="$start_hhmm"
      next_end="$end_hhmm"
      next_title="$title"
      break
    fi
  done < <(printf '%s\n' "$events")

  if [ -z "$next_title" ]; then
    ok=false
  fi

  tmp="${CACHE_FILE}.$$"
  {
    printf '%s\t%s\t%s\t%s\t%s\n' "$updated_at" "$ok" "$next_start" "$next_end" "$next_title"
    printf '%s\n' "$events"
  } > "$tmp"
  mv "$tmp" "$CACHE_FILE"

  event_count="$(printf '%s\n' "$events" | awk 'NF{c++} END{print c+0}')"
  key="${ok}|${next_start}|${next_end}|${next_title}|${event_count}"
  if [ "$key" != "$last_key" ]; then
    sketchybar --trigger calendar_change >/dev/null 2>&1 || true
    last_key="$key"
  fi

  interval="$NORMAL_INTERVAL"
  if [ -n "$next_start" ]; then
    next_min="$(to_minutes "$next_start")"
    diff=$((next_min - now_min))
    if [ "$diff" -le 30 ] && [ "$diff" -ge 0 ]; then
      interval="$NEAR_INTERVAL"
    fi
  fi

  elapsed=0
  while [ "$elapsed" -lt "$interval" ]; do
    if [ -f "$REQUEST_FILE" ]; then
      break
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
done
