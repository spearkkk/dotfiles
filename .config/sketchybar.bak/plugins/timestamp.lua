#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local theme = require("lib.theme")
local date_item = os.getenv("TIMESTAMP_DATE_ITEM") or "lua.timestamp.date"
local time_item = os.getenv("TIMESTAMP_TIME_ITEM") or "lua.timestamp.time"

local base_label_color = os.getenv("TIMESTAMP_BASE_LABEL_COLOR") or theme.colors.text_lightest
local base_icon_color = os.getenv("TIMESTAMP_BASE_ICON_COLOR") or theme.colors.bright_yellow
local base_label_size = tonumber(os.getenv("TIMESTAMP_BASE_LABEL_SIZE") or "") or 16

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("\n$", ""))
end

local function parse_hex_rgb(hex)
  local h = tostring(hex or ""):gsub("^#", ""):gsub("^0x", ""):gsub("^0X", "")
  if #h == 8 then
    h = h:sub(-6)
  end
  if #h ~= 6 then
    return 255, 255, 255
  end
  local r = tonumber(h:sub(1, 2), 16) or 255
  local g = tonumber(h:sub(3, 4), 16) or 255
  local b = tonumber(h:sub(5, 6), 16) or 255
  return r, g, b
end

local function blend_rgb(from_hex, to_hex, t)
  local r1, g1, b1 = parse_hex_rgb(from_hex)
  local r2, g2, b2 = parse_hex_rgb(to_hex)
  local r = math.floor(r1 + (r2 - r1) * t + 0.5)
  local g = math.floor(g1 + (g2 - g1) * t + 0.5)
  local b = math.floor(b1 + (b2 - b1) * t + 0.5)
  return string.format("0xFF%02X%02X%02X", r, g, b)
end

local raw = capture("LC_TIME=it_IT.UTF-8 TZ=Asia/Seoul date '+%Y-%m-%d(%a)  %H %M %S'")
local prefix, hh, mm, ss = raw:match("^(.-)%s+(%d%d)%s+(%d%d)%s+(%d%d)$")
if not prefix or not hh or not mm or not ss then
  sbar.set(date_item, { label = raw })
  sbar.set(time_item, { label = "" })
  os.exit(0)
end

local sec_num = tonumber(ss) or 0
local min_num = tonumber(mm) or 0
local in_countdown = (min_num == 59 and sec_num >= 50)

-- Blink separators every second by toggling ':' and ' '.
local sep = (sec_num % 2 == 0) and " " or ":"
local clock = string.format("%s%s%s%s%s", hh, sep, mm, sep, ss)

if in_countdown then
  local remaining = 60 - sec_num
  local progress = (10 - remaining) / 9
  local emphasis_color = blend_rgb(theme.colors.bright_yellow, theme.colors.bright_red, progress)
  local size = base_label_size + math.floor(progress * 14 + 0.5)
  if remaining <= 3 then
    size = size + 4
  end
  sbar.set(date_item, {
    label = prefix,
    ["label.color"] = base_label_color,
    ["label.font.size"] = tostring(base_label_size),
  })
  sbar.set(time_item, {
    label = clock,
    ["label.color"] = emphasis_color,
    ["label.font.size"] = tostring(size),
    ["icon.color"] = base_icon_color,
  })
else
  sbar.set(date_item, {
    label = prefix,
    ["label.color"] = base_label_color,
    ["label.font.size"] = tostring(base_label_size),
  })
  sbar.set(time_item, {
    label = clock,
    ["label.color"] = base_label_color,
    ["label.font.size"] = tostring(base_label_size),
    ["icon.color"] = base_icon_color,
  })
end
