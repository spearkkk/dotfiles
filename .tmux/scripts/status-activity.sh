#!/usr/bin/env bash
# Activity output for status-format[1]. Keep the front of long commands and
# trim the tail. When duration is available, preserve it as the suffix.
cmd="$1"
last_cmd="$2"
duration_ms="$3"
window_width="$4"
client_prefix="$5"

if [[ "$window_width" =~ ^[0-9]+$ ]] && (( window_width > 0 )); then
  width="$window_width"
else
  width=26
fi
content_width=$((width - 2))
(( content_width < 1 )) && content_width=1

if [[ "$client_prefix" == "1" ]]; then
  line_style='#[fg=#0A1F2E,bg=#7896CC]'
else
  line_style='#[fg=#C6D8E4,bg=#1C3A50]'
fi

format_duration() {
  local ms="$1"
  [[ "$ms" =~ ^[0-9]+$ ]] || { printf ''; return; }
  if (( ms >= 1000 )); then
    printf '%d.%ds' "$(( ms / 1000 ))" "$(( (ms % 1000) / 100 ))"
  else
    printf '%dms' "$ms"
  fi
}

truncate_tail() {
  local value="$1"
  local max_width="$2"
  local len=${#value}

  if (( len <= max_width )); then
    printf '%s' "$value"
  elif (( max_width > 1 )); then
    printf '%s…' "${value:0:$((max_width - 1))}"
  fi
}

case "$cmd" in
  fish|zsh|bash|sh)
    if [[ -n "$last_cmd" ]]; then
      dur=$(format_duration "$duration_ms")
      if [[ -n "$dur" ]]; then
        suffix=" (${dur})"
        suffix_len=${#suffix}
        command_width=$((content_width - suffix_len))
        if (( command_width > 0 )); then
          raw="$(truncate_tail "$last_cmd" "$command_width")$suffix"
        else
          raw="$(truncate_tail "$suffix" "$width")"
        fi
      else
        raw="$(truncate_tail "$last_cmd" "$content_width")"
      fi
    else
      raw=""
    fi
    ;;
  *)
    raw="$("$(dirname "${BASH_SOURCE[0]}")/pane-activity.sh" "$cmd" "$last_cmd" "$duration_ms")"
    raw="$(truncate_tail "$raw" "$content_width")"
    ;;
esac

visible_text() {
  local value="$1"
  while [[ "$value" == *'#['*']'* ]]; do
    if [[ "$value" =~ (.*)#\[[^]]*\](.*) ]]; then
      value="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    else
      break
    fi
  done
  printf '%s' "$value"
}

visible_raw="$(visible_text "$raw")"
visible_len=$((1 + ${#visible_raw}))
pad_width=$((width - visible_len))
(( pad_width < 1 )) && pad_width=1

printf '%s %s%*s' "$line_style" "$raw" "$pad_width" ''
