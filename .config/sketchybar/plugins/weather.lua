#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local theme = require("lib.theme")
local item = os.getenv("NAME") or "lua.weather"

local API_KEY = "73a4c1b756384c228e9142307250307"

local BRIGHT_RED = theme.colors.bright_red
local BRIGHT_YELLOW = theme.colors.bright_yellow
local BRIGHT_CYAN = theme.colors.bright_cyan
local BRIGHT_BLUE = theme.colors.bright_blue
local BRIGHT_MAGENTA = theme.colors.bright_magenta

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

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return out:gsub("%s+$", "")
end

local city = capture("curl -s ipinfo.io/loc")
if city == "" then
  sbar.set(item, { icon = "􀇃", label = "N/A" })
  os.exit(0)
end

local query = string.format(
  "curl -s 'http://api.weatherapi.com/v1/current.json?key=%s&q=%s' | jq -r '.current.condition.code, .current.temp_c, .current.is_day'",
  API_KEY,
  city
)
local raw = capture(query)
local code, temp_str, is_day = raw:match("([^\n]*)\n([^\n]*)\n([^\n]*)")

if not code or not temp_str or not is_day then
  sbar.set(item, { icon = "􀇃", label = "N/A" })
  os.exit(0)
end

local temp = tonumber(temp_str) or 0
local icons = (is_day == "1") and day_icons or night_icons
local icon = icons[code] or "􀇃"

local color
if is_day == "1" then
  if temp >= 28 then
    color = BRIGHT_RED
  else
    color = BRIGHT_YELLOW
  end
else
  if temp >= 25 then
    color = BRIGHT_MAGENTA
  elseif temp < 0 then
    color = BRIGHT_CYAN
  else
    color = BRIGHT_BLUE
  end
end

sbar.set(item, {
  icon = icon,
  ["icon.color"] = color,
  label = string.format("%s􂧤", temp_str),
})
