local function run(fail)
  local stopped,shutdown,loaded=0,0,{}
  local old={stop=function() stopped=stopped+1 end}
  local service={stop=function() stopped=stopped+1 end}
  local env=setmetatable({nudge=old,hs={shutdownCallback=function() shutdown=shutdown+1 end},
    require=function(name)
      loaded[name]=true
      if name=='nudge' then return {start=function() if fail then error('init failure') end; return service end} end
      return {}
    end},{__index=_G})
  assert(loadfile('home/.hammerspoon/init.lua','t',env))()
  assert(stopped==1,'Previous renderer must be stopped before replacing it')
  assert(loaded['modules.aerospace_alt_tab'] and loaded['modules.inactive_display_dim'])
  env.hs.shutdownCallback()
  assert(shutdown==1 and stopped==(fail and 1 or 2))
  if fail then assert(env.nudge.handle_json():find('failed to initialize',1,true)) end
end
run(false);run(true)
print('PASS: nudge-startup (cleanup, shutdown chaining, initialization isolation)')
