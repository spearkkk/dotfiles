local utils = require("lib.utils")
local M = {}

local reasons = {
  timeout = true, spawn_failed = true, child_failed = true,
  invalid_json = true, output_limit = true, cleanup_failed = true,
}

-- Keep one empty 0600 namespace anchor per module instance. Removing it could
-- let a future os.tmpname reuse the namespace of a delayed bridge invocation.
-- Attempts use a never-reused counter suffix; confirmed attempt files are
-- removed, but this anchor and unresolved ownership records intentionally stay.
local namespace, serial = nil, 0
local function new_permit()
  namespace = namespace or os.tmpname()
  serial = serial + 1
  local temporary = os.tmpname()
  local permit = namespace .. "." .. serial
  if not os.rename(temporary, permit) then
    os.remove(temporary)
    return nil
  end
  return permit
end

local function read_proof(permit)
  local file = io.open(permit .. ".done", "r")
  if not file then return nil end
  local text = file:read(64)
  file:close()
  local reason = text and text:match("^([a-z_]+)\n$")
  if reason == "ok" or reasons[reason] then return reason end
end

local function retire(permit)
  if not permit then return end
  os.rename(permit, permit .. ".revoked")
  for _, suffix in ipairs({ ".claimed", ".revoked", ".done", ".done.tmp" }) do
    os.remove(permit .. suffix)
  end
end

local function failure(reason, exit_code)
  return { ok = false, reason = reason, exit_code = exit_code }
end

local function normalize(result, exit_code)
  -- A nonzero wrapper exit must never turn known incomplete cleanup into a
  -- retryable error: the old group may still be running.
  if type(result) == "table" and result.ok == false and result.reason == "cleanup_failed" then
    return failure("cleanup_failed", type(result.exit_code) == "number" and result.exit_code or nil), true
  end
  if exit_code ~= 0 then return failure("child_failed", exit_code) end
  if type(result) ~= "table" or type(result.ok) ~= "boolean" then
    return failure("invalid_json")
  end
  if result.ok and result.reason == "ok" and result.exit_code == 0 then
    return { ok = true, reason = "ok", exit_code = 0, payload = result.payload }, true
  end
  if not result.ok and reasons[result.reason] then
    return failure(result.reason, type(result.exit_code) == "number" and result.exit_code or nil), true
  end
  return failure("invalid_json")
end

local function recover(permit, fallback)
  -- The same source rename is the launch fence on both sides. Absence of a
  -- start marker, a PID probe, elapsed time, or a bridge exception is NOT proof.
  if os.rename(permit, permit .. ".revoked") then return failure("spawn_failed"), true end
  local reason = read_proof(permit)
  -- Missing/malformed proof is unknown ownership, not a cleanup failure.
  -- A late claim or sleep/wake may precede eventual proof or a valid callback.
  if not reason then return nil end
  if reason == "cleanup_failed" then return failure("cleanup_failed"), true end
  pcall(utils.log, "bounded_query completion_recovered")
  -- Completion proves cleanup, not the lost payload. Never invent success.
  return reason == "ok" and fallback or failure(reason), true
end

function M.new(options)
  assert(type(options) == "table" and type(options.argv) == "table" and #options.argv > 0,
    "argv required")
  assert(type(options.argv[1]) == "string" and options.argv[1]:sub(1, 1) == "/",
    "absolute executable required")
  local timeout = options.timeout_ms
  assert(type(timeout) == "number" and timeout % 1 == 0 and timeout >= 1000 and timeout <= 5000,
    "timeout_ms must be an integer from 1000 to 5000")
  assert(type(options.on_result) == "function", "on_result required")
  local prefix = {
    utils.shell_quote(assert(os.getenv("HOME")) .. "/.local/libexec/sketchybar-bounded-query"),
    "--timeout-ms", tostring(timeout),
  }
  local argv = {}
  for _, value in ipairs(options.argv) do
    assert(type(value) == "string" and not value:find("\0", 1, true), "argv must contain strings without NUL")
    argv[#argv + 1] = utils.shell_quote(value)
  end
  prefix = table.concat(prefix, " ")
  argv = table.concat(argv, " ")
  local on_result = options.on_result
  local job = {}
  local running, pending, closed, halted = false, false, false, false
  local current
  local function notify(result)
    if not closed and not pcall(on_result, result) then
      -- Neither consumer exceptions nor diagnostic I/O may change ownership.
      pcall(utils.log, "bounded_query callback_failed")
    end
  end

  function job:request()
    if closed or halted then return end
    if running then
      pending = true
      -- Recovery uses the existing heartbeat/request path, never another exec
      -- or timer. Wall-clock changes may delay/advance detection, but cannot
      -- authorize overlap: only revocation or cleanup evidence can do that.
      if current and not current.delivered and os.time() >= current.deadline then
        current.finish(recover(current.permit, failure("child_failed")))
      end
      return
    end
    running = true
    local allocated, permit = pcall(new_permit)
    if not allocated then permit = nil end
    local attempt = { permit = permit, deadline = os.time() + math.ceil(timeout / 1000) + 1 }
    current = attempt
    function attempt.finish(result, recovered)
      if attempt.delivered or current ~= attempt then return end
      if not result then
        -- Stay running/fenced and retain the original callback. Heartbeats
        -- keep checking evidence, but report this uncertainty only once.
        if not attempt.reported then
          attempt.reported = true
          pcall(utils.log, "bounded_query completion_unconfirmed")
          notify(failure("child_failed"))
        end
        return
      end
      attempt.delivered = true
      -- Fail closed: even heartbeat requests must not overlap an unclean group.
      halted = result.reason == "cleanup_failed"
      if not halted then retire(permit) end
      if halted then pcall(utils.log, "bounded_query cleanup_failed") end
      -- Cleanup proof cannot recover payload. If uncertainty was already
      -- reported, don't repeat the placeholder; the fresh query supplies data.
      if not (recovered and attempt.reported and result.reason == "child_failed") then
        notify(result)
      end
      running = false
      if pending then
        pending = false
        self:request()
      end
    end
    if not permit then attempt.finish(failure("spawn_failed")); return end
    local command = prefix .. " --permit " .. utils.shell_quote(permit) .. " -- " .. argv .. " 2>/dev/null"
    local function complete(result, exit_code)
      if attempt.delivered or current ~= attempt then return end
      local normalized, confirmed = normalize(result, exit_code)
      if confirmed then
        attempt.finish(normalized)
      else
        attempt.finish(recover(permit, normalized))
      end
    end
    local scheduled = pcall(Sbar.exec, command, complete)
    if not scheduled and not attempt.delivered then
      attempt.finish(recover(permit, failure("spawn_failed")))
    end
  end

  function job:close()
    closed, pending = true, false
    if current and not current.delivered and current.permit
      and os.rename(current.permit, current.permit .. ".revoked") then
      retire(current.permit)
      current.delivered = true
      running = false
    end
    -- This suppresses delivery, not OS cancellation. The supervisor still
    -- owns its group until cleanup finishes within the original deadline.
  end

  return job
end

return M
