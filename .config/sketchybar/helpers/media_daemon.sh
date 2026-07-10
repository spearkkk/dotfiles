#!/usr/bin/env bash

set -u

CACHE_JSON="/tmp/sketchybar_media.json"
CACHE_TSV="/tmp/sketchybar_media.tsv"
PID_FILE="/tmp/sketchybar_media_daemon.pid"
REQUEST_FILE="/tmp/sketchybar_media_refresh_request"
NP_BIN="$(command -v nowplaying-cli 2>/dev/null || true)"
JQ_BIN="$(command -v jq 2>/dev/null || true)"
TIMEOUT_SECONDS=4
PLAYING_INTERVAL=3
IDLE_INTERVAL=10
ERROR_INTERVAL=15
FAILURE_TOLERANCE=3

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

json_escape() {
  "$JQ_BIN" -Rs .
}

write_cache() {
  ok="$1"
  title="$2"
  artist="$3"
  playing="$4"
  error="${5:-}"
  updated_at="$(date +%s)"

  title_json="$(printf '%s' "$title" | json_escape)"
  artist_json="$(printf '%s' "$artist" | json_escape)"
  error_json="$(printf '%s' "$error" | json_escape)"

  tmp_json="${CACHE_JSON}.$$"
  tmp_tsv="${CACHE_TSV}.$$"

  cat > "$tmp_json" <<EOF
{"ok":$ok,"title":$title_json,"artist":$artist_json,"playing":$playing,"updated_at":$updated_at,"error":$error_json}
EOF

  # Lua reads this cheap cache. Strip tabs/newlines to keep parsing constant-time.
  clean_title="$(printf '%s' "$title" | tr '\t\r\n' '   ')"
  clean_artist="$(printf '%s' "$artist" | tr '\t\r\n' '   ')"
  printf '%s\t%s\t%s\t%s\t%s\n' "$updated_at" "$ok" "$playing" "$clean_title" "$clean_artist" > "$tmp_tsv"

  mv "$tmp_json" "$CACHE_JSON"
  mv "$tmp_tsv" "$CACHE_TSV"
}

timeout_nowplaying() {
  /usr/bin/perl -e 'alarm shift @ARGV; exec @ARGV' "$TIMEOUT_SECONDS" "$NP_BIN" get --json title artist playbackRate 2>/dev/null
}

last_key=""
consecutive_failures=0
last_ok_title=""
last_ok_artist=""
last_ok_playing=false

while true; do
  rm -f "$REQUEST_FILE"

  if [ -z "$NP_BIN" ] || [ -z "$JQ_BIN" ]; then
    ok=false
    title=""
    artist=""
    playing=false
    error="missing nowplaying-cli or jq"
    interval="$ERROR_INTERVAL"
  else
    raw="$(timeout_nowplaying || true)"
    title="$(printf '%s' "$raw" | "$JQ_BIN" -r '.title // empty' 2>/dev/null)"
    artist="$(printf '%s' "$raw" | "$JQ_BIN" -r '.artist // empty' 2>/dev/null)"
    rate="$(printf '%s' "$raw" | "$JQ_BIN" -r '.playbackRate // 0' 2>/dev/null)"

    if [ -n "$title" ]; then
      ok=true
      error=""
      consecutive_failures=0
      case "$rate" in
        ''|0|0.0|null) playing=false ;;
        *) playing=true ;;
      esac
      last_ok_title="$title"
      last_ok_artist="$artist"
      last_ok_playing="$playing"
      if [ "$playing" = true ]; then
        interval="$PLAYING_INTERVAL"
      else
        interval="$IDLE_INTERVAL"
      fi
    else
      consecutive_failures=$((consecutive_failures + 1))
      if [ "$consecutive_failures" -lt "$FAILURE_TOLERANCE" ] && [ -n "$last_ok_title" ]; then
        ok=true
        title="$last_ok_title"
        artist="$last_ok_artist"
        playing="$last_ok_playing"
        error="temporary nowplaying-cli failure (holding last good value)"
      else
        ok=false
        title=""
        artist=""
        playing=false
        if [ -z "$raw" ]; then
          error="nowplaying-cli timed out or returned no data"
        else
          error="no media"
        fi
      fi
      interval="$IDLE_INTERVAL"
    fi
  fi

  key="${ok}|${playing}|${title}|${artist}"
  write_cache "$ok" "$title" "$artist" "$playing" "$error"

  if [ "$key" != "$last_key" ]; then
    sketchybar --trigger media_change >/dev/null 2>&1 || true
    last_key="$key"
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
