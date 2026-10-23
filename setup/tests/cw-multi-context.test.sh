#!/usr/bin/env bash

set -u

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cw_file="$repo_root/home/.config/fish/functions/cw.fish"
renderer="$repo_root/home/.tmux/scripts/status-box.sh"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/cw-multi-context.XXXXXX")
failures=0

cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s: %s\n' "$1" "$2" >&2
  failures=$((failures + 1))
}

cat >"$tmpdir/tmux" <<'FAKE_TMUX'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_TMUX_LOG"

previous=
last=
for arg do
  previous=$last
  last=$arg
done

case ${1:-} in
  has-session) exit 0 ;;
  list-windows) printf '%s\n' "${FAKE_WINDOWS:-}" ;;
  new-window|set-option|switch-client|attach-session) exit 0 ;;
  show-options)
    case $last in
      @cw_context) value=${FAKE_CW_CONTEXT:-} ;;
      @cw_context_prod) value=${FAKE_CW_CONTEXT_PROD:-} ;;
      @kube_context) value=${FAKE_KUBE_CONTEXT:-} ;;
      @aws_profile) value=${FAKE_AWS_PROFILE:-} ;;
      *) value= ;;
    esac
    [ -n "$value" ] || exit 1
    printf '%s\n' "$value"
    ;;
  *) exit 2 ;;
esac
FAKE_TMUX
chmod +x "$tmpdir/tmux"

export PATH="$tmpdir:$PATH"
export FAKE_TMUX_LOG="$tmpdir/tmux.log"
export CW_HOOK_LOG="$tmpdir/hooks.log"

run_cw() {
  : >"$FAKE_TMUX_LOG"
  : >"$CW_HOOK_LOG"
  fish --no-config --command '
    source "$argv[1]"

    function __cw_context --argument-names name
      switch $name
        case dev-k8s
          printf "%s\n" name=dev-k8s title=dev-k8s type=kubernetes env=dev session=test reset=reset_window pane_reset=reset_pane init=init_context pane_init=init_pane
        case fos-dev
          printf "%s\n" name=fos-dev title=fos-dev type=object-storage env=dev session=test reset=reset_window pane_reset=reset_pane init=init_context pane_init=init_pane
        case pulsar-prod
          printf "%s\n" name=pulsar-prod title=pulsar-prod type=pulsar env=prod session=test reset=reset_window pane_reset=reset_pane init=init_context pane_init=init_pane
        case other-k8s
          printf "%s\n" name=other-k8s title=other-k8s type=kubernetes env=dev session=test reset=reset_window pane_reset=reset_pane init=init_context pane_init=init_pane
        case remote-prod
          printf "%s\n" name=remote-prod title=remote-prod type=hadoop env=prod deferred=1 session=test reset=reset_window pane_reset=reset_pane reuse_guard=guard_remote init=init_context pane_init=init_pane
        case unsupported
          printf "%s\n" name=unsupported title=unsupported type=database env=dev session=test reset=reset_window pane_reset=reset_pane init=init_context pane_init=init_pane
        case "*"
          return 1
      end
    end

    function reset_window
      printf "reset-window:%s\n" "$argv" >>"$CW_HOOK_LOG"
    end
    function reset_pane
      printf "reset-pane:%s\n" "$argv" >>"$CW_HOOK_LOG"
    end
    function init_context
      printf "init:%s:%s\n" "$argv[1]" (__cw_get name $argv[2..-1]) >>"$CW_HOOK_LOG"
    end
    function init_pane
      printf "pane:%s\n" (__cw_get name $argv) >>"$CW_HOOK_LOG"
    end
    function guard_remote
      test "$FAKE_REMOTE_ACTIVE" = 1
    end

    cw $argv[2..-1]
  ' "$cw_file" "$@"
}

run_cw dev-k8s fos-dev || fail combine "cw exited $?"
[ "$(grep -c '^reset-window:' "$CW_HOOK_LOG")" -eq 1 ] || fail combine "window reset did not run exactly once"
[ "$(grep -c '^init:' "$CW_HOOK_LOG")" -eq 2 ] || fail combine "both context initializers did not run"
grep -q '^init:test:dev-k8s+fos-dev:dev-k8s$' "$CW_HOOK_LOG" || fail combine "missing Kubernetes initializer"
grep -q '^init:test:dev-k8s+fos-dev:fos-dev$' "$CW_HOOK_LOG" || fail combine "missing object-storage initializer"
grep -q 'new-window .* -n dev-k8s+fos-dev ' "$FAKE_TMUX_LOG" || fail combine "combined window title was not used"
grep -q 'set-option -w -t test:dev-k8s+fos-dev @cw_context dev-k8s | fos-dev' "$FAKE_TMUX_LOG" || fail combine "combined context metadata was not stored"
grep -q 'set-option -w -t test:dev-k8s+fos-dev @cw_context_prod 0' "$FAKE_TMUX_LOG" || fail combine "dev combination was marked prod"

