#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cw_file="$repo_root/home/.config/fish/functions/cw.fish"
renderer="$repo_root/home/.tmux/scripts/status-box.sh"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/cw-pane-context.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/tmux" <<'TMUX'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_TMUX_LOG"
last=
for arg do last=$arg; done
case ${1:-} in
  has-session) exit "${FAKE_SESSION_FAIL:-0}" ;;
  list-windows) printf '%s\n' '1:other' ;;
  list-panes) printf '%s\n' "${FAKE_PANES:-}" ;;
  display-message)
    case $last in
      '#S') printf '%s\n' test ;;
      '#{pane_id}') printf '%s\n' %4 ;;
      *) exit 1 ;;
    esac
    ;;
  split-window) [ "${FAKE_SPLIT_FAIL:-0}" = 0 ] || exit 1; printf '%s\n' %9 ;;
  send-keys|switch-client|attach-session|select-pane) exit 0 ;;
  *) exit 2 ;;
esac
TMUX
chmod +x "$tmpdir/tmux"

cat >"$tmpdir/context-helper" <<'HELPER'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_CONTEXT_LOG"
state_file=$FAKE_CONTEXT_STATE
update_state() {
  jq -c "$@" "$state_file" >"$state_file.tmp" && mv "$state_file.tmp" "$state_file"
}
case $1 in
  list) cat "$state_file" ;;
  inject)
    if [ "$#" -eq 4 ]; then
      actual=$(jq -r --argjson descriptor "$3" 'first(.contexts[] | select(.slot == $descriptor.slot) | .instance) // ""' "$state_file")
      [ "$actual" = "$4" ] || exit 75
    fi
    update_state --argjson descriptor "$3" \
      '.revision += 1 | .contexts = ([.contexts[] | select(.slot != $descriptor.slot)] + [$descriptor])'
    ;;
  eject)
    update_state --arg slot "$3" --arg instance "${4:-}" \
      '.revision += 1 | .contexts = [.contexts[] | select(.slot != $slot or ($instance != "" and .instance != $instance))]'
    ;;
  state)
    update_state --arg instance "$3" --arg state "$4" \
      '.revision += 1 | .contexts |= map(if .instance == $instance then .state = $state else . end)'
    ;;
  clear)
    update_state '.revision += 1 | .contexts = []'
    ;;
  *) exit 0 ;;
esac
HELPER
chmod +x "$tmpdir/context-helper"

export PATH="$tmpdir:$PATH"
export CW_CONTEXT_HELPER="$tmpdir/context-helper"
export FAKE_TMUX_LOG="$tmpdir/tmux.log"
export FAKE_CONTEXT_LOG="$tmpdir/context.log"
export FAKE_CONTEXT_STATE="$tmpdir/context-state.json"
export PROVIDER_LOG="$tmpdir/provider.log"

run_fish() {
  : >"$FAKE_TMUX_LOG"
  : >"$FAKE_CONTEXT_LOG"
  : >"$PROVIDER_LOG"
  if [[ -n ${FAKE_CONTEXTS:-} ]]; then
    printf '%s\n' "$FAKE_CONTEXTS" >"$FAKE_CONTEXT_STATE"
  else
    printf '%s\n' '{"schema":1,"revision":0,"contexts":[]}' >"$FAKE_CONTEXT_STATE"
  fi
  fish --no-config --command '
    source $argv[1]

    function __cw_context --argument-names name
      switch $name
        case dev-k8s
          printf "%s\n" name=dev-k8s title=dev-k8s type=kubernetes env=dev session=test cwd=/tmp inject=provider_inject restore=provider_restore eject=provider_eject
        case k8s-dev
          printf "%s\n" name=dev-k8s title=dev-k8s type=kubernetes env=dev session=test cwd=/tmp inject=provider_inject restore=provider_restore eject=provider_eject
        case prod-object
          printf "%s\n" name=prod-object title=prod-object type=object-storage env=prod alert=1 session=test cwd=/tmp inject=provider_inject restore=provider_restore eject=provider_eject
        case other-k8s
          printf "%s\n" name=other-k8s title=other-k8s type=kubernetes env=dev session=test cwd=/tmp inject=provider_inject restore=provider_restore eject=provider_eject
        case broken
          printf "%s\n" name=broken title=broken type=pulsar env=dev session=test cwd=/tmp inject=provider_fail restore=provider_restore eject=provider_eject
        case broken-k8s
          printf "%s\n" name=broken-k8s title=broken-k8s type=kubernetes env=dev session=test cwd=/tmp inject=provider_fail restore=provider_restore eject=provider_eject
        case "*"
          return 1
      end
    end

    function provider_inject
      printf "inject:%s:%s:%s\n" $argv[1] $argv[2] (__cw_get name $argv[3..-1]) >>$PROVIDER_LOG
    end
    function provider_fail
      printf "fail:%s:%s:%s\n" $argv[1] $argv[2] (__cw_get name $argv[3..-1]) >>$PROVIDER_LOG
      return 1
    end
    function provider_restore
      printf "restore:%s:%s:%s\n" $argv[1] $argv[2] (__cw_get name $argv[3..-1]) >>$PROVIDER_LOG
    end
    function provider_eject
      printf "eject:%s:%s:%s\n" $argv[1] $argv[2] (__cw_get name $argv[3..-1]) >>$PROVIDER_LOG
    end

    eval $argv[2..-1]
  ' "$cw_file" "$@"
}

