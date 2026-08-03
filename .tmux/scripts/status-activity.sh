#!/usr/bin/env bash
# Fixed-width pane-activity.sh output for status-format[1]: same
# pad/truncate-front scheme as status-dir.sh/status-branch.sh, but at a
# dedicated (shorter) width -- activity text (agent name, last command +
# duration) is typically short, so 32 cols would leave excess blank space.
width=24
raw="$("$(dirname "${BASH_SOURCE[0]}")/pane-activity.sh" "$1" "$2" "$3")"
len=${#raw}

if (( len <= width )); then
  printf '%s%*s' "$raw" $((width - len)) ''
else
  keep=$((width - 1))
  printf '…%s' "${raw: -$keep}"
fi
