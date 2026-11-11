local icons = require("lib.icons")
local colors = require("lib.colors")
local settings = require("lib.settings")
local utils = require("lib.utils")

local ICON_SIZE = settings.icon_size
local UPDATE_FREQ = 1800

local day_icons = {
  clear = icons.sun,
  partly_cloudy = icons.cloud,
  cloudy = icons.cloud,
  fog = icons.cloud_fog,
  drizzle = icons.cloud_rain,
  rain = icons.cloud_rain,
  heavy_rain = icons.cloud_rain,
  snow = icons.cloud_snow,
  thunder = icons.cloud_storm,
  hail = icons.cloud_exclamation,
}

local night_icons = {
  clear = icons.moon_stars,
  partly_cloudy = icons.cloud,
  cloudy = icons.cloud,
  fog = icons.cloud_fog,
  drizzle = icons.cloud_rain,
  rain = icons.cloud_rain,
  heavy_rain = icons.cloud_rain,
  snow = icons.cloud_snow,
  thunder = icons.cloud_storm,
  hail = icons.cloud_exclamation,
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
  width = settings.icon_cell_width,
  -- Bracket uses the first member's padding for its left edge; keep the
  -- fixed-width icon cell in place while insetting the underline by 12px.
  padding_left = settings.defaults.padding_left - 12,
  padding_right = settings.defaults.padding_right,
  y_offset = 0,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = true,
    align = "center",
    padding_left = settings.inner_padding,
    padding_right = settings.inner_padding,
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
  ["popup.height"] = 22,
  ["popup.align"] = "center",
  ["popup.y_offset"] = -4,
  ["popup.background.height"] = 20,
  ["popup.background.color"] = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_color"] = colors.border,
  ["popup.background.border_width"] = 2,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.drawing"] = true,
})

local weather_temp = Sbar.add("item", "weather_temp", {
  position = "popup.weather_icon",
  icon = { drawing = false },
  label = {
    drawing = true,
    color = colors.foreground,
    font = { size = 12 },
    padding_left = settings.inner_padding,
    padding_right = settings.inner_padding,
  },
  background = { drawing = false },
})

local function parse_weather(raw)
  if type(raw) ~= "string" then return nil end
  raw = raw:gsub("%s+$", "")
  local code, temperature, daytime = raw:match("^(%d+)\t([^\t]+)\t([01])$")
  local temp = tonumber(temperature)
  if not code or not temp or not math.tointeger(math.floor(temp + 0.5)) then
    return nil
  end

  return { code = tonumber(code), temperature = temp, is_day = daytime == "1" }
end

local function weather_status(data)
  if not data then
    return nil
  end

  local temp = data.temperature
  local icons = data.is_day and day_icons or night_icons
  local icon = icons[weather_icon_key(data.code)] or day_icons.cloudy

  local icon_color
  if data.is_day then
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

local function render_weather(data)
  local st = weather_status(data)
  if not st then
    weather_icon:set({
      icon = icons.cloud,
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

local in_flight = false
local helper = os.getenv("HOME") .. "/.local/libexec/sketchybar-fetch-weather"
local function update_weather()
  if in_flight then return end
  in_flight = true
  local scheduled = pcall(Sbar.exec, utils.shell_quote(helper) .. " 2>/dev/null", function(raw, exit_code)
    in_flight = false
    -- Do not render partial stdout from a failed or timed-out helper.
    render_weather(exit_code == 0 and parse_weather(raw) or nil)
  end)
  if not scheduled then
    in_flight = false
    render_weather(nil)
  end
end

weather_icon:subscribe("mouse.entered", function()
  weather_icon:set({ ["popup.drawing"] = true })
end)
weather_icon:subscribe("mouse.exited", function()
  weather_icon:set({ ["popup.drawing"] = false })
end)

weather_icon:subscribe({ "routine", "forced", "system_woke", "wifi_change" }, update_weather)
render_weather(nil)
update_weather()
