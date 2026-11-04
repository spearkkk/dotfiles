#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
controller="$repo_root/home/.local/libexec/tmux-reconcile-pane-activity"
fish_config="$repo_root/home/.config/fish/conf.d/0200-tmux-pane-activity.fish"
tmux_config="$repo_root/home/.tmux.conf"
renderer="$repo_root/home/.local/libexec/tmux-render-status-box"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/tmux-pane-activity.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/tmux" <<'TMUX'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_CALL_LOG"
target=
previous=
last=
for arg do
  [ "$previous" = -t ] && target=$arg
  previous=$arg
  last=$arg
done
case ${1:-} in
  wait-for|refresh-client) exit 0 ;;
  list-panes)
    case "$*" in
      *'#{window_id}|#{pane_id}|#{@activity}'*) printf '%s\n' "${FAKE_PANES:-}" ;;
      *'#{@activity}'*) printf '%s\n' "${FAKE_WINDOW_STATES:-}" ;;
      *) exit 2 ;;
    esac
    ;;
  list-clients) printf '%s\n' "${FAKE_CLIENTS:-}" ;;
  display-message)
    [ "$last" = '#{pane_title}' ] || exit 2
    printf '%s\n' "${FAKE_TITLE:-Idle}"
    ;;
  show-options)
    case $last in
      @activity) value=${FAKE_ACTIVITY:-} ;;
      @activity_window) value=${FAKE_WINDOW_ACTIVITY:-} ;;
      *) value= ;;
    esac
    [ -n "$value" ] || exit 1
    printf '%s\n' "$value"
    ;;
  set-option) [ "${FAKE_MUTATION_FAIL:-0}" != 1 ] ;;
  *) exit 2 ;;
esac
TMUX
sed -i '' 's/^+//' "$tmpdir/tmux"
chmod +x "$tmpdir/tmux"

export PATH="$tmpdir:$PATH"
export FAKE_CALL_LOG="$tmpdir/calls.log"
export FAKE_PANES=$'@1|%1|idle\n@1|%2|idle\n@2|%3|idle'
export FAKE_CLIENTS='client|focused,UTF-8|@1|%1|0'

run_controller() {
  : >"$FAKE_CALL_LOG"
  "$controller" "$@"
}

assert_called() {
  grep -Eq -- "$2" "$FAKE_CALL_LOG" || {
    printf 'FAIL: %s: missing %s\n' "$1" "$2" >&2
    cat "$FAKE_CALL_LOG" >&2
    exit 1
  }
}

assert_not_called() {
  if grep -Eq -- "$2" "$FAKE_CALL_LOG"; then
    printf 'FAIL: %s: unexpected %s\n' "$1" "$2" >&2
    cat "$FAKE_CALL_LOG" >&2
    exit 1
  fi
}

# A background pane completing while another pane/client has keyboard focus.
run_controller command-done %2
assert_called background_complete 'set-option -p -t %2 @activity completed'

# No focused tmux client means another app (on either monitor) owns keyboard focus.
export FAKE_CLIENTS='client|UTF-8|@1|%1|0'
run_controller command-done %1
assert_called other_app_complete 'set-option -p -t %1 @activity completed'

# A focused terminal on another monitor acknowledges only its own pane.
export FAKE_CLIENTS=$'left|UTF-8|@1|%1|0\nright|focused,UTF-8|@2|%3|0'
run_controller command-done %1
assert_called other_monitor_complete 'set-option -p -t %1 @activity completed'

export FAKE_CLIENTS='client|focused,UTF-8|@1|%1|0'
export FAKE_ACTIVITY=working
run_controller command-done %1
assert_called focused_complete 'set-option -p -t %1 @activity idle'

export FAKE_TITLE='⠋ Build'
export FAKE_ACTIVITY=idle
run_controller reconcile-title %2
assert_called title_working 'set-option -p -t %2 @activity working'

export FAKE_TITLE='Build'
export FAKE_ACTIVITY=working
run_controller reconcile-title %2
assert_called title_completed 'set-option -p -t %2 @activity completed'

export FAKE_TITLE='Build'
export FAKE_ACTIVITY=working
run_controller reconcile-title %1
assert_called title_focused_idle 'set-option -p -t %1 @activity idle'

export FAKE_TITLE='Action Required | repo'
export FAKE_ACTIVITY=working
run_controller reconcile-title %1
assert_called waiting_even_focused 'set-option -p -t %1 @activity waiting'

