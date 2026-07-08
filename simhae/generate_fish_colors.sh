#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PALETTE_FILE="${1:-$ROOT_DIR/simhae/simhae-pelagic.yaml}"
OUT_FILE="${2:-$ROOT_DIR/.config/fish/conf.d/colors_generated.fish}"

if [ ! -f "$PALETTE_FILE" ]; then
  echo "Palette file not found: $PALETTE_FILE" >&2
  exit 1
fi

get_yaml_hex() {
  local section="$1"
  local key="$2"
  awk -v section="$section" -v key="$key" '
    BEGIN { in_section = 0 }
    $0 ~ "^" section ":[[:space:]]*$" { in_section = 1; next }
    in_section && $0 !~ /^  / { in_section = 0 }
    in_section && $1 == key ":" {
      v = $2
      gsub(/"/, "", v)
      gsub(/#/, "", v)
      print toupper(v)
      exit
    }
  ' "$PALETTE_FILE"
}

base00="$(get_yaml_hex colors base00)"
base01="$(get_yaml_hex colors base01)"
base02="$(get_yaml_hex colors base02)"
base03="$(get_yaml_hex colors base03)"
base04="$(get_yaml_hex colors base04)"
base05="$(get_yaml_hex colors base05)"
base06="$(get_yaml_hex colors base06)"
base07="$(get_yaml_hex colors base07)"
base08="$(get_yaml_hex colors base08)"
base09="$(get_yaml_hex colors base09)"
base0A="$(get_yaml_hex colors base0A)"
base0B="$(get_yaml_hex colors base0B)"
base0C="$(get_yaml_hex colors base0C)"
base0D="$(get_yaml_hex colors base0D)"
base0E="$(get_yaml_hex colors base0E)"
base0F="$(get_yaml_hex colors base0F)"
base10="$(get_yaml_hex colors base10)"
base11="$(get_yaml_hex colors base11)"
base12="$(get_yaml_hex colors base12)"
base13="$(get_yaml_hex colors base13)"
base14="$(get_yaml_hex colors base14)"
base15="$(get_yaml_hex colors base15)"
base16="$(get_yaml_hex colors base16)"
base17="$(get_yaml_hex colors base17)"

ext_background="$(get_yaml_hex extended background)"
ext_foreground="$(get_yaml_hex extended foreground)"
ext_muted="$(get_yaml_hex extended muted)"
ext_accent="$(get_yaml_hex extended accent)"
ext_error="$(get_yaml_hex extended error)"
ext_warning="$(get_yaml_hex extended warning)"
ext_success="$(get_yaml_hex extended success)"
ext_link="$(get_yaml_hex extended link)"
ext_info="$(get_yaml_hex extended info)"
ext_search_highlight="$(get_yaml_hex extended search_highlight)"

mkdir -p "$(dirname "$OUT_FILE")"

cat > "$OUT_FILE" <<EOF2
#!/usr/bin/env fish
# Generated from: ${PALETTE_FILE#$ROOT_DIR/}
# Do not edit manually. Regenerate with: simhae/generate_fish_colors.sh

set -gx BASE00 $base00
set -gx BASE01 $base01
set -gx BASE02 $base02
set -gx BASE03 $base03
set -gx BASE04 $base04
set -gx BASE05 $base05
set -gx BASE06 $base06
set -gx BASE07 $base07
set -gx BASE08 $base08
set -gx BASE09 $base09
set -gx BASE0A $base0A
set -gx BASE0B $base0B
set -gx BASE0C $base0C
set -gx BASE0D $base0D
set -gx BASE0E $base0E
set -gx BASE0F $base0F
set -gx BASE10 $base10
set -gx BASE11 $base11
set -gx BASE12 $base12
set -gx BASE13 $base13
set -gx BASE14 $base14
set -gx BASE15 $base15
set -gx BASE16 $base16
set -gx BASE17 $base17

set -gx COLOR_BG        ${ext_background:-$base00}
set -gx COLOR_BG_ALT    $base01
set -gx COLOR_FG        ${ext_foreground:-$base05}
set -gx COLOR_ACCENT    ${ext_accent:-$base0C}
set -gx COLOR_MUTED     ${ext_muted:-$base04}
set -gx COLOR_ERROR     ${ext_error:-$base08}
set -gx COLOR_WARN      ${ext_warning:-$base0A}
set -gx COLOR_SUCCESS   ${ext_success:-$base0B}
set -gx COLOR_LINK      ${ext_link:-$base0D}
set -gx COLOR_INFO      ${ext_info:-$base0C}
set -gx COLOR_HIGHLIGHT ${ext_search_highlight:-$base09}
EOF2

echo "Generated: $OUT_FILE"
