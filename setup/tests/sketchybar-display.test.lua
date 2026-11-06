local root = assert(arg[1], "base root required")
package.path = root .. "/home/.config/sketchybar/?.lua;" .. package.path
local logs, requests, items = {}, {}, {}
local policy_text, policy_errno = "# exclude\n Blocked \n", nil
local real_open = io.open
-- Permission/proof files are an OS boundary, not runtime HOME state. Keep
-- them virtual so interrupted fixture queries cannot leave real temp files.
local permits, permit_sequence = {}, 0
local permit_prefix = "/tmp/sketchybar-display-fixture-permit-"
os.tmpname = function()
  permit_sequence = permit_sequence+1
  local path = permit_prefix .. permit_sequence
  permits[path] = ""
  return path
end
local real_remove, real_rename = os.remove, os.rename
os.remove = function(path)
  if path:sub(1,#permit_prefix) ~= permit_prefix then return real_remove(path) end
  permits[path] = nil
  return true
end
os.rename = function(from, to)
  if from:sub(1,#permit_prefix) ~= permit_prefix then return real_rename(from,to) end
  if permits[from] == nil then return nil,"missing",2 end
  permits[to], permits[from] = permits[from], nil
  return true
end
io.open = function(path, mode)
  if path:sub(1,#permit_prefix) == permit_prefix then
    if mode=="w" then permits[path]="" end
    if permits[path]==nil then return nil,"missing",2 end
    return {
      read=function() return permits[path] end,
      write=function(_,value) permits[path]=(permits[path] or "")..value; return true end,
      close=function() return true end,
    }
  end
  if path:match("/display_blocklist$") then
    if policy_errno then return nil, "fixture read failure", policy_errno end
    return {
      read = function() return policy_text end,
      close = function() return true end,
      lines = function() return (policy_text .. "\n"):gmatch("([^\n]*)\n") end,
    }
  end
  return real_open(path, mode)
end
local utils = require("lib.utils")
utils.log = function(s) logs[#logs+1] = s end
Sbar = {
  add = function(_, name, props)
    assert(not items[name], "duplicate controller item")
    local item = {props=props, callbacks={}}
    function item:subscribe(events, callback)
      for _, event in ipairs(events) do self.callbacks[event] = callback end
    end
    items[name] = item
    return item
  end,
  exec = function(command, callback)
    requests[#requests+1] = {command=command, callback=callback}
  end,
}
local display = require("lib.display")
assert(type(display.compute) == "function", "focus-independent display.compute is required")
assert(next(items) == nil and #requests == 0, "requiring policy must not start UI or queries")
local function snapshot(ids, names, fingerprint)
  local rows = {}
  for i,id in ipairs(ids) do
    rows[i] = {identity="uuid-"..i, name=names[i], sketchybar_id=id}
  end
  return {status="ready", topology_key=fingerprint or "fixture", displays=rows}
end
local data = snapshot({2,1,3}, {"Allowed", "Blocked", "Allowed2"})
local state = display.compute(data, {Blocked=true})
assert(state.status == "ready" and state.reason == "allowed")
assert(table.concat(state.allowed_ids, ",") == "2,3", "D01/D04: exclude by identity/name, sort output")
local attrs = display.attributes(state, true)
assert(attrs.drawing == true and attrs.display == "2,3")
assert(display.attributes(state, false).drawing == false)
for _,case in ipairs({
  {snapshot({1},{"Blocked"}), "all_excluded", "ready"},
  {snapshot({},{}), "no_displays", "ready"},
  {{status="error", reason="identity_unresolved"}, "identity_unresolved", "error"},
  {{status="error", reason="unexpected raw secret"}, "query_failed", "error"},
  {nil, "query_failed", "error"},
  {snapshot({1,1},{"Allowed","Allowed2"}), "identity_unresolved", "error"},
}) do
  local s = display.compute(case[1], {Blocked=true})
  assert(s.reason == case[2] and s.status == case[3])
  local a = display.attributes(s, true)
  assert(a.drawing == false and a.display == nil, "D05/D10: never broaden empty/error state to all")
end
local moved = display.compute(snapshot({1,2},{"Allowed","Blocked"}),{Blocked=true})
assert(table.concat(moved.allowed_ids,",") == "1", "D07: use new arrangement IDs")
assert(display.compute(data,nil,"policy_unreadable").reason == "policy_unreadable")
local blocklist = require("lib.blocklist")
local names,err = blocklist.read("/fixture/display_blocklist")
assert(names.Blocked and not err)
policy_errno = 2
names,err = blocklist.read("/fixture/display_blocklist")
assert(next(names)==nil and err==nil, "D11 missing file means no exclusions")
policy_errno = 13
names,err = blocklist.read("/fixture/display_blocklist")
assert(names==nil and err=="policy_unreadable", "D11 permission failure must not mean empty list")
policy_errno = nil
if arg[2] == "--policy-only" then print("PASS: display pure policy and blocklist"); return end

local received = {}
display.subscribe("fixture", function(s) received[#received+1]=s end)
assert(#requests==1 and #received==1 and received[1].generation==0)
local timer = assert(items["dotfiles.display_policy"])
assert(timer.props.drawing==false and timer.props.updates=="on" and timer.props.update_freq==60)
assert(not timer.callbacks.aerospace_workspace_change)
local function complete(index,payload)
  requests[index].callback({ok=true,reason="ok",exit_code=0,payload=payload},0)
end
complete(1,data)
assert(received[#received].generation==1)
local count = #received
timer.callbacks.display_change({SENDER="display_change",INFO="1"})
timer.callbacks.display_change({SENDER="display_change",INFO="2"})
timer.callbacks.display_change({SENDER="display_change",INFO="2"})
assert(#requests==2, "D14: no concurrent query on repeated focus events")
complete(2,data)
assert(#requests==3 and #received==count, "D02/D03: same snapshot not changed by focus; one pending query")
complete(3,data)
local notifications = #received
-- D06/D08: all excluded, then a wake snapshot with remapped allowed screen.
timer.callbacks.routine({SENDER="routine"})
complete(4,snapshot({1},{"Blocked"},"blocked-only"))
assert(received[#received].reason=="all_excluded")
timer.callbacks.system_woke({SENDER="system_woke"})
complete(5,snapshot({1,2},{"Allowed","Blocked"},"reconnected"))
assert(received[#received].allowed_ids[1]==1)
-- D09: no topology event; next hidden heartbeat (60 s) and a query <=5 s recover.
timer.callbacks.routine({SENDER="routine"})
complete(6,snapshot({3,2},{"Allowed","Blocked"},"missed-event"))
assert(received[#received].allowed_ids[1]==3)
-- D12/D14: pending events do not discard a successful in-flight result.
timer.callbacks.display_change({SENDER="display_change"})
for _=1,10 do timer.callbacks.display_change({SENDER="display_change"}) end
complete(7,snapshot({4,2},{"Allowed","Blocked"},"new-layout"))
assert(received[#received].allowed_ids[1]==4 and #requests==8)
complete(8,snapshot({4,2},{"Allowed","Blocked"},"new-layout"))
local current_count=#received
complete(7,data) -- duplicate/late callback must not roll back the newer state
assert(#received==current_count)
-- A policy change is noticed by a normal heartbeat even without a screen event.
policy_text="Allowed\n"
timer.callbacks.routine({SENDER="routine"})
complete(9,snapshot({4,2},{"Allowed","Blocked"},"new-layout"))
assert(received[#received].allowed_ids[1]==2)
policy_errno=13
timer.callbacks.routine({SENDER="routine"})
complete(10,data)
assert(received[#received].reason=="policy_unreadable")
policy_errno=nil; policy_text=""
timer.callbacks.forced({SENDER="forced"})
requests[11].callback({ok=false,reason="timeout",payload=nil},0)
assert(received[#received].status=="error" and received[#received].reason=="query_failed")
timer.callbacks.routine({SENDER="routine"})
complete(12,data)
assert(#received[#received].allowed_ids==3)
-- Subscriber replacement, defensive copies and module re-require cannot create a second owner.
local replaced=0
display.subscribe("fixture",function(s) replaced=replaced+1; s.allowed_ids[1]=999 end)
local latest
display.subscribe("second",function(s) latest=s end)
assert(latest.allowed_ids[1]~=999)
package.loaded["lib.display"]=nil
assert(require("lib.display")==display)
assert(#requests==12)
assert(not table.concat(logs,"\n"):find("unexpected raw secret",1,true))

-- Drive the real registered timer by its frequency, not by manually delivering
-- routine. Native hidden-item delivery is verified separately by the live probe.
local clock, due, source = 0, {}, snapshot({1},{"Blocked"},"clock-hidden")
Sbar.exec = function(command, callback)
  due[#due+1] = {at=clock+4, callback=callback, payload=source}
end
policy_text="Blocked\n"
display.request()
local function advance(target, focus_storm)
  while clock < target do
    clock=clock+1
    if clock % timer.props.update_freq == 0 and timer.props.updates=="on" then
      timer.callbacks.routine({SENDER="routine"})
    end
    if focus_storm then timer.callbacks.display_change({SENDER="display_change",INFO="2"}) end
    local ready={}
    while due[1] and due[1].at<=clock do ready[#ready+1]=table.remove(due,1) end
    for _,entry in ipairs(ready) do
      entry.callback({ok=true,reason="ok",exit_code=0,payload=entry.payload},0)
    end
  end
end
advance(4)
assert(latest.reason=="all_excluded")
source=snapshot({1},{"Allowed"},"clock-reconnected") -- lose every topology event
advance(59)
assert(latest.reason=="all_excluded", "no premature synthetic event")
advance(65)
assert(latest.reason=="allowed" and latest.allowed_ids[1]==1,
  "D09: scheduled hidden heartbeat and bounded query must recover within 65 seconds")
source=snapshot({1},{"Blocked"},"clock-hidden-again")
display.request(); advance(69)
assert(latest.reason=="all_excluded")
source=snapshot({2},{"Allowed"},"clock-focus-storm")
display.request(); advance(73,true)
assert(latest.reason=="allowed" and latest.allowed_ids[1]==2,
  "D14: repeated focus events must not starve the completed slow query")
print("PASS: D01-D14 policy, heartbeat contract, event coalescing, recovery and privacy")
