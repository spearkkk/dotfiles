#!/usr/bin/env bash
# pane_current_path for status-format[2]: tilde-collapsed, then truncated only
# when too long. Truncation cuts the FRONT (ancestor dirs) and keeps the tail,
# since the current/deepest directory name is the useful part.
path="$1"
width="${2:-32}"
style='#[fg=#C6D8E4,bg=#0A1F2E]'
reset='#[fg=#C6D8E4,bg=#142C3E]'

path="${path/#$HOME/~}"
len=${#path}

printf '%s' "$style"
if (( len <= width )); then
  printf '%s' "$path"
else
  keep=$((width - 1))
  printf '…%s' "${path: -$keep}"
fi
printf '%s' "$reset"
