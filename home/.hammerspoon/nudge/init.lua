-- Host orchestration only; contract and core also run in ordinary Lua.
local contract = require('nudge.contract')
local core = require('nudge.core')
local M = {}
local function error_response(operation, code, message)
  return {ok=false, operation=operation or 'unknown', exit_code=code,
    error={message=message}, stored=false}
end
local function diagnostic(err, fallback)
  -- Only explicitly structured diagnostics are forwarded; arbitrary host errors
  -- can contain notification text. Never put a stack trace in normal output.
  if type(err)=='table' and type(err.message)=='string' then return err.message end
  return fallback
end

function M.new(deps)
  local self = {state=core.empty(), renderer=deps.renderer, applied_revision=nil,
    renderer_dirty=true, last_render_error=nil, storage_error=nil, busy=false}
  local store, clock = deps.store, deps.clock
  local function render_info()
    return {status=self.renderer_dirty and 'failed' or 'applied',
      renderer=self.renderer.kind or 'debug', presented=false}
  end
  local function render(events, force, now)
    local ok = pcall(function()
      if force or self.renderer_dirty then
        self.renderer:restore(core.visible(self.state, now))
      else
        for _, event in ipairs(events or {}) do
          if event.kind=='upsert' then self.renderer:upsert(event.record)
          else self.renderer:remove(event.id,event.reason) end
        end
      end
    end)
    if not ok then
      self.renderer_dirty=true
      self.last_render_error='Renderer application failed; full restore will be retried'
    else
      self.renderer_dirty=false
      self.applied_revision=self.state.revision
    end
    return ok
  end
  local function commit(next_state, events, now)
    if next_state.revision==self.state.revision then
      return true, false, render({},false,now)
    end
    local saved, err = pcall(function() assert(store:save(next_state)) end)
    if not saved then
      self.storage_error=diagnostic(err,'State persistence failed; previous snapshot retained')
      -- Expiry is a visibility rule even when durable cleanup cannot commit.
      -- Apply only expired removals, never an uncommitted upsert/dismiss. A full
      -- restore on every failed retry would repeatedly copy all live payloads.
      local expired_events={}
      for _, event in ipairs(events or {}) do
        if event.kind=='remove' and event.reason=='expired' then
          expired_events[#expired_events+1]=event
        end
      end
      render(expired_events,false,now)
      return false,false,not self.renderer_dirty
    end
    self.state=next_state
    self.storage_error=nil
    return true,true,render(events,false,now)
  end
  local function expire(now)
    local ok, state, _, events=pcall(core.transition,self.state,{operation='expire'},now,deps.id)
    if not ok then self.storage_error='Expiry transition failed'; return false end
    return commit(state,events,now)
  end
  local function startup()
    local read_ok, input=pcall(function() return store:config() end)
    if not read_ok then
      self.startup_error=diagnostic(input,'Configuration could not be read')
      self.startup_code=type(input)=='table' and input.code=='config_error' and 2 or 4
      return
    end
    local config_ok, config=pcall(contract.config,input)
    if not config_ok then
      self.startup_error=diagnostic(config,'Configuration could not be validated')
      self.startup_code=2; return
    end
    self.config=config
    local ok, err=pcall(function()
      store:initialize()
      self.state=store:load()
      core.validate(self.state)
    end)
    if not ok then
      self.startup_error=diagnostic(err,'State initialization or snapshot validation failed')
      self.startup_code=4; return
    end
    -- A failed expiry save is retryable, unlike a corrupt snapshot.
    expire(clock())
    render({},true,clock())
    self.timer=deps.timer(1,function()
      if self.busy then return end
      self.busy=true
      local tick_ok=pcall(function() expire(clock()) end)
      if not tick_ok then self.storage_error='Expiry timer failed; will retry' end
      self.busy=false
    end)
  end
  local ok=pcall(startup)
  if not ok then self.startup_error='Service startup failed'; self.startup_code=4 end

  local function handle(raw)
    if type(raw)~='string' or #raw>132096 then
      return error_response(nil,2,'Invalid or oversized IPC envelope')
    end
    local decoded_ok, decoded=pcall(contract.decode,raw)
    if not decoded_ok then return error_response(nil,2,'Invalid UTF-8 JSON request') end
    -- Quoting up to 64 KiB of original JSON can double the transport size.
    -- Only this data-only wrapper gets the larger budget; contract.request
    -- enforces the original user JSON byte limit before strict decoding.
    if #raw>65536 and not (type(decoded)=='table' and decoded.operation=='send'
      and type(decoded.request_json)=='string') then
      return error_response(nil,2,'Request exceeds 64 KiB')
    end
    -- Diagnose even when user configuration is broken. Built-in config is enough
    -- for doctor/capabilities envelope validation; blocked writes never reach core.
    local valid, request=pcall(contract.request,decoded,self.config or contract.config())
    if not valid then return error_response(nil,2,diagnostic(request,'Invalid request fields or values')) end
    local operation=request.operation
    if operation=='capabilities' then
      return {ok=true,operation=operation,exit_code=0,version=1,renderer='debug',
        presented=false, max_request_bytes=65536,max_active=1000,max_snapshot_bytes=8388608,
        operations=contract.array{'send','list','inspect','dismiss','doctor','capabilities'},
        defaults={ttl_seconds=86400,dedupe_seconds=10},stored=false}
    end
    if operation=='doctor' then
      if not self.startup_error then expire(clock()) end
      local count_ok,count=pcall(function() return self.renderer:count() end)
      local healthy=not self.startup_error and not self.storage_error and not self.renderer_dirty
      return {ok=healthy,operation=operation,exit_code=self.startup_code or
        (self.storage_error and 4 or (self.renderer_dirty and 5 or 0)),
        startup_error=self.startup_error, storage_error=self.storage_error, revision=self.state.revision,
        stored=false, renderer={kind=self.renderer.kind or 'debug',applied_revision=self.applied_revision,
          count=count_ok and count or 0,last_error=self.last_render_error,status=render_info().status,
          presented=false}}
    end
    if self.startup_error then return error_response(operation,self.startup_code,self.startup_error) end
    local now=clock()
    local transitioned,state,response,events=pcall(core.transition,self.state,request,now,deps.id)
    if not transitioned then
      local code=type(state)=='table' and state.code=='validation_error' and 2 or 4
      return error_response(operation,code,diagnostic(state,
        code==2 and 'State transition rejected' or 'State transition failed'))
    end
    if request.dry_run then
      response.exit_code=0; response.stored=false; response.render={status='skipped',renderer=self.renderer.kind,presented=false}
      return response
    end
    local saved,stored,rendered=commit(state,events,now)
    if not saved then
      if operation=='list' or operation=='inspect' then
        -- Preserve query data, computed with expired records excluded, but report
        -- the failed durable cleanup rather than pretending persistence succeeded.
        response.ok=false; response.error={message=self.storage_error}; response.exit_code=4
      else
        response=error_response(operation,4,self.storage_error)
      end
      response.revision=self.state.revision
    else
      response.exit_code=rendered and 0 or 5
      if not rendered then response.ok=false; response.error={message=self.last_render_error} end
    end
    response.stored=stored; response.render=render_info()
    return response
  end
  function self:handle_json(raw)
    if self.busy then return contract.encode(error_response(nil,4,'Service is busy')) end
    self.busy=true
    local handled,response=pcall(handle,raw)
    self.busy=false
    if not handled then response=error_response(nil,4,'Unexpected service error') end
    local encoded,result=pcall(contract.encode,response)
    if encoded then return result end
    return '{"ok":false,"exit_code":4,"stored":false,"error":{"message":"Response encoding failed"}}'
  end
  function self:stop() if self.timer then self.timer:stop(); self.timer=nil end end
  return self
