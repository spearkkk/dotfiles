-- Display policy belongs to screen topology, never to keyboard/mouse focus.
-- Keep one owner even if a configuration re-requires this module in one VM.
local existing = rawget(_G, "__dotfiles_display_policy")
if existing then return existing end

local utils = require("lib.utils")
local blocklist = require("lib.blocklist")
local M = {}
local home = os.getenv("HOME") or ""
local subscribers, visibility_logs = {}, {}
local state = {status="error", reason="query_failed", allowed_ids={}, generation=0}
local fingerprint, started, job

local function failure(reason)
  return {status="error", reason=reason, allowed_ids={}}
end

function M.compute(snapshot, blocked, policy_error)
  if policy_error or type(blocked) ~= "table" then return failure("policy_unreadable") end
  if type(snapshot) ~= "table" or snapshot.status ~= "ready" then
    return failure(type(snapshot)=="table" and snapshot.reason=="identity_unresolved"
      and "identity_unresolved" or "query_failed")
  end
  if type(snapshot.displays) ~= "table" then return failure("identity_unresolved") end
  local ids, seen_ids, seen_identity = {}, {}, {}
  for _, screen in ipairs(snapshot.displays) do
    if type(screen) ~= "table" then return failure("identity_unresolved") end
    local id = screen.sketchybar_id
    if type(id) ~= "number" or id < 1 or id ~= math.floor(id) or id == math.huge
      or type(screen.name) ~= "string" or screen.name == ""
      or type(screen.identity) ~= "string" or screen.identity == ""
      or seen_ids[id] or seen_identity[screen.identity] then
      return failure("identity_unresolved")
    end
    seen_ids[id], seen_identity[screen.identity] = true, true
    if not blocked[screen.name] then ids[#ids+1] = id end
  end
  table.sort(ids)
  return {status="ready", allowed_ids=ids,
    reason=#snapshot.displays==0 and "no_displays" or (#ids==0 and "all_excluded" or "allowed")}
end

function M.attributes(current, content_visible)
  local allowed = current.status=="ready" and #current.allowed_ids>0
  local attrs = {drawing=allowed and content_visible==true or false}
  if allowed then attrs.display = table.concat(current.allowed_ids, ",") end
  return attrs
end

local function copy_state()
  local ids = {}
  for i,id in ipairs(state.allowed_ids) do ids[i] = id end
  return {status=state.status, reason=state.reason, generation=state.generation, allowed_ids=ids}
end

local function notify(callback)
  local ok = pcall(callback, copy_state())
  if not ok then utils.log("display: subscriber_failed") end -- never log an exception containing user data
end

local function publish(result)
  local blocked, policy_error = blocklist.read(home .. "/.config/sketchybar/display_blocklist")
  local snapshot = result.ok and result.payload or nil
  local next_state = M.compute(snapshot, blocked, policy_error)
  local next_fingerprint = table.concat({next_state.status, next_state.reason,
    table.concat(next_state.allowed_ids, ","),
    next_state.status=="ready" and tostring(snapshot.topology_key or "") or ""}, "|")
  if next_fingerprint == fingerprint then return end
  fingerprint = next_fingerprint
  next_state.generation = state.generation+1
  state = next_state
  utils.log(string.format("display: generation=%d reason=%s ids=%s", state.generation,
    state.reason, table.concat(state.allowed_ids, ",")))
  for _, callback in pairs(subscribers) do notify(callback) end
end

local function start()
  if started then return end
  started = true
  job = require("lib.bounded_query").new({
    argv={home .. "/.local/libexec/sketchybar-display-snapshot"}, timeout_ms=5000,
    on_result=publish,
  })
  local timer = Sbar.add("item", "dotfiles.display_policy", {
    drawing=false, updates="on", update_freq=60,
    icon={drawing=false}, label={drawing=false}, background={drawing=false},
  })
  timer:subscribe({"routine", "forced", "system_woke", "display_change"}, function()
    job:request()
  end)
  job:request()
end

function M.subscribe(key, callback)
  assert(type(key)=="string" and type(callback)=="function", "invalid display subscriber")
  subscribers[key] = callback
  notify(callback)
  start()
  return function()
    if subscribers[key] == callback then subscribers[key] = nil end
  end
end

function M.request()
  if started then job:request() else start() end
end

-- Renderers supply fixed reason codes, not titles, CLI responses or budgets.
function M.log_visibility(key, current, content_reason, visible)
  local function code(value)
    return type(value)=="string" and value:match("^[a-z][a-z0-9_.]*$") and value or "invalid"
  end
  key, content_reason = code(key), code(content_reason)
  local signature = table.concat({current.generation, current.reason, content_reason,
    tostring(visible), table.concat(current.allowed_ids, ",")}, "|")
  if visibility_logs[key] == signature then return end
  visibility_logs[key] = signature
  utils.log(string.format("widget=%s generation=%d display_reason=%s content_reason=%s visible=%s ids=%s",
    key, current.generation, code(current.reason), content_reason, tostring(visible),
    table.concat(current.allowed_ids, ",")))
end

_G.__dotfiles_display_policy = M
return M
