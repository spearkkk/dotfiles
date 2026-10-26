#!/bin/sh

[ "$#" -ge 3 ] || exit 64

bg=$1
fg=$2
border=$3
kube_context=${4:-x}
aws_profile=${5:-x}
cw_context=${6:-x}
kube_context=${kube_context#x}
aws_profile=${aws_profile#x}
cw_context=${cw_context#x}

style_text="#[fg=${fg},bg=${bg}]"
style_border="#[fg=${border},bg=${bg}]"
style_chip="#[fg=${bg},bg=${fg},bold]"
context_line=

if [ -n "$cw_context" ]; then
  context_line="${style_chip} ${cw_context} ${style_text}"
else
  if [ -n "$kube_context" ] && [ -f "$HOME/.tmux/config/kube-func.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.tmux/config/kube-func.sh"
  fi
  if [ -n "$kube_context" ]; then
    if command -v kube_tmux_shorten_context >/dev/null 2>&1; then
      kube_context=$(kube_tmux_shorten_context "$kube_context")
    fi
    context_line="${style_chip} ${kube_context} ${style_text}"
  fi
  if [ -n "$aws_profile" ]; then
    context_line="${context_line}${style_chip} ${aws_profile} ${style_text}"
  fi
fi

printf '#[pop-default]%s%s %s│' "$style_text" "$context_line" "$style_border"
