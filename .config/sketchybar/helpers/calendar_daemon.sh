#!/usr/bin/env bash

set -u

CACHE_FILE="/tmp/sketchybar_todays_v2.cache"
PID_FILE="/tmp/sketchybar_todays_daemon.pid"
REQUEST_FILE="/tmp/sketchybar_todays_refresh_request"
NORMAL_INTERVAL=60
NEAR_INTERVAL=20
EMPTY_GRACE_SECONDS=180

cleanup() {
  if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then
    rm -f "$PID_FILE"
  fi
}

trap cleanup EXIT INT TERM

if [ -f "$PID_FILE" ]; then
  old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    # Single-instance guard: keep the existing daemon and exit quickly.
    exit 0
  fi
fi

printf '%s\n' "$$" > "$PID_FILE"

collect_today_events() {
  icalBuddy \
    -nrd \
    -npn \
    -ea \
    -tf '%H:%M' \
    -iep 'datetime,title' \
    -po 'datetime,title' \
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

trim_ws() {
  printf '%s' "$1" | tr '\t\r\n' '   ' | sed 's/  */ /g; s/^ //; s/ $//'
}

split_title_calendar() {
  local s="$1"
  local len i ch depth open_idx open0
  SPLIT_TITLE="$s"
  SPLIT_CALENDAR=""

  [ -n "$s" ] || return 0
  [ "${s:${#s}-1:1}" = ")" ] || return 0

  len="${#s}"
  depth=0
  open_idx=0

  for (( i=len; i>=1; i-- )); do
    ch="${s:i-1:1}"
    if [ "$ch" = ")" ]; then
      depth=$((depth + 1))
    elif [ "$ch" = "(" ]; then
      depth=$((depth - 1))
      if [ "$depth" -eq 0 ]; then
        open_idx="$i"
        break
      fi
    fi
  done

  if [ "$open_idx" -le 2 ]; then
    return 0
  fi
  if [ "${s:open_idx-2:1}" != " " ]; then
    return 0
  fi

  open0=$((open_idx - 1))
  SPLIT_TITLE="$(trim_ws "${s:0:open0-1}")"
  SPLIT_CALENDAR="$(trim_ws "${s:open0+1:len-open0-2}")"

  if [ -z "$SPLIT_TITLE" ] || [ -z "$SPLIT_CALENDAR" ]; then
    SPLIT_TITLE="$s"
    SPLIT_CALENDAR=""
  fi
}

normalize_events() {
  local raw="$1"
  local datetime title start end clean_title clean_calendar times
  local line c1 c2 c3
  while IFS= read -r line; do
    [ -n "${line:-}" ] || continue

    c1=""; c2=""; c3=""
    IFS=$'\t' read -r c1 c2 c3 <<< "$line"
    datetime="${c1:-}"
    title="${c2:-}"

    times="$(printf '%s\n' "$datetime" | grep -oE '[0-9]{1,2}:[0-9]{2}' | head -n2 | tr '\n' ' ' || true)"
    set -- $times
    if [ "$#" -ge 2 ]; then
      start="$(to_hhmm "$1")"
      end="$(to_hhmm "$2")"
      clean_title="$(trim_ws "${title:-}")"
      [ -n "$clean_title" ] || continue

      split_title_calendar "$clean_title"
      clean_title="$(trim_ws "$SPLIT_TITLE")"
      clean_calendar="$(trim_ws "$SPLIT_CALENDAR")"

      printf '%s\t%s\t%s\t%s\n' "$start" "$end" "$clean_title" "$clean_calendar"
    fi
  done < <(printf '%s\n' "$raw")
}

last_key=""
TAB="$(printf '\t')"
last_good_events=""
last_good_updated_at=0

if [ -f "$CACHE_FILE" ]; then
  seed_events="$(awk -F "$TAB" 'NR>1 && NF>=3 {print $0}' "$CACHE_FILE" 2>/dev/null || true)"
  if [ -n "$seed_events" ]; then
    last_good_events="$seed_events"
    last_good_updated_at="$(date +%s)"
  fi
fi

while true; do
  rm -f "$REQUEST_FILE"

  raw="$(collect_today_events)"
  events="$(normalize_events "$raw" | awk 'NF' | sort -t "$TAB" -k1,1 -k3,3 | awk -F "$TAB" '!seen[$3]++')"
  now_min=$((10#$(date +%H) * 60 + 10#$(date +%M)))
  updated_at="$(date +%s)"
  event_count="$(printf '%s\n' "$events" | awk 'NF{c++} END{print c+0}')"

  if [ "$event_count" -gt 0 ]; then
    last_good_events="$events"
    last_good_updated_at="$updated_at"
  elif [ -n "$last_good_events" ]; then
    age=$((updated_at - last_good_updated_at))
    if [ "$age" -le "$EMPTY_GRACE_SECONDS" ]; then
      events="$last_good_events"
      event_count="$(printf '%s\n' "$events" | awk 'NF{c++} END{print c+0}')"
    fi
  fi

  ok=true
  next_start=""
  next_end=""
  next_title=""

  while IFS=$'\t' read -r start_hhmm end_hhmm title _calendar; do
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
    printf '%s\t%s\n' "$updated_at" "$ok"
    printf '%s\n' "$events"
  } > "$tmp"
  mv "$tmp" "$CACHE_FILE"

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
