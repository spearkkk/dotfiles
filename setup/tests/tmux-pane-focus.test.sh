#!/usr/bin/env bash

set -u

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config="$repo_root/home/.tmux.conf"
toggle="$repo_root/home/.local/libexec/tmux-pane-focus-toggle"
failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_line() {
  local expected=$1
  grep -Fqx "$expected" "$config" || fail "missing config line: $expected"
}

assert_line "set-hook -g after-select-pane[10] 'run-shell -b \"~/.local/libexec/tmux-pane-attention acknowledge-visible\"'"
assert_line "set -g @pane-focus-enabled off"
assert_line "set -g @pane-focus-size '70'"
assert_line "set -g @pane-focus-direction '+'"
assert_line "set -g @plugin 'graemedavidson/tmux-pane-focus#v0.5.0-alpha'"
assert_line 'set -g pane-border-format " #{?pane_active,▶,·} #{pane_index} #{=30:pane_title} "'
assert_line "bind-key F run-shell '~/.local/libexec/tmux-pane-focus-toggle \"#{window_id}\"'"

if grep -Fqx "set-hook -g after-select-pane   'run-shell -b \"~/.local/libexec/tmux-pane-attention acknowledge-visible\"'" "$config"; then
  fail 'pane-attention still owns the unindexed after-select-pane hook'
fi

settings_line=$(grep -nF "set -g @pane-focus-enabled on" "$config" | cut -d: -f1)
plugin_line=$(grep -nF "set -g @plugin 'graemedavidson/tmux-pane-focus#v0.5.0-alpha'" "$config" | cut -d: -f1)
tpm_run_line=$(grep -nF "run '~/.tmux/plugins/tpm/tpm'" "$config" | cut -d: -f1)
attention_hook_line=$(grep -nF "set-hook -g after-select-pane[10]" "$config" | cut -d: -f1)
if [[ -n "$settings_line" && -n "$plugin_line" && -n "$tpm_run_line" ]]; then
  (( settings_line < plugin_line && plugin_line < tpm_run_line )) || \
    fail 'pane-focus settings and plugin must be declared before TPM initialization'
fi
if [[ -n "$tpm_run_line" && -n "$attention_hook_line" ]]; then
  (( tpm_run_line < attention_hook_line )) || \
    fail 'indexed pane-attention hook must be registered after pane-focus initializes'
fi

if [[ ! -x "$toggle" ]]; then
  fail 'pane-focus toggle helper is missing or not executable'
elif command -v tmux >/dev/null 2>&1; then
  tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/tmux-pane-focus.XXXXXX")
  socket_name="pane-focus-test-$$"
  real_tmux=$(command -v tmux)
  cleanup() {
    "$real_tmux" -L "$socket_name" kill-server >/dev/null 2>&1 || true
    rm -rf "$tmpdir"
  }
  trap cleanup EXIT

  cat >"$tmpdir/tmux" <<EOF
#!/bin/sh
exec "$real_tmux" -L "$socket_name" "\$@"
EOF
  chmod +x "$tmpdir/tmux"

  "$real_tmux" -L "$socket_name" -f /dev/null new-session -d -s focus-test -x 120 -y 30
  "$real_tmux" -L "$socket_name" split-window -h -t focus-test:0
  initial_layout=$("$real_tmux" -L "$socket_name" display-message -p -t focus-test:0 '#{window_layout}')

  PATH="$tmpdir:$PATH" HOME="$tmpdir" "$toggle" focus-test:0
  enabled=$("$real_tmux" -L "$socket_name" show-options -wqv -t focus-test:0 @pane-focus-enabled)
  saved_layout=$("$real_tmux" -L "$socket_name" show-options -wqv -t focus-test:0 @pane-focus-saved-layout)
  [[ "$enabled" == on ]] || fail 'toggle did not enable pane focus'
  [[ "$saved_layout" == "$initial_layout" ]] || fail 'toggle did not save the original layout'

  "$real_tmux" -L "$socket_name" select-layout -t focus-test:0 even-vertical >/dev/null
  PATH="$tmpdir:$PATH" HOME="$tmpdir" "$toggle" focus-test:0
  restored_layout=$("$real_tmux" -L "$socket_name" display-message -p -t focus-test:0 '#{window_layout}')
  enabled=$("$real_tmux" -L "$socket_name" show-options -wqv -t focus-test:0 @pane-focus-enabled)
  saved_layout=$("$real_tmux" -L "$socket_name" show-options -wqv -t focus-test:0 @pane-focus-saved-layout)
  [[ "$enabled" == off ]] || fail 'toggle did not disable pane focus'
  [[ "$restored_layout" == "$initial_layout" ]] || fail 'toggle did not restore the original layout'
  [[ -z "$saved_layout" ]] || fail 'toggle did not clear the saved layout after restore'

  PATH="$tmpdir:$PATH" HOME="$tmpdir" "$toggle" focus-test:0
  "$real_tmux" -L "$socket_name" split-window -v -t focus-test:0
  if ! PATH="$tmpdir:$PATH" HOME="$tmpdir" "$toggle" focus-test:0; then
    fail 'toggle did not fall back when pane topology changed'
  fi
  enabled=$("$real_tmux" -L "$socket_name" show-options -wqv -t focus-test:0 @pane-focus-enabled)
  [[ "$enabled" == off ]] || fail 'fallback did not disable pane focus'
fi

if (( failures > 0 )); then
  exit 1
fi

printf 'PASS: tmux-pane-focus\n'
