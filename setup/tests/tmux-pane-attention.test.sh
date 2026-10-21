#!/usr/bin/env bash

set -u

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
controller="$repo_root/home/.local/libexec/tmux-pane-attention"
renderer="$repo_root/home/.tmux/scripts/status-box.sh"
fish_config="$repo_root/home/.config/fish/conf.d/0200-tmux-pane-attention.fish"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/tmux-pane-attention.XXXXXX")
real_tmux=$(command -v tmux || true)
real_path=$PATH
socket_name="attention-test-$$"
failures=0

cleanup() {
  [ -z "$real_tmux" ] || "$real_tmux" -L "$socket_name" kill-server >/dev/null 2>&1 || true
  rm -rf "$tmpdir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2" >&2
  failures=$((failures + 1))
}

cat >"$tmpdir/tmux" <<'FAKE'
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
  wait-for)
    [ "${FAKE_LOCK_FAIL:-0}" != 1 ]
    ;;
  list-clients)
    case "$*" in
      *client_name*)
        if [ -n "${FAKE_NAMED_CLIENTS:-}" ]; then
          printf '%s\n' "$FAKE_NAMED_CLIENTS"
        else
          printf '%s\n' "${FAKE_CLIENTS:-}" | awk 'NF { count++; printf "/dev/ttys%03d|%s\n", count, $0 }'
        fi
        ;;
      *) printf '%s\n' "${FAKE_CLIENTS:-}" ;;
    esac
    ;;
  list-panes)
    case "$*" in
      *pane_active*) printf '%s\n' "${FAKE_RENDER_PANES:-}" ;;
      *) printf '%s\n' "${FAKE_PANES:-}" ;;
    esac
    ;;
  list-windows)
    printf '%s\n' "${FAKE_WINDOWS:-}"
    ;;
  display-message|display)
    printf '%s\n' "$FAKE_PANES" | grep -q "|${target}$" || exit 1
    case $last in
      '#{pane_id}') printf '%s\n' "$target" ;;
      '#{pane_title}') printf '%s\n' "${FAKE_TITLE:-}" ;;
      *) exit 1 ;;
    esac
    ;;
  show-options|show-option)
    case $last in
      @attention_state) value=${FAKE_ATTENTION_STATE:-} ;;
      @attention_codex_state) value=${FAKE_CODEX_STATE:-} ;;
      @attention_reconcile_pending) value=${FAKE_PENDING:-} ;;
      *) exit 1 ;;
    esac
    [ -n "$value" ] || exit 1
    printf '%s\n' "$value"
    ;;
  set-option)
    [ "${FAKE_MUTATION_FAIL:-0}" != 1 ] || exit 1
    ;;
  refresh-client)
    ;;
  *) exit 2 ;;
esac
FAKE
chmod +x "$tmpdir/tmux"

export PATH="$tmpdir:$PATH"
export FAKE_CALL_LOG="$tmpdir/calls.log"

run_controller() {
  : >"$FAKE_CALL_LOG"
  env TMUX=1 "$controller" "$@" >"$tmpdir/stdout" 2>"$tmpdir/stderr"
}

assert_called() {
  local name=$1 pattern=$2
  grep -Eq -- "$pattern" "$FAKE_CALL_LOG" || fail "$name" "missing call matching: $pattern"
}

assert_not_called() {
  local name=$1 pattern=$2
  if grep -Eq -- "$pattern" "$FAKE_CALL_LOG"; then
    fail "$name" "unexpected call matching: $pattern"
  fi
}

export FAKE_PANES=$'@1|%1\n@1|%2\n@2|%3'
export FAKE_CLIENTS='focused,UTF-8|@1|%1|0'
run_controller command-done %2 || fail unzoomed_visible "controller exited $?"
assert_not_called unzoomed_visible 'set-option .*%2 .*@attention_state done'

export FAKE_CLIENTS='focused,UTF-8|@1|%1|1'
run_controller command-done %2 || fail zoomed_hidden_done "controller exited $?"
assert_called zoomed_hidden_done 'set-option .*%2 .*@attention_state done'

export FAKE_CLIENTS=$'focused|@1|%1|1\nfocused|@2|%3|0'
run_controller acknowledge-visible || fail multi_client_union "controller exited $?"
assert_called multi_client_union 'set-option .*%1 -u @attention_state|set-option .*%1 .* -u .*@attention_state'
assert_called multi_client_union 'set-option .*%3 -u @attention_state|set-option .*%3 .* -u .*@attention_state'
assert_not_called multi_client_union 'set-option .*%2 .*@attention_state'

export FAKE_CLIENTS='UTF-8|@1|%1|0'
run_controller acknowledge-visible || fail unfocused_no_ack "controller exited $?"
assert_not_called unfocused_no_ack 'set-option .*@attention_state'

reconcile() {
  local title=$1 attention=$2 codex=$3
  export FAKE_TITLE=$title FAKE_ATTENTION_STATE=$attention FAKE_CODEX_STATE=$codex FAKE_PENDING=1
  export FAKE_CLIENTS='UTF-8|@1|%1|0'
  run_controller reconcile-title %3 || fail "$4" "controller exited $?"
}

