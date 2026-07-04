#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local theme = require("lib.theme")
local item = os.getenv("NAME") or "lua.volume"
local sender = os.getenv("SENDER") or ""
local info = os.getenv("INFO") or ""
local mode = arg[1] or ""

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function current_volume()
  if sender == "volume_change" and info ~= "" then
    return tonumber(info)
  end

  local muted = capture("osascript -e 'output muted of (get volume settings)'")
  if muted == "true" then
    return 0
  end

  local out = capture("osascript -e 'output volume of (get volume settings)'")
  return tonumber(out)
end

local function toggle_mute()
  local muted = capture("osascript -e 'output muted of (get volume settings)'")
  if muted == "true" then
    os.execute("osascript -e 'set volume output muted false' >/dev/null 2>&1")
  else
    os.execute("osascript -e 'set volume output muted true' >/dev/null 2>&1")
  end
end

local function volume_icon(volume)
  if not volume or volume <= 0 then
    return "􀊡"
  elseif volume >= 60 then
    return "􀊩"
  elseif volume >= 30 then
    return "􀊧"
  else
    return "􀊥"
  end
end

if mode == "--toggle" then
  toggle_mute()
end

local volume = current_volume()
local icon = volume_icon(volume)
local color = (not volume or volume <= 0) and theme.colors.bright_red or theme.colors.bright_yellow

sbar.set(item, { icon = icon, ["icon.color"] = color })