end

-- No payload text is passed to a shell. These fixed filesystem commands only
-- receive shell-quoted paths generated from the user's home and UUID tokens.
function M.host_dependencies(root)
  local function quote(value)
    assert(type(value)=='string' and not value:find('\0',1,true),'Invalid filesystem path')
    return "'" .. value:gsub("'", "'\\''") .. "'"
  end
  local function command(value)
    local output,success,_,code=hs.execute(value,false)
    if not success or code~=0 then return nil,'filesystem command failed' end
    return output
  end
  local fs={}
  function fs.attributes(path)
    local attr,_,errno=hs.fs.symlinkAttributes(path)
    if attr then
      -- Unix permission bits do not account for macOS ACL grants. Escape names
      -- in ls output so a filename cannot impersonate a separate ACL entry.
      local listing=command('/bin/ls -ldeb '..quote(path))
      if not listing then error({code='storage_error',message='Cannot inspect storage ACL safely'}) end
      attr.has_acl=false; attr.inheritable_acl=false
      for line in listing:gmatch('[^\r\n]+') do
        if line:match('^%s*%d+:') then
          attr.has_acl=true
          local flags=line:match('%sallow%s+(.*)$') or line:match('%sdeny%s+(.*)$') or ''
          for flag in flags:gmatch('[^,%s]+') do
            if flag=='file_inherit' or flag=='directory_inherit' then attr.inheritable_acl=true end
          end
        end
      end
      return attr
    end
    if errno==2 then return nil,'missing' end
    -- hs.fs drops errno on some releases. Listing the parent distinguishes a
    -- missing entry from a permission/I/O failure without matching localized
    -- strerror text (and without silently resetting an unreadable snapshot).
    local parent,name=path:match('^(.*)/([^/]+)$')
    if parent and name then
      if parent=='' then parent='/' end
      local parent_attr,parent_error=fs.attributes(parent)
      if not parent_attr and parent_error=='missing' then return nil,'missing' end
      if parent_attr and parent_attr.mode=='directory' then
        local listed,found=pcall(function()
          for entry in hs.fs.dir(parent) do if entry==name then return true end end
          return false
        end)
        if listed and not found then return nil,'missing' end
      end
    end
    error({message='Cannot inspect storage path safely'})
  end
  function fs.mkdir(path) return command('umask 077; /bin/mkdir -m 700 '..quote(path))~=nil end
  function fs.chmod(path,mode)
    return command('/bin/chmod '..string.format('%o',mode)..' '..quote(path))~=nil
  end
  function fs.read(path,limit)
    local f=io.open(path,'rb'); if not f then return nil,'read failed' end
    local data,err=f:read(limit+1); local closed=f:close()
    if err or not closed then return nil,'read failed' end
    return data or ''
  end
  function fs.write_exclusive(path,data)
    -- noclobber refuses an existing file or symlink; the containing directory
    -- has already been verified owner-only before this operation.
    if not command('umask 077; set -C; : > '..quote(path)) then return nil,'create failed' end
    local f=io.open(path,'wb')
    if not f then os.remove(path); return nil,'open failed' end
    local written=f:write(data); local closed=f:close()
    if not written or not closed then os.remove(path); return nil,'write failed' end
    return true
  end
  fs.rename=os.rename
  fs.remove=os.remove
  local uid=tonumber(assert(command('/usr/bin/id -u')))
  assert(uid,'Cannot determine storage owner')
  local store=require('nudge.store').new({root=root or (assert(os.getenv('HOME'))..'/.nudge'),
    fs=fs,encode=contract.encode,decode=contract.decode,validate=core.validate,
    token=hs.host.uuid,uid=uid})
  return {store=store,renderer=require('nudge.renderers.debug').new(),
    clock=function() return math.floor(hs.timer.secondsSinceEpoch()*1000) end,
    id=hs.host.uuid,timer=function(seconds,callback) return hs.timer.doEvery(seconds,callback) end}
end
function M.start(root) return M.new(M.host_dependencies(root)) end
return M
