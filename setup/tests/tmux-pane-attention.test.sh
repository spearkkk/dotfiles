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
      *'#{window_id}|#{pane_id}|#{@attention_state}'*)
        if [ "${FAKE_PANE_SNAPSHOT+x}" = x ]; then
          printf '%s\n' "$FAKE_PANE_SNAPSHOT"
        else
          printf '%s\n' "${FAKE_PANES:-}" | awk -F'|' 'NF { print $1 "|" $2 "|" }'
        fi
        ;;
      *@attention_state*) printf '%s\n' "${FAKE_AGGREGATE_PANES:-}" ;;
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
      @attention_window_state) value=${FAKE_ATTENTION_WINDOW_STATE:-} ;;
      @attention_codex_state) value=${FAKE_CODEX_STATE:-} ;;
      @attention_reconcile_pending) value=${FAKE_PENDING:-} ;;
      *) exit 1 ;;
    esac
    [ -n "$value" ] || exit 1
    printf '%s\n' "$value"
    ;;
  set-option)
    [ "${FAKE_MUTATION_FAIL:-0}" != 1 ] || exit 1
    case "$*" in
      *'-u @attention_state')
        [ "${FAKE_MISSING_ATTENTION_UNSET_FAIL:-0}" != 1 ] || [ -n "${FAKE_ATTENTION_STATE:-}" ] || exit 1
        ;;
    esac
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
export FAKE_AGGREGATE_PANES='done'
run_controller command-done %2 || fail zoomed_hidden_done "controller exited $?"
assert_called zoomed_hidden_done 'set-option .*%2 .*@attention_state done'
assert_called zoomed_hidden_done 'set-option -w -t @1 @attention_window_state done'

export FAKE_CLIENTS=$'focused|@1|%1|1\nfocused|@2|%3|0'
export FAKE_PANE_SNAPSHOT=$'@1|%1|waiting\n@1|%2|\n@2|%3|done'
run_controller acknowledge-visible || fail multi_client_union "controller exited $?"
assert_called multi_client_union 'set-option .*%1 -u @attention_state|set-option .*%1 .* -u .*@attention_state'
assert_called multi_client_union 'set-option .*%3 -u @attention_state|set-option .*%3 .* -u .*@attention_state'
assert_not_called multi_client_union 'set-option .*%2 .*@attention_state'
unset FAKE_PANE_SNAPSHOT

export FAKE_CLIENTS='UTF-8|@1|%1|0'
run_controller acknowledge-visible || fail unfocused_no_ack "controller exited $?"
assert_not_called unfocused_no_ack 'set-option .*@attention_state'

# A common navigation/focus event with no attention state must be a true no-op.
export FAKE_PANES=$'@1|%1\n@1|%2\n@2|%3'
export FAKE_PANE_SNAPSHOT=$'@1|%1|\n@1|%2|\n@2|%3|'
export FAKE_CLIENTS='focused|@1|%1|0'
run_controller acknowledge-visible || fail attention_noop "controller exited $?"
assert_not_called attention_noop 'set-option .*@attention_state'
assert_not_called attention_noop 'list-panes -t '
assert_not_called attention_noop 'refresh-client '
unset FAKE_PANE_SNAPSHOT

reconcile() {
  local title=$1 attention=$2 codex=$3
  export FAKE_TITLE=$title FAKE_ATTENTION_STATE=$attention FAKE_CODEX_STATE=$codex FAKE_PENDING=1
  export FAKE_PANE_SNAPSHOT="@1|%1|
@1|%2|
@2|%3|$attention"
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
export FAKE_AGGREGATE_PANES=$'done\nwaiting'
run_controller reconcile-title %3 || fail waiting_window_state "controller exited $?"
assert_called waiting_window_state 'set-option -w -t @2 @attention_window_state waiting'
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
unset FAKE_PANE_SNAPSHOT

export FAKE_PANES=$'@0|%0\n@1|%1\n@2|%2'
export FAKE_CLIENTS='focused|@1|%1|0'
run_controller command-done %404 || fail stale_pane_noop "missing pane was not a no-op"
assert_not_called stale_pane_noop 'set-option '

export FAKE_PANES=$'@0|%0\n@1|%1\n@2|%2'
export FAKE_CLIENTS='focused,UTF-8|@1|%1|0'
: >"$FAKE_CALL_LOG"
export FAKE_PANE_SNAPSHOT=$'@0|%0|\n@1|%1|waiting\n@2|%2|'
env -u TMUX "$controller" acknowledge-visible >/dev/null 2>&1 || fail server_hook_acknowledges "server hook exited unexpectedly"
assert_called server_hook_acknowledges 'set-option .*%1 -u @attention_state|set-option .*%1 .* -u .*@attention_state'
unset FAKE_PANE_SNAPSHOT

env TMUX=1 "$controller" invalid-operation >/dev/null 2>&1
[ "$?" -eq 64 ] || fail invalid_operation "expected status 64"

: >"$FAKE_CALL_LOG"
env TMUX=1 FAKE_MUTATION_FAIL=1 FAKE_PANES='@2|%3' FAKE_CLIENTS='' \
  "$controller" command-done %3 >/dev/null 2>&1 || true
assert_called lock_release '^wait-for -U tmux-pane-attention-lock$'

# The renderer only draws the dynamic frame and context. Window navigation is
# a native tmux format so selecting a window never waits on a #() command.
: >"$FAKE_CALL_LOG"
renderer_output=$("$renderer" middle-left 100 attention %1 @1 0)
case $renderer_output in
  *'│ '*'#[push-default]'*) ;;
  *) fail renderer_middle_left "missing native-list prefix: $renderer_output" ;;
esac
renderer_output=$("$renderer" middle-right 100 attention %1 @1 0)
assert_not_called renderer_budget '^list-windows '
assert_not_called renderer_budget '^list-panes '
assert_not_called renderer_read_only '^set-option '

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
grep -q 'client-focus-in.*if-shell -F.*@attention_window_state.*acknowledge-visible' "$tmux_config" || \
  fail focus_hook_fast_path "client focus hook is not attention-gated"
grep -q 'after-select-window.*if-shell -F.*@attention_window_state.*acknowledge-visible' "$tmux_config" || \
  fail window_hook_fast_path "window selection hook is not attention-gated"
grep -q 'after-resize-pane.*if-shell -F.*@attention_window_state.*acknowledge-visible' "$tmux_config" || \
  fail resize_hook_fast_path "resize hook is not attention-gated"
grep -q 'after-select-pane.*if-shell -F.*@attention_window_state.*acknowledge-visible' "$tmux_config" || \
  fail pane_hook_fast_path "pane selection hook is not attention-gated"
grep -q "set -g @plugin 'jabirali/tmux-tilish'" "$tmux_config" || fail tilish_plugin "missing Tilish TPM plugin"
grep -q "set -g @tilish-default 'tiled'" "$tmux_config" || fail tilish_default "Tilish does not default to the tiled layout"
if grep -qE "^[[:space:]]*set[[:space:]]+-g[[:space:]]+@tilish-enforce([[:space:]]|$)" "$tmux_config"; then
  fail tilish_enforce "Tilish must use its full default enforcement hook, not an explicit enforcement override"
fi
grep -q "set -g @tilish-createauto 'off'" "$tmux_config" || fail tilish_createauto "Tilish auto split direction is not disabled"
grep -q 'bind-key -n M-\[ previous-window' "$tmux_config" || fail previous_window_binding "Alt-[ binding changed"
grep -q 'bind-key -n M-\] next-window' "$tmux_config" || fail next_window_binding "Alt-] binding changed"
for binding in \
  'bind-key -r h select-pane -L' \
  'bind-key -r j select-pane -D' \
  'bind-key -r k select-pane -U' \
  'bind-key -r l select-pane -R'; do
  grep -qF "$binding" "$tmux_config" || fail prefix_pane_bindings "missing required prefix pane binding: $binding"
done
for binding in \
  'bind-key -r ㅗ select-pane -L' \
  'bind-key -r ㅓ select-pane -D' \
  'bind-key -r ㅏ select-pane -U' \
  'bind-key -r ㅣ select-pane -R' \
  'bind-key ㅋ resize-pane -Z'; do
  grep -qF "$binding" "$tmux_config" || fail korean_pane_bindings "missing required Korean pane binding: $binding"
done
if grep -Eq '^[[:space:]]*bind(-key)?[[:space:]]+-n[[:space:]]+M-[hjklz][[:space:]]' "$tmux_config"; then
  fail tilish_binding_owner "duplicate native Tilish navigation or zoom binding remains"
fi

tpm_count=$(grep -cF "run '~/.tmux/plugins/tpm/tpm'" "$tmux_config" || true)
pane_exit_declarations=$(grep -E '^[[:space:]]*set-hook[[:space:]].*pane-exited\[0\]' "$tmux_config" || true)
kill_hook_declarations=$(grep -E '^[[:space:]]*set-hook[[:space:]].*after-kill-pane' "$tmux_config" || true)
expected_kill_hook_declarations='set-hook -g after-kill-pane[90] '"'"'select-layout ; select-layout -E ; run-shell -b "~/.local/libexec/tmux-pane-attention reconcile-window #{window_id}"'"'"''
[ "$tpm_count" -eq 1 ] || fail tpm_loader_count "expected exactly one TPM loader, found $tpm_count"
if grep -qE '^[[:space:]]*set-hook[[:space:]]+-gu[[:space:]]+after-kill-pane' "$tmux_config"; then
  fail kill_pane_hook_ownership "configuration globally clears after-kill-pane callbacks"
