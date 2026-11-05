-- Exercise the real Pomodoro module without touching user state or invoking IPC.
local root='home/.config/sketchybar/'
local tests=0
local function test(name,fn) fn();tests=tests+1;print('ok - '..name) end
local function harness(seed)
  local h={now=100000,disk=seed,items={},jobs={},shell={},logs={}}
  h.home=[[/tmp/Pomodoro ' home $(printf harmless)]]
  local settings=assert(loadfile(root..'lib/settings.lua'))()
  local utils=assert(loadfile(root..'lib/utils.lua'))()
  utils.log=function(message) h.logs[#h.logs+1]=message end
  local libs={['lib.settings']=settings,['lib.utils']=utils,
    ['lib.colors']={foreground='0xffffffff',base04='0xff444444',base0d='0xff00ffff',
      base0e='0xffff00ff',background_alt='0xff000000',base0a='0xffffff00'}}
  local env=setmetatable({require=function(name) return assert(libs[name],name) end},{__index=_G})
  env.os={getenv=function(name) if name=='HOME' then return h.home end;return os.getenv(name) end,
    time=function() return h.now end,execute=function(command) h.shell[#h.shell+1]=command;return true end}
  env.io={open=function(path,mode)
    assert(path==h.home..'/.pomodoro/pomo_state')
    if mode=='w' then
      local parts={}
      return {write=function(self,value) parts[#parts+1]=value;return self end,
        close=function() h.disk=table.concat(parts) end}
    end
    assert(mode=='r')
    if not h.disk then return end
    local data,pos=h.disk,1
    return {read=function()
      if pos>#data then return end
      local finish=data:find('\n',pos,true)
      local line=data:sub(pos,(finish or (#data+1))-1);pos=(finish or #data)+1;return line
    end,close=function() end}
  end}
  env.Sbar={add=function(_,name,options)
    local item={options=options,values={},callbacks={}}
    function item:set(values) for key,value in pairs(values) do self.values[key]=value end end
    function item:subscribe(event,callback) self.callbacks[event]=callback end
    h.items[name]=item;return item
  end,exec=function(command,callback)
    if h.fail_schedule then error('private scheduling diagnostic') end
    h.jobs[#h.jobs+1]={command=command,callback=callback}
  end}
  assert(loadfile(root..'items/pomodoro.lua','t',env))()
  function h.command(action) h.items.pomodoro_work.callbacks.pomodoro_change({ACTION=action}) end
  function h.advance(seconds)
    h.now=h.now+seconds
    h.items.pomodoro_work.callbacks.routine({})
    h.items.pomodoro_break.callbacks.routine({})
  end
  function h.args(index)
    -- Parse the generated shell words without executing the nudge executable.
    local p=assert(io.popen('set -- '..h.jobs[index].command..'; printf "%s\\0" "$@"','r'))
    local data=p:read('*a');assert(p:close())
    local result={};for value in data:gmatch('([^%z]*)%z') do result[#result+1]=value end
    assert(result[1]==h.home..'/.local/bin/nudge' and result[2]=='send')
    local flags={};for i=3,#result,2 do assert(result[i+1]);flags[result[i]]=result[i+1] end
    return flags
  end
  function h.finish(index,result,code) h.jobs[index].callback(result,code) end
  return h,settings
end

test('work completion queues nudge and starts short break without waiting',function()
  local h,s=harness();h.command('start');h.advance(s.pomodoro_work_seconds-1)
  assert(#h.jobs==0);h.advance(1)
  assert(#h.jobs==1,'work completion must use asynchronous nudge delivery')
  assert(h.disk:match('^break\n') and h.disk:match('\n1\nshort\n$'))
  local a=h.args(1)
  assert(a['--source']=='pomodoro' and a['--event']=='work-completed' and a['--preset']=='timer-ended')
  assert(a['--title']=='Pomodoro' and a['--subtitle']=='1 tomato done' and a['--body']=='Short break: 5 min')
  assert(a['--sound']=='Glass' and a['--ttl-seconds']=='60')
  assert(#h.shell==1,'only initial mkdir may use os.execute, never native notifications')
end)

test('four complete cycles preserve Glass Ping Hero mapping and reset after long break',function()
  local h,s=harness();h.command('start')
  for cycle=1,4 do
    h.advance(s.pomodoro_work_seconds)
    local a=h.args(#h.jobs)
    assert(a['--sound']==(cycle==4 and 'Hero' or 'Glass'))
    assert(a['--body']==(cycle==4 and 'Long break: 15 min' or 'Short break: 5 min'))
    h.advance(cycle==4 and s.pomodoro_long_break_seconds or s.pomodoro_short_break_seconds)
    a=h.args(#h.jobs)
    assert(a['--event']=='break-completed' and a['--sound']=='Ping' and a['--body']=='Work time: 25 min')
  end
  assert(#h.jobs==8 and h.disk:match('^work\n') and h.disk:match('\n0\nlong\n$'))
end)

test('manual commands and clicks remain silent',function()
  local h=harness();h.command('start');h.command('stop');h.command('break')
  h.items.pomodoro_break.callbacks['mouse.clicked']({BUTTON='secondary'})
  h.items.pomodoro_work.callbacks['mouse.clicked']({BUTTON='left'})
  assert(#h.jobs==0 and h.disk:match('^none\n'))
end)

test('restored elapsed phases notify once and preserve the long-break reset',function()
  for _,case in ipairs{
    {state='work\n98500\n3\nshort\n',sound='Hero',mode='break',count='4'},
    {state='break\n99100\n4\nlong\n',sound='Ping',mode='work',count='0'},
  } do
    local h=harness(case.state);assert(#h.jobs==0)
    h.advance(0);assert(#h.jobs==1 and h.args(1)['--sound']==case.sound)
    assert(h.disk:match('^'..case.mode..'\n') and h.disk:match('\n'..case.count..'\nlong\n$'))
    h.advance(0);assert(#h.jobs==1)
  end
end)

test('delivery faults log diagnostics without blocking or repeating transitions',function()
  for _,case in ipairs{
    {code=3,result={ok=false,error='private reply'}},
    {code=127,result='private stderr'},
    {code=5,result={ok=false}},
    {code=0,result='private malformed response'},
    {code=0,result={ok=false}},
    {code=0,result={ok=true,sound={status='failed',warning='private sound path'}}},
  } do
    local h,s=harness();h.command('start');h.advance(s.pomodoro_work_seconds)
    local before=#h.logs;h.finish(1,case.result,case.code)
    assert(#h.logs==before+1 and h.disk:match('^break\n') and #h.jobs==1)
    for _,message in ipairs(h.logs) do assert(not message:find('private',1,true)) end
    h.advance(1);assert(#h.jobs==1 and #h.shell==1)
  end
end)

test('successful or suppressed sound delivery does not log errors',function()
  for _,status in ipairs{'started','skipped'} do
    local h,s=harness();h.command('start');h.advance(s.pomodoro_work_seconds)
    local before=#h.logs;h.finish(1,{ok=true,sound={status=status}},0);assert(#h.logs==before)
  end
end)

test('scheduling exceptions cannot stop the next timer',function()
  local h,s=harness();h.fail_schedule=true;h.command('start');h.advance(s.pomodoro_work_seconds)
  assert(h.disk:match('^break\n') and #h.jobs==0)
  local found=false
  for _,message in ipairs(h.logs) do
    assert(not message:find('private',1,true))
    if message:find('nudge',1,true) then found=true end
  end
  assert(found)
end)

print('PASS: sketchybar-pomodoro ('..tests..' tests)')
