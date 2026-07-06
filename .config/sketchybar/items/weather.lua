local colors = require("helpers.colors")
local settings = require("helpers.settings")
local utils = require("helpers.utils")

local TOP_Y = settings.double_line_bottom_y
local BOTTOM_Y = settings.double_line_top_y
local ICON_SIZE = settings.text_size_small - 1
local TEMP_SIZE = settings.text_size_large 
local UPDATE_FREQ = 600

local STACK_WIDTH = 16
local STACK_RIGHT_GAP = 0

local API_KEY = "73a4c1b756384c228e9142307250307"

local day_icons = {
  ["1000"] = "􀆮", ["1003"] = "􀇕", ["1006"] = "􀇃", ["1009"] = "􀇃",
  ["1030"] = "􀇋", ["1063"] = "􀇅", ["1066"] = "􀇏", ["1069"] = "􀇑",
  ["1072"] = "􀇅", ["1087"] = "􀇓", ["1114"] = "􀇏", ["1117"] = "􀇦",
  ["1135"] = "􀇋", ["1147"] = "􀇋", ["1150"] = "􀇅", ["1153"] = "􀇅",
  ["1168"] = "􀇅", ["1171"] = "􀇅", ["1180"] = "􀇇", ["1183"] = "􀇇",
  ["1186"] = "􀇇", ["1189"] = "􀇉", ["1192"] = "􀇉", ["1195"] = "􀇉",
  ["1198"] = "􀇇", ["1201"] = "􀇉", ["1204"] = "􀇑", ["1207"] = "􀇑",
  ["1210"] = "􀇏", ["1213"] = "􀇏", ["1216"] = "􀇏", ["1219"] = "􀇏",
  ["1222"] = "􀇏", ["1225"] = "􀇏", ["1237"] = "􀇍", ["1240"] = "􀇗",
  ["1243"] = "􀇗", ["1246"] = "􀇗", ["1249"] = "􀇑", ["1252"] = "􀇑",
  ["1255"] = "􀇏", ["1258"] = "􀇏", ["1261"] = "􀇍", ["1264"] = "􀇍",
  ["1273"] = "􀇟", ["1276"] = "􀇟", ["1279"] = "􀇏", ["1282"] = "􀇏",
}

local night_icons = {
  ["1000"] = "􀇁", ["1003"] = "􀇛", ["1006"] = "􀇃", ["1009"] = "􀇃",
  ["1030"] = "􀇋", ["1063"] = "􀇝", ["1066"] = "􀇏", ["1069"] = "􀇑",
  ["1072"] = "􀇝", ["1087"] = "􀇓", ["1114"] = "􀇏", ["1117"] = "􀇦",
  ["1135"] = "􀇋", ["1147"] = "􀇋", ["1150"] = "􀇝", ["1153"] = "􀇝",
  ["1168"] = "􀇝", ["1171"] = "􀇝", ["1180"] = "􀇝", ["1183"] = "􀇝",
  ["1186"] = "􀇝", ["1189"] = "􀇝", ["1192"] = "􀇝", ["1195"] = "􀇝",
  ["1198"] = "􀇝", ["1201"] = "􀇝", ["1204"] = "􀇑", ["1207"] = "􀇑",
  ["1210"] = "􀇏", ["1213"] = "􀇏", ["1216"] = "􀇏", ["1219"] = "􀇏",
  ["1222"] = "􀇏", ["1225"] = "􀇏", ["1237"] = "􀇍", ["1240"] = "􀇝",
  ["1243"] = "􀇝", ["1246"] = "􀇝", ["1249"] = "􀇑", ["1252"] = "􀇑",
  ["1255"] = "􀇏", ["1258"] = "􀇏", ["1261"] = "􀇍", ["1264"] = "􀇍",
  ["1273"] = "􀇟", ["1276"] = "􀇟", ["1279"] = "􀇏", ["1282"] = "􀇏",
}

local weather_icon = Sbar.add("item", "weather_icon", {
  position = "right",
  width = STACK_WIDTH,
  padding_left = 0,
  padding_right = STACK_RIGHT_GAP,
  y_offset = TOP_Y,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = true,
    align = "right",
    padding_right = 6,
    color = colors.foreground,
    font = {
      size = ICON_SIZE,
    },
  },
  label = {
    drawing = false,
  },
  background = {
    drawing = false,
  },
})

local weather_temp = Sbar.add("item", "weather_temp", {
  position = "right",
  width = STACK_WIDTH,
  padding_left = 0,
  padding_right = -STACK_WIDTH + STACK_RIGHT_GAP,
  y_offset = BOTTOM_Y,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = false,
  },
  label = {
    drawing = true,
    align = "right",
    color = colors.foreground,
    font = {
      size = TEMP_SIZE,
    },
  },
  background = {
    drawing = false,
  },
})

local function weather_status()
  local loc = utils.capture("curl -fsS ipinfo.io/loc 2>/dev/null")
  if loc == "" then
    return nil
  end

  local query = string.format(
    "curl -fsS 'http://api.weatherapi.com/v1/current.json?key=%s&q=%s' | jq -r '.current.condition.code, .current.temp_c, .current.is_day' 2>/dev/null",
    API_KEY,
    loc
  )
  local raw = utils.capture(query)
  local code, temp_str, is_day = raw:match("([^\n]*)\n([^\n]*)\n([^\n]*)")
  if not code or not temp_str or not is_day then
    return nil
  end

  local temp = tonumber(temp_str)
  if not temp then
    return nil
  end

  local icons = (is_day == "1") and day_icons or night_icons
  local icon = icons[code] or "􀇃"

  local icon_color
  if is_day == "1" then
    if temp >= 28 then
      icon_color = colors.base08
    else
      icon_color = colors.base0a
    end
  else
    if temp >= 25 then
      icon_color = colors.base0e
    elseif temp < 0 then
      icon_color = colors.base0c
    else
      icon_color = colors.base0d
    end
  end

  return {
    icon = icon,
    icon_color = icon_color,
    temp = string.format("%d°", math.floor(temp + 0.5)),
  }
end

local function update_weather()
  local st = weather_status()
  if not st then
    weather_icon:set({
      icon = "􀇃",
      ["icon.color"] = colors.base04,
    })
    weather_temp:set({
      label = "--°",
      ["label.color"] = colors.base04,
    })
    return
  end

  weather_icon:set({
    icon = st.icon,
    ["icon.color"] = st.icon_color,
  })

  weather_temp:set({
    label = st.temp,
    ["label.color"] = colors.foreground,
  })
end

update_weather()

weather_icon:subscribe({ "routine", "forced", "system_woke", "wifi_change" }, update_weather)
weather_temp:subscribe({ "routine", "forced", "system_woke", "wifi_change" }, update_weather)