fi
[ "$kill_hook_declarations" = "$expected_kill_hook_declarations" ] || \
  fail kill_pane_hook_declarations "after-kill-pane is not the dedicated [90] callback: $kill_hook_declarations"
case $pane_exit_declarations in
  *'select-layout -t'*'#{hook_window}'*'reconcile-window'*'#{hook_window}'*) ;;
  *) fail pane_exit_hook_target "pane-exited[0] is not target-aware and reconciled: $pane_exit_declarations" ;;
esac
grep -qF 'bind-key -n M-Q kill-pane' "$tmux_config" || \
  fail tilish_kill_binding "M-Q must delegate layout work to the lifecycle hook"
tpm_line=$(grep -nF "run '~/.tmux/plugins/tpm/tpm'" "$tmux_config" | cut -d: -f1)
pane_exit_line=$(grep -nE '^[[:space:]]*set-hook[[:space:]]+-g[[:space:]]+pane-exited\[0\]' "$tmux_config" | cut -d: -f1)
kill_hook_line=$(grep -nE '^[[:space:]]*set-hook[[:space:]]+-g[[:space:]]+after-kill-pane\[90\]' "$tmux_config" | cut -d: -f1)
[ -n "$pane_exit_line" ] && [ "$pane_exit_line" -gt "$tpm_line" ] || \
  fail pane_exit_hook_order "target-aware pane-exited replacement is not after TPM"
[ -n "$kill_hook_line" ] && [ "$kill_hook_line" -gt "$tpm_line" ] || \
  fail kill_pane_hook_order "owned after-kill-pane callback is not after TPM"
grep -q 'pane-moved.*reconcile-all' "$tmux_config" || fail pane_move_hook "missing window attention reconciliation after pane move"
grep -q 'status-format\[2\].*#{W:' "$tmux_config" || fail native_window_loop "middle status does not use native W: loop"
grep -q 'window-status-current-format.*bg=#50C4C0' "$tmux_config" || fail native_current_style "current window style is not native"
grep -q 'window-status-current-format.*window_zoomed_flag' "$tmux_config" || \
  fail native_current_marker "current window marker is not limited to zoomed hidden panes"
if grep -q 'list-windows' "$renderer"; then
  fail renderer_native_boundary "renderer still computes the active window"
fi
if grep -q '@client_focused' "$tmux_config"; then
  fail obsolete_focus_state "config still uses @client_focused"
fi

export FAKE_PANES=$'@1|%1\n@1|%2'
export FAKE_CLIENTS='focused|@1|%1|0'
export FAKE_TITLE='shell' FAKE_ATTENTION_STATE='' FAKE_CODEX_STATE='' FAKE_PENDING=''
export FAKE_ATTENTION_WINDOW_STATE=done FAKE_AGGREGATE_PANES=''
export FAKE_PANE_SNAPSHOT=$'@1|%1|done\n@1|%2|waiting'
run_controller reconcile-all || fail reconcile_all "controller exited $?"
assert_called reconcile_all '@attention_codex_working'
assert_called reconcile_all '%1 -u @attention_state'
assert_called reconcile_all '%2 -u @attention_state'
assert_called reconcile_all 'set-option -wu -t @1 @attention_window_state'
unset FAKE_PANE_SNAPSHOT

# Window-scoped reconciliation must not inspect or synchronize other windows.
export FAKE_PANES=$'@1|%1\n@1|%2\n@2|%3'
export FAKE_PANE_SNAPSHOT=$'@1|%1|done\n@1|%2|\n@2|%3|waiting'
export FAKE_CLIENTS=$'focused|@1|%1|0\nfocused|@2|%3|0'
export FAKE_TITLE='shell' FAKE_ATTENTION_STATE='' FAKE_CODEX_STATE='' FAKE_PENDING=''
export FAKE_ATTENTION_WINDOW_STATE=done FAKE_AGGREGATE_PANES=''
run_controller reconcile-window @1 || fail reconcile_window "controller exited $?"
assert_called reconcile_window 'display-message -p -t %1'
assert_called reconcile_window 'display-message -p -t %2'
assert_not_called reconcile_window 'display-message -p -t %3'
assert_not_called reconcile_window 'set-option -p -t %3 -u @attention_state'
assert_called reconcile_window 'list-panes -t @1'
assert_not_called reconcile_window 'list-panes -t @2'
unset FAKE_PANE_SNAPSHOT

# A stale window aggregate must be cleared even when no pane attention state
# changes, proving reconcile-window marks its target dirty directly.
export FAKE_PANES=$'@1|%1\n@1|%2\n@2|%3'
export FAKE_PANE_SNAPSHOT=$'@1|%1|\n@1|%2|\n@2|%3|waiting'
export FAKE_CLIENTS=''
export FAKE_ATTENTION_WINDOW_STATE=done FAKE_AGGREGATE_PANES=''
run_controller reconcile-window @1 || fail reconcile_window_stale_aggregate "controller exited $?"
assert_called reconcile_window_stale_aggregate 'set-option -wu -t @1 @attention_window_state'
assert_not_called reconcile_window_stale_aggregate 'set-option -wu -t @2 @attention_window_state'
unset FAKE_PANE_SNAPSHOT

# A pane-exited hook can run after the final attention-marked pane is gone.
# Even when unsetting absent pane options fails, every current window must be
# synchronized so a stale aggregate is removed.
export FAKE_PANES=$'@1|%1\n@1|%2'
export FAKE_CLIENTS='focused|@1|%1|0'
export FAKE_TITLE='shell' FAKE_ATTENTION_STATE='' FAKE_CODEX_STATE='' FAKE_PENDING=''
export FAKE_ATTENTION_WINDOW_STATE=done FAKE_AGGREGATE_PANES=''
export FAKE_MISSING_ATTENTION_UNSET_FAIL=1
run_controller reconcile-all || fail stale_window_aggregate "controller exited $?"
assert_not_called stale_window_aggregate 'set-option -p -t %1 -u @attention_state'
assert_called stale_window_aggregate 'set-option -wu -t @1 @attention_window_state'
unset FAKE_MISSING_ATTENTION_UNSET_FAIL

# Parse the complete tmux configuration in an isolated server.
if [ -z "$real_tmux" ]; then
  fail tmux_config_parse "tmux is not installed"
else
  integration_home="$tmpdir/integration-home"
  mkdir -p "$integration_home/.local/libexec" "$integration_home/.tmux/plugins/tpm"
  ln -s "$controller" "$integration_home/.local/libexec/tmux-pane-attention"
  cat >"$integration_home/.tmux/plugins/tpm/tpm" <<'FAKE_TPM'
