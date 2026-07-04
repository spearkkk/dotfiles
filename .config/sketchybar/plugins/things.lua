#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local theme = require("lib.theme")
local item = os.getenv("NAME") or "lua.things"

local BRIGHT_BLUE = theme.colors.bright_blue
local BRIGHT_GREEN = theme.colors.bright_green
local BRIGHT_YELLOW = theme.colors.bright_yellow
local BRIGHT_RED = theme.colors.bright_red

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local count_str = capture([[
osascript <<'EOF'
tell application "Things3"
  set todayCount to count of to dos of list "Today"
  set inboxCount to count of to dos of list "Inbox"
end tell
return todayCount + inboxCount
EOF
]])

local count = tonumber(count_str) or 0

local color
if count < 5 then
  color = BRIGHT_BLUE
elseif count < 10 then
  color = BRIGHT_GREEN
elseif count < 20 then
  color = BRIGHT_YELLOW
else
  color = BRIGHT_RED
end

sbar.set(item, {
  label = tostring(count),
  ["icon.color"] = color,
  ["label.color"] = color,
})
