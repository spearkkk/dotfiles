#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local item = os.getenv("NAME") or "lua.cmux_workspace"
local cmux_bin = os.getenv("CMUX_BIN") or (home .. "/.local/bin/cmux")

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function first_line(s)
  return (s:match("([^\n]+)") or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function current_workspace()
  local out = capture("CMUX_QUIET=1 " .. cmux_bin .. " current-workspace 2>&1")
  if out:match("Broken pipe") or out:match("^Error:") then
    return "offline"
  end
  local line = first_line(out)
  if line == "" or line:match("^Error:") then
    return "-"
  end
  return line
end

sbar.set(item, {
  label = "cmux: " .. current_workspace(),
})
