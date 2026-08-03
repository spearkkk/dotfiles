#!/usr/bin/env bash
# Fixed-width pane_current_path for status-format[1]: tilde-collapsed, then
# padded/truncated to a constant width so the column doesn't jump around as
# panes change directory. Truncation cuts the FRONT (ancestor dirs) and keeps
# the tail, since the current/deepest directory name is the useful part.
path="$1"
width="${2:-32}"

path="${path/#$HOME/~}"
len=${#path}

if (( len <= width )); then
  printf '%s%*s' "$path" $((width - len)) ''
else
  keep=$((width - 1))
  printf '…%s' "${path: -$keep}"
fi
