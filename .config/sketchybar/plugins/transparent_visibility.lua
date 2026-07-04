#!/usr/bin/env lua

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function shell_quote(s)
  local v = tostring(s or "")
  return "'" .. v:gsub("'", "'\\''") .. "'"
end

local name = os.getenv("NAME") or ""
if name == "" then
  os.exit(0)
end

local config_dir = os.getenv("CONFIG_DIR") or ((os.getenv("HOME") or "") .. "/.config/sketchybar-lua")
local dell_id = capture("aerospace list-monitors 2>/dev/null | awk -F'|' '/DELL P2723QE/{gsub(/ /,\"\",$1); print $1; exit}'")
local target_id = capture(config_dir .. "/plugins/resolve_display.lua")

if dell_id ~= "" and target_id == dell_id then
  os.execute("sketchybar --set " .. shell_quote(name) .. " drawing=off")
else
  if target_id ~= "" then
    os.execute("sketchybar --set " .. shell_quote(name) .. " display=" .. shell_quote(target_id) .. " drawing=on")
  else
    os.execute("sketchybar --set " .. shell_quote(name) .. " drawing=on")
  end
end
