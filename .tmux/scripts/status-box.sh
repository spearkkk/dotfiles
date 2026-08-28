#!/usr/bin/env bash
set -euo pipefail

mode="${1:-top}"
width="${2:-80}"
session="${3:-}"
window="${4:-}"
windows="${5:-}"
pane_id="${6:-}"
window_id="${7:-}"
client_prefix="${8:-0}"

[[ "$width" =~ ^[0-9]+$ ]] || width=80
(( width < 8 )) && width=8

bg="#1C3A50"
fg="#C6D8E4"
border="#4A6E86"
inactive_fg="${border}"
accent="#68BE92"
dark="#0A1F2E"
selected="${bg}"

tmux_option_value() {
  local scope="$1"
  local target="$2"
  local option="$3"

  [[ -z "$target" ]] && return
  tmux show-options "$scope" -v -t "$target" "$option" 2>/dev/null || true
}

is_prod_context() {
  local ctx="$1"
  local short="$ctx"

  [[ -z "$ctx" ]] && return 1

  if type kube_tmux_shorten_context >/dev/null 2>&1; then
    short="$(kube_tmux_shorten_context "$ctx")"
  fi

  type kube_tmux_is_prod >/dev/null 2>&1 && kube_tmux_is_prod "$short"
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

is_prod_aws_profile() {
  case "$1" in
    dragon-kks|dragon-ssk|fos-prod) return 0 ;;
    *) return 1 ;;
  esac
}

kube_context="$(tmux_option_value -p "$pane_id" @kube_context)"
if [[ -z "$kube_context" ]]; then
  kube_context="$(tmux_option_value -w "$window_id" @kube_context)"
fi

aws_profile="$(tmux_option_value -p "$pane_id" @aws_profile)"
if [[ -z "$aws_profile" ]]; then
  aws_profile="$(tmux_option_value -w "$window_id" @aws_profile)"
fi

# shellcheck disable=SC1091
[[ -f "$HOME/.tmux/config/kube-func.sh" ]] && source "$HOME/.tmux/config/kube-func.sh"

if is_prod_context "$kube_context" || is_prod_aws_profile "$aws_profile"; then
  bg="#C47A72"
  fg="#0A1F2E"
  border="#0A1F2E"
  inactive_fg="#1C3A50"
  selected="${bg}"
fi

if [[ "$client_prefix" == "1" ]]; then
  bg="#0A1F2E"
  fg="#C6D8E4"
  border="#C6D8E4"
  inactive_fg="#4A6E86"
  selected="${bg}"
fi

style_border="#[fg=${border},bg=${bg}]"
style_text="#[fg=${fg},bg=${bg}]"
style_inactive="#[fg=${inactive_fg},bg=${bg}]"
style_title="#[fg=${fg},bg=${bg},bold]"
style_current="#[fg=${fg},bg=${selected},bold]"
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

truncate_tail() {
  local value="$1"
  local max_width="$2"
  local len
  len="$(visible_len "$value")"

  if (( len <= max_width )); then
    printf '%s' "$value"
  elif (( max_width > 1 )); then
    printf '%s…' "${value:0:$((max_width - 1))}"
  fi
}

window_index_icon() {
  case "$1" in
    0) printf '#[underscore]0#[nounderscore]' ;;
    1) printf '#[underscore]1#[nounderscore]' ;;
    2) printf '#[underscore]2#[nounderscore]' ;;
    3) printf '#[underscore]3#[nounderscore]' ;;
    4) printf '#[underscore]4#[nounderscore]' ;;
    5) printf '#[underscore]5#[nounderscore]' ;;
    6) printf '#[underscore]6#[nounderscore]' ;;
    7) printf '#[underscore]7#[nounderscore]' ;;
    8) printf '#[underscore]8#[nounderscore]' ;;
    9) printf '#[underscore]9#[nounderscore]' ;;
    *) printf '%s' "$1" ;;
  esac
}

format_window_item() {
  local item="$1"
  local index name icon

  if [[ "$item" == *:* ]]; then
    index="${item%%:*}"
    name="${item#*:}"
    icon="$(window_index_icon "$index")"
    printf '[%s·%s]' "$icon" "$name"
  else
    printf '%s' "$item"
  fi
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
  middle)
    nav="${windows:-}"
    nav="${nav//, / }"
    nav="${nav%,}"
    nav="${nav%" "}"

    styled_nav=""
    for item in $nav; do
      if [[ "$item" == __CURRENT__* ]]; then
        item="${item#__CURRENT__}"
        item="$(format_window_item "$item")"
        styled_nav+="${style_current}${item}${style_text}"
      else
        item="$(format_window_item "$item")"
        styled_nav+="${style_inactive}${item}"
      fi
    done
    nav="${styled_nav}"

    context_line=""
    short_kube="$(short_kube_context "$kube_context")"
    [[ -n "$short_kube" ]] && context_line+="${style_chip} ${short_kube} ${style_text}"
    [[ -n "$aws_profile" ]] && context_line+="${style_chip} ${aws_profile} ${style_text}"

    inner_width=$((width - 4))
    (( inner_width < 1 )) && inner_width=1

    context_len="$(visible_len "$context_line")"
    nav_width=$((inner_width - context_len))
    if [[ -n "$context_line" ]]; then
      nav_width=$((nav_width - 1))
    fi
    (( nav_width < 1 )) && nav_width=1

    body="${style_text}${nav}"
    body="$(truncate_tail "$body" "$nav_width")"
    body_len="$(visible_len "$body")"
    pad_count=$((inner_width - body_len - context_len))
    (( pad_count < 0 )) && pad_count=0

    printf '%s│ %s%*s%s %s│' "$style_border" "$body" "$pad_count" '' "$context_line" "$style_border"
    ;;
  bottom)
    filler="$(printf '%*s' "$((width - 2))" '' | tr ' ' '─')"
    printf '%s╰%s╯' "$style_border" "$filler"
    ;;
  *)
    printf '%s' ""
    ;;
esac
