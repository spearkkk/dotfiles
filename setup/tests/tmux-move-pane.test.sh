#!/usr/bin/env bash

set -u

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$repo_root/home/.local/libexec/tmux-move-pane"
config="$repo_root/home/.tmux.conf"
real_tmux=$(command -v tmux || true)
socket_name="move-pane-test-$$"
failures=0

cleanup() {
  [ -z "$real_tmux" ] || "$real_tmux" -L "$socket_name" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2" >&2
  failures=$((failures + 1))
}

[ -n "$real_tmux" ] || {
  printf 'FAIL: tmux-move-pane: tmux is not installed\n' >&2
  exit 1
}

"$real_tmux" -L "$socket_name" -f /dev/null new-session -d -s move-test -x 120 -y 30
"$real_tmux" -L "$socket_name" source-file "$config" >/dev/null 2>&1
root_keys=$("$real_tmux" -L "$socket_name" list-keys -T root)

assert_root_key() {
  local key=$1
  local command=$2
  grep -Eq "M-${key}[[:space:]]+${command}" <<<"$root_keys" || \
    fail root_key "missing binding: M-${key} ${command}"
}

assert_root_key h 'select-pane -L'
assert_root_key j 'select-pane -D'
assert_root_key k 'select-pane -U'
assert_root_key l 'select-pane -R'
assert_root_key S-H 'run-shell .*tmux-move-pane left'
assert_root_key S-J 'run-shell .*tmux-move-pane down'
assert_root_key S-K 'run-shell .*tmux-move-pane up'
assert_root_key S-L 'run-shell .*tmux-move-pane right'

if "$real_tmux" -L "$socket_name" list-keys -T root M-Enter >/dev/null 2>&1; then
  fail alt_enter "Alt+Enter must remain available to the active pane"
fi
assert_root_key S-Enter 'split-window -v -c "#{pane_current_path}"'

socket_path=$("$real_tmux" -L "$socket_name" display-message -p '#{socket_path}')
tmux_env="$socket_path,$$,0"
first_pane=$("$real_tmux" -L "$socket_name" display-message -p '#{pane_id}')
second_pane=$("$real_tmux" -L "$socket_name" split-window -h -P -F '#{pane_id}')
third_pane=$("$real_tmux" -L "$socket_name" split-window -h -P -F '#{pane_id}')

pane_order() {
  "$real_tmux" -L "$socket_name" list-panes -t "$1" -F '#{pane_id}'
}

TMUX="$tmux_env" TMUX_BIN="$real_tmux" "$helper" left "$third_pane" || \
  fail move_left "helper failed to move pane left"
expected=$(printf '%s\n%s\n%s' "$first_pane" "$third_pane" "$second_pane")
actual=$(pane_order move-test:0)
[ "$actual" = "$expected" ] || fail move_left "unexpected order: $actual"
active=$("$real_tmux" -L "$socket_name" display-message -p -t move-test:0 '#{pane_id}')
[ "$active" = "$third_pane" ] || fail move_left_focus "focus did not follow moved pane: $active"

TMUX="$tmux_env" TMUX_BIN="$real_tmux" "$helper" right "$third_pane" || \
  fail move_right "helper failed to move pane right"
expected=$(printf '%s\n%s\n%s' "$first_pane" "$second_pane" "$third_pane")
actual=$(pane_order move-test:0)
[ "$actual" = "$expected" ] || fail move_right "unexpected order: $actual"

before=$actual
TMUX="$tmux_env" TMUX_BIN="$real_tmux" "$helper" right "$third_pane" || \
  fail boundary "helper failed at a pane boundary"
after=$(pane_order move-test:0)
[ "$after" = "$before" ] || fail boundary "boundary move changed pane order: $after"

"$real_tmux" -L "$socket_name" new-window -d -n vertical
top_pane=$("$real_tmux" -L "$socket_name" display-message -p -t move-test:vertical '#{pane_id}')
middle_pane=$("$real_tmux" -L "$socket_name" split-window -v -t move-test:vertical -P -F '#{pane_id}')
bottom_pane=$("$real_tmux" -L "$socket_name" split-window -v -t move-test:vertical -P -F '#{pane_id}')

TMUX="$tmux_env" TMUX_BIN="$real_tmux" "$helper" up "$bottom_pane" || \
  fail move_up "helper failed to move pane up"
expected=$(printf '%s\n%s\n%s' "$top_pane" "$bottom_pane" "$middle_pane")
actual=$(pane_order move-test:vertical)
[ "$actual" = "$expected" ] || fail move_up "unexpected order: $actual"

TMUX="$tmux_env" TMUX_BIN="$real_tmux" "$helper" down "$bottom_pane" || \
  fail move_down "helper failed to move pane down"
expected=$(printf '%s\n%s\n%s' "$top_pane" "$middle_pane" "$bottom_pane")
actual=$(pane_order move-test:vertical)
[ "$actual" = "$expected" ] || fail move_down "unexpected order: $actual"

if TMUX="$tmux_env" TMUX_BIN="$real_tmux" "$helper" diagonal "$bottom_pane" >/dev/null 2>&1; then
  fail invalid_direction "invalid direction succeeded"
fi
if TMUX="$tmux_env" TMUX_BIN="$real_tmux" "$helper" left '%99999' >/dev/null 2>&1; then
  fail missing_pane "missing pane succeeded"
fi

if [ "$failures" -eq 0 ]; then
  printf 'PASS: tmux-move-pane\n'
else
  printf 'FAIL: tmux-move-pane (%d failures)\n' "$failures" >&2
  exit 1
fi
