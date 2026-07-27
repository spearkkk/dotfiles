#!/usr/bin/env bash
# Full-width divider for status-format[0]: kube context on the left, dashes
# filling the rest. Kept as a script (rather than an inline #() command)
# because tmux runs status-format strings through strftime first, which
# mangles a literal "%*s" in the config file.
#
# Turns red (both the context label and the dashes) when the context is a
# known-production cluster -- the name mapping and prod list are
# company-specific and live in ~/.tmux/config/kube-func.sh (work/ package
# only; gracefully does nothing on machines without it).
#
# Context resolution order:
#   1. This session's pinned @kube_context (tmux session option, $2 below --
#      passed in since #() commands don't inherit the pane's shell env, only
#      the tmux server's). Pin one with:
#        tmux set-option -t <session> @kube_context <context-name>
#   2. Fall back to whatever `kubectl config view` reports as current-context
#      (machine-wide, not session-specific).
# $3 is the tmux session name, shown on the right edge.
width="$1"
pinned_ctx="$2"
session="$3"

if [[ -n "$pinned_ctx" ]]; then
  ctx="$pinned_ctx"
else
  ctx=$(kubectl config view --minify -o jsonpath='{.current-context}' 2>/dev/null)
fi

# shellcheck disable=SC1091
[[ -f "$HOME/.tmux/config/kube-func.sh" ]] && source "$HOME/.tmux/config/kube-func.sh"

short="$ctx"
if [[ -n "$ctx" ]] && type kube_tmux_shorten_context >/dev/null 2>&1; then
  short=$(kube_tmux_shorten_context "$ctx")
fi

is_prod=false
if [[ -n "$short" ]] && type kube_tmux_is_prod >/dev/null 2>&1 && kube_tmux_is_prod "$short"; then
  is_prod=true
fi

if $is_prod; then
  label_style='#[bg=#C47A72,fg=#ECF0F4]'
  # tmux styles carry over -- explicitly restore bg here, otherwise the
  # dashes inherit the label's red bg instead of just getting a red fg.
  dash_style='#[bg=#142C3E,fg=#C47A72]'
else
  label_style='#[fg=#C6D8E4]'
  dash_style='#[fg=#4A6E86]'
fi

label=""
[[ -n "$short" ]] && label=" ${short} "

right_label=""
[[ -n "$session" ]] && right_label=" ${session} "

dash_count=$(( width - ${#label} - ${#right_label} ))
(( dash_count < 0 )) && dash_count=0
dashes=$(printf '%*s' "$dash_count" '' | tr ' ' '-')

printf '%s%s%s%s#[fg=#C6D8E4]%s' "$label_style" "$label" "$dash_style" "$dashes" "$right_label"
