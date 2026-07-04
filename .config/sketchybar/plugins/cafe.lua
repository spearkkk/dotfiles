#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local theme = require("lib.theme")
local item = os.getenv("NAME") or "lua.cafe"
local button = os.getenv("BUTTON") or ""

local OFF_ICON = "􀸘"
local ON_ICON = "􀸙"

local OFF_COLOR = theme.colors.text_lightest
local ON_COLOR = theme.colors.text_lightest

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function caffeinate_pid()
  return capture("pgrep -x caffeinate | head -n 1")
end

local pid = caffeinate_pid()

if button == "" then
  if pid == "" then
    sbar.set(item, { icon = OFF_ICON, ["icon.color"] = OFF_COLOR })
  else
    sbar.set(item, { icon = ON_ICON, ["icon.color"] = ON_COLOR })
  end
  os.exit(0)
end

if pid == "" then
  os.execute("nohup caffeinate -dimsu > /dev/null 2>&1 &")
  sbar.set(item, { icon = ON_ICON, ["icon.color"] = ON_COLOR })
else
  os.execute("kill " .. pid .. " > /dev/null 2>&1")
  sbar.set(item, { icon = OFF_ICON, ["icon.color"] = OFF_COLOR })
end
