package.path = './home/.hammerspoon/?.lua;./home/.hammerspoon/?/init.lua;' .. package.path
local loaded, service = pcall(require, 'nudge')
assert(loaded, 'Nudge service module must be implemented')
local contract = require('nudge.contract')
local core = require('nudge.core')
local debug_renderer = require('nudge.renderers.debug')
local tests = 0
local function test(name, fn) fn(); tests = tests + 1; print('ok - ' .. name) end
local function harness(config)
  local h = {now=1000000, ids=0, saves=0, disk=core.empty()}
  h.renderer = debug_renderer.new()
  local store = {}
  function store:config() if h.config_error then error(h.config_error) end; return config end
  function store:initialize() if h.init_error then error('unsafe storage') end end
  function store:load() if h.load_error then error('corrupt snapshot') end; return contract.copy(h.disk) end
  function store:save(state)
    h.saves = h.saves + 1
    if h.fail_save then error('write failed') end
    h.disk = contract.copy(state); return true
  end
  h.store = store
  function h.start()
    h.service = service.new({store=store, renderer=h.renderer,
      clock=function() if h.clock_error then error('clock fault') end; return h.now end,
      id=function()
        if h.id_error then error(h.id_error) end
        h.ids=h.ids+1; return string.format('00000000-0000-4000-8000-%012d',h.ids)
      end,
      sound=h.sound,
      timer=function(interval, cb) assert(interval==1); h.tick=cb; return {stop=function() h.stopped=true end} end})
    return h.service
  end
  function h.call(raw) return contract.decode(h.service:handle_json(raw)) end
  function h.send(title, ttl)
    return h.call(contract.encode(contract.object{operation='send', request=contract.object{source='test',key='job',content=contract.object{title=title or '완료'},policy=contract.object{ttl_seconds=ttl or 60}}}))
  end
  return h
end

for _, case in ipairs({
  {name='tagged storage failure', err={code='storage_error',message='Storage inspection failed'}, code=4},
  {name='untagged storage failure', err='private config read fault', code=4},
  {name='unknown storage failure tag', err={code='unexpected_error',message='Storage inspection failed'}, code=4},
  {name='tagged config decode failure', err={code='config_error',message='Invalid configuration JSON'}, code=2},
}) do
  test('config read classifies '..case.name, function()
    local h=harness(); h.config_error=case.err; h.start()
    local d=h.call('{"operation":"doctor"}')
    assert(not d.ok and d.exit_code==case.code,
      'expected config-read exit code '..case.code..', got '..tostring(d.exit_code))
    assert(d.startup_error and not d.stored and d.revision==0)
    local r=h.send(); assert(not r.ok and r.exit_code==case.code and not r.stored)
    assert(h.call('{"operation":"capabilities"}').ok)
    assert(h.saves==0 and h.ids==0 and h.renderer:count()==0)
    assert(not contract.encode(d):find('private config read fault',1,true))
    assert(not contract.encode(r):find('private config read fault',1,true))
  end)
end

test('decoded config validation failures remain argument errors', function()
  local h=harness(contract.object{defaults=contract.object{severity='unsupported'}}); h.start()
  local d=h.call('{"operation":"doctor"}')
  assert(not d.ok and d.exit_code==2 and d.startup_error)
  local r=h.send(); assert(not r.ok and r.exit_code==2 and not r.stored)
  assert(h.saves==0 and h.ids==0)
end)