reconcile '⠋ Build' '' '' working
assert_called working 'set-option .*%3 .*@attention_codex_state working'
assert_not_called working 'set-option .*%3 .*@attention_state (done|waiting)'

reconcile 'Build' '' working invisible_done
assert_called invisible_done 'set-option .*%3 -u @attention_codex_state|set-option .*%3 .* -u .*@attention_codex_state'
assert_called invisible_done 'set-option .*%3 .*@attention_state done'

export FAKE_NAMED_CLIENTS=$'/dev/ttys001|UTF-8|@1|%1|0\n/dev/ttys002|UTF-8|@2|%2|0'
reconcile 'Action Required | repo' '' working waiting
assert_called waiting 'set-option .*%3 .*@attention_codex_state waiting'
assert_called waiting 'set-option .*%3 .*@attention_state waiting'
assert_called waiting 'refresh-client -S -t /dev/ttys001'
assert_called waiting 'refresh-client -S -t /dev/ttys002'
unset FAKE_NAMED_CLIENTS

reconcile 'Action Required' '' '' strict_waiting
assert_not_called strict_waiting '@attention_state waiting|@attention_codex_state waiting'

reconcile 'Action Required | repo' '' waiting waiting_ack
assert_not_called waiting_ack '@attention_state waiting'

reconcile '⠙ Resume' waiting waiting waiting_to_working
assert_called waiting_to_working '@attention_codex_state working'
assert_called waiting_to_working '-u @attention_state'

reconcile 'Idle' waiting waiting waiting_to_idle
assert_called waiting_to_idle '-u @attention_codex_state'
assert_called waiting_to_idle '-u @attention_state'

reconcile 'Idle' waiting '' stale_waiting
assert_called stale_waiting '-u @attention_state'

export FAKE_PANES=$'@0|%0\n@1|%1\n@2|%2'
export FAKE_CLIENTS='focused|@1|%1|0'
run_controller command-done %404 || fail stale_pane_noop "missing pane was not a no-op"
assert_not_called stale_pane_noop 'set-option '

export FAKE_PANES=$'@0|%0\n@1|%1\n@2|%2'
export FAKE_CLIENTS='focused,UTF-8|@1|%1|0'
: >"$FAKE_CALL_LOG"
env -u TMUX "$controller" acknowledge-visible >/dev/null 2>&1 || fail server_hook_acknowledges "server hook exited unexpectedly"
assert_called server_hook_acknowledges 'set-option .*%1 -u @attention_state|set-option .*%1 .* -u .*@attention_state'

env TMUX=1 "$controller" invalid-operation >/dev/null 2>&1
[ "$?" -eq 64 ] || fail invalid_operation "expected status 64"

: >"$FAKE_CALL_LOG"
env TMUX=1 FAKE_MUTATION_FAIL=1 FAKE_PANES='@2|%3' FAKE_CLIENTS='' \
  "$controller" command-done %3 >/dev/null 2>&1 || true
assert_called lock_release '^wait-for -U tmux-pane-attention-lock$'

# The renderer reads stored pane state only. A zoomed current window can show
# hidden sibling attention, but it must retain the current-window color.
export FAKE_RENDER_PANES=$'@1|%1|1|\n@1|%2|0|waiting\n@2|%3|1|done\n@3|%4|1|done\n@3|%5|0|waiting'
export FAKE_WINDOWS=$'@1|a|1|1|main\n@2|b|0|0|build\n@3|c|0|0|mixed'
: >"$FAKE_CALL_LOG"
renderer_output=$("$renderer" middle 100 attention %1 @1 0)
plain_renderer_output=$(printf '%s' "$renderer_output" | sed 's/#\[[^]]*\]//g')
[ "$(grep -c '^list-windows ' "$FAKE_CALL_LOG")" -eq 1 ] || fail renderer_budget "expected one list-windows"
[ "$(grep -c '^list-panes ' "$FAKE_CALL_LOG")" -eq 1 ] || fail renderer_budget "expected one list-panes"
assert_not_called renderer_read_only '^set-option '
case $plain_renderer_output in
  *'[a·main?]'*'[b·build✓]'*'[c·mixed?]'*) ;;
  *) fail renderer_markers "unexpected markers: $plain_renderer_output" ;;
esac
case $renderer_output in
  *'#[fg=#0A1F2E,bg=#50C4C0,bold][a·main?]'*) ;;
  *) fail renderer_current_style "current zoom marker changed style" ;;
esac

export FAKE_WINDOWS=$'@1|a|1|0|main'
export FAKE_RENDER_PANES=$'@1|%1|1|\n@1|%2|0|waiting'
: >"$FAKE_CALL_LOG"
renderer_output=$("$renderer" middle 80 attention %1 @1 0)
plain_renderer_output=$(printf '%s' "$renderer_output" | sed 's/#\[[^]]*\]//g')
case $plain_renderer_output in
  *'[a·main?]'*) fail renderer_unzoomed "visible sibling rendered unread" ;;