if run_fish 'cw dev-k8s other-k8s' >"$tmpdir/stdout" 2>"$tmpdir/stderr"; then
  echo 'FAIL: duplicate slots accepted' >&2
  exit 1
fi
grep -q 'context slot already selected: kubernetes' "$tmpdir/stderr"
[[ ! -s "$FAKE_TMUX_LOG" ]]

# Default applies in the caller, regardless of profile session defaults.
TMUX=1 TMUX_PANE=%7 run_fish 'cw dev-k8s prod-object'
[[ $(grep -c '^inject:' "$PROVIDER_LOG") -eq 2 ]]
[[ $(grep -c '^inject %7 ' "$FAKE_CONTEXT_LOG") -eq 2 ]]
[[ $(grep -c '^state %7 .* active$' "$FAKE_CONTEXT_LOG") -eq 2 ]]
[[ ! -s "$FAKE_TMUX_LOG" ]]

# Explicit creation never reuses a pane with the same context set.
export FAKE_PANES='%4|{"contexts":[{"id":"dev-k8s"},{"id":"prod-object"}]}'
for flags in '--pane' '-P'; do
  TMUX=1 TMUX_PANE=%7 run_fish "cw dev-k8s prod-object $flags"
  grep -q '^split-window -h -d -P -F #{pane_id} -t %7 -c /tmp$' "$FAKE_TMUX_LOG"
  grep -q '^send-keys -t %9 cw dev-k8s prod-object C-m$' "$FAKE_TMUX_LOG"
  grep -q '^switch-client -t %9$' "$FAKE_TMUX_LOG"
  [[ ! -s "$FAKE_CONTEXT_LOG" && ! -s "$PROVIDER_LOG" ]]
  ! grep -Eq '^new-window|^list-panes' "$FAKE_TMUX_LOG"
done
unset FAKE_PANES
TMUX=1 TMUX_PANE=%7 run_fish 'cw dev-k8s --pane --bottom'
grep -q '^split-window -v .* -t %7 -c /tmp$' "$FAKE_TMUX_LOG"

# Explicit session overrides the caller pane and profile default session.
for flags in '--session other' '--pane --session other' '-s other'; do
  TMUX=1 TMUX_PANE=%7 run_fish "cw dev-k8s $flags"
  grep -q '^display-message -p -t =other: #{pane_id}$' "$FAKE_TMUX_LOG"
  grep -q '^split-window -h .* -t %4 -c /tmp$' "$FAKE_TMUX_LOG"
done
run_fish 'set -e TMUX_PANE; cw dev-k8s --session other --bottom'
grep -q '^split-window -v .* -t %4 -c /tmp$' "$FAKE_TMUX_LOG"

for invocation in 'cw dev-k8s' 'cw dev-k8s --pane'; do
  if run_fish "set -e TMUX_PANE; $invocation"; then
    echo 'FAIL: current-pane operation accepted outside tmux' >&2; exit 1
  fi
  [[ ! -s "$FAKE_TMUX_LOG" && ! -s "$FAKE_CONTEXT_LOG" ]]
done
for invocation in 'cw dev-k8s --bottom' 'cw dev-k8s --session' 'cw dev-k8s --session ""' 'cw clear --pane' 'cw dev-k8s --unknown'; do
  if TMUX=1 TMUX_PANE=%7 run_fish "$invocation"; then
    echo "FAIL: invalid arguments accepted: $invocation" >&2; exit 1
  fi
  [[ ! -s "$FAKE_TMUX_LOG" && ! -s "$FAKE_CONTEXT_LOG" ]]
done
if FAKE_SESSION_FAIL=1 run_fish 'cw dev-k8s --session missing'; then
  echo 'FAIL: missing session accepted' >&2; exit 1
fi
! grep -Eq '^split-window|^send-keys' "$FAKE_TMUX_LOG"
if FAKE_SPLIT_FAIL=1 TMUX=1 TMUX_PANE=%7 run_fish 'cw dev-k8s --pane'; then
  echo 'FAIL: split failure ignored' >&2; exit 1
