#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")

local item = os.getenv("NAME") or "lua.workspace"
local focused = sbar.capture("aerospace list-workspaces --focused 2>/dev/null | tr -d '\\n'")

if focused == "" then
  focused = "-"
end

sbar.set(item, { label = focused })
