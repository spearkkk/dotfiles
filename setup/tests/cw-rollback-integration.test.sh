#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
real_tmux=$(command -v tmux)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/cw-rollback.XXXXXX")
export TMPDIR="$tmpdir"
socket="cw-rollback-$$"
cleanup() {
  "$real_tmux" -L "$socket" kill-server >/dev/null 2>&1 || true
  rm -rf "$tmpdir"
}
trap cleanup EXIT
cat >"$tmpdir/tmux" <<EOF
#!/bin/sh
exec "$real_tmux" -L "$socket" "\$@"
EOF
chmod +x "$tmpdir/tmux"
export PATH="$tmpdir:$PATH"
export CW_CONTEXT_HELPER="$repo_root/home/.local/libexec/tmux-manage-pane-context"
tmux -f /dev/null new-session -d -s rollback
export TMUX_PANE
TMUX_PANE=$(tmux display-message -p -t rollback: '#{pane_id}')

cat >"$tmpdir/scenario.fish" <<'FISH'
source $argv[1]
set -l scenario $argv[2]
set -gx TEST_A old

function __cw_context --argument-names name
    set -l slot a
    test "$name" != broken; or set slot b
    printf '%s\n' name=$name type=$slot env=prod alert=1 inject=test_inject restore=test_restore eject=test_eject
end
function test_inject --argument-names pane instance
    set -l name (__cw_get name $argv[3..-1])
    if test "$name" = broken
        set -gx TEST_B partial
        return 1
    end
    set -gx TEST_A new
    if test "$TEST_SCENARIO" = conflict
        # A second helper process replaces our slot before our failure unwinds.
        "$CW_CONTEXT_HELPER" inject "$pane" '{"instance":"foreign","id":"foreign","slot":"a","environment":"prod","alert":true,"state":"active"}'
        or exit 1
        return 1
    end
    if test "$TEST_SCENARIO" = restore_fail; or test "$TEST_SCENARIO" = eject_fail
        return 1
    end
end
function test_restore --argument-names pane instance
    if test "$TEST_SCENARIO" = restore_fail
        return 1
    end
    set -gx TEST_A old
end
function test_eject --argument-names pane instance
    set -l name (__cw_get name $argv[3..-1])
    if test "$name" = broken
        set -e TEST_B
    else
        set -e TEST_A
    end
    if test "$TEST_SCENARIO" = eject_fail; and test "$name" = new
        return 1
    end
    if test "$TEST_SCENARIO" = old_eject_fail; and test "$name" = old
        return 1
    end
    if test "$TEST_SCENARIO" = conflict_after_eject; and test "$name" = new
        "$CW_CONTEXT_HELPER" inject "$pane" '{"instance":"foreign","id":"foreign","slot":"a","environment":"prod","alert":true,"state":"active"}'
        or exit 1
    end
    return 0
end

if test "$scenario" = batch; or test "$scenario" = conflict_after_eject
    cw new broken
else
    cw new
end
set -l result $status
test $result -ne 0; or exit 10
if test "$scenario" = batch
    test "$TEST_A" = old; or exit 11
    not set -q TEST_B; or exit 12
end
if test "$scenario" = old_eject_fail
    test "$TEST_A" = old; or exit 13
end
FISH

failures=0
for scenario in batch restore_fail eject_fail old_eject_fail conflict conflict_after_eject; do
  export TEST_SCENARIO="$scenario"
  tmux set-option -p -t "$TMUX_PANE" @contexts '{"schema":1,"revision":1,"contexts":[{"instance":"old","id":"old","slot":"a","environment":"prod","alert":true,"state":"active"},{"instance":"untouched","id":"untouched","slot":"c","environment":"dev","alert":false,"state":"offline"}]}'
  if ! fish --no-config "$tmpdir/scenario.fish" "$repo_root/home/.config/fish/functions/cw.fish" "$scenario" >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "FAIL: $scenario shell environment or exit status" >&2
    cat "$tmpdir/err" >&2
    failures=$((failures + 1))
    continue
  fi
  value=$(tmux show-options -pqv -t "$TMUX_PANE" @contexts)
  case $scenario in
    batch) expected='old|active'; display='untouched○ | old'; alert=1 ;;
    restore_fail) expected='old|error'; display='untouched○ | old!'; alert=0 ;;
    eject_fail) expected='new|error'; display='untouched○ | new!'; alert=0 ;;
    old_eject_fail) expected='old|active'; display='old | untouched○'; alert=1 ;;
    conflict*) expected='foreign|active'; display='untouched○ | foreign'; alert=1 ;;
  esac
  actual=$(printf '%s' "$value" | jq -r '.contexts[] | select(.slot == "a") | .id + "|" + .state')
  if [[ "$actual" != "$expected" ]] ||
     [[ $(tmux show-options -pqv -t "$TMUX_PANE" @contexts_display) != "$display" ]] ||
     [[ $(tmux show-options -pqv -t "$TMUX_PANE" @contexts_alert) != "$alert" ]] ||
     ! printf '%s' "$value" | jq -e '.contexts | length == 2 and any(.[]; .instance == "untouched" and .state == "offline")' >/dev/null; then
    echo "FAIL: $scenario expected $expected and consistent projection, got $value" >&2
    failures=$((failures + 1))
  elif [[ "$scenario" != batch && ! -s "$tmpdir/err" ]]; then
    echo "FAIL: $scenario recovery/conflict failure was not reported" >&2
    failures=$((failures + 1))
  else
    echo "PASS: cw rollback $scenario"
  fi
done

# Two concurrent writers must not both claim an empty slot. The check and
# write belong to the same real lockf critical section, not a Fish-side check.
tmux set-option -p -t "$TMUX_PANE" @contexts '{"schema":1,"revision":0,"contexts":[]}'
pids=()
for index in 1 2; do
  descriptor=$(jq -cn --arg instance "writer-$index" '{instance:$instance,id:$instance,slot:"a",environment:"dev",alert:false,state:"active"}')
  "$CW_CONTEXT_HELPER" inject "$TMUX_PANE" "$descriptor" "" >"$tmpdir/writer-$index.out" 2>"$tmpdir/writer-$index.err" &
  pids+=("$!")
done
successes=0
for pid in "${pids[@]}"; do
  if wait "$pid"; then successes=$((successes + 1)); fi
done
if [[ "$successes" != 1 ]] || ! "$CW_CONTEXT_HELPER" list "$TMUX_PANE" | jq -e '.revision == 1 and (.contexts | length == 1)' >/dev/null; then
  echo 'FAIL: concurrent writers both claimed the same slot or lost the winner' >&2
  failures=$((failures + 1))
else
  echo 'PASS: cw concurrent conditional injection'
fi
[[ "$failures" -eq 0 ]]
