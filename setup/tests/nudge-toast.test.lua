package.path='home/.hammerspoon/?.lua;home/.hammerspoon/?/init.lua;'..package.path
local ok, Toast=pcall(require,'nudge.renderers.toast')
assert(ok,'Toast renderer is not implemented')
local c=require('nudge.contract')
local tests=0
local function test(name,fn) fn(); tests=tests+1; print('ok - '..name) end
local function record(id,title,ttl)
  return {id=id,updated_at=1000,expires_at=ttl,content={title=title or id},severity='info',source='test'}
end
local function harness()
  local h={now=0,wall=1000,painted={},paints=0,allowed=true,screen='a',screens={a={x=0,y=0,w=1000,h=800}}}
  local b={}
  function b.available() return h.allowed end
  function b.current_screen() return h.screen end
  function b.screens() return h.screens end
  function b.paint(cards)
    h.paints=h.paints+1
    if h.fail then error('private notification failure') end
    h.painted=c.copy(cards)
  end
  function b.subscribe(cb) h.change=cb end
  function b.stop() h.stopped=true; h.painted={} end
  h.renderer=Toast.new{backend=b,clock=function() return h.now end,wall=function() return h.wall end,
    after=function(delay,cb)
      local task={at=h.now+delay,cb=cb}; h.task=task
      function task:stop() self.stopped=true end
      return task
    end}
  function h.advance(dt)
    h.now=h.now+dt; h.wall=h.wall+dt*1000
    if h.task and not h.task.stopped and h.task.at<=h.now then local t=h.task; h.task=nil;t.cb() end
  end
  function h.presented(id) return h.renderer:status(id).presented end
  return h
end

test('startup restores counts but never replays persisted alerts',function()
  local h=harness();h.renderer:restore{record('old')}
  assert(h.renderer:count()==1 and #h.painted==0 and not h.presented('old'))
  h.renderer:upsert(record('new'));assert(h.presented('new') and #h.painted==1)
end)
test('three-second expiry hides without dismissing durable records',function()
  local h=harness();h.renderer:restore{};h.renderer:upsert(record('a'))
  h.advance(2.999);assert(h.presented('a'))
  h.advance(.001);assert(not h.presented('a') and #h.painted==0 and h.renderer:count()==1)
  h.renderer:restore{record('a')};assert(#h.painted==0)
end)
test('identical event does not extend but same-timestamp replacement does',function()
  local h=harness();h.renderer:restore{};h.renderer:upsert(record('a'))
  h.advance(2);h.renderer:upsert(record('a'));h.advance(1);assert(not h.presented('a'))
  h.renderer:upsert(record('a','changed'));assert(h.presented('a'))
  h.advance(2);h.renderer:restore{record('a','changed')};h.advance(1);assert(not h.presented('a'))
end)
test('overflow discards oldest globally with no delayed replay',function()
  local h=harness();h.renderer:restore{}
  for _,id in ipairs{'a','b','c','d'} do h.renderer:upsert(record(id));h.advance(.1) end
  assert(#h.painted==3 and not h.presented('a') and h.painted[1].record.id=='d')
  assert(h.painted[1].frame.w==360 and h.painted[1].frame.h==164)
  assert(h.painted[1].frame.x==626 and h.painted[1].frame.y==14)
  assert(h.painted[2].frame.y==188)
  h.advance(3);assert(#h.painted==0 and h.renderer:count()==4)
end)
test('short TTL and explicit removal hide early',function()
  local h=harness();h.renderer:restore{};h.renderer:upsert(record('a','short',2000))
  h.advance(1);assert(not h.presented('a'))
  h.renderer:upsert(record('b'));h.renderer:remove('b','dismissed');assert(#h.painted==0 and h.renderer:count()==1)
end)
test('lock consumes events and wake never replays them',function()
  local h=harness();h.renderer:restore{};h.renderer:upsert(record('a'))
  h.allowed=false;h.change();assert(#h.painted==0)
  h.renderer:upsert(record('b'));assert(#h.painted==0 and h.renderer:count()==2)
  h.allowed=true;h.change();h.renderer:restore{record('a'),record('b')};assert(#h.painted==0)
  h.renderer:upsert(record('c'));assert(h.presented('c'))
end)
test('screen changes retain placement, remove disconnected cards and fit small screens',function()
  local h=harness();h.screens.b={x=-400,y=-200,w=300,h=370};h.renderer:restore{}
  h.renderer:upsert(record('a'));h.screen='b';h.renderer:upsert(record('b'));h.renderer:upsert(record('c'))
  assert(h.painted[1].frame.x==-386 and h.painted[1].frame.w==272)
  assert(h.painted[1].frame.y==-186)
  h.renderer:upsert(record('d'));assert(not h.presented('b'))
  h.screens.b=nil;h.change();assert(#h.painted==0)
  h.screen='a';h.screens.a.h=100;h.renderer:upsert(record('tiny'));assert(#h.painted==0)
end)
test('failed draw retains original deadline and recovers without replay',function()
  local h=harness();h.renderer:restore{};h.fail=true
  assert(not pcall(function() h.renderer:upsert(record('a')) end))
  assert(h.renderer:status().error and not h.presented('a'))
  h.advance(1);h.fail=false;h.renderer:restore{record('a')};assert(h.presented('a'))
  h.advance(2);assert(not h.presented('a'))
  h.renderer:restore{record('a')};assert(#h.painted==0)
end)
test('async draw failure is contained and diagnosable',function()
  local h=harness();h.renderer:restore{};h.renderer:upsert(record('a'));h.fail=true
  assert(pcall(function() h.advance(3) end));assert(h.renderer:status().error)
  h.fail=false;h.renderer:restore{record('a')};assert(#h.painted==0)
  assert(h.renderer:status().error==nil)
end)
test('restore removes stale cards but processes a subsequent new event',function()
  local h=harness();h.renderer:restore{};h.renderer:upsert(record('old'))
  h.renderer:restore{record('new')};assert(#h.painted==0)
  h.renderer:upsert(record('new'));assert(h.presented('new'))
end)
test('stop cancels callbacks and releases backend',function()
  local h=harness();h.renderer:restore{};h.renderer:upsert(record('a'));local cb=h.task.cb
  h.renderer:stop();h.renderer:stop();local paints=h.paints
  cb();h.change();assert(h.stopped and h.paints==paints and #h.painted==0)
end)
print('PASS: nudge-toast ('..tests..' tests)')
