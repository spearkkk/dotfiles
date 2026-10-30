#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$repo_root/home/.local/libexec/tmux-pane-context"
real_tmux=$(command -v tmux)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/tmux-pane-context.XXXXXX")
socket="pane-context-$$"

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

tmux -f /dev/null new-session -d -s test
pane=$(tmux display-message -p -t test: '#{pane_id}')

assert_json() {
  local filter=$1 expected=$2 actual
  actual=$("$helper" list "$pane" | jq -c "$filter")
  [[ "$actual" == "$expected" ]] || {
    printf 'FAIL: jq %s: expected %s, got %s\n' "$filter" "$expected" "$actual" >&2
    exit 1
  }
}

assert_pane_json() {
  local target=$1 filter=$2 expected=$3 actual
  actual=$("$helper" list "$target" | jq -c "$filter")
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: pane %s jq %s: expected %s, got %s\n' \
      "$target" "$filter" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_eq() {
  local expected=$1 actual=$2 label=$3
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_empty() {
  local actual=$1 label=$2
  if [[ -n "$actual" ]]; then
    printf 'FAIL: %s: expected empty, got %s\n' "$label" "$actual" >&2
    exit 1
  fi
}

assert_eq '{"schema":1,"revision":0,"contexts":[]}' \
  "$("$helper" list "$pane")" 'initial contexts'

"$helper" inject "$pane" '{"instance":"ctx-1","id":"dev-k8s","slot":"kubernetes","environment":"dev","alert":false,"state":"connecting"}'
assert_json '.revision' '1'
assert_json '.contexts | length' '1'
assert_json '.contexts[0] | {instance,id,slot,environment,alert,state}' \
  '{"instance":"ctx-1","id":"dev-k8s","slot":"kubernetes","environment":"dev","alert":false,"state":"connecting"}'
assert_eq 'dev-k8s…' "$(tmux show-options -pqv -t "$pane" @contexts_display)" 'connecting display'
assert_eq 0 "$(tmux show-options -pqv -t "$pane" @contexts_alert)" 'connecting alert'

"$helper" inject "$pane" '{"instance":"ctx-2","id":"object-prod","slot":"object-storage","environment":"prod","alert":true,"state":"active"}'
assert_json '.contexts | map(.id)' '["dev-k8s","object-prod"]'
assert_eq 'dev-k8s… | object-prod' "$(tmux show-options -pqv -t "$pane" @contexts_display)" 'multiple context display'
assert_eq 1 "$(tmux show-options -pqv -t "$pane" @contexts_alert)" 'production alert'

"$helper" inject "$pane" '{"instance":"ctx-3","id":"prod-k8s","slot":"kubernetes","environment":"prod","alert":true,"state":"connecting"}'
assert_json '.contexts | map(.id)' '["object-prod","prod-k8s"]'
assert_json '.contexts | map(.slot) | unique | length' '2'

revision=$("$helper" list "$pane" | jq '.revision')
"$helper" state "$pane" ctx-1 offline
assert_eq "$revision" "$("$helper" list "$pane" | jq '.revision')" 'unknown instance revision'

"$helper" state "$pane" ctx-3 active
assert_json '.contexts[] | select(.instance == "ctx-3") | .state' '"active"'
assert_eq 'object-prod | prod-k8s' "$(tmux show-options -pqv -t "$pane" @contexts_display)" 'active display'

"$helper" state "$pane" ctx-3 offline
assert_eq 'object-prod | prod-k8s○' "$(tmux show-options -pqv -t "$pane" @contexts_display)" 'offline display'
assert_eq 1 "$(tmux show-options -pqv -t "$pane" @contexts_alert)" 'remaining production alert'

"$helper" state "$pane" ctx-2 error
assert_eq 'object-prod! | prod-k8s○' "$(tmux show-options -pqv -t "$pane" @contexts_display)" 'error display'
assert_eq 0 "$(tmux show-options -pqv -t "$pane" @contexts_alert)" 'inactive alerts'

revision=$("$helper" list "$pane" | jq '.revision')
"$helper" eject "$pane" kubernetes wrong-instance
assert_eq "$revision" "$("$helper" list "$pane" | jq '.revision')" 'wrong instance eject revision'
"$helper" eject "$pane" kubernetes ctx-3
assert_json '.contexts | map(.id)' '["object-prod"]'

if "$helper" inject "$pane" '{"instance":"bad","id":"x","slot":"x","environment":"dev","alert":false,"state":"invalid"}' >/dev/null 2>&1; then
  echo 'FAIL: invalid state accepted' >&2
  exit 1
fi

oversized=$(jq -cn --arg id "$(printf 'x%.0s' {1..4100})" \
  '{instance:"large",id:$id,slot:"large",environment:"dev",alert:false,state:"active"}')
if "$helper" inject "$pane" "$oversized" >/dev/null 2>&1; then
  echo 'FAIL: oversized context value accepted' >&2
  exit 1
fi

"$helper" clear "$pane"
assert_eq '{"schema":1,"revision":8,"contexts":[]}' "$("$helper" list "$pane")" 'cleared contexts'
assert_eq '{"schema":1,"revision":8,"contexts":[]}' \
  "$(tmux show-options -pqv -t "$pane" @contexts)" 'stored cleared contexts'
assert_empty "$(tmux show-options -pqv -t "$pane" @contexts_display 2>/dev/null || true)" 'cleared display'
assert_eq 0 "$(tmux show-options -pqv -t "$pane" @contexts_alert)" 'cleared alert'

concurrent_pane=$(tmux split-window -d -P -F '#{pane_id}' -t "$pane")
pids=()
for index in {1..8}; do
  descriptor=$(jq -cn --arg index "$index" \
    '{instance:("parallel-" + $index),id:("context-" + $index),slot:("slot-" + $index),environment:"dev",alert:false,state:"connecting"}')
  "$helper" inject "$concurrent_pane" "$descriptor" &
  pids+=("$!")
done
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    echo 'FAIL: concurrent inject failed' >&2
    exit 1
  fi
done
assert_pane_json "$concurrent_pane" '.revision' '8'
assert_pane_json "$concurrent_pane" '.contexts | length' '8'
assert_pane_json "$concurrent_pane" '.contexts | map(.slot) | unique | length' '8'

pids=()
for index in {1..8}; do
  "$helper" state "$concurrent_pane" "parallel-$index" active &
  pids+=("$!")
done
for pid in "${pids[@]}"; do
  if ! wait "$pid"; then
    echo 'FAIL: concurrent state transition failed' >&2
    exit 1
  fi
done
assert_pane_json "$concurrent_pane" '.revision' '16'
assert_pane_json "$concurrent_pane" '[.contexts[].state] | unique' '["active"]'

grep -q 'tmux-pane-context' "$repo_root/setup/check.fish"

echo 'PASS: tmux-pane-context'
