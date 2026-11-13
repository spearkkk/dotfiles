local path = 'home/.config/sketchybar/items/expansion.lua'
local tests = 0
local function test(name, fn) fn(); tests=tests+1; print('ok - '..name) end
local function harness(defer)
  local file=io.open(path); assert(file, 'missing expansion hover controller');file:close()
  local h={jobs={},logs={},defer=defer,point={x=500,y=160}}
  local utils=assert(loadfile('home/.config/sketchybar/lib/utils.lua'))()
  utils.log=function(message) h.logs[#h.logs+1]=message end
  local env=setmetatable({require=function(name) assert(name=='lib.utils');return utils end}, {__index=_G})
  env.os={getenv=function() return [[/tmp/Bar ' home]] end}
  env.Sbar={add=function(kind,name,options)
    if kind=='event' then h.event=name;return end
    local item={options=options,callbacks={}}
    function item:subscribe(event,fn) self.callbacks[event]=fn end
    h.item=item;return item
  end,query=function(name)
    assert(name=='displays')
    if (h.display_failures or 0)>0 then h.display_failures=h.display_failures-1;error('temporary display query failure') end
    return {{frame={x=0,y=0,w=2560,h=1440}}}
  end,exec=function(command,callback)
    if h.throw then error('unavailable executor') end
    local job={command=command,callback=callback}
    h.jobs[#h.jobs+1]=job
    if command:find('CGEventGetLocation',1,true) then
      if (h.point_failures or 0)>0 then h.point_failures=h.point_failures-1;callback('',0) else callback(h.point,0) end
    elseif command:find('--query bar',1,true) then
      if (h.bar_failures or 0)>0 then h.bar_failures=h.bar_failures-1;callback('',0)
      else callback({height=80,y_offset=4,margin=0,position='top'},0) end
    elseif not command:find('sleep',1,true) and not h.defer then callback('',0) end
  end}
  assert(loadfile(path,'t',env))()
  function h.event_main(action) h.item.callbacks['mouse.'..action..'.global']({}) end
  function h.event_detail(action) h.item.callbacks.sketchibar_hover({ACTION=action}) end
  function h.finish(index,code) h.jobs[index].done=true;h.jobs[index].callback('',code or 0) end
  function h.run_timer()
    for i,job in ipairs(h.jobs) do
      if not job.done and job.command:find('sleep',1,true) then h.finish(i);return true end
    end
    return false
  end
  function h.commands()
    local commands={}
    for _,job in ipairs(h.jobs) do if job.command:find('--bar',1,true) then commands[#commands+1]=job.command end end
    return commands
  end
  return h
end

test('startup closes only the optional detail bar without changing geometry',function()
  local h=harness()
  assert(h.event=='sketchibar_hover')
  assert(h.item.options.drawing==false and h.item.options.updates=='on')
  local cmd=h.commands()[1]
  assert(cmd:find('/.local/bin/sketchibar',1,true) and cmd:find('hidden=on',1,true))
  assert(not cmd:find('height=',1,true) and not cmd:find('y_offset=',1,true))
end)

test('main hover opens and leaving both bars closes after 300 milliseconds',function()
  local h=harness();h.event_main('entered')
  assert(h.commands()[2]:find('hidden=off',1,true))
  h.event_main('exited')
  assert(#h.commands()==2, 'do not close immediately')
  assert(h.jobs[3].command=='/bin/sleep 0.3')
  h.finish(3)
  assert(h.commands()[3]:find('hidden=on',1,true))
end)

test('moving into detail cancels a pending main exit',function()
  local h=harness();h.event_main('entered');h.event_main('exited')
  h.point={x=500,y=64};h.event_detail('enter');h.finish(3)
  assert(h.commands()[#h.commands()]:find('hidden=off',1,true), 'stay open over the detail bar')
  h.point={x=500,y=160};h.event_detail('exit');h.finish(#h.jobs)
  assert(h.commands()[#h.commands()]:find('hidden=on',1,true))
end)

test('moving back to main or reentering cancels stale close callbacks',function()
  local h=harness();h.event_main('entered');h.event_main('exited')
  h.event_main('entered');h.finish(3)
  assert(#h.commands()==3 and h.commands()[3]:find('hidden=off',1,true))
  h.event_main('exited');h.event_detail('enter');h.event_detail('exit')
  local timer=#h.jobs
  h.event_main('entered');h.finish(timer)
  assert(h.commands()[#h.commands()]:find('hidden=off',1,true))
end)

test('overlapping tracking need not emit detail enter again after a main roundtrip',function()
  local h=harness();h.event_main('entered');h.event_detail('enter');h.event_main('exited')
  h.event_main('entered');h.event_main('exited')
  h.point={x=500,y=64}
  h.finish(#h.jobs)
  assert(h.commands()[#h.commands()]:find('hidden=off',1,true), 'actual pointer over detail wins over missing enter')
end)

test('detail entry supersedes a hide already queued behind a show',function()
  local h=harness(true);h.finish(1);h.event_main('entered')
  h.event_main('exited');h.finish(3)
  h.event_detail('enter');h.finish(2)
  assert(h.commands()[#h.commands()]:find('hidden=off',1,true), 'discard queued hide')
end)

test('out-of-order detail relays reconcile with actual cursor instead of staying open',function()
  local h=harness();h.event_main('entered');h.event_main('exited')
  h.event_detail('exit');h.event_detail('enter')
  h.point={x=500,y=160}
  h.finish(#h.jobs)
  assert(h.commands()[#h.commands()]:find('hidden=on',1,true), 'stale enter cannot keep detail open')
end)

test('visibility commands are serialized so late completion cannot win',function()
  local h=harness(true)
  h.event_main('entered');assert(#h.jobs==1,'opening waits for startup hide')
  h.finish(1);assert(#h.jobs==2 and h.jobs[2].command:find('hidden=off',1,true))
  h.event_main('exited');h.finish(3)
  assert(#h.commands()==2,'closing waits for in-flight open')
  h.event_main('entered') -- latest intent wins; discard queued hide
  h.finish(2)
  assert(h.jobs[#h.jobs].command:find('hidden=off',1,true))
end)

test('optional bar failures release queue and invalid relay actions do nothing',function()
  local h=harness(true);h.finish(1,1)
  h.event_detail('invalid');assert(#h.jobs==1)
  h.event_main('entered');assert(#h.jobs==2)
  h.finish(2,1);h.event_main('exited');h.finish(3)
  assert(h.commands()[3]:find('hidden=on',1,true))
end)

test('transient cursor, IPC and display failures retry instead of sticking open',function()
  for _,source in ipairs({'point_failures','bar_failures','display_failures'}) do
    local h=harness();h.event_main('entered');h.event_main('exited');h[source]=1
    assert(h.run_timer())
    assert(h.run_timer(),'failed reconciliation must schedule a retry: '..source)
    assert(h.commands()[#h.commands()]:find('hidden=on',1,true),'retry closes detail: '..source)
  end
end)

test('reconciliation retries are bounded and a re-entry cancels them',function()
  local h=harness();h.event_main('entered');h.event_main('exited');h.bar_failures=20
  for i=1,4 do assert(h.run_timer()) end
  assert(not h.run_timer(),'never poll failed IPC forever')
  assert(#h.logs==1,'exhaustion must be visible in diagnostics')
  local k=harness();k.event_main('entered');k.event_main('exited');k.bar_failures=1
  k.run_timer();k.event_main('entered');k.run_timer()
  assert(k.commands()[#k.commands()]:find('hidden=off',1,true),'old retry must not close a new hover')
end)

print('PASS: sketchybar-expansion ('..tests..' tests)')
