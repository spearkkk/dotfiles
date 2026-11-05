package.path='home/.hammerspoon/?.lua;home/.hammerspoon/?/init.lua;'..package.path
local c=require('nudge.contract')
local function normalized(sound,config)
  return c.send({content={title='sound'},sound=sound},config)
end
local config=c.config({defaults={sound={name='Glass'}},presets={custom={sound={file='/tmp/a.wav'}}}})
assert(normalized(nil,config).sound.name=='Glass')
assert(normalized(false,config).sound==false)
local r=c.send({content={title='sound'},policy={preset='custom'},sound={name='Ping'}},config)
assert(r.sound.name=='Ping' and r.sound.file==nil, 'sound overrides must be atomic')
assert(c.send({content={title='sound'},policy={preset='custom'}},config).sound.file=='/tmp/a.wav')
for _,bad in ipairs{true,'Glass',{}, {name=''}, {name=' '}, {name='\0'}, {file='~/a.wav'},
  {file='relative.wav'}, {file='/tmp/a\0.wav'}, {name='Glass',file='/tmp/a.wav'}, {url='file:///tmp/a'}} do
  assert(not pcall(normalized,bad), 'invalid sound accepted')
end
local core=require('nudge.core')
local env={operation='send',request=normalized({name='Glass'})}
local state=core.transition(core.empty(),env,1000,function() return 'id' end)
assert(core.validate(state))
local old=core.transition(core.empty(),{operation='send',request=normalized(nil)},1000,function() return 'old' end)
assert(core.validate(old) and old.active[1].sound==nil)
local Sound=require('nudge.sound')
local h={created={},names={},files={}}
local function make()
  local o={}
  function o:setCallback(cb) self.cb=cb;return self end
  function o:loopSound(v) assert(v==false);self.loop=false;return self end
  function o:play() if h.throw then error('private audio path') end;self.playing=not h.fail;return not h.fail end
  function o:isPlaying() return self.playing end
  function o:stop() self.playing=false;self.stopped=true;if self.cb then self.cb(false,self) end;return self end
  h.created[#h.created+1]=o;return o
end
local sound=Sound.new{getByName=function(name) h.names[#h.names+1]=name;if name~='Missing' then return make() end end,
  getByFile=function(file) h.files[#h.files+1]=file;if file~='/missing' then return make() end end}
assert(sound:play({name='Glass'}) and h.names[1]=='Glass' and h.created[1].loop==false)
local first=h.created[1];first.playing=false;first.cb(true,first)
assert(sound:status().last_error==nil)
assert(sound:play({file='/tmp/chime with spaces.wav'}) and h.files[1]=='/tmp/chime with spaces.wav')
local second=h.created[2];second.playing=false;second.cb(false,second)
assert(sound:status().last_error and not sound:status().last_error:find('/tmp',1,true))
assert(not sound:play({name='Missing'}))
assert(not sound:play({file='/missing'}))
h.fail=true;assert(not sound:play({name='Ping'}));h.fail=false
h.throw=true;assert(not sound:play({name='Ping'}));h.throw=false
assert(sound:play({name='Ping'}));local last=h.created[#h.created]
sound:stop();assert(last.stopped and not first.stopped and not second.stopped)
assert(not sound:play({name='Glass'}))
-- Resolve names through system sound directories, never NSSound's shared cache.
local entries={['/custom/Library/Sounds']={'Glass.wav','Glass.aaa','Glass.aiff'},
  ['/Library/Sounds']={'Ping.aiff'},['/System/Library/Sounds']={'Glass.aiff','Hero.aiff'}}
local loads={}
local host={fs={dir=function(directory)
  local files=assert(entries[directory], 'missing directory');local i=0
  return function() i=i+1;return files[i] end
end},sound={getByName=function() error('shared named native sounds must not be used') end,
  getByFile=function(path)
    loads[#loads+1]=path
    if path:match('%.aaa$') then return nil end
    return make()
  end}}
local adapter=Sound.host_backend(host,'/custom')
local a=adapter.getByName('Glass');local b=adapter.getByName('Glass')
assert(a and b and a~=b, 'each named event must load an independent file object')
assert(loads[1]=='/custom/Library/Sounds/Glass.aaa' and loads[2]=='/custom/Library/Sounds/Glass.aiff')
assert(adapter.getByName('Hero') and loads[#loads]=='/System/Library/Sounds/Hero.aiff')
assert(adapter.getByName('Ping') and loads[#loads]=='/Library/Sounds/Ping.aiff')
assert(adapter.getByName('Missing')==nil and adapter.getByName('../Glass')==nil)
assert(adapter.getByFile('/tmp/local chime.wav') and loads[#loads]=='/tmp/local chime.wav')
local independent=Sound.new(adapter)
assert(independent:play({name='Glass'}));local one=h.created[#h.created]
assert(independent:play({name='Glass'}));local two=h.created[#h.created]
assert(one~=two and not one.stopped and not two.stopped)
independent:stop();assert(one.stopped and two.stopped)
print('PASS: nudge-sound (contract, compatibility, resolution, loading, failures, callbacks, cleanup)')