export FAKE_PANES=$'@1|%1|waiting\n@1|%2|completed\n@2|%3|idle'
export FAKE_ACTIVITY=waiting
run_controller acknowledge-visible
assert_not_called waiting_persists 'set-option -p -t %1 @activity idle'

export FAKE_TITLE='⠙ Resume'
run_controller reconcile-title %1
assert_called waiting_to_working 'set-option -p -t %1 @activity working'

export FAKE_TITLE='Idle'
export FAKE_ACTIVITY=waiting
run_controller reconcile-title %1
assert_called waiting_to_idle 'set-option -p -t %1 @activity idle'

export FAKE_PANES=$'@1|%1|completed\n@1|%2|idle\n@2|%3|idle'
export FAKE_ACTIVITY=completed
run_controller acknowledge-visible
assert_called acknowledge_completed 'set-option -p -t %1 @activity idle'

export FAKE_PANES=$'@1|%1|waiting\n@1|%2|completed\n@2|%3|working'
export FAKE_WINDOW_STATES=$'waiting\ncompleted'
export FAKE_WINDOW_ACTIVITY=idle
run_controller reconcile-window @1
assert_called window_priority 'set-option -w -t @1 @activity_window waiting'

export FAKE_PANES='@1|%1|idle'
run_controller command-done %404
assert_not_called stale_pane 'set-option -p'

export FAKE_MUTATION_FAIL=1
run_controller command-done %1 || true
assert_called lock_release '^wait-for -U tmux-pane-activity-lock$'
unset FAKE_MUTATION_FAIL

# Fish forwards long-command completion with an explicit pane ID.
fish_home="$tmpdir/fish-home"
mkdir -p "$fish_home/.local/libexec"
cat >"$fish_home/.local/libexec/tmux-reconcile-pane-activity" <<'FISH_HELPER'
#!/bin/sh
printf '%s|%s\n' "$1" "$2" >>"$FISH_HELPER_LOG"
FISH_HELPER
chmod +x "$fish_home/.local/libexec/tmux-reconcile-pane-activity"
: >"$tmpdir/fish.log"
env HOME="$fish_home" FISH_HELPER_LOG="$tmpdir/fish.log" TMUX=1 TMUX_PANE=%9 TMUX_ACTIVITY_MIN_SECONDS=10 \
  fish --no-config --interactive --command "source '$fish_config'; set -g CMD_DURATION 10000; emit fish_postexec" \
  >/dev/null 2>&1
[[ $(cat "$tmpdir/fish.log") == 'command-done|%9' ]]
: >"$tmpdir/fish.log"
env HOME="$fish_home" FISH_HELPER_LOG="$tmpdir/fish.log" TMUX=1 TMUX_PANE=%9 TMUX_ACTIVITY_MIN_SECONDS=10 \
  fish --no-config --interactive --command "source '$fish_config'; set -g CMD_DURATION 9999; emit fish_postexec" \
  >/dev/null 2>&1
[[ ! -s "$tmpdir/fish.log" ]]

grep -q 'pane-title-changed.*@activity_reconcile_pending.*reconcile-title' "$tmux_config"
grep -q 'client-focus-in.*acknowledge-visible' "$tmux_config"
grep -q 'after-select-pane.*acknowledge-visible' "$tmux_config"
grep -q 'pane-border-style.*@activity.*waiting.*completed' "$tmux_config"
grep -q 'window-status-format.*@activity_window.*waiting.*completed' "$tmux_config"
if grep -Eq '@attention_(state|codex_state|window_state)' "$controller" "$tmux_config"; then
  echo 'FAIL: legacy attention state remains' >&2
  exit 1
fi
if grep -Eq '@activity=(idle|working|completed|waiting)' "$tmux_config"; then
  echo 'FAIL: activity values should be pane options, not global tmux config' >&2
  exit 1
fi
[[ $(grep -o 'tmux-render-status-box' "$tmux_config" | wc -l | tr -d ' ') == 1 ]]

[[ -x "$renderer" ]]
[[ ! -e "$repo_root/home/.tmux/scripts/status-box.sh" ]]
[[ ! -L "$repo_root/home/.tmux/scripts/status-box.sh" ]]
/bin/sh -n "$renderer"

renderer_output=$("$renderer" '#112233' '#AABBCC' '#445566' 'xcontext○')
case $renderer_output in *' context○ '*) ;; *) exit 1 ;; esac

echo 'PASS: tmux-pane-activity'

# Old entrypoints are intentionally removed; sessions are recreated by the user.
[[ ! -e "$repo_root/home/.local/libexec/tmux-pane-attention" ]]
[[ ! -L "$repo_root/home/.local/libexec/tmux-pane-attention" ]]
