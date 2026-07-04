export BASE00=0xFF282828
export BASE01=0xFF32302F
export BASE02=0xFF45403D
export BASE03=0xFF5A524C
export BASE04=0xFF7C6F64
export BASE05=0xFFD4BE98
export BASE06=0xFFDDC7A1
export BASE07=0xFFEBDBB2
export BASE08=0xFFEA6962
export BASE09=0xFFE78A4E
export BASE0A=0xFFD8A657
export BASE0B=0xFFA9B665
export BASE0C=0xFF89B482
export BASE0D=0xFF7DAEA3
export BASE0E=0xFFD3869B
export BASE0F=0xFFA89984
export BASE10=0xFF1B1B1B
export BASE11=0xFF141617
export BASE12=0xFFEA6962
export BASE13=0xFFD8A657
export BASE14=0xFFA9B665
export BASE15=0xFF89B482
export BASE16=0xFF7DAEA3
export BASE17=0xFFD3869B

# === Base Colors ===
export BACKGROUND_DARKEST=$BASE00
# BASE01 is predefined
export BACKGROUND_DARK=$BASE02
export BACKGROUND_LIGHT=$BASE03

export ACCENT_PRIMARY=$BASE0C
export TEXT_DEFAULT=$BASE05
export TEXT_LIGHT=$BASE06
export TEXT_LIGHTEST=$BASE07

# === Standard Base16 Color Roles ===
export RED=$BASE08
export ORANGE=$BASE09
export YELLOW=$BASE0A
export GREEN=$BASE0B
export CYAN=$BASE0C
export BLUE=$BASE0D
export MAGENTA=$BASE0E
export PINK=$BASE0F

# === UI Layers ===
export LAYER_1=$BASE10
export LAYER_2=$BASE11

# === Bright Colors ===
export BRIGHT_RED=$BASE12
export BRIGHT_YELLOW=$BASE13
export BRIGHT_GREEN=$BASE14
export BRIGHT_CYAN=$BASE15
export BRIGHT_BLUE=$BASE16
export BRIGHT_MAGENTA=$BASE17

# === ANSI Standard Bindings ===
export BLACK=$BASE01
export WHITE=$BASE05
export BRIGHT_BLACK=$BASE03
export BRIGHT_WHITE=$BASE07

set_alpha() {
  local hex="$1"
  local percent="$2"

  # clamp percent between 0~100
  if [ "$percent" -lt 0 ]; then percent=0; fi
  if [ "$percent" -gt 100 ]; then percent=100; fi

  # strip prefix
  hex="${hex#\#}"
  hex="${hex#0x}"

  # if length is 8, remove existing alpha (assume AARRGGBB or RRGGBBAA)
  if [ "${#hex}" -eq 8 ]; then
    hex="${hex: -6}"  # keep last 6 chars
  fi

  # upper case
  hex=$(echo "$hex" | tr '[:lower:]' '[:upper:]')

  # compute alpha
  local a_int=$(printf "%.0f" "$(echo "$percent * 2.55" | bc -l)")
  local alpha_hex=$(printf "%02X" "$a_int")

  echo "0x${alpha_hex}${hex}"
}
