local utils = require("helpers.utils")

local M = {}

local function capture(cmd)
  return utils.capture(cmd)
end

local function is_numeric(s)
  return tostring(s or ""):match("^%d+$") ~= nil
end

local function list_monitor_ids()
  local out = capture("aerospace list-monitors 2>/dev/null | awk -F'|' '{gsub(/ /,\"\",$1); print $1}'")
  local ids = {}
  for id in out:gmatch("[^\n]+") do
    if id ~= "" then
      ids[#ids + 1] = id
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

function M.resolve_target_id(ctx)
  ctx = ctx or {}

  local sender = ctx.sender or os.getenv("SENDER") or ""
  local info = ctx.info or os.getenv("INFO") or ""
  local focused_ws = ctx.focused_workspace or os.getenv("FOCUSED_WORKSPACE") or ""

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

  return target
end

function M.monitor_name_by_id(target_id)
  if target_id == "" then
    return ""
  end

  local monitors = capture("aerospace list-monitors 2>/dev/null")
  for line in (monitors .. "\n"):gmatch("([^\n]*)\n") do
    local id, name = line:match("^%s*([^|]+)%s*|%s*(.-)%s*$")
    if id and name then
      id = id:gsub("%s+", "")
      if id == target_id then
        return name
      end
    end
  end

  return ""
end

return M