#!/bin/sh
tmux set-hook -g pane-exited 'select-layout; select-layout -E'
tmux set-hook -g after-kill-pane[2] 'display-message stale-hook'
FAKE_TPM
  chmod +x "$integration_home/.tmux/plugins/tpm/tpm"
  env HOME="$integration_home" PATH="$real_path" "$real_tmux" -L "$socket_name" -f /dev/null \
    new-session -d -s attention-test 'sleep 30' || \
    fail tmux_config_parse "could not start isolated server"
  source_output=$("$real_tmux" -L "$socket_name" source-file "$tmux_config" 2>&1)
  source_status=$?
  if [ "$source_status" -ne 0 ]; then
    fail tmux_config_parse "could not source isolated tmux configuration (exit $source_status): $source_output"
  fi
  pane_exit_hooks=$(
    "$real_tmux" -L "$socket_name" show-hooks -g pane-exited 2>/dev/null
  )
  pane_exit_hook_count=$(printf '%s\n' "$pane_exit_hooks" | grep -Ec '^pane-exited\[[0-9]+\] ' || true)
  [ "$pane_exit_hook_count" -eq 1 ] || \
    fail pane_exit_hook_integration "expected one owned pane-exited hook: $pane_exit_hooks"
  case $pane_exit_hooks in
    'pane-exited[0] '*'select-layout -t'*'#{hook_window}'*'tmux-pane-attention reconcile-window'*'#{hook_window}'*) ;;
    *) fail pane_exit_hook_integration "pane-exited hook is not target-aware and reconciled: $pane_exit_hooks" ;;
  esac
  pane_kill_hooks=$("$real_tmux" -L "$socket_name" show-hooks -g after-kill-pane 2>/dev/null)
  case $pane_kill_hooks in
    *'after-kill-pane[2] display-message stale-hook'*'after-kill-pane[90] select-layout ; select-layout -E ; run-shell -b '*'tmux-pane-attention reconcile-window'*'#{window_id}'*) ;;
    *) fail kill_pane_hook_integration "unrelated after-kill hook was not preserved with owned [90]: $pane_kill_hooks" ;;
  esac
  kill_binding=$("$real_tmux" -L "$socket_name" list-keys -T root M-Q 2>/dev/null || true)
  case $kill_binding in
    *'kill-pane'*) ;;
    *) fail tilish_kill_binding_integration "M-Q does not invoke kill-pane: $kill_binding" ;;
  esac
  case $kill_binding in
    *'select-layout'*) fail tilish_kill_binding_integration "M-Q still duplicates layout work: $kill_binding" ;;
  esac

  # A natural exit in an inactive window must rebalance that window, not the
  # currently selected one. Two survivors of even-horizontal differ by <= 1.
  active_window=$("$real_tmux" -L "$socket_name" display-message -p '#{window_id}')
  "$real_tmux" -L "$socket_name" new-window -d -n lifecycle-target 'sleep 30'
  "$real_tmux" -L "$socket_name" split-window -d -t lifecycle-target -h 'sleep 30'
  "$real_tmux" -L "$socket_name" split-window -d -t lifecycle-target -h 'sleep 1'
  "$real_tmux" -L "$socket_name" select-layout -t lifecycle-target even-horizontal
  "$real_tmux" -L "$socket_name" select-window -t "$active_window"
  sleep 1.3
  survivor_widths=$("$real_tmux" -L "$socket_name" list-panes -t lifecycle-target -F '#{pane_width}')
  survivor_count=$(printf '%s\n' "$survivor_widths" | awk 'NF { count++ } END { print count + 0 }')
  width_min=$(printf '%s\n' "$survivor_widths" | sort -n | head -1)
  width_max=$(printf '%s\n' "$survivor_widths" | sort -n | tail -1)
  [ "$survivor_count" -eq 2 ] && [ $((width_max - width_min)) -le 1 ] || \
    fail inactive_window_layout "inactive natural exit was not balanced: $survivor_widths"
  [ "$("$real_tmux" -L "$socket_name" display-message -p '#{window_id}')" = "$active_window" ] || \
    fail inactive_window_focus "pane exit changed the active window"

  attention_window=$("$real_tmux" -L "$socket_name" display-message -p '#{window_id}')
  "$real_tmux" -L "$socket_name" set-option -w -t "$attention_window" @attention_window_state waiting
  waiting_format=$("$real_tmux" -L "$socket_name" display-message -p -t "$attention_window" '#{E:window-status-format}')
  case $waiting_format in
    *'#[fg=#0A1F2E,bg=#C8AE6A,bold]'*) ;;
    *) fail attention_waiting_format "missing complete waiting style token: $waiting_format" ;;
  esac
  "$real_tmux" -L "$socket_name" set-option -w -t "$attention_window" @attention_window_state done
  done_format=$("$real_tmux" -L "$socket_name" display-message -p -t "$attention_window" '#{E:window-status-format}')
  case $done_format in
    *'#[fg=#0A1F2E,bg=#9A7EC8,bold]'*) ;;
    *) fail attention_done_format "missing complete done style token: $done_format" ;;
  esac
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

  # select-pane implicitly unzooms before after-select-pane runs. The hook must
  # still acknowledge the newly visible window when attention exists.
  hook_log="$tmpdir/select-pane-hook.log"
  rm -f "$integration_home/.local/libexec/tmux-pane-attention"
  cat >"$integration_home/.local/libexec/tmux-pane-attention" <<HOOK_HELPER
#!/bin/sh
printf '%s\n' "\$*" >>"$hook_log"
HOOK_HELPER
  chmod +x "$integration_home/.local/libexec/tmux-pane-attention"
  "$real_tmux" -L "$socket_name" split-window -h -d 'sleep 30'
  left_pane=$("$real_tmux" -L "$socket_name" list-panes -F '#{pane_id}' | head -1)
  "$real_tmux" -L "$socket_name" select-pane -t "$left_pane"
  "$real_tmux" -L "$socket_name" resize-pane -Z
  "$real_tmux" -L "$socket_name" set-option -w @attention_window_state waiting
  : >"$hook_log"
  "$real_tmux" -L "$socket_name" select-pane -R
  attempts=0
  while ! grep -q '^acknowledge-visible$' "$hook_log" && [ "$attempts" -lt 20 ]; do
    sleep 0.1
    attempts=$((attempts + 1))
  done
  grep -q '^acknowledge-visible$' "$hook_log" || \
    fail select_pane_unzoom_ack "zoom-to-unzoom pane selection did not acknowledge the visible window"
fi

if [ "$failures" -ne 0 ]; then
  printf 'FAIL: tmux-pane-attention (%s failures)\n' "$failures" >&2
  exit 1
fi

printf 'PASS: tmux-pane-attention\n'
