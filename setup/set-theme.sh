#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PALETTE_FILE="${1:-$LAYOUT_ROOT/share/themes/simhae/palette.yaml}"
FISH_OUT="${2:-$LAYOUT_ROOT/home/.config/fish/conf.d/0010-theme-colors.fish}"
GHOSTTY_OUT="$LAYOUT_ROOT/home/.config/ghostty/themes/simhae.ghostty"
SKETCHYBAR_OUT="$LAYOUT_ROOT/home/.config/sketchybar/lib/colors.lua"
HAMMERSPOON_OUT="$LAYOUT_ROOT/home/.hammerspoon/lib/theme.lua"
BTOP_OUT="$LAYOUT_ROOT/home/.config/btop/themes/simhae.theme"
K9S_OUT="$LAYOUT_ROOT/home/.config/k9s/skins/simhae.yaml"
NVIM_PALETTE_OUT="$LAYOUT_ROOT/home/.config/nvim/lua/config/theme/simhae_palette.lua"

if [ ! -f "$PALETTE_FILE" ]; then
  echo "Palette file not found: $PALETTE_FILE" >&2
  exit 1
fi

yaml_value() {
  local key="$1"

  awk -v key="$key" '
    $1 == key ":" {
      value = $2
      gsub(/"/, "", value)
      print value
      exit
    }
  ' "$PALETTE_FILE"
}

yaml_palette_hex() {
  local palette="$1"
  local key="$2"

  awk -v palette="$palette" -v key="$key" '
    BEGIN {
      in_palettes = 0
      in_palette = 0
    }

    /^palettes:[[:space:]]*$/ {
      in_palettes = 1
      next
    }

    in_palettes && $0 ~ "^  " palette ":[[:space:]]*$" {
      in_palette = 1
      next
    }

    in_palette && $0 ~ /^  [^[:space:]][^:]*:[[:space:]]*$/ {
      in_palette = 0
    }

    in_palette && $1 == key ":" {
      value = $2
      gsub(/"/, "", value)
      gsub(/#/, "", value)
      print toupper(value)
      exit
    }
  ' "$PALETTE_FILE"
}

require_hex() {
  local name="$1"
  local value="$2"

  if [ -z "$value" ]; then
    echo "Missing color value: $name" >&2
    exit 1
  fi

  printf '%s\n' "$value"
}

with_hash() {
  printf '#%s\n' "$1"
}

with_sketchybar_alpha() {
  printf '0xFF%s\n' "$1"
}

main_palette="$(yaml_value main)"
if [ -z "$main_palette" ]; then
  echo "Missing main palette in: $PALETTE_FILE" >&2
  exit 1
fi

base00="$(require_hex base00 "$(yaml_palette_hex "$main_palette" base00)")"
base01="$(require_hex base01 "$(yaml_palette_hex "$main_palette" base01)")"
base02="$(require_hex base02 "$(yaml_palette_hex "$main_palette" base02)")"
base03="$(require_hex base03 "$(yaml_palette_hex "$main_palette" base03)")"
base04="$(require_hex base04 "$(yaml_palette_hex "$main_palette" base04)")"
base05="$(require_hex base05 "$(yaml_palette_hex "$main_palette" base05)")"
base06="$(require_hex base06 "$(yaml_palette_hex "$main_palette" base06)")"
base07="$(require_hex base07 "$(yaml_palette_hex "$main_palette" base07)")"
base08="$(require_hex base08 "$(yaml_palette_hex "$main_palette" base08)")"
base09="$(require_hex base09 "$(yaml_palette_hex "$main_palette" base09)")"
base0A="$(require_hex base0A "$(yaml_palette_hex "$main_palette" base0A)")"
base0B="$(require_hex base0B "$(yaml_palette_hex "$main_palette" base0B)")"
base0C="$(require_hex base0C "$(yaml_palette_hex "$main_palette" base0C)")"
base0D="$(require_hex base0D "$(yaml_palette_hex "$main_palette" base0D)")"
base0E="$(require_hex base0E "$(yaml_palette_hex "$main_palette" base0E)")"
base0F="$(require_hex base0F "$(yaml_palette_hex "$main_palette" base0F)")"
base10="$(require_hex base10 "$(yaml_palette_hex "$main_palette" base10)")"
base11="$(require_hex base11 "$(yaml_palette_hex "$main_palette" base11)")"
base12="$(require_hex base12 "$(yaml_palette_hex "$main_palette" base12)")"
base13="$(require_hex base13 "$(yaml_palette_hex "$main_palette" base13)")"
base14="$(require_hex base14 "$(yaml_palette_hex "$main_palette" base14)")"
base15="$(require_hex base15 "$(yaml_palette_hex "$main_palette" base15)")"
base16="$(require_hex base16 "$(yaml_palette_hex "$main_palette" base16)")"
base17="$(require_hex base17 "$(yaml_palette_hex "$main_palette" base17)")"

roles_file="$(mktemp)"
trap 'rm -f "$roles_file"' EXIT

add_role() {
  local group="$1"
  local role="$2"
  local value="$3"

  printf '%s|%s|%s\n' "$group" "$role" "$value" >> "$roles_file"
}

# Core
add_role "Core" "BG" "$base00"
add_role "Core" "BG_ALT" "$base01"
add_role "Core" "FG" "$base05"
add_role "Core" "ACCENT" "$base0C"
add_role "Core" "MUTED" "$base04"

# Surfaces
add_role "Surfaces" "BG_DEEP" "$base10"
add_role "Surfaces" "SURFACE" "$base01"
add_role "Surfaces" "SURFACE_ALT" "$base02"
add_role "Surfaces" "SURFACE_SELECTED" "$base02"
add_role "Surfaces" "OVERLAY" "$base10"
add_role "Surfaces" "BORDER" "$base03"
add_role "Surfaces" "BORDER_STRONG" "$base04"

# Text
add_role "Text" "FG_MUTED" "$base04"
add_role "Text" "FG_SUBTLE" "$base03"
add_role "Text" "FG_STRONG" "$base06"
add_role "Text" "FG_INVERSE" "$base00"
add_role "Text" "FG_DISABLED" "$base03"

# Intent / Status
add_role "Intent / Status" "PRIMARY" "$base0D"
add_role "Intent / Status" "SECONDARY" "$base0E"
add_role "Intent / Status" "INFO" "$base0C"
add_role "Intent / Status" "SUCCESS" "$base0B"
add_role "Intent / Status" "WARN" "$base0A"
add_role "Intent / Status" "ERROR" "$base08"
add_role "Intent / Status" "PENDING" "$base09"
add_role "Intent / Status" "ATTENTION" "$base12"
add_role "Intent / Status" "SPECIAL" "$base0E"
add_role "Intent / Status" "DEPRECATED" "$base0F"

# Interactive UI
add_role "Interactive UI" "LINK" "$base0D"
add_role "Interactive UI" "LINK_VISITED" "$base0E"
add_role "Interactive UI" "CURSOR" "$base06"
add_role "Interactive UI" "SELECTION_BG" "$base02"
add_role "Interactive UI" "SELECTION_FG" "$base07"
add_role "Interactive UI" "SEARCH_BG" "$base09"
add_role "Interactive UI" "SEARCH_FG" "$base00"
add_role "Interactive UI" "MATCH" "$base0A"
add_role "Interactive UI" "FOCUS" "$base0E"

# Diff / Git
add_role "Diff / Git" "ADDED" "$base0B"
add_role "Diff / Git" "ADDED_BRIGHT" "$base14"
add_role "Diff / Git" "MODIFIED" "$base0A"
add_role "Diff / Git" "MODIFIED_BRIGHT" "$base13"
add_role "Diff / Git" "REMOVED" "$base08"
add_role "Diff / Git" "REMOVED_BRIGHT" "$base11"
add_role "Diff / Git" "CONFLICT" "$base0E"
add_role "Diff / Git" "UNTRACKED" "$base0C"
add_role "Diff / Git" "IGNORED" "$base04"

# Syntax
add_role "Syntax" "SYNTAX_COMMENT" "$base04"
add_role "Syntax" "SYNTAX_STRING" "$base0B"
add_role "Syntax" "SYNTAX_NUMBER" "$base09"
add_role "Syntax" "SYNTAX_KEYWORD" "$base0E"
add_role "Syntax" "SYNTAX_FUNCTION" "$base0D"
add_role "Syntax" "SYNTAX_TYPE" "$base0A"
add_role "Syntax" "SYNTAX_CONSTANT" "$base09"
add_role "Syntax" "SYNTAX_OPERATOR" "$base0C"
add_role "Syntax" "SYNTAX_PROPERTY" "$base0D"
add_role "Syntax" "SYNTAX_VARIABLE" "$base05"

# ANSI
add_role "ANSI" "BLACK" "$base00"
add_role "ANSI" "RED" "$base08"
add_role "ANSI" "GREEN" "$base0B"
add_role "ANSI" "YELLOW" "$base0A"
add_role "ANSI" "BLUE" "$base0D"
add_role "ANSI" "MAGENTA" "$base0E"
add_role "ANSI" "CYAN" "$base0C"
add_role "ANSI" "WHITE" "$base05"

# Bright ANSI
add_role "Bright ANSI" "BRIGHT_BLACK" "$base03"
add_role "Bright ANSI" "BRIGHT_RED" "$base11"
add_role "Bright ANSI" "BRIGHT_GREEN" "$base14"
add_role "Bright ANSI" "BRIGHT_YELLOW" "$base13"
add_role "Bright ANSI" "BRIGHT_BLUE" "$base16"
add_role "Bright ANSI" "BRIGHT_MAGENTA" "$base17"
add_role "Bright ANSI" "BRIGHT_CYAN" "$base15"
add_role "Bright ANSI" "BRIGHT_WHITE" "$base07"

mkdir -p "$(dirname "$FISH_OUT")"
{
  cat <<EOF_FISH
#!/usr/bin/env fish
# Generated from: ${PALETTE_FILE#$LAYOUT_ROOT/}
# Main palette: $main_palette
# Do not edit manually. Regenerate with: setup/set-theme.sh

EOF_FISH

  awk -F '|' '
    BEGIN { previous_group = "" }
    {
      group = $1
      role = $2
      value = $3

      if (group != previous_group) {
        if (previous_group != "") {
          print ""
        }

        print "# " group
        previous_group = group
      }

      printf "set -gx __COLOR_%-20s %s\n", role, value
    }
  ' "$roles_file"
} > "$FISH_OUT"

echo "Generated: $FISH_OUT"

mkdir -p "$(dirname "$GHOSTTY_OUT")"
cat > "$GHOSTTY_OUT" <<EOF_GHOSTTY
# simhae theme
# Generated from: ${PALETTE_FILE#$LAYOUT_ROOT/}
# Main palette: $main_palette
# Do not edit manually. Regenerate with: setup/set-theme.sh

background = #$base00
foreground = #$base05
cursor-color = #$base06
selection-background = #$base0C
selection-foreground = #$base00
unfocused-split-fill = "#$base01"
split-divider-color = "#$base03"

palette = 0=#$base00
palette = 1=#$base08
palette = 2=#$base0B
palette = 3=#$base0A
palette = 4=#$base0D
palette = 5=#$base0E
palette = 6=#$base0C
palette = 7=#$base05
palette = 8=#$base03
palette = 9=#$base11
palette = 10=#$base14
palette = 11=#$base13
palette = 12=#$base16
palette = 13=#$base17
palette = 14=#$base15
palette = 15=#$base07
EOF_GHOSTTY

echo "Generated: $GHOSTTY_OUT"

mkdir -p "$(dirname "$SKETCHYBAR_OUT")"
cat > "$SKETCHYBAR_OUT" <<EOF_SKETCHYBAR
-- Generated from: ${PALETTE_FILE#$LAYOUT_ROOT/}
-- Main palette: $main_palette
-- Do not edit manually. Regenerate with: setup/set-theme.sh

local M = {}

M.base00 = "$(with_sketchybar_alpha "$base00")"
M.base01 = "$(with_sketchybar_alpha "$base01")"
M.base02 = "$(with_sketchybar_alpha "$base02")"
M.base03 = "$(with_sketchybar_alpha "$base03")"
M.base04 = "$(with_sketchybar_alpha "$base04")"
M.base05 = "$(with_sketchybar_alpha "$base05")"
M.base06 = "$(with_sketchybar_alpha "$base06")"
M.base07 = "$(with_sketchybar_alpha "$base07")"
M.base08 = "$(with_sketchybar_alpha "$base08")"
M.base09 = "$(with_sketchybar_alpha "$base09")"
M.base0a = "$(with_sketchybar_alpha "$base0A")"
M.base0b = "$(with_sketchybar_alpha "$base0B")"
M.base0c = "$(with_sketchybar_alpha "$base0C")"
M.base0d = "$(with_sketchybar_alpha "$base0D")"
M.base0e = "$(with_sketchybar_alpha "$base0E")"
M.base0f = "$(with_sketchybar_alpha "$base0F")"
M.base10 = "$(with_sketchybar_alpha "$base10")"
M.base11 = "$(with_sketchybar_alpha "$base11")"
M.base12 = "$(with_sketchybar_alpha "$base12")"
M.base13 = "$(with_sketchybar_alpha "$base13")"
M.base14 = "$(with_sketchybar_alpha "$base14")"
M.base15 = "$(with_sketchybar_alpha "$base15")"
M.base16 = "$(with_sketchybar_alpha "$base16")"
M.base17 = "$(with_sketchybar_alpha "$base17")"

M.background     = M.base00
M.background_alt = M.base01
M.foreground     = M.base05
M.accent         = M.base0c
M.border         = M.base03
M.bar_border     = M.base00

return M
EOF_SKETCHYBAR

echo "Generated: $SKETCHYBAR_OUT"

mkdir -p "$(dirname "$HAMMERSPOON_OUT")"
cat > "$HAMMERSPOON_OUT" <<EOF_HAMMERSPOON
-- Generated from: ${PALETTE_FILE#$LAYOUT_ROOT/}
-- Main palette: $main_palette
-- Do not edit manually. Regenerate with: setup/set-theme.sh

local M = {}

M.colors = {
  bg = { hex = "#$base00", alpha = 1 },
  surface = { hex = "#$base01", alpha = 1 },
  surface_alt = { hex = "#$base02", alpha = 1 },
  fg = { hex = "#$base05", alpha = 1 },
  muted = { hex = "#$base04", alpha = 1 },
  accent = { hex = "#$base0C", alpha = 1 },
  warn = { hex = "#$base0A", alpha = 1 },
  error = { hex = "#$base08", alpha = 1 },
}

M.aerospace_alt_tab = {
  background = M.colors.surface,
  border = { hex = M.colors.muted.hex, alpha = 0.90 },
  icon = M.colors.warn,
  text = M.colors.fg,
  empty = M.colors.muted,
  selected = { hex = M.colors.warn.hex, alpha = 0.22 },
}

M.inactive_display_dim = {
  overlay = { hex = M.colors.muted.hex, alpha = 0.45 },
}

return M
EOF_HAMMERSPOON

echo "Generated: $HAMMERSPOON_OUT"

mkdir -p "$(dirname "$BTOP_OUT")"
cat > "$BTOP_OUT" <<EOF_BTOP
# Theme: Simhae
# Generated from: ${PALETTE_FILE#$LAYOUT_ROOT/}
# Main palette: $main_palette
# Do not edit manually. Regenerate with: setup/set-theme.sh

theme[main_bg]="#$base00"
theme[main_fg]="#$base05"
theme[title]="#$base06"
theme[hi_fg]="#$base0C"
theme[selected_bg]="#$base02"
theme[selected_fg]="#$base07"
theme[inactive_fg]="#$base04"
theme[proc_misc]="#$base0D"
theme[cpu_box]="#$base03"
theme[mem_box]="#$base03"
theme[net_box]="#$base03"
theme[proc_box]="#$base03"
theme[div_line]="#$base03"
theme[temp_start]="#$base0B"
theme[temp_mid]="#$base0A"
theme[temp_end]="#$base08"
theme[cpu_start]="#$base0B"
theme[cpu_mid]="#$base0A"
theme[cpu_end]="#$base08"
theme[free_start]="#$base14"
theme[free_mid]="#$base0A"
theme[free_end]="#$base08"
theme[cached_start]="#$base0C"
theme[cached_mid]="#$base0D"
theme[cached_end]="#$base0E"
theme[available_start]="#$base0C"
theme[available_mid]="#$base0B"
theme[available_end]="#$base0A"
theme[used_start]="#$base0A"
theme[used_mid]="#$base09"
theme[used_end]="#$base08"
theme[download_start]="#$base0C"
theme[download_mid]="#$base0D"
theme[download_end]="#$base0E"
theme[upload_start]="#$base0B"
theme[upload_mid]="#$base0A"
theme[upload_end]="#$base08"
EOF_BTOP

echo "Generated: $BTOP_OUT"

mkdir -p "$(dirname "$K9S_OUT")"
cat > "$K9S_OUT" <<EOF_K9S
# Generated from: ${PALETTE_FILE#$LAYOUT_ROOT/}
# Main palette: $main_palette
# Do not edit manually. Regenerate with: setup/set-theme.sh

k9s:
  body:
    fgColor: "#$base05"
    bgColor: "#$base00"
    logoColor: "#$base0D"
  prompt:
    fgColor: "#$base05"
    bgColor: "#$base01"
    suggestColor: "#$base0C"
  help:
    fgColor: "#$base05"
    bgColor: "#$base00"
    indicator:
      fgColor: "#$base00"
      bgColor: "#$base0A"
  frame:
    title:
      fgColor: "#$base05"
      bgColor: "#$base00"
      highlightColor: "#$base0A"
      counterColor: "#$base0D"
      filterColor: "#$base0B"
    border:
      fgColor: "#$base04"
      focusColor: "#$base0A"
    menu:
      fgColor: "#$base05"
      keyColor: "#$base0A"
      numKeyColor: "#$base0C"
    crumbs:
      fgColor: "#$base05"
      bgColor: "#$base01"
      activeColor: "#$base0B"
    status:
      newColor: "#$base0D"
      modifyColor: "#$base0A"
      addColor: "#$base0B"
      errorColor: "#$base08"
      highlightcolor: "#$base0A"
      killColor: "#$base0E"
      completedColor: "#$base04"
  views:
    charts:
      bgColor: "#$base00"
      chartBgColor: "#$base01"
      dialBgColor: "#$base01"
      defaultDialColors:
        - "#$base0E"
        - "#$base09"
      defaultChartColors:
        - "#$base0E"
        - "#$base09"
      resourceColors:
        cpu:
          - "#$base0D"
          - "#$base0A"
        mem:
          - "#$base0C"
          - "#$base0E"
    table:
      fgColor: "#$base05"
      bgColor: "#$base00"
      cursorFgColor: "#$base00"
      cursorBgColor: "#$base0A"
      markColor: "#$base0A"
      header:
        fgColor: "#$base05"
        bgColor: "#$base01"
        sorterColor: "#$base0B"
    xray:
      fgColor: "#$base05"
      bgColor: "#$base00"
      cursorColor: "#$base0A"
      cursorTextColor: "#$base00"
    yaml:
      keyColor: "#$base0D"
      colonColor: "#$base04"
      valueColor: "#$base05"
EOF_K9S

echo "Generated: $K9S_OUT"

mkdir -p "$(dirname "$NVIM_PALETTE_OUT")"
awk -v main="$main_palette" -v source="${PALETTE_FILE#$LAYOUT_ROOT/}" '
  BEGIN {
    print "-- Generated from: " source
    print "-- Main palette: " main
    print "-- Do not edit manually. Regenerate with: setup/set-theme.sh"
    print ""
    print "local M = {}"
    print ""
    print "M.main = \"" main "\""
    print "M.palettes = {"
    in_palettes = 0
    in_palette = 0
    count = 0
  }

  /^palettes:[[:space:]]*$/ {
    in_palettes = 1
    next
  }

  in_palettes && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
    if (in_palette) {
      print "  },"
    }
    palette = $1
    sub(/:/, "", palette)
    print "  " palette " = {"
    in_palette = 1
    count++
    next
  }

  in_palette && $1 ~ /^base[0-9A-Fa-f]+:$/ {
    key = $1
    sub(/:/, "", key)
    value = $2
    gsub(/\"/, "", value)
    printf "    %s = \"%s\",\n", key, value
  }

  END {
    if (in_palette) {
      print "  },"
    }
    print "}"
    print ""
    print "return M"
  }
' "$PALETTE_FILE" > "$NVIM_PALETTE_OUT"

echo "Generated: $NVIM_PALETTE_OUT"
