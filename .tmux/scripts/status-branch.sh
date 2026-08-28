#!/usr/bin/env bash
# Git branch for status-format[2]. Read git state from the active pane's path,
# not tmux server cwd, so branch state stays isolated per pane/session.
# Truncate only when too long; do not pad short branch labels to fixed width.
target_dir="${1:-$PWD}"
width="${2:-32}"
default_style='#[fg=#C6D8E4,bg=#1C3A50]'
important_style='#[fg=#0A1F2E,bg=#68BE92,bold]'
reset='#[fg=#C6D8E4,bg=#1C3A50]'

if [[ -d "$target_dir" ]]; then
  branch="$(git -C "$target_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$branch" == "HEAD" ]]; then
    branch="$(git -C "$target_dir" rev-parse --short HEAD 2>/dev/null)"
  fi

  changes=()
  untracked="$(git -C "$target_dir" status --porcelain 2>/dev/null | grep -c '^??')"
  shortstat="$(git -C "$target_dir" diff --shortstat 2>/dev/null)"
  if [[ "$shortstat" =~ ([0-9]+)[[:space:]]+files?[[:space:]]+changed ]]; then
    changes+=("~${BASH_REMATCH[1]}")
  fi
  if [[ "$shortstat" =~ ([0-9]+)[[:space:]]+insertions? ]]; then
    changes+=("+${BASH_REMATCH[1]}")
  fi
  if [[ "$shortstat" =~ ([0-9]+)[[:space:]]+deletions? ]]; then
    changes+=("-${BASH_REMATCH[1]}")
  fi
  if [[ "$untracked" =~ ^[0-9]+$ ]] && (( untracked > 0 )); then
    changes+=("?$untracked")
  fi

  if [[ -n "$branch" ]]; then
    raw=" $branch"
    if (( ${#changes[@]} > 0 )); then
      raw+=" ${changes[*]}"
    fi
    raw+=" "
  else
    raw=""
  fi
else
  raw=""
fi
len=${#raw}

case "$branch" in
  main|develop|release/*) style="$important_style" ;;
  *) style="$default_style" ;;
esac

printf '%s' "$style"
if (( len <= width )); then
  printf '%s' "$raw"
else
  keep=$((width - 1))
  printf '…%s' "${raw: -$keep}"
fi
printf '%s' "$reset"
