#!/usr/bin/env bash
# "What am I doing in this pane" for the tmux status line, in priority order:
#   1. Known AI agent running (claude/codex/gemini)  -> icon + agent name only
#   2. Something else actively running (not a shell) -> a running-indicator + that command's name
#   3. Idle at a shell prompt                         -> the last finished command + how long it took
#      (recorded per-pane by .config/fish/conf.d/tmux_last_cmd.fish into the
#      @last_cmd / @last_cmd_duration_ms pane options, since pane_current_command
#      is just "fish" here)
#
# macOS truncates comm names to 15 chars (e.g. codex's real binary is
# codex-aarch64-apple-darwin -> "codex-aarch64-a"), so agent matches use
# wildcards.
cmd="$1"
last_cmd="$2"
duration_ms="$3"

case "$cmd" in
  claude*) printf '󰧑 클로드'; exit 0 ;;
  codex*)  printf '󰧑 코덱스'; exit 0 ;;
  gemini*) printf '󰧑 젬미니'; exit 0 ;;
esac

format_duration() {
  local ms="$1"
  [[ "$ms" =~ ^[0-9]+$ ]] || { printf ''; return; }
  if (( ms >= 1000 )); then
    printf '%d.%ds' "$(( ms / 1000 ))" "$(( (ms % 1000) / 100 ))"
  else
    printf '%dms' "$ms"
  fi
}

case "$cmd" in
  fish|zsh|bash|sh)
    if [[ -n "$last_cmd" ]]; then
      dur=$(format_duration "$duration_ms")
      if [[ -n "$dur" ]]; then
        printf '%s (%s)' "$last_cmd" "$dur"
      else
        printf '%s' "$last_cmd"
      fi
    fi
    ;;
  *) printf '󱎫 %s' "$cmd" ;;
esac
