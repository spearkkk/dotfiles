#!/usr/bin/env bash

set -u

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config="$repo_root/home/.tmux.conf"
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
assert_line "set -g @pane-focus-enabled on"
assert_line "set -g @pane-focus-size '80'"
assert_line "set -g @pane-focus-direction '+'"
assert_line "set -g @plugin 'graemedavidson/tmux-pane-focus#v0.5.0-alpha'"

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

if (( failures > 0 )); then
  exit 1
fi

printf 'PASS: tmux-pane-focus\n'
