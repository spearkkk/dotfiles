#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local item = os.getenv("NAME") or "lua.front_app"
local sender = os.getenv("SENDER") or ""
local info = (os.getenv("INFO") or ""):gsub("^%s+", ""):gsub("%s+$", "")
local focused_workspace_env = (os.getenv("FOCUSED_WORKSPACE") or ""):gsub("^%s+", ""):gsub("%s+$", "")
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local debounce_id = (os.getenv("USER") or "user") .. "_sketchybar_front_app"
local seq_file = tmpdir .. debounce_id .. ".seq"
local app_file = tmpdir .. debounce_id .. ".app"
local debounce_ms_front = 120
local debounce_ms_workspace = 160

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function read_text(path)
  local f = io.open(path, "r")
  if not f then
    return ""
  end
  local v = f:read("*a") or ""
  f:close()
  return (v:gsub("%s+$", ""))
end

local function write_text(path, value)
  local f = io.open(path, "w")
  if not f then
    return false
  end
  f:write(value or "")
  f:close()
  return true
end

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function current_front_app()
  if sender == "front_app_switched" and info ~= "" then
    return info
  end

  local app = capture("lsappinfo info -only name $(lsappinfo front) 2>/dev/null | cut -d'\"' -f4 | xargs")
  if app ~= "" then
    return app
  end

  return capture("lsappinfo list 2>/dev/null | rg 'in front' | awk -F'\"' '{print $2}' | xargs")
end

local function resolved_display_id()
  local env_prefix = string.format(
    "SENDER=%q INFO=%q FOCUSED_WORKSPACE=%q CONFIG_DIR=%q ",
    sender,
    info,
    focused_workspace_env,
    config_dir
  )
  return capture(env_prefix .. config_dir .. "/plugins/resolve_display.lua")
end

local function set_front_app_label(app_name)
  local target_display = resolved_display_id()
  local props = {
    label = app_name ~= "" and app_name or "-",
    drawing = "on",
  }
  if target_display ~= "" then
    props.display = target_display
  end
  sbar.set(item, props)
end

local function schedule_debounced_update(app_name, delay_ms)
  local last_seq = tonumber(read_text(seq_file)) or 0
  local next_seq = last_seq + 1
  write_text(seq_file, tostring(next_seq))
  write_text(app_file, app_name or "")

  local cmd = string.format(
    "(sleep %.3f; FRONT_APP_DEBOUNCE_FLUSH=1 FRONT_APP_DEBOUNCE_SEQ=%d NAME=%s CONFIG_DIR=%s %s >/dev/null 2>&1) &",
    (delay_ms or debounce_ms_front) / 1000.0,
    next_seq,
    shell_quote(item),
    shell_quote(config_dir),
    shell_quote(config_dir .. "/plugins/front_app.lua")
  )
  os.execute(cmd)
end

if os.getenv("FRONT_APP_DEBOUNCE_FLUSH") == "1" then
  local expected = tonumber(os.getenv("FRONT_APP_DEBOUNCE_SEQ") or "") or -1
  local current = tonumber(read_text(seq_file)) or -2
  if expected == current then
    local app_name = read_text(app_file)
    if app_name == "" then
      app_name = current_front_app()
    end
    set_front_app_label(app_name)
  end
  return
end

if sender == "front_app_switched" then
  schedule_debounced_update(info ~= "" and info or current_front_app(), debounce_ms_front)
  return
end

if sender == "aerospace_workspace_change" or sender == "display_change" then
  schedule_debounced_update(current_front_app(), debounce_ms_workspace)
  return
end

local app_name = read_text(app_file)
if app_name == "" then
  app_name = current_front_app()
end
set_front_app_label(app_name)
