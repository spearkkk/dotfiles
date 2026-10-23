#!/usr/bin/env bash
set -euo pipefail

mode="${1:-top}"
width="${2:-80}"
session="${3:-}"
pane_id="${4:-}"
window_id="${5:-}"
style_variant="${6:-normal}"

[[ "$width" =~ ^[0-9]+$ ]] || width=80
(( width < 8 )) && width=8

bg="#1C3A50"
fg="#C6D8E4"
border="#4A6E86"
inactive_fg="${border}"

case "$style_variant" in
  prod)
    bg="#C47A72"
    fg="#0A1F2E"
    border="#0A1F2E"
    inactive_fg="#1C3A50"
    ;;
  prefix)
    bg="#0A1F2E"
    fg="#C6D8E4"
    border="#C6D8E4"
    inactive_fg="#4A6E86"
    ;;
esac

tmux_option_value() {
  local scope="$1"
  local target="$2"
  local option="$3"

  [[ -z "$target" ]] && return
  tmux show-options "$scope" -v -t "$target" "$option" 2>/dev/null || true
}

short_kube_context() {
  local ctx="$1"

  [[ -z "$ctx" ]] && return
  if type kube_tmux_shorten_context >/dev/null 2>&1; then
    kube_tmux_shorten_context "$ctx"
  else
    printf '%s' "$ctx"
  fi
}

style_border="#[fg=${border},bg=${bg}]"
style_text="#[fg=${fg},bg=${bg}]"
style_inactive="#[fg=${inactive_fg},bg=${bg}]"
style_title="#[fg=${fg},bg=${bg},bold]"
style_chip="#[fg=${bg},bg=${fg},bold]"

strip_styles() {
  local value="$1"
  while [[ "$value" == *'#['*']'* ]]; do
    if [[ "$value" =~ (.*)#\[[^]]*\](.*) ]]; then
      value="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    else
      break
    fi
  done
  printf '%s' "$value"
}

visible_len() {
  local value
  value="$(strip_styles "$1")"
  printf '%s' "${#value}"
}

pad_line() {
  local left="$1"
  local right="$2"
  local fill="$3"
  local left_len right_len fill_count

  left_len="$(visible_len "$left")"
  right_len="$(visible_len "$right")"
  fill_count=$((width - left_len - right_len))
  (( fill_count < 0 )) && fill_count=0

  local filler
  filler="$(printf '%*s' "$fill_count" '' | tr ' ' "$fill")"
  printf '%s%s%s%s' "$left" "$style_border" "$filler" "$right"
}

case "$mode" in
  spacer)
    printf '#[bg=#0A1F2E]%*s' "$width" ''
    ;;
  top)
    title="${session:-tmux}"
    left="${style_border}╭─ ${style_title}${title} ${style_border}"
    right="${style_border}╮"
    pad_line "$left" "$right" "─"
    ;;
  middle-left)
    printf '%s│ %s#[push-default]' "$style_border" "$style_inactive"
    ;;
  middle-right)
    kube_context="$(tmux_option_value -p "$pane_id" @kube_context)"
    if [[ -z "$kube_context" ]]; then
      kube_context="$(tmux_option_value -w "$window_id" @kube_context)"
    fi
    aws_profile="$(tmux_option_value -p "$pane_id" @aws_profile)"
    if [[ -z "$aws_profile" ]]; then
      aws_profile="$(tmux_option_value -w "$window_id" @aws_profile)"
    fi
    cw_context="$(tmux_option_value -p "$pane_id" @cw_context)"
    if [[ -z "$cw_context" ]]; then
      cw_context="$(tmux_option_value -w "$window_id" @cw_context)"
    fi
    # shellcheck disable=SC1091
    [[ -f "$HOME/.tmux/config/kube-func.sh" ]] && source "$HOME/.tmux/config/kube-func.sh"

    context_line=""
    if [[ -n "$cw_context" ]]; then
      context_line+="${style_chip} ${cw_context} ${style_text}"
    else
      short_kube="$(short_kube_context "$kube_context")"
      [[ -n "$short_kube" ]] && context_line+="${style_chip} ${short_kube} ${style_text}"
      [[ -n "$aws_profile" ]] && context_line+="${style_chip} ${aws_profile} ${style_text}"
    fi
    printf '#[pop-default]%s%s %s│' "$style_text" "$context_line" "$style_border"
    ;;
  bottom)
    filler="$(printf '%*s' "$((width - 2))" '' | tr ' ' '─')"
    printf '%s╰%s╯' "$style_border" "$filler"
    ;;
  *)
    printf '%s' ""
    ;;
esac
