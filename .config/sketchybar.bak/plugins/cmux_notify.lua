#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local item = os.getenv("NAME") or "lua.cmux_notify"
local cmux_bin = os.getenv("CMUX_BIN") or (home .. "/.local/bin/cmux")
local mode = arg[1] or ""
local max_lines = 8
local cmux_offline = false

local spinner_first_chars = {
  ["⠋"] = true, ["⠙"] = true, ["⠹"] = true, ["⠸"] = true, ["⠼"] = true,
  ["⠴"] = true, ["⠦"] = true, ["⠧"] = true, ["⠇"] = true, ["⠏"] = true,
}

local function capture(cmd)
  local p = io.popen(cmd)
  if not p then
    return ""
  end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function command_succeeds(cmd)
  local ok, _, code = os.execute(cmd)
  if ok == true then
    return true
  end
  return code == 0
end

local function shell_quote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function tsv_fields(line, n)
  local fields = {}
  local idx = 1
  for _ = 1, n - 1 do
    local pos = line:find("\t", idx, true)
    if not pos then
      return nil
    end
    table.insert(fields, line:sub(idx, pos - 1))
    idx = pos + 1
  end
  table.insert(fields, line:sub(idx))
  return fields
end

local function first_utf8_char(s)
  if s == nil or s == "" then
    return ""
  end
  local i = utf8.offset(s, 1)
  if not i then
    return ""
  end
  local j = utf8.offset(s, 2)
  if j then
    return s:sub(i, j - 1)
  end
  return s:sub(i)
end

local function truncate_text(s, max_chars)
  local out = s or ""
  local count = utf8.len(out)
  if not count or count <= max_chars then
    return out
  end
  local byte_index = utf8.offset(out, max_chars + 1)
  if not byte_index then
    return out
  end
  return out:sub(1, byte_index - 1) .. "…"
end

local function list_workspaces()
  if not command_succeeds("command -v jq >/dev/null 2>&1") then
    return nil, "jq missing"
  end
  local cmd = "CMUX_QUIET=1 " .. shell_quote(cmux_bin)
    .. " --id-format both workspace list --json 2>&1"
    .. " | jq -r '.workspaces[] | [.id,.ref,.title,(if .selected then \"1\" else \"0\" end)] | @tsv'"
  local out = capture(cmd)
  if out:match("Broken pipe") or out:match("^Error:") then
    cmux_offline = true
    return nil, "cmux offline"
  end
  local workspaces = {}
  for line in out:gmatch("[^\n]+") do
    local fields = tsv_fields(line, 4)
    if fields then
      table.insert(workspaces, {
        id = trim(fields[1]),
        ref = trim(fields[2]),
        title = trim(fields[3]),
        selected = trim(fields[4]) == "1",
      })
    end
  end
  return workspaces, nil
end

local function list_notifications_by_workspace()
  if not command_succeeds("command -v jq >/dev/null 2>&1") then
    return nil, "jq missing"
  end
  local cmd = "CMUX_QUIET=1 " .. shell_quote(cmux_bin)
    .. " list-notifications --json 2>&1"
    .. " | jq -r '.[] | [.workspace_id,(if .is_read then \"1\" else \"0\" end),(.title // \"\"),(.created_at // \"\")] | @tsv'"
  local out = capture(cmd)
  if out:match("Broken pipe") or out:match("^Error:") then
    cmux_offline = true
    return nil, "cmux offline"
  end
  local map = {}
  for line in out:gmatch("[^\n]+") do
    local fields = tsv_fields(line, 4)
    if fields then
      local wsid = trim(fields[1])
      if wsid ~= "" then
        map[wsid] = map[wsid] or { unread = 0, latest_title = "", latest_at = "" }
        local rec = map[wsid]
        local is_read = trim(fields[2]) == "1"
        local title = trim(fields[3])
        local created_at = trim(fields[4])
        if not is_read then
          rec.unread = rec.unread + 1
        end
        if created_at >= rec.latest_at then
          rec.latest_at = created_at
          rec.latest_title = title
        end
      end
    end
  end
  return map, nil
end

local function workspace_state(rec)
  if rec and rec.unread and rec.unread > 0 then
    return "waiting"
  end
  local title = rec and rec.latest_title or ""
  if spinner_first_chars[first_utf8_char(title)] then
    return "working"
  end
  if title:match("^[✔✓]") then
    return "done"
  end
  return "idle"
end

local function popup_lines_from_state(workspaces, notifications)
  local lines = {}
  local waiting = 0
  local working = 0
  for _, ws in ipairs(workspaces) do
    local rec = notifications[ws.id] or { unread = 0, latest_title = "" }
    local state = workspace_state(rec)
    if state == "waiting" then
      waiting = waiting + 1
    elseif state == "working" then
      working = working + 1
    end

    local mark = ws.selected and "*" or " "
    local title = truncate_text(ws.title ~= "" and ws.title or ws.ref, 18)
    local last = truncate_text(rec.latest_title or "", 20)
    local suffix = ""
    if rec.unread and rec.unread > 0 then
      suffix = " (" .. tostring(rec.unread) .. " unread)"
    elseif last ~= "" then
      suffix = " [" .. last .. "]"
    end
    table.insert(lines, string.format("%s %s %s | %s%s", mark, ws.ref, title, state, suffix))
  end
  return lines, waiting, working
end

local function set_popup_lines(lines)
  for i = 1, max_lines do
    local name = "lua.cmux_notify.line" .. i
    local text = lines[i]
    if text then
      sbar.set(name, { label = text, drawing = "on" })
    else
      sbar.set(name, { label = "", drawing = "off" })
    end
  end
end

local function popup_is_open()
  local query = capture("sketchybar --query " .. item .. " 2>/dev/null")
  local state = query:match('"popup"%s*:%s*{.-"drawing"%s*:%s*"([^"]+)"')
  return state == "on"
end

local workspaces = list_workspaces() or {}
local notifications = list_notifications_by_workspace() or {}

local lines = {}
local waiting = 0
local working = 0

if #workspaces > 0 then
  lines, waiting, working = popup_lines_from_state(workspaces, notifications)
elseif cmux_offline then
  lines = { "cmux offline (socket)" }
else
  lines = { "No cmux workspace data" }
end

if cmux_offline then
  sbar.set(item, { label = "react: off" })
else
  sbar.set(item, { label = string.format("react w:%d r:%d", waiting, working) })
end
set_popup_lines(lines)

if mode == "--toggle-popup" then
  if popup_is_open() then
    os.execute("sketchybar --set " .. item .. " popup.drawing=off")
  else
    os.execute("sketchybar --set " .. item .. " popup.drawing=on")
    os.execute("(sleep 6; sketchybar --set " .. item .. " popup.drawing=off) >/dev/null 2>&1 &")
  end
end
