#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")

local item = os.getenv("NAME") or "lua.workspace"
local sender = os.getenv("SENDER") or ""
local info = (os.getenv("INFO") or ""):gsub("^%s+", ""):gsub("%s+$", "")
local focused_workspace_env = (os.getenv("FOCUSED_WORKSPACE") or ""):gsub("^%s+", ""):gsub("%s+$", "")
local workspace_id = os.getenv("AEROSPACE_WORKSPACE_ID") or ""
local base_color = os.getenv("AEROSPACE_WORKSPACE_BASE_COLOR") or "0xFFEBDBB2"
local active_color = os.getenv("AEROSPACE_WORKSPACE_ACTIVE_COLOR") or "0xFFD8A657"
local icon_size = os.getenv("AEROSPACE_WORKSPACE_ICON_SIZE") or "18"
local active_icon_size = os.getenv("AEROSPACE_WORKSPACE_ACTIVE_ICON_SIZE") or "22"
local tmpdir = os.getenv("TMPDIR") or "/tmp"
local debounce_id = (os.getenv("USER") or "user") .. "_sketchybar_ws_" .. item:gsub("[^%w_%-]", "_")
local seq_file = tmpdir .. debounce_id .. ".seq"
local debounce_ms = 60

local function normalize_workspace_id(v)
  local s = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" or s == "`" then
    return s
  end
  return s:upper()
end

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

local function current_focused_workspace()
  if focused_workspace_env ~= "" then
    return normalize_workspace_id(focused_workspace_env)
  end

  if sender == "aerospace_workspace_change" and info ~= "" then
    local token = info:match("([%w`]+)")
    if token and token ~= "" then
      return normalize_workspace_id(token)
    end
  end

  return normalize_workspace_id(capture("aerospace list-workspaces --focused 2>/dev/null | head -n1 | xargs"))
end

local function apply_workspace_state()
  local focused = current_focused_workspace()
  local active = (normalize_workspace_id(workspace_id) ~= "" and focused == normalize_workspace_id(workspace_id))
  sbar.set(item, {
    ["icon.color"] = active and active_color or base_color,
    ["icon.font.size"] = active and active_icon_size or icon_size,
    ["label.color"] = base_color,
    ["background.drawing"] = "off",
  })
end

local function schedule_debounced_update(delay_ms)
  local last_seq = tonumber(read_text(seq_file)) or 0
  local next_seq = last_seq + 1
  write_text(seq_file, tostring(next_seq))

  local cmd = string.format(
    "(sleep %.3f; AEROSPACE_WS_DEBOUNCE_FLUSH=1 AEROSPACE_WS_DEBOUNCE_SEQ=%d NAME=%s AEROSPACE_WORKSPACE_ID=%s AEROSPACE_WORKSPACE_BASE_COLOR=%s AEROSPACE_WORKSPACE_ACTIVE_COLOR=%s AEROSPACE_WORKSPACE_ICON_SIZE=%s AEROSPACE_WORKSPACE_ACTIVE_ICON_SIZE=%s CONFIG_DIR=%s %s >/dev/null 2>&1) &",
    (delay_ms or debounce_ms) / 1000.0,
    next_seq,
    shell_quote(item),
    shell_quote(workspace_id),
    shell_quote(base_color),
    shell_quote(active_color),
    shell_quote(icon_size),
    shell_quote(active_icon_size),
    shell_quote(config_dir),
    shell_quote(config_dir .. "/plugins/aerospace_workspace.lua")
  )
  os.execute(cmd)
end

if os.getenv("AEROSPACE_WS_DEBOUNCE_FLUSH") == "1" then
  local expected = tonumber(os.getenv("AEROSPACE_WS_DEBOUNCE_SEQ") or "") or -1
  local current = tonumber(read_text(seq_file)) or -2
  if expected == current then
    apply_workspace_state()
  end
  return
end

if sender == "front_app_switched" or sender == "aerospace_workspace_change" or sender == "display_change" or sender == "system_woke" or sender == "mouse.entered.global" then
  schedule_debounced_update(debounce_ms)
  return
end

apply_workspace_state()
