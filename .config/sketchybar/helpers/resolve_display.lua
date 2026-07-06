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

local function is_numeric(s)
  return tostring(s or ""):match("^%d+$") ~= nil
end

local function list_monitor_ids()
  local out = capture("aerospace list-monitors 2>/dev/null | awk -F'|' '{gsub(/ /,\"\",$1); print $1}'")
  local ids = {}
  for id in out:gmatch("[^\n]+") do
    if id ~= "" then
      table.insert(ids, id)
    end
  end
  return ids
end

local function monitor_for_workspace(workspace)
  if workspace == "" then
    return ""
  end
  for _, id in ipairs(list_monitor_ids()) do
    local visible = capture("aerospace list-workspaces --monitor " .. id .. " --visible 2>/dev/null")
    for ws in visible:gmatch("[^\n]+") do
      if ws == workspace then
        return id
      end
    end
  end
  return ""
end

local sender = os.getenv("SENDER") or ""
local info = os.getenv("INFO") or ""
local focused_ws = os.getenv("FOCUSED_WORKSPACE") or ""

local target = ""

if sender == "aerospace_workspace_change" and focused_ws ~= "" then
  target = monitor_for_workspace(focused_ws)
end

if target == "" and sender == "display_change" and is_numeric(info) then
  target = info
end

if target == "" and focused_ws ~= "" then
  target = monitor_for_workspace(focused_ws)
end

if target == "" then
  local ws = capture("aerospace list-workspaces --focused 2>/dev/null | head -n1 | xargs")
  target = monitor_for_workspace(ws)
end

if target == "" then
  target = capture("aerospace list-monitors --focused 2>/dev/null | awk -F'|' '{gsub(/ /,\"\",$1); print $1; exit}'")
end

io.write(target)
