#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local theme = require("lib.theme")
local item = os.getenv("NAME") or "lua.battery"
local mode = arg[1] or ""
local popup_item = "lua.battery.popup"
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local token_file = tmpdir .. "/sketchybar_battery_popup.token"

local GREEN = theme.colors.bright_green
local ORANGE = theme.colors.bright_orange
local RED = theme.colors.bright_red
local LABEL_ON = theme.colors.text_lightest
local LABEL_OFF = "0x00EBDBB2"

local function set_alpha(hex, alpha)
  local h = tostring(hex or ""):gsub("^#", ""):gsub("^0x", ""):gsub("^0X", "")
  if #h == 8 then
    h = h:sub(-6)
  end
  h = h:upper()
  if #h ~= 6 then
    h = "EBDBB2"
  end
  local a = tonumber(alpha) or 255
  if a < 0 then
    a = 0
  elseif a > 255 then
    a = 255
  end
  return string.format("0x%02X%s", a, h)
end

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return out
end

local function popup_is_open()
  local query = capture("sketchybar --query " .. item .. " 2>/dev/null")
  local state = query:match('"popup"%s*:%s*{.-"drawing"%s*:%s*"([^"]+)"')
  return state == "on"
end

local function read_token()
  local f = io.open(token_file, "r")
  if not f then
    return 0
  end
  local v = tonumber(f:read("*a") or "") or 0
  f:close()
  return v
end

local function write_token(v)
  local f = io.open(token_file, "w")
  if not f then
    return
  end
  f:write(tostring(v))
  f:close()
end

local function next_token()
  local t = read_token() + 1
  write_token(t)
  return t
end

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function fade_in_popup()
  os.execute("sketchybar --set " .. item .. " popup.drawing=on")
  os.execute("sketchybar --set " .. popup_item .. " label.color=" .. set_alpha(LABEL_ON, 0) .. " y_offset=2")
  os.execute("sketchybar --animate sin 15 --set " .. popup_item .. " label.color=" .. LABEL_ON .. " y_offset=0")
end

local function fade_out_popup()
  os.execute("sketchybar --animate sin 12 --set " .. popup_item .. " label.color=" .. LABEL_OFF .. " y_offset=2")
  os.execute("(sleep 0.16; sketchybar --set " .. item .. " popup.drawing=off " .. popup_item .. " label.color=" .. LABEL_ON .. " y_offset=0) >/dev/null 2>&1 &")
end

local batt = capture("pmset -g batt")
local pct = batt:match("(%d+)%%")
if not pct then
  os.exit(0)
end

local percentage = tonumber(pct) or 0
local charging = batt:find("AC Power", 1, true) ~= nil

local icon
if charging then
  icon = "􀢋"
elseif percentage >= 90 then
  icon = "􀛨"
elseif percentage >= 60 then
  icon = "􀺸"
elseif percentage >= 30 then
  icon = "􀺶"
elseif percentage >= 10 then
  icon = "􀛩"
else
  icon = "􀛪"
end

local color
if percentage > 50 then
  color = GREEN
elseif percentage > 20 then
  color = ORANGE
else
  color = RED
end

sbar.set(item, {
  icon = icon,
  label = string.format("%d%%", percentage),
  ["icon.color"] = color,
})

sbar.set(popup_item, {
  label = string.format("Battery %d%%", percentage),
})

if mode == "--toggle-popup" then
  next_token()
  if popup_is_open() then
    fade_out_popup()
  else
    local token = read_token()
    fade_in_popup()
    os.execute("(sleep 2; CONFIG_DIR=" .. shell_quote(config_dir) .. " NAME=" .. shell_quote(item) .. " " .. shell_quote(config_dir .. "/plugins/battery.lua") .. " --autoclose " .. token .. ") >/dev/null 2>&1 &")
  end
end

if mode == "--autoclose" then
  local token = tonumber(arg[2] or "") or -1
  if token == read_token() and popup_is_open() then
    fade_out_popup()
  end
end
