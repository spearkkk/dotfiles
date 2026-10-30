#!/bin/sh

[ "$#" -ge 3 ] || exit 64

bg=$1
fg=$2
border=$3
contexts=${4:-x}
contexts=${contexts#x}

style_text="#[fg=${fg},bg=${bg}]"
style_border="#[fg=${border},bg=${bg}]"
style_chip="#[fg=${bg},bg=${fg},bold]"
context_line=

if [ -n "$contexts" ]; then
  context_line="${style_chip} ${contexts} ${style_text}"
fi

printf '#[pop-default]%s%s %s│' "$style_text" "$context_line" "$style_border"