test('persist before rendering and restore after restart', function()
  local h=harness(); h.start()
  local r=h.send(); assert(r.ok and r.result=='created' and r.stored and r.exit_code==0)
  assert(r.render.presented==false and r.render.status=='applied')
  assert(h.disk.revision==1 and #h.disk.active==1 and h.ids==1)
  local id=r.id
  h.service:stop(); assert(h.stopped)
  h.renderer=debug_renderer.new(); h.start()
  local read=h.call('{"operation":"inspect","source":"test","key":"job"}')
  assert(read.record.id==id)
  local d=h.call('{"operation":"doctor"}')
  assert(d.renderer.kind=='debug' and d.renderer.applied_revision==1 and d.renderer.count==1)
end)

test('save failure leaves durable memory and renderer untouched', function()
  local h=harness(); h.start(); local first=h.send('old'); h.fail_save=true
  local r=h.send('new'); assert(not r.ok and r.exit_code==4 and not r.stored)
  assert(h.disk.revision==1)
  local read=h.call('{"operation":"inspect","source":"test","key":"job"}')
  assert(read.record.content.title=='old' and read.record.id==first.id)
  assert(h.call('{"operation":"doctor"}').renderer.applied_revision==1)
end)

test('dry run validates through shared contract without IDs writes or rendering', function()
  local h=harness(); h.start()
  local r=h.call([[{"operation":"send","dry_run":true,"request":{"content":{"title":"한글\n\"quoted\""},"policy":{"ttl_seconds":0}}}]])
  assert(r.exit_code==0 and r.result=='dry_run' and r.request.source=='manual')
  assert(r.request.policy.ttl_seconds==0 and not r.stored and h.ids==0 and h.saves==0)
  assert(h.call('{"operation":"send","dry_run":true,"request":{"content":{"title":" "}}}').exit_code==2)
  assert(h.call('{"operation":"send","request":null}').exit_code==2)
  assert(h.call('[]').exit_code==2)
  assert(h.call('{"operation":"doctor","unknown":true}').exit_code==2)
end)

test('renderer failure preserves committed state then resynchronizes on next request', function()
  local h=harness(); h.start()
  local original=h.renderer.upsert
  h.renderer.upsert=function() error('renderer fault') end
  local r=h.send(); assert(r.exit_code==5 and r.stored and r.id and r.render.status=='failed')
  assert(h.disk.revision==1)
  h.renderer.upsert=original
  assert(h.call('{"operation":"list"}').exit_code==0)
  local d=h.call('{"operation":"doctor"}')
  assert(d.renderer.applied_revision==1 and d.renderer.count==1)
  assert(d.renderer.last_error)
end)

test('failed timer persistence hides expiry and retries next tick', function()
  local h=harness(); h.start(); h.send('short',1); h.now=h.now+1000; h.fail_save=true; h.tick()
  local r=h.call('{"operation":"list"}'); assert(r.active and #r.active==0)
  assert(#h.disk.active==1)
  local d=h.call('{"operation":"doctor"}')
  assert(d.storage_error and d.renderer.count==0)
  h.fail_save=false; h.tick(); assert(#h.disk.active==0 and h.disk.revision==2)
end)

test('startup config/store failure is diagnosable without leaking input', function()
  local h=harness(); h.load_error=true; h.start()
  local d=h.call('{"operation":"doctor"}')
  assert(not d.ok and d.exit_code==4 and d.startup_error)
  assert(h.send().exit_code==4)
  assert(h.call('{"operation":"capabilities"}').ok)
  local c=harness(contract.object{defaults=contract.object{severity='unsupported'}}); c.start()
  assert(c.call('{"operation":"doctor"}').exit_code==2)
end)

for _, case in ipairs({
  {name='untagged exception', err='private ID generation fault'},
  {name='unknown error tag', err={code='unexpected_error',message='ID generation failed'}},
}) do
  test('core internal failure returns code 4 for '..case.name, function()
    local h=harness(); h.start(); h.id_error=case.err
    local r=h.send()
    assert(not r.ok and r.exit_code==4,
      'expected internal-error exit code 4, got '..tostring(r.exit_code))
    assert(not r.stored and h.saves==0 and h.disk.revision==0 and h.service.state.revision==0)
    assert(h.renderer:count()==0)
    assert(not contract.encode(r):find('private ID generation fault',1,true))
    h.id_error=nil; assert(h.send().exit_code==0)
  end)
end

test('tagged core validation rejection remains an argument error', function()
  local h=harness(); h.start()
  local r=h.send('timestamp overflow',9007199254740991)
  assert(not r.ok and r.exit_code==2 and r.error.message and not r.stored)
  assert(h.saves==0 and h.disk.revision==0 and h.renderer:count()==0)
end)

test('timer clock failure releases busy guard and permits recovery', function()
  local h=harness(); h.start(); h.clock_error=true
  local ok=pcall(h.tick); h.clock_error=nil
  assert(ok, 'timer clock failure must be contained by the callback')
  assert(not h.service.busy, 'timer clock failure must release the busy guard')
  local d=h.call('{"operation":"doctor"}')
  assert(d.operation=='doctor' and d.storage_error and d.exit_code==4)
  assert(h.send().exit_code==0)
  h.tick(); assert(h.call('{"operation":"doctor"}').ok)
end)

test('request expiry and replacement are serialized into a single durable revision', function()
  local h=harness(); h.start(); local r=h.send('short',1); h.now=h.now+1000
  local n=h.send('fresh',60); assert(n.id~=r.id and h.disk.revision==2 and #h.disk.active==1)
  local same=h.send('fresh',60); assert(same.result=='suppressed' and not same.stored and h.disk.revision==2)
  local dismissed=h.call('{"operation":"dismiss","id":"'..n.id..'"}'); assert(dismissed.result=='dismissed')
  assert(h.call('{"operation":"dismiss","id":"'..n.id..'"}').result=='not_found')
end)

test('debug renderer does not alias caller records', function()
  local r=debug_renderer.new(); local a={id='abc',content={title='before'}}
  r:restore({a}); a.content.title='changed'; assert(r.records.abc.content.title=='before')
  r:upsert({id='def'}); r:remove('abc','dismissed'); assert(r:count()==1)
end)

-- Existing host modules must still load even if Nudge fails during require/start.
test('host init isolates Nudge startup failure from existing modules', function()
  local calls={}
  local env=setmetatable({require=function(name)
    calls[name]=true
    if name=='nudge' then error('startup fault') end
    return {}
  end, hs={printf=function() end}}, {__index=_G})
  local chunk=assert(loadfile('home/.hammerspoon/init.lua','t',env))
  assert(pcall(chunk)); assert(calls['modules.aerospace_alt_tab'] and calls['modules.inactive_display_dim'])
  assert(env.nudge and type(env.nudge.handle_json)=='function')
end)

-- Hammerspoon's lstat wrapper returns only nil/message, not POSIX errno.
-- The adapter must distinguish a genuinely absent name from inspection errors.
local function host_filesystem(listing, listed)
  local real_hs=hs
  local attrs={['/sandbox']={mode='directory',uid=501,permissions='rwx------',nlink=1}}
  hs={fs={
    symlinkAttributes=function(path) return attrs[path], 'localized error, no errno' end,
    dir=function(path)
      assert(path=='/sandbox')
      local names={'.','..','unreadable'}; local i=0
      return function() i=i+1; return names[i] end
    end}, execute=function(command,with_env)
      assert(with_env==false)
      if command=='/usr/bin/id -u' then return '501\n',true,'exit',0 end
      assert(command:match('^/bin/ls %-ldeb '), 'ACL inspection must escape filenames and list only the path')
      if listed==false then return 'private ACL inspection error',nil,'exit',1 end
      return listing or 'drwx------ 2 user staff 64 Nov 3 12:00 /sandbox\n',true,'exit',0
    end,
    host={uuid=function() return 'test-token' end},timer={},sound={}}
  local captured
  local original=package.loaded['nudge.store']
  package.loaded['nudge.store']={new=function(opts) captured=opts; return {} end}
  service.host_dependencies('/sandbox/new')
  local fake_hs=hs
  package.loaded['nudge.store']=original; hs=real_hs
  return captured.fs, fake_hs, attrs
end

test('host filesystem adapter detects absence without locale-dependent errors', function()
  local fs,fake_hs=host_filesystem(); local original=hs; hs=fake_hs
  local ok,attr,err=pcall(fs.attributes,'/sandbox/new')
  local unreadable_ok=pcall(fs.attributes,'/sandbox/unreadable')
  hs=original
  assert(ok and attr==nil and err=='missing')
  assert(not unreadable_ok)
end)

for _, case in ipairs({
  {name='no ACL', entry='', has_acl=false, inheritable=false},
  {name='noninherited HOME deny-delete ACL', entry=' 0: group:everyone deny delete\n', has_acl=true, inheritable=false},
  {name='file inheritance', entry=' 0: user:other allow read,file_inherit\n', has_acl=true, inheritable=true},
  {name='directory inheritance', entry=' 0: group:staff inherited allow list,directory_inherit\n', has_acl=true, inheritable=true},
  {name='inheritance-like principal name', entry=' 0: user:file_inherit allow read\n', has_acl=true, inheritable=false},
  {name='later inheritable entry', entry=' 0: group:everyone deny delete\n 1: user:other allow read,file_inherit\n', has_acl=true, inheritable=true},
}) do
  test('host filesystem adapter reports '..case.name, function()
    local listing='drwx------ 2 user staff 64 Nov 3 12:00 /sandbox\n'..case.entry
    local fs,fake_hs=host_filesystem(listing); local original=hs; hs=fake_hs
    local ok,attr=pcall(fs.attributes,'/sandbox'); hs=original
    assert(ok, 'ACL inspection failed')
    assert(attr.has_acl==case.has_acl, 'incorrect has_acl metadata')
    assert(attr.inheritable_acl==case.inheritable, 'incorrect inheritable_acl metadata')
  end)
end

test('host filesystem adapter fails closed when ACL inspection fails', function()
  local fs,fake_hs=host_filesystem(nil,false); local original=hs; hs=fake_hs
  local ok,err=pcall(fs.attributes,'/sandbox'); hs=original
  assert(not ok, 'failed ACL inspection must not yield trusted metadata')
  assert(not contract.encode(err):find('private ACL inspection error',1,true))
end)

test('host filesystem adapter quotes paths and ignores escaped filename ACL text', function()
  local path="/sandbox/quote'$(inert)\n 0: user:other allow file_inherit"
  local listing="-rw------- 1 user staff 0 Nov 3 12:00 /sandbox/quote'$(inert)\\n 0: user:other allow file_inherit\n"
  local fs,fake_hs,attrs=host_filesystem(listing)
  attrs[path]={mode='file',uid=501,permissions='rw-------',nlink=1}
  local execute=fake_hs.execute; local command
  fake_hs.execute=function(value,with_env) command=value; return execute(value,with_env) end
  local original=hs; hs=fake_hs
  local ok,attr=pcall(fs.attributes,path); hs=original
  assert(ok and attr.has_acl==false and attr.inheritable_acl==false)
  assert(command=="/bin/ls -ldeb '/sandbox/quote'\\''$(inert)\n 0: user:other allow file_inherit'")
end)

local function read_fixture(fs, file)
  local original=io.open
  io.open=function(path,mode) assert(path=='config fixture' and mode=='rb'); return file end
  local ok,data,err=pcall(fs.read,'config fixture',65536)
  io.open=original
  assert(ok,data)
  return data,err
end

test('host filesystem adapter returns empty bytes for an empty regular file', function()
  local fs=host_filesystem(); local file=assert(io.tmpfile())
  local data,err=read_fixture(fs,file)
  assert(data=='' and err==nil, 'EOF must be empty data, not a storage read error')
  assert(io.type(file)=='closed file')
end)

for _, case in ipairs({
  {name='read failure', data=nil, read_error='private read failure', closed=true},
  {name='close failure', data='', closed=nil},
}) do
  test('host filesystem adapter preserves '..case.name, function()
    local fs=host_filesystem()
    local data,err=read_fixture(fs,{
      read=function() return case.data,case.read_error end,
      close=function() return case.closed end})
    assert(data==nil and err=='read failed')
  end)
end


test('raw request transport preserves strict validation and large escaped payloads', function()
  local h=harness(); h.start()
  local title=string.rep('"',20000)
  local inner=contract.encode({content={title=title}})
  local wire=contract.encode({operation='send',request_json=inner,dry_run=true})
  assert(#inner<65536 and #wire>65536)
  local r=h.call(wire)
  assert(r.exit_code==0 and r.request.content.title==title and h.ids==0 and h.saves==0)
  for _,raw in ipairs({'{"content":{"title":"x"},"policy":{"ttl_seconds":01}}',
    '{"content":{"title":"x"},"context":{"a":NaN}}'}) do
    assert(h.call(contract.encode({operation='send',request_json=raw})).exit_code==2)
  end
  assert(h.call(contract.encode({operation='send',request_json=string.rep(' ',65537)})).exit_code==2)
  assert(h.call(string.rep(' ',132097)).exit_code==2)
  assert(h.call(string.rep(' ',65536)..'{"operation":"doctor"}').exit_code==2)
end)


test('failed expiry retries update visibility without restoring unchanged live records', function()
  local h=harness(); h.start(); h.send('short',1)
  assert(h.call('{"operation":"send","request":{"source":"test","key":"live","content":{"title":"live"},"policy":{"ttl_seconds":0}}}').ok)
  local restores=0
  local original=h.renderer.restore
  h.renderer.restore=function(self,active) restores=restores+1; return original(self,active) end
  h.fail_save=true; h.now=h.now+1000
  h.tick(); h.tick()
  assert(#h.disk.active==2 and h.renderer:count()==1)
  assert(restores==0,'failed retries must not repeatedly deep-copy unchanged visible records')
  h.fail_save=false; h.tick()
  assert(#h.disk.active==1 and h.renderer:count()==1)
end)

local function with_toast()
  local h=harness()
  h.ui_now=0; h.drawn={};h.allowed=true
  local backend={available=function() return h.allowed end,current_screen=function() return 'main' end,
    screens=function() return {main={x=0,y=0,w=1000,h=800}} end,
    subscribe=function(cb) h.ui_change=cb end,stop=function() h.ui_stopped=true;h.drawn={} end,
    paint=function(cards)
      if h.ui_failure then error('private canvas contents') end
      h.drawn=cards
    end}
  h.renderer=require('nudge.renderers.toast').new{backend=backend,
    clock=function() return h.ui_now end,wall=function() return h.now end,
    after=function(_,cb) h.ui_tick=cb;return {stop=function() end} end}
  return h
end

test('Canvas capabilities and doctor distinguish durable count from transient display',function()
  local h=with_toast();h.start()
  assert(h.call('{"operation":"capabilities"}').renderer=='canvas')
  local r=h.send();assert(r.render.presented and r.render.renderer=='canvas')
  local d=h.call('{"operation":"doctor"}')
  assert(d.renderer.count==1 and d.renderer.displayed_count==1 and d.renderer.presented)
  h.ui_now=3;h.ui_tick()
  d=h.call('{"operation":"doctor"}')
  assert(d.renderer.count==1 and d.renderer.displayed_count==0 and not d.renderer.presented)
  local same=h.send();assert(same.result=='suppressed' and not same.render.presented)
end)

test('Canvas restart restores durable state silently and accepts only fresh changes',function()
  local h=with_toast();h.start();local first=h.send();h.service:stop()
  local next=with_toast();next.disk=contract.copy(h.disk);next.start()
  assert(#next.drawn==0 and next.renderer:count()==1)
  local suppressed=next.send();assert(suppressed.result=='suppressed' and not suppressed.render.presented)
  local changed=next.send('changed');assert(changed.id==first.id and changed.render.presented)
end)

test('Canvas never receives unsaved changes or dry runs',function()
  local h=with_toast();h.start();h.fail_save=true
  assert(h.send().exit_code==4 and #h.drawn==0)
  h.fail_save=false
  assert(h.call('{"operation":"send","dry_run":true,"request":{"content":{"title":"preview"}}}').ok)
  assert(#h.drawn==0)
end)

test('dirty recovery delivers the new transaction event after restoring',function()
  local h=with_toast();h.start();h.ui_failure=true
  local first=h.send();assert(first.exit_code==5 and first.stored)
  h.ui_failure=false
  local second=h.call('{"operation":"send","request":{"source":"test","key":"other","content":{"title":"new"}}}')
  assert(second.ok and second.render.presented and #h.drawn==2)
end)

test('async Canvas failure is observed and retried by service timer',function()
  local h=with_toast();h.start();h.send();h.ui_now=3;h.ui_failure=true;h.ui_tick()
  local d=h.call('{"operation":"doctor"}')
  assert(d.exit_code==5 and d.renderer.last_error and not d.renderer.presented)
  assert(not contract.encode(d):find('private canvas contents',1,true))
  h.ui_failure=false;h.tick()
  d=h.call('{"operation":"doctor"}')
  assert(d.ok and d.renderer.displayed_count==0 and d.renderer.count==1)
end)

test('service stop releases renderer and refuses further requests',function()
  local h=with_toast();h.start();h.send();h.service:stop()
  assert(h.stopped and h.ui_stopped and #h.drawn==0)
  assert(h.send().exit_code==4)
end)

local function audible()
  local h=with_toast(); h.plays=0
  h.sound={play=function(_,spec)
    assert(h.disk.revision>0 and #h.drawn>0, 'sound must follow persistence and drawing')
    h.plays=h.plays+1; h.spec=spec
    if h.audio_failure then error('private file path') end
    return true
  end,status=function() return {last_error=h.async_error} end,
  stop=function() h.audio_stopped=true end}
  h.start()
  function h.alert(spec,extra)
    local request={source='test',key='job',content={title='sound'},sound=spec}
    return h.call(contract.encode({operation='send',request=request,dry_run=extra}))
  end
  return h
end

test('sound follows saved displayed upserts and suppressed calls stay silent',function()
  local h=audible(); local r=h.alert({name='Glass'})
  assert(r.ok and r.sound.status=='started' and h.plays==1 and h.spec.name=='Glass')
  r=h.alert({name='Glass'});assert(r.result=='suppressed' and r.sound.status=='skipped' and h.plays==1)
  h.now=h.now+1
  r=h.alert({file='/tmp/chime.wav'});assert(r.ok and h.plays==2 and h.spec.file=='/tmp/chime.wav')
  assert(h.call('{"operation":"inspect","source":"test","key":"job"}').record.sound.file=='/tmp/chime.wav')
  h.service:stop();assert(h.audio_stopped)
end)
test('sound is opt in and never plays for dry runs or unsaved requests',function()
  local h=audible();assert(h.send().sound.status=='not_requested' and h.plays==0)
  assert(h.alert(false).sound.status=='not_requested' and h.plays==0)
  assert(h.alert({name='Glass'},true).sound.status=='skipped' and h.plays==0)
  h.fail_save=true;assert(h.alert({name='Glass'}).exit_code==4 and h.plays==0)
end)
test('hidden and failed toasts consume sound without later replay',function()
  local h=audible();h.allowed=false
  assert(h.alert({name='Glass'}).sound.status=='skipped' and h.plays==0)
  h.allowed=true;h.ui_change();h.tick();assert(h.plays==0)
  h.ui_failure=true;h.now=h.now+1
  local r=h.alert({name='Ping'});assert(r.exit_code==5 and r.sound.status=='skipped' and h.plays==0)
  h.ui_failure=false;h.tick();assert(h.plays==0)
  h.call('{"operation":"list"}');h.call('{"operation":"dismiss","source":"test","key":"job"}')
  assert(h.plays==0)
end)
test('audio failure is a sanitized warning independent of renderer health',function()
  local h=audible();h.audio_failure=true
  local r=h.alert({name='Missing'});assert(r.ok and r.exit_code==0 and r.stored and r.render.presented)
  assert(r.sound.status=='failed' and r.sound.warning and not contract.encode(r):find('private file path',1,true))
  h.async_error='Sound playback failed'
  local d=h.call('{"operation":"doctor"}');assert(d.ok and d.sound.last_error=='Sound playback failed')
end)
test('restart restores sound records without playing and advertises audio support',function()
  local h=audible();h.alert({name='Glass'});h.service:stop()
  local n=audible();n.service:stop();n.disk=contract.copy(h.disk);n.start()
  assert(n.plays==0 and n.alert({name='Glass'}).result=='suppressed' and n.plays==0)
  assert(n.call('{"operation":"capabilities"}').sound.file==true)
end)

print('PASS: nudge-service ('..tests..' tests)')
