#!/bin/zsh

API_KEY="73a4c1b756384c228e9142307250307" # insert api key here
CITY="$(curl -s ipinfo.io/loc)" # get current location coordinates

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

# Weather icon maps (SF Symbol names)
weather_icons_day=(
  [1000]="sun.max.fill"
  [1003]="cloud.sun.fill"
  [1006]="cloud.fill"
  [1009]="cloud.fill"
  [1030]="cloud.fog.fill"
  [1063]="cloud.drizzle.fill"
  [1066]="cloud.snow.fill"
  [1069]="cloud.sleet.fill"
  [1072]="cloud.drizzle.fill"
  [1087]="cloud.bolt.fill"
  [1114]="cloud.snow.fill"
  [1117]="wind.snow"
  [1135]="cloud.fog.fill"
  [1147]="cloud.fog.fill"
  [1150]="cloud.drizzle.fill"
  [1153]="cloud.drizzle.fill"
  [1168]="cloud.drizzle.fill"
  [1171]="cloud.drizzle.fill"
  [1180]="cloud.rain.fill"
  [1183]="cloud.rain.fill"
  [1186]="cloud.rain.fill"
  [1189]="cloud.heavyrain.fill"
  [1192]="cloud.heavyrain.fill"
  [1195]="cloud.heavyrain.fill"
  [1198]="cloud.rain.fill"
  [1201]="cloud.heavyrain.fill"
  [1204]="cloud.sleet.fill"
  [1207]="cloud.sleet.fill"
  [1210]="cloud.snow.fill"
  [1213]="cloud.snow.fill"
  [1216]="cloud.snow.fill"
  [1219]="cloud.snow.fill"
  [1222]="cloud.snow.fill"
  [1225]="cloud.snow.fill"
  [1237]="cloud.hail.fill"
  [1240]="cloud.sun.rain.fill"
  [1243]="cloud.sun.rain.fill"
  [1246]="cloud.sun.rain.fill"
  [1249]="cloud.sleet.fill"
  [1252]="cloud.sleet.fill"
  [1255]="cloud.snow.fill"
  [1258]="cloud.snow.fill"
  [1261]="cloud.hail.fill"
  [1264]="cloud.hail.fill"
  [1273]="cloud.bolt.rain.fill"
  [1276]="cloud.bolt.rain.fill"
  [1279]="cloud.snow.fill"
  [1282]="cloud.snow.fill"
)

weather_icons_night=(
  [1000]="moon.stars.fill"
  [1003]="cloud.moon.fill"
  [1006]="cloud.fill"
  [1009]="cloud.fill"
  [1030]="cloud.fog.fill"
  [1063]="cloud.moon.rain.fill"
  [1066]="cloud.snow.fill"
  [1069]="cloud.sleet.fill"
  [1072]="cloud.moon.rain.fill"
  [1087]="cloud.bolt.fill"
  [1114]="cloud.snow.fill"
  [1117]="wind.snow"
  [1135]="cloud.fog.fill"
  [1147]="cloud.fog.fill"
  [1150]="cloud.moon.rain.fill"
  [1153]="cloud.moon.rain.fill"
  [1168]="cloud.moon.rain.fill"
  [1171]="cloud.moon.rain.fill"
  [1180]="cloud.moon.rain.fill"
  [1183]="cloud.moon.rain.fill"
  [1186]="cloud.moon.rain.fill"
  [1189]="cloud.moon.rain.fill"
  [1192]="cloud.moon.rain.fill"
  [1195]="cloud.moon.rain.fill"
  [1198]="cloud.moon.rain.fill"
  [1201]="cloud.moon.rain.fill"
  [1204]="cloud.sleet.fill"
  [1207]="cloud.sleet.fill"
  [1210]="cloud.snow.fill"
  [1213]="cloud.snow.fill"
  [1216]="cloud.snow.fill"
  [1219]="cloud.snow.fill"
  [1222]="cloud.snow.fill"
  [1225]="cloud.snow.fill"
  [1237]="cloud.hail.fill"
  [1240]="cloud.moon.rain.fill"
  [1243]="cloud.moon.rain.fill"
  [1246]="cloud.moon.rain.fill"
  [1249]="cloud.sleet.fill"
  [1252]="cloud.sleet.fill"
  [1255]="cloud.snow.fill"
  [1258]="cloud.snow.fill"
  [1261]="cloud.hail.fill"
  [1264]="cloud.hail.fill"
  [1273]="cloud.bolt.rain.fill"
  [1276]="cloud.bolt.rain.fill"
  [1279]="cloud.snow.fill"
  [1282]="cloud.snow.fill"
)

# Fetch weather data
data=$(curl -s "http://api.weatherapi.com/v1/current.json?key=$API_KEY&q=$CITY")
condition=$(echo "$data" | jq -r '.current.condition.code')
temp=$(echo "$data" | jq -r '.current.temp_c')
humidity=$(echo "$data" | jq -r '.current.humidity')
is_day=$(echo "$data" | jq -r '.current.is_day')

# Determine icon and color
if [[ "$is_day" == "1" ]]; then
  icon="${weather_icons_day[$condition]}"
  if (( $(echo "$temp >= 28" | bc -l) )); then
    color="$BRIGHT_RED"
  else
    color="$BRIGHT_YELLOW"
  fi
else
  icon="${weather_icons_night[$condition]}"
  if (( $(echo "$temp >= 25" | bc -l) )); then
    color="$BRIGHT_MAGENTA"
  elif (( $(echo "$temp < 0" | bc -l) )); then
    color="$BRIGHT_CYAN"
  else
    color="$BRIGHT_BLUE"
  fi
fi

# Set sketchybar item
sketchybar --set "$NAME" \
  icon="$(sf_symbol_for $icon)" \
  icon.color="$color" \
  label="${temp}􂧤"