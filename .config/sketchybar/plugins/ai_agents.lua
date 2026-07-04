#!/usr/bin/env lua

local home = os.getenv("HOME") or ""
local config_dir = os.getenv("CONFIG_DIR") or (home .. "/.config/sketchybar-lua")
package.path = config_dir .. "/lua/?.lua;" .. config_dir .. "/lua/?/init.lua;" .. package.path

local sbar = require("lib.sketchybar")
local item = os.getenv("NAME") or "lua.ai_agents"
local mode = arg[1] or ""
local max_lines = 8
local data_file = config_dir .. "/data/ai_agents.json"

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

local function focused_workspace()
  local ws = capture("aerospace list-workspaces --focused 2>/dev/null | head -n1 | xargs")
  return trim(ws)
end

local function parse_agents()
  local cmd = "if command -v jq >/dev/null 2>&1 && [ -f " .. shell_quote(data_file) .. " ]; then "
    .. "jq -r '.agents[] | [(.workspace_id // .workspace // \"\"),(.application_name // .application // \"\"),(.agent_name // .agent // \"\"),(.session_name // .session // \"\"),(.status // \"unknown\"),(.priority // \"normal\"),(.updated_at // \"\"),(.note // \"\")] | @tsv' "
    .. shell_quote(data_file)
    .. "; fi"

  local out = capture(cmd)
  local agents = {}
  for line in out:gmatch("[^\n]+") do
    local f = tsv_fields(line, 8)
    if f then
      table.insert(agents, {
        workspace_id = trim(f[1]),
        application_name = trim(f[2]),
        agent_name = trim(f[3]),
        session_name = trim(f[4]),
        status = trim(f[5]),
        priority = trim(f[6]),
        updated_at = trim(f[7]),
        note = trim(f[8]),
      })
    end
  end
  return agents
end

local function status_short(s)
  if s == "waiting_input" then
    return "wait"
  end
  if s == "working" then
    return "run"
  end
  if s == "blocked" then
    return "block"
  end
  if s == "error" then
    return "err"
  end
  return s
end

local function set_popup_lines(lines)
  for i = 1, max_lines do
    local name = "lua.ai_agents.line" .. i
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

local ws_focused = focused_workspace()
local agents = parse_agents()

local total = #agents
local waiting = 0
local running = 0
local blocked = 0
local errored = 0

local lines = {}
if total == 0 then
  lines = { "No agent records (data/ai_agents.json)" }
else
  for _, a in ipairs(agents) do
    if a.status == "waiting_input" then
      waiting = waiting + 1
    elseif a.status == "working" then
      running = running + 1
    elseif a.status == "blocked" then
      blocked = blocked + 1
    elseif a.status == "error" then
      errored = errored + 1
    end

    local mark = (a.workspace_id ~= "" and a.workspace_id == ws_focused) and "*" or " "
    local left = string.format("%s %s %s/%s", mark, a.workspace_id ~= "" and a.workspace_id or "-", truncate_text(a.application_name, 12), truncate_text(a.agent_name, 10))
    local right = string.format("%s | %s", status_short(a.status), truncate_text(a.session_name, 16))
    table.insert(lines, left .. " | " .. right)
    if #lines >= max_lines then
      break
    end
  end
end

local label = string.format("ai %d w:%d r:%d", total, waiting, running)
if blocked > 0 or errored > 0 then
  label = label .. string.format(" !:%d", blocked + errored)
end

sbar.set(item, { label = label })
set_popup_lines(lines)

if mode == "--toggle-popup" then
  if popup_is_open() then
    os.execute("sketchybar --set " .. item .. " popup.drawing=off")
  else
    os.execute("sketchybar --set " .. item .. " popup.drawing=on")
    os.execute("(sleep 8; sketchybar --set " .. item .. " popup.drawing=off) >/dev/null 2>&1 &")
  end
end
