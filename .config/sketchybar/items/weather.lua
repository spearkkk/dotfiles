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

local day_icons = {
  clear = "􀆮",
  partly_cloudy = "􀇕",
  cloudy = "􀇃",
  fog = "􀇋",
  drizzle = "􀇅",
  rain = "􀇇",
  heavy_rain = "􀇉",
  snow = "􀇏",
  thunder = "􀇓",
  hail = "􀇑",
}

local night_icons = {
  clear = "􀇁",
  partly_cloudy = "􀇛",
  cloudy = "􀇃",
  fog = "􀇋",
  drizzle = "􀇝",
  rain = "􀇝",
  heavy_rain = "􀇝",
  snow = "􀇏",
  thunder = "􀇓",
  hail = "􀇑",
}

local function weather_icon_key(code)
  if type(code) ~= "number" then return "cloudy" end
  if code == 0 then return "clear" end
  if code == 1 or code == 2 then return "partly_cloudy" end
  if code == 3 then return "cloudy" end
  if code == 45 or code == 48 then return "fog" end
  if code >= 51 and code <= 57 then return "drizzle" end
  if code == 61 or code == 63 or code == 80 or code == 81 then return "rain" end
  if code == 65 or code == 66 or code == 67 or code == 82 then return "heavy_rain" end
  if code >= 71 and code <= 77 or code == 85 or code == 86 then return "snow" end
  if code == 95 then return "thunder" end
  if code == 96 or code == 99 then return "hail" end
  return "cloudy"
end

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
  local latitude, longitude = loc:match("^%s*(-?%d+%.?%d*)%s*,%s*(-?%d+%.?%d*)%s*$")
  if not latitude or not longitude then
    return nil
  end

  local query = string.format(
    "curl -fsS 'https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature_2m,weather_code,is_day' | jq -r '.current.weather_code, .current.temperature_2m, .current.is_day' 2>/dev/null",
    latitude,
    longitude
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
  local icon = icons[weather_icon_key(tonumber(code))] or day_icons.cloudy

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
