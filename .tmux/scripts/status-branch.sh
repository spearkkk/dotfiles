#!/usr/bin/env bash
# Fixed-width git branch for status-format[2]. Run the vendored
# tmux-simple-git-status plugin from the active pane's path, not tmux server
# cwd, so branch state stays isolated per pane/session.
target_dir="${1:-$PWD}"
width="${2:-32}"

if [[ -d "$target_dir" ]]; then
  raw="$(cd "$target_dir" && "$HOME/.tmux/plugins/tmux-simple-git-status/scripts/git_status.sh")"
else
  raw=""
fi
len=${#raw}

if (( len <= width )); then
  printf '%s%*s' "$raw" $((width - len)) ''
else
  keep=$((width - 1))
  printf '…%s' "${raw: -$keep}"
fi
