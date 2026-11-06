local root = assert(arg[1], "repo root required")
local paths = {}
local original_tmpname, original_time = os.tmpname, os.time
os.tmpname = function()
  local path = original_tmpname()
  paths[path] = true
  return path
end
local now = 100
os.time = function() return now end
local function run()
package.path = root .. "/home/.config/sketchybar/?.lua;" .. package.path
local file = io.open(root .. "/home/.config/sketchybar/lib/bounded_query.lua")
assert(file, "bounded_query module is not implemented")
file:close()
local query = require("lib.bounded_query")
-- Replace only diagnostic I/O, so even a regression cannot write HOME logs.
local utils = require("lib.utils")
local original_log = utils.log
local diagnostics = {}
utils.log = function(message) diagnostics[#diagnostics + 1] = message end
local calls, results = {}, {}
local calls_at_delivery = {}
Sbar = { exec = function(command, callback)
  local permit = assert(command:match("%-%-permit '([^']+)'"), "launch requires a unique permit")
  paths[permit] = true
  calls[#calls + 1] = { command = command, callback = callback, permit = permit }
end }
local schedule = Sbar.exec
local function claim(index)
  local permit = calls[index].permit
  assert(os.rename(permit, permit .. ".claimed"))
end
local function proof(index, reason)
  local file = assert(io.open(calls[index].permit .. ".done", "w"))
  file:write(reason .. "\n")
  file:close()
end
local function reply(index, result, status)
  -- Normal bridge callbacks follow helper termination. Model that boundary;
  -- absent-callback tests below explicitly claim/publish without replying.
  local permit = calls[index].permit
  if os.rename(permit, permit .. ".claimed") then
    local reason = type(result) == "table" and result.reason or "ok"
    proof(index, reason)
  end
  calls[index].callback(result, status or 0)
end
local success = { ok = true, reason = "ok", exit_code = 0, payload = { value = 0 } }
local job = query.new({ argv = { "/usr/bin/printf", "%s", "a ' ; $(x)\nb" }, timeout_ms = 1000,
  on_result = function(result)
    results[#results + 1] = result
    calls_at_delivery[#results] = #calls
  end })
assert(#calls == 0, "constructor must not execute")
job:request()
assert(calls[1], "bounded query must launch using a per-attempt permit")
local home = assert(os.getenv("HOME"))
local quote = require("lib.utils").shell_quote
assert(calls[1].command == table.concat({ quote(home .. "/.local/libexec/sketchybar-bounded-query"),
  "--timeout-ms", "1000", "--permit", quote(calls[1].permit), "--",
  quote("/usr/bin/printf"), quote("%s"), quote("a ' ; $(x)\nb") }, " ") .. " 2>/dev/null",
  "helper must use HOME and quote each argv element")
for _ = 1, 100 do job:request() end
assert(#calls == 1)
reply(1, success)
assert(#results == 1 and results[1].payload.value == 0 and #calls == 2)
assert(calls_at_delivery[1] == 1, "pending exec started before result delivery")
for _ = 1, 100 do job:request() end
reply(2, success)
assert(#results == 2 and #calls == 3, "request storms must not starve results")
assert(calls_at_delivery[2] == 2)
reply(1, success)
assert(#results == 2 and #calls == 3, "duplicate old callbacks must be ignored")
job:close()
reply(3, success)
job:request()
assert(#results == 2 and #calls == 3, "close suppresses callbacks and pending work")

calls, results = {}, {}
job = query.new({ argv = { "/usr/bin/true" }, timeout_ms = 5000,
  on_result = function(result) results[#results + 1] = result end })
job:request()
job:request()
reply(1, { ok = false, reason = "cleanup_failed", exit_code = 137 })
job:request()
assert(#results == 1 and results[1].reason == "cleanup_failed" and #calls == 1,
  "cleanup_failed must halt even later heartbeat retries")

calls, results = {}, {}
local calls_during_result
job = query.new({ argv = { "/usr/bin/true" }, timeout_ms = 1000,
  on_result = function(result) results[#results + 1] = result end })
job:request()
job:request()
reply(1, { ok = false, reason = "cleanup_failed", exit_code = 137 }, 1)
job:request()
assert(#calls == 1 and #results == 1 and results[1].reason == "cleanup_failed",
  "abnormal wrapper exit must not downgrade known cleanup failure to a retryable error")

calls, results = {}, {}
job = query.new({ argv = { "/usr/bin/true" }, timeout_ms = 1000,
  on_result = function(result) results[#results + 1] = result end })
job:request()
job:request()
reply(1, { ok = false, reason = "timeout", exit_code = 137 })
assert(#calls == 2 and results[1].reason == "timeout")
reply(2, success)
assert(#results == 2 and results[2].ok, "normal failure must allow recovery")
job:request()
reply(3, success, 9)
assert(not results[3].ok and results[3].payload == nil, "wrapper exit must be checked")
job:request()
reply(4, "PRIVATE raw invalid result")
assert(not results[4].ok and results[4].payload == nil and results[4].reason == "invalid_json")
job:request()
reply(5, { ok = true, reason = "ok", exit_code = 7, payload = "PRIVATE" })
assert(not results[5].ok and results[5].payload == nil, "inconsistent envelope is not success")

calls, results = {}, {}
job = query.new({ argv = { "/usr/bin/true" }, timeout_ms = 1000,
  on_result = function(result)
    results[#results + 1] = result
    job:request()
    job:request()
    calls_during_result = #calls
    job:close()
  end })
job:request()
reply(1, success)
assert(#calls == 1 and #results == 1)
assert(calls_during_result == 1, "reentrant requests wait for result delivery")
for _, message in ipairs(diagnostics) do
  assert(message ~= "bounded_query callback_failed", "unexpected consumer callback failure")
end

calls, results = {}, {}
diagnostics = {}
job = query.new({ argv = { "/usr/bin/true" }, timeout_ms = 1000,
  on_result = function(result)
    results[#results + 1] = result
    error("PRIVATE consumer callback data")
  end })
job:request()
job:request()
local callback_ok = pcall(reply, 1, success)
assert(callback_ok, "consumer exceptions must not escape the async callback")
assert(#calls == 2 and #results == 1, "throwing callback must release the slot and service pending work")
reply(2, success)
job:request()
assert(#calls == 3, "throwing callback must also permit later requests without pending work")
assert(#diagnostics == 2 and diagnostics[1] == "bounded_query callback_failed",
  "callback diagnostics must be sanitized")
reply(3, { ok = false, reason = "cleanup_failed", exit_code = 137 })
job:request()
assert(#calls == 3 and #results == 3, "callback exception must not bypass cleanup_failed halt")

local function fresh(timeout)
  calls, results, diagnostics = {}, {}, {}
  Sbar.exec = schedule
  return query.new({ argv = { "/usr/bin/true" }, timeout_ms = timeout or 1000,
    on_result = function(result) results[#results + 1] = result end })
end

-- Late claim across sleep/wake: the dispatch deadline does not establish
-- whether the supervisor has reached its own cleanup deadline.
for _, completion in ipairs({ "callback", "proof_only" }) do
  now = 100
  job = fresh(5000)
  job:request()
  now = 105
  claim(1)
  now = 106
  job:request()
  assert(#calls == 1 and #results == 1 and results[1].reason == "child_failed"
    and results[1].payload == nil, "unknown ownership must report failure without releasing the slot")
  job:request()
  assert(#calls == 1 and #results == 1, "unknown ownership must not overlap or repeat failure delivery")
  now = 107
  proof(1, "ok")
  if completion == "callback" then
    reply(1, success)
    assert(#calls == 2 and #results == 2 and results[2].ok,
      "original callback must remain eligible after an unknown-ownership report")
    reply(2, success)
    now = 167
    job:request()
    assert(#calls == 3, "later heartbeat must remain operational")
    reply(3, success)
  else
    now = 167
    job:request()
    assert(#calls == 2 and #results == 1,
      "later cleanup proof must permit one retry without repeating the placeholder failure")
    reply(2, success)
    reply(1, success)
    assert(#results == 2 and results[2].ok and #calls == 2,
      "proof-only recovery must restore queries and ignore the superseded callback")
  end
  job:close()
end

job = fresh()
job:request() -- exec silently returns; no helper claims the permit
local old_permit = calls[1].permit
for _ = 1, 100 do job:request() end
assert(#calls == 1 and #results == 0, "must not recover before the deadline")
now = now + 3
job:request()
assert(#calls == 2 and #results == 1 and results[1].reason == "spawn_failed",
  "silent fork failure must recover on a later heartbeat")
assert(calls[2].permit ~= old_permit, "revoked launch tokens must never be reused")
assert(not os.rename(old_permit, old_permit .. ".claimed"), "late invocation must be fenced")
reply(1, success)
assert(#results == 1 and #calls == 2, "revoked launch's callback cannot release the new slot")
reply(2, success)
assert(#results == 2 and results[2].ok)

for _, reason in ipairs({ "ok", "timeout", "cleanup_failed" }) do
  job = fresh()
  job:request()
  claim(1)
  proof(1, reason)
  now = now + 60
  job:request()
  assert(#results == 1 and not results[1].ok and results[1].payload == nil,
    "proof must never invent a lost successful payload")
  if reason == "cleanup_failed" then
    assert(#calls == 1 and results[1].reason == "cleanup_failed")
    job:request()
    assert(#calls == 1, "cleanup_failed proof must stop all automatic retries")
  else
    assert(#calls == 2 and results[1].reason == (reason == "ok" and "child_failed" or reason))
    reply(1, success)
    assert(#results == 1 and #calls == 2, "proof recovery must ignore old callbacks")
    job:close()
  end
end

for _, bad in ipairs({ "missing", "ok\nPRIVATE forged data", string.rep("x", 100) }) do
  job = fresh()
  job:request()
  claim(1)
  if bad ~= "missing" then proof(1, bad) end
  now = now + 60
  job:request()
  assert(#calls == 1 and #results == 1 and results[1].reason == "child_failed",
    "claimed without valid completion evidence must remain fenced")
  now = now + 60
  job:request()
  assert(#calls == 1 and #results == 1, "unknown ownership must not overlap or repeat failure delivery")
  proof(1, "ok")
  reply(1, success)
  assert(#calls == 2 and #results == 2 and results[2].ok,
    "missing or malformed proof must not permanently discard eventual completion")
  job:close()
  for _, message in ipairs(diagnostics) do assert(not message:find("PRIVATE", 1, true)) end
end

for _, completion in ipairs({ "callback", "proof_only" }) do
  job = fresh()
  job:request()
  claim(1)
  now = now + 60
  job:request()
  proof(1, "cleanup_failed")
  if completion == "callback" then
    reply(1, { ok = false, reason = "cleanup_failed", exit_code = 137 })
  else
    job:request()
  end
  assert(#calls == 1 and #results == 2 and results[2].reason == "cleanup_failed")
  now = now + 60
  job:request()
  reply(1, success)
  assert(#calls == 1 and #results == 2, "explicit cleanup_failed must still permanently halt")
end

job = fresh()
job:request()
claim(1)
calls[1].callback("PRIVATE malformed bridge output", 9)
job:request()
assert(#calls == 1 and results[1].reason == "child_failed",
  "abnormal callback without cleanup proof cannot release a claimed job")

job = fresh()
job:request()
local closing = calls[1].permit
job:close()
assert(not os.rename(closing, closing .. ".claimed"), "close must revoke an unclaimed delayed invocation")
now = now + 60
job:request()
reply(1, success)
assert(#calls == 1 and #results == 0)

job = fresh()
job:request()
claim(1)
job:close()
local owned = assert(io.open(calls[1].permit .. ".claimed"))
owned:close()
proof(1, "ok")
reply(1, success)
assert(#results == 0 and #calls == 1, "closing a claimed query only suppresses delivery")

Sbar.exec = function() error("PRIVATE bridge failure") end
results = {}
job = query.new({ argv = { "/usr/bin/true" }, timeout_ms = 1000,
  on_result = function(result) results[#results + 1] = result end })
job:request()
assert(#results == 1 and results[1].reason == "spawn_failed" and results[1].payload == nil)

job = fresh()
Sbar.exec = function(command, callback)
  schedule(command, callback)
  claim(1)
  error("PRIVATE bridge exception after launch")
end
job:request()
job:request()
assert(#results == 1 and results[1].reason == "child_failed" and #calls == 1,
  "a bridge exception does not prove nothing launched")
utils.log = original_log
print("PASS: bounded_query Lua async lifecycle")
end
local ok, err = xpcall(run, debug.traceback)
os.tmpname, os.time = original_tmpname, original_time
for path in pairs(paths) do
  for _, suffix in ipairs({ "", ".claimed", ".revoked", ".done", ".done.tmp" }) do os.remove(path .. suffix) end
end
assert(ok, err)