if run_cw dev-k8s other-k8s >"$tmpdir/stdout" 2>"$tmpdir/stderr"; then
  fail duplicate_type "same-type contexts were accepted"
else
  grep -q 'context type already selected: kubernetes' "$tmpdir/stderr" || fail duplicate_type "missing duplicate-type explanation"
  [ ! -s "$FAKE_TMUX_LOG" ] || fail duplicate_type "tmux was touched before validation completed"
fi

run_cw dev-k8s pulsar-prod || fail prod "cw exited $?"
grep -q 'set-option -w -t test:dev-k8s+pulsar-prod @cw_context_prod 1' "$FAKE_TMUX_LOG" || fail prod "prod metadata was not stored"

run_cw remote-prod dev-k8s || fail deferred "cw exited $?"
expected_order=$(printf '%s\n' \
  'reset-window:test:remote-prod+dev-k8s' \
  'init:test:remote-prod+dev-k8s:dev-k8s' \
  'init:test:remote-prod+dev-k8s:remote-prod')
[ "$(cat "$CW_HOOK_LOG")" = "$expected_order" ] || fail deferred "blocking context was not initialized last: [$(cat "$CW_HOOK_LOG")]"
grep -q 'set-option -w -t test:remote-prod+dev-k8s @cw_context_prod 1' "$FAKE_TMUX_LOG" || fail deferred "prod Hadoop metadata was not stored"

FAKE_WINDOWS=remote-prod+dev-k8s FAKE_REMOTE_ACTIVE=1 run_cw remote-prod dev-k8s || fail active_remote "cw exited $?"
[ ! -s "$CW_HOOK_LOG" ] || fail active_remote "active remote window was reinitialized: [$(cat "$CW_HOOK_LOG")]"
grep -q '^switch-client -t test:remote-prod+dev-k8s$' "$FAKE_TMUX_LOG" || fail active_remote "active remote window was not focused"
if grep -q '^set-option\|^new-window' "$FAKE_TMUX_LOG"; then
  fail active_remote "active remote window was mutated"
fi

if run_cw unsupported >"$tmpdir/stdout" 2>"$tmpdir/stderr"; then
  fail unsupported_type "unsupported context type was accepted"
else
  grep -q 'unsupported context type: database' "$tmpdir/stderr" || fail unsupported_type "missing unsupported-type explanation"
  [ ! -s "$FAKE_TMUX_LOG" ] || fail unsupported_type "tmux was touched before type validation completed"
fi

TMUX_PANE=%7 run_cw dev-k8s fos-dev --pane || fail pane "cw exited $?"
[ "$(grep -c '^reset-pane:' "$CW_HOOK_LOG")" -eq 1 ] || fail pane "pane reset did not run exactly once"
[ "$(grep -c '^pane:' "$CW_HOOK_LOG")" -eq 2 ] || fail pane "both pane initializers did not run"
grep -q 'set-option -p -t %7 @cw_context dev-k8s | fos-dev' "$FAKE_TMUX_LOG" || fail pane "pane context metadata was not stored"

export FAKE_CW_CONTEXT='dev-k8s | fos-dev'
export FAKE_CW_CONTEXT_PROD=0
renderer_output=$($renderer middle-right 100 test %7 @1 normal)
case $renderer_output in
  *' dev-k8s | fos-dev '*) ;;
  *) fail status_context "combined context missing from status: $renderer_output" ;;
esac

export FAKE_CW_CONTEXT='dev-k8s | pulsar-prod'
export FAKE_CW_CONTEXT_PROD=1
renderer_output=$($renderer middle-right 100 test %7 @1 prod)
case $renderer_output in
  *'#[fg=#0A1F2E,bg=#C47A72]'*) ;;
  *) fail status_prod "prod status color missing: $renderer_output" ;;
esac

if [ "$failures" -gt 0 ]; then
  printf 'FAIL: cw-multi-context (%d failures)\n' "$failures" >&2
  exit 1
fi

printf 'PASS: cw-multi-context\n'
