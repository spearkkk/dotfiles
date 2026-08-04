#!/usr/bin/env bash
# Full-width divider for status-format[0]: kube context on the left, pane
# divider characters filling the rest. Kept as a script (rather than an inline #() command)
# because tmux runs status-format strings through strftime first, which
# mangles a literal "%*s" in the config file.
#
# Turns red (both the context label and the dashes) when the context is a
# known-production cluster -- the name mapping and prod list are
# company-specific and live in ~/.tmux/config/kube-func.sh (work/ package
# only; gracefully does nothing on machines without it).
#
# Context comes only from this session's pinned @kube_context (tmux session
# option, $2 below -- passed in since #() commands don't inherit the pane's
# shell env, only the tmux server's). Pin one with:
#   tmux set-option -t <session> @kube_context <context-name>
# Do not call kubectl here: status-line commands must never trigger auth or
# block the UI on kubeconfig/network work.
# $3 is the tmux session name, shown on the right edge.
width="$1"
pinned_ctx="$2"
session="$3"

ctx="$pinned_ctx"

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
  # Whole line goes red bg / bold, with the normal status-bar bg (#142C3E)
  # as text color -- dark-on-red reads clearly as a single unmissable prod
  # warning strip, rather than trying to make individual chips pop.
  prod_style='#[bg=#C47A72,fg=#142C3E,bold]'
  label_style="$prod_style"
  dash_style="$prod_style"
  tail_style="$prod_style"
else
  label_style='#[fg=#C6D8E4]'
  dash_style='#[fg=#24425C]'
  tail_style='#[fg=#C6D8E4]'
fi

label=""
[[ -n "$short" ]] && label=" ${short} "

right_label=""
[[ -n "$session" ]] && right_label=" ${session} "

dash_count=$(( width - ${#label} - ${#right_label} ))
(( dash_count < 0 )) && dash_count=0
dashes=$(printf '%*s' "$dash_count" '' | tr ' ' '═')

printf '%s%s%s%s%s%s' "$label_style" "$label" "$dash_style" "$dashes" "$tail_style" "$right_label"
