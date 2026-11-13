-- Real cafe module, isolated from user processes, files and native bar IPC.
local root = 'home/.config/sketchybar/'
local tests = 0
local function test(name, fn) fn(); tests = tests + 1; print('ok - ' .. name) end
local function harness(initial)
  local h = {pid=initial or '', jobs={}, logs={}}
  local utils = assert(loadfile(root .. 'lib/utils.lua'))()
  utils.capture = function() return h.pid end
  utils.log = function(message) h.logs[#h.logs+1] = message end
  local libs = {['lib.utils']=utils, ['lib.icons']=assert(loadfile(root .. 'lib/icons.lua'))(),
    ['lib.colors']=assert(loadfile(root .. 'lib/colors.lua'))(),
    ['lib.settings']=assert(loadfile(root .. 'lib/settings.lua'))()}
  local env = setmetatable({require=function(name) return assert(libs[name]) end}, {__index=_G})
  env.os = {getenv=function() return [[/tmp/Cafe ' home]] end,
    execute=function() error('toggle must not block the UI with os.execute') end}
  env.Sbar = {add=function(_, name, options)
    local item = {options=options, values={}, callbacks={}}
    function item:set(values) for k,v in pairs(values) do self.values[k]=v end end
    function item:subscribe(event, callback) self.callbacks[event]=callback end
    h.item = item
    return item
  end, exec=function(command, callback)
    if h.schedule_error then error('unavailable scheduler') end
    h.jobs[#h.jobs+1]={command=command, callback=callback}
  end}
  assert(loadfile(root .. 'items/cafe.lua', 't', env))()
  h.jobs = {}
  function h.click() h.item.callbacks['mouse.clicked']({}) end
  function h.routine() h.item.callbacks.routine({}) end
  function h.finish(index, code) h.jobs[index].callback('', code or 0) end
  function h.events()
    local n=0
    for _,job in ipairs(h.jobs) do
      if job.command:find('--trigger cafe_changed',1,true) then n=n+1 end
    end
    return n
  end
  return h, libs['lib.icons']
end

test('start waits for assertion readiness before notifying the detail bar', function()
  local h,icons=harness()
  h.click()
  assert(#h.jobs==1 and h.events()==0, 'start is asynchronous; no premature detail event')
  local command=h.jobs[1].command
  assert(command:find('caffeinate',1,true) and command:find('86400',1,true))
  assert(command:find('pmset',1,true) and command:find('sleep',1,true), 'wait for assertion, not just fork')
  h.pid='123'; h.finish(1)
  assert(h.events()==1 and h.item.values.icon==icons.square_rounded)
  assert(h.jobs[2].command:find('/.local/bin/sketchibar',1,true))
end)

test('stop waits for exit then emits event; repeated clicks cannot race', function()
  local h,icons=harness('123')
  h.click(); h.click(); h.routine()
  assert(#h.jobs==1 and h.events()==0, 'one toggle in flight')
  assert(h.jobs[1].command:find('kill',1,true) and h.jobs[1].command:find('123',1,true))
  assert(h.jobs[1].command:match('^pid=123%s+kill'), 'PID assignment and kill must be separate shell commands')
  assert(h.jobs[1].command:find('sleep',1,true), 'wait until process is gone')
  h.pid=''; h.finish(1)
  assert(h.events()==1 and h.item.values.icon==icons.square_rounded_minus)
end)

test('routine emits changes for external expiry but does not flood unchanged state', function()
  local h=harness('123')
  h.routine(); assert(h.events()==0)
  h.pid=''; h.routine(); assert(h.events()==1)
  h.routine(); assert(h.events()==1)
  h.pid='456'; h.routine(); assert(h.events()==2)
end)

test('failed toggles restore actual UI state and notify a refresh', function()
  local h,icons=harness()
  h.click(); h.finish(1,1)
  assert(h.item.values.icon==icons.square_rounded_minus and h.events()==1)
  h.click(); assert(#h.jobs==3, 'busy flag released after failure')
end)

test('invalid PID never reaches a kill command', function()
  local h=harness('123; unexpected')
  h.click()
  assert(#h.jobs==0, 'refuse invalid process identity')
end)

print('PASS: sketchybar-cafe (' .. tests .. ' tests)')