esac

# Fish forwards the semantic operation and explicit pane ID.
fish_home="$tmpdir/fish-home"
fish_log="$tmpdir/fish-helper.log"
mkdir -p "$fish_home/.local/libexec"
cat >"$fish_home/.local/libexec/tmux-pane-attention" <<'HELPER'
#!/bin/sh
printf '%s|%s\n' "$1" "$2" >>"$FISH_HELPER_LOG"
HELPER
chmod +x "$fish_home/.local/libexec/tmux-pane-attention"
: >"$fish_log"
env HOME="$fish_home" FISH_HELPER_LOG="$fish_log" TMUX=1 TMUX_PANE=%9 TMUX_ATTENTION_MIN_SECONDS=10 \
  fish --no-config --interactive --command "source '$fish_config'; set -g CMD_DURATION 10000; emit fish_postexec" \
  >"$tmpdir/stdout" 2>"$tmpdir/stderr"
[ "$(cat "$fish_log")" = 'command-done|%9' ] || fail fish_bridge "expected command-done|%9, got [$(cat "$fish_log")]"

: >"$fish_log"
env -u TMUX -u TMUX_PANE HOME="$fish_home" FISH_HELPER_LOG="$fish_log" TMUX_ATTENTION_MIN_SECONDS=10 \
  fish --no-config --interactive --command "source '$fish_config'; set -g CMD_DURATION 10000; emit fish_postexec" \
  >"$tmpdir/stdout" 2>"$tmpdir/stderr" || fail fish_outside_tmux "fish exited unsuccessfully"
[ ! -s "$fish_log" ] || fail fish_outside_tmux "fish outside tmux called the controller"

# Hooks enqueue controller operations instead of mutating semantic state.
tmux_config="$repo_root/home/.tmux.conf"
grep -q 'pane-title-changed.*@attention_reconcile_pending.*reconcile-title' "$tmux_config" || \
  fail title_hook "missing coalesced reconcile-title hook"
grep -q 'client-focus-in.*acknowledge-visible' "$tmux_config" || fail focus_hook "missing focus acknowledgement"
grep -q 'after-select-window.*acknowledge-visible' "$tmux_config" || fail window_hook "missing window acknowledgement"
grep -q 'after-select-pane.*acknowledge-visible' "$tmux_config" || fail pane_hook "missing pane acknowledgement"
grep -q 'after-resize-pane.*acknowledge-visible' "$tmux_config" || fail resize_hook "missing resize acknowledgement"
if grep -q '@client_focused' "$tmux_config"; then
  fail obsolete_focus_state "config still uses @client_focused"
fi

export FAKE_PANES=$'@1|%1\n@1|%2'
export FAKE_CLIENTS='focused|@1|%1|0'
export FAKE_TITLE='shell' FAKE_ATTENTION_STATE='' FAKE_CODEX_STATE='' FAKE_PENDING=''
run_controller reconcile-all || fail reconcile_all "controller exited $?"
assert_called reconcile_all '@attention_codex_working'
assert_called reconcile_all '%1 -u @attention_state'
assert_called reconcile_all '%2 -u @attention_state'

# Parse the complete tmux configuration in an isolated server.
if [ -z "$real_tmux" ]; then
  fail tmux_config_parse "tmux is not installed"
else
  integration_home="$tmpdir/integration-home"
  mkdir -p "$integration_home/.local/libexec"
  ln -s "$controller" "$integration_home/.local/libexec/tmux-pane-attention"
  env HOME="$integration_home" PATH="$real_path" "$real_tmux" -L "$socket_name" -f /dev/null \
    new-session -d -s attention-test 'sleep 30' || \
    fail tmux_config_parse "could not start isolated server"
  "$real_tmux" -L "$socket_name" source-file "$tmux_config" >/dev/null 2>&1 || true
  pane_id=$("$real_tmux" -L "$socket_name" display-message -p '#{pane_id}')
  "$real_tmux" -L "$socket_name" select-pane -t "$pane_id" -T '⠋ Working'
  "$real_tmux" -L "$socket_name" select-pane -t "$pane_id" -T 'Action Required | review'
  sleep 1
  codex_state=$("$real_tmux" -L "$socket_name" show-option -pqv -t "$pane_id" @attention_codex_state)
  attention_state=$("$real_tmux" -L "$socket_name" show-option -pqv -t "$pane_id" @attention_state)
  pending_state=$("$real_tmux" -L "$socket_name" show-option -pqv -t "$pane_id" @attention_reconcile_pending)
  [ "$codex_state" = waiting ] || fail title_hook_integration "final title was not reconciled: $codex_state"
  [ "$attention_state" = waiting ] || fail title_hook_integration "waiting marker was not stored: $attention_state"
  [ -z "$pending_state" ] || fail title_hook_integration "pending flag was not cleared: $pending_state"
fi

if [ "$failures" -ne 0 ]; then
  printf 'FAIL: tmux-pane-attention (%s failures)\n' "$failures" >&2
  exit 1
fi

printf 'PASS: tmux-pane-attention\n'
