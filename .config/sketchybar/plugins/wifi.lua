#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local item = os.getenv("NAME") or "lua.wifi"

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local device = capture("networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2; exit}'")
local status = "연결 no"
local icon = "󰤭"
local color = "0xFFEA6962"

if device ~= "" then
  local network_info = capture("networksetup -getairportnetwork " .. device .. " 2>/dev/null")
  if network_info:match("Current Wi%-Fi Network:") then
    status = "연결"
    icon = "󰤨"
    color = "0xFFA9B665"
  end
end

sbar.set(item, {
  icon = icon,
  label = status,
  ["icon.color"] = color,
})