fi
! grep -Eq '^send-keys|^switch-client' "$FAKE_TMUX_LOG"
TMUX=1 TMUX_PANE=%7 run_fish 'cw k8s-dev'
grep -q '^inject:%7:.*:dev-k8s$' "$PROVIDER_LOG"

if TMUX=1 TMUX_PANE=%7 run_fish 'cw broken'; then
  echo 'FAIL: provider failure returned success' >&2
  exit 1
fi
grep -q '^state %7 .* error$' "$FAKE_CONTEXT_LOG"

old_context='{"instance":"old-1","id":"dev-k8s","slot":"kubernetes","environment":"dev","alert":false,"state":"active"}'
export FAKE_CONTEXTS="{\"schema\":1,\"revision\":1,\"contexts\":[$old_context]}"
if TMUX=1 TMUX_PANE=%7 run_fish 'cw broken-k8s'; then
  echo 'FAIL: replacement provider failure returned success' >&2
  exit 1
fi
grep -q '^eject:%7:old-1:dev-k8s$' "$PROVIDER_LOG"
grep -q '^fail:%7:.*:broken-k8s$' "$PROVIDER_LOG"
grep -q '^eject:%7:.*:broken-k8s$' "$PROVIDER_LOG"
grep -q '^restore:%7:old-1:dev-k8s$' "$PROVIDER_LOG"
if [[ $(jq -c '.contexts' "$FAKE_CONTEXT_STATE") != "[$old_context]" ]]; then
  printf 'FAIL: existing context was not restored: %s\n' \
    "$(cat "$FAKE_CONTEXT_STATE")" >&2
  exit 1
fi
unset FAKE_CONTEXTS

old_context='{"instance":"old-1","id":"dev-k8s","slot":"kubernetes","environment":"dev","alert":false,"state":"active"}'
export FAKE_CONTEXTS="{\"schema\":1,\"revision\":1,\"contexts\":[$old_context]}"
if TMUX=1 TMUX_PANE=%7 run_fish 'cw other-k8s broken'; then
  echo 'FAIL: multi-context provider failure returned success' >&2
  exit 1
fi
assert_eq_batch=$(jq -c '.contexts' "$FAKE_CONTEXT_STATE")
if [[ "$assert_eq_batch" != "[$old_context]" ]]; then
  printf 'FAIL: batch failure did not restore original contexts: %s\n' \
    "$assert_eq_batch" >&2
  exit 1
fi
grep -q '^eject:%7:.*:other-k8s$' "$PROVIDER_LOG"
grep -q '^restore:%7:old-1:dev-k8s$' "$PROVIDER_LOG"
unset FAKE_CONTEXTS

export FAKE_CONTEXTS='{"schema":1,"revision":3,"contexts":[{"instance":"old-1","id":"dev-k8s","slot":"kubernetes","environment":"dev","alert":false,"state":"active"},{"instance":"old-2","id":"prod-object","slot":"object-storage","environment":"prod","alert":true,"state":"offline"}]}'
TMUX=1 TMUX_PANE=%7 run_fish 'cw clear'
grep -q '^eject:%7:old-1:dev-k8s$' "$PROVIDER_LOG"
grep -q '^eject:%7:old-2:prod-object$' "$PROVIDER_LOG"
grep -q '^clear %7$' "$FAKE_CONTEXT_LOG"
unset FAKE_CONTEXTS

renderer_output=$("$renderer" '#112233' '#AABBCC' '#445566' 'xdev-k8s | prod-object')
case $renderer_output in
  *' dev-k8s | prod-object '*) ;;
  *) echo "FAIL: pane contexts missing from renderer: $renderer_output" >&2; exit 1 ;;
esac

if grep -Eq '@cw_context|@kube_context|@aws_profile' "$cw_file"; then
  echo 'FAIL: cw still depends on legacy/provider-specific options' >&2
  exit 1
fi

if grep -Eq '@(kube_context|fke_config|aws_profile|kube_context_disabled)' "$repo_root/home/.config/fish/functions/ctx.fish"; then
  echo 'FAIL: ctx still reads provider-specific tmux options' >&2
  exit 1
fi
grep -q '@contexts_display' "$repo_root/home/.config/fish/functions/ctx.fish"

# The optional, local-only compatibility wrapper must not turn its current-pane
# mode into a split merely because cw changed its flag contract.
cx_file="$repo_root/profiles/work/home/.config/fish/functions/cx.fish"
if [[ -f "$cx_file" ]]; then
  TMUX_PANE=%7 fish --no-config -c '
    source $argv[1]
    function cw; string join "|" -- $argv; end
    test (cx demo) = demo; or exit 1
    test (cx demo --pane) = demo; or exit 1
    test (cx demo --new) = "demo|--pane"; or exit 1
    test (cx demo --new --session other) = "demo|--session|other"; or exit 1
  ' "$cx_file"
fi

echo 'PASS: cw-multi-context'
