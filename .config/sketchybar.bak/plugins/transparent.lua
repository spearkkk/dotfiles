#!/usr/bin/env lua

local suffix = arg[1] or "1"
local position = arg[2] or "right"
local display = arg[3] or "active"
local mode = arg[4] or "normal"

local function set_alpha(hex, percent)
  local p = tonumber(percent) or 100
  if p < 0 then p = 0 end
  if p > 100 then p = 100 end

  local h = tostring(hex or ""):gsub("^#", ""):gsub("^0x", ""):gsub("^0X", "")
  if #h == 8 then
    h = h:sub(-6)
  end
  h = h:upper()
  if #h ~= 6 then
    h = "32302F"
  end

  local a = math.floor((p * 2.55) + 0.5)
  return string.format("0x%02X%s", a, h)
end

local black = os.getenv("BLACK") or "0xFF32302F"
local bg = set_alpha(black, 80)
local name = "lua.transparent." .. suffix
local config_dir = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar-lua")

local extras = {
  "display=" .. display,
}

if mode == "hide_on_dell" then
  extras = {
    "display=all",
  }
  table.insert(extras, "script=" .. config_dir .. "/plugins/transparent_visibility.lua")
end

local cmd = table.concat({
  "sketchybar",
  "--add item " .. name .. " " .. position,
  "--set " .. name,
  "background.color=" .. bg,
  "background.padding_left=2",
  "background.padding_right=2",
  "background.drawing=on",
  "background.height=22",
  table.concat(extras, " "),
}, " ")

os.execute(cmd)

if mode == "hide_on_dell" then
  os.execute("sketchybar --subscribe " .. name .. " display_change space_change aerospace_workspace_change system_woke mouse.entered.global")
  os.execute("NAME=" .. name .. " " .. config_dir .. "/plugins/transparent_visibility.lua")
end
