-- Immutable, host-independent state transitions. Persistence belongs to service.
local contract = require("nudge.contract")
local M = {}
local MAX_SAFE_INTEGER, MAX_ACTIVE = 9007199254740991, 1000
local function reject(message)
  error({code="validation_error",message=message}, 0)
end
local function integer(value)
  return type(value)=="number" and value>=0 and value<=MAX_SAFE_INTEGER and value%1==0
end
local function nonempty(value) return type(value)=="string" and #value>0 end
local function json_kind(value)
  local ok, result=pcall(contract.kind,value)
  return ok and result or nil
end
local function object_fields(value, allowed)
  if json_kind(value)~="object" then
    reject("invalid snapshot object")
  end
  for key in pairs(value) do if not allowed[key] then reject("invalid snapshot fields") end end
end
local function expires_at(now, ttl)
  if ttl==0 then return nil end
  if ttl>math.floor((MAX_SAFE_INTEGER-now)/1000) then reject("expiration timestamp out of range") end
  return now+ttl*1000
end
local request_fields = {version=true,source=true,event=true,key=true,severity=true,content=true,context=true,policy=true,sound=true}
local record_fields = {version=true,source=true,event=true,key=true,severity=true,content=true,context=true,policy=true,sound=true,
  id=true,created_at=true,updated_at=true,expires_at=true}
local function request_from(record)
  local result=contract.object{}
  for key in pairs(request_fields) do result[key]=record[key] end
  return result
end

function M.empty()
  return contract.object{version=1,revision=0,active=contract.array{}}
end

function M.validate(state)
  -- Validate each field once. Serializing the snapshot, active array, and each
  -- record repeatedly here can block Hammerspoon on every failed expiry retry.
  object_fields(state,{version=true,revision=true,active=true})
  if state.version~=1 then reject("unsupported snapshot version") end
  if not integer(state.revision) then reject("invalid snapshot revision") end
  if json_kind(state.active)~="array" then reject("invalid snapshot active array") end
  local count=0
  for index in pairs(state.active) do
    if not integer(index) or index<1 then reject("invalid snapshot active index") end
    count=count+1
  end
  if count>MAX_ACTIVE then reject("active record limit reached") end
  for index=1,count do
    if state.active[index]==nil then reject("invalid snapshot active array") end
  end
  local ids, keys={},{}
  for _, record in ipairs(state.active) do
    object_fields(record,record_fields)
    if not nonempty(record.id) or not pcall(contract.encode,record.id) then reject("invalid snapshot identifier") end
    if ids[record.id] then reject("duplicate snapshot identifier") end
    ids[record.id]=true
    if not pcall(contract.validate_normalized,request_from(record)) then reject("invalid normalized snapshot record") end
    if not integer(record.created_at) or not integer(record.updated_at) or record.updated_at<record.created_at then
      reject("invalid snapshot timestamps")
    end
    local expiration=expires_at(record.updated_at,record.policy.ttl_seconds)
    if record.expires_at~=expiration then reject("invalid snapshot expiration") end
    if record.key~=nil then
      local source_keys=keys[record.source] or {}; keys[record.source]=source_keys
      if source_keys[record.key] then reject("duplicate snapshot key") end
      source_keys[record.key]=true
    end
  end
  return state
end

local function clock(now)
  if not integer(now) then reject("invalid epoch milliseconds") end
end
local function expired(record, now) return record.expires_at~=nil and record.expires_at<=now end

function M.visible(state, now)
  clock(now)
  local active=contract.array{}
  for _, record in ipairs(state.active) do
    if not expired(record,now) then active[#active+1]=contract.copy(record) end
  end
  table.sort(active,function(a,b)
    if a.updated_at==b.updated_at then return a.id<b.id end
    return a.updated_at>b.updated_at
  end)
  return active
end

local function matches(record, envelope)
  if envelope.id~=nil then return record.id==envelope.id end
  return record.source==envelope.source and record.key==envelope.key
end
local function same_request(record, request)
  local a,b=contract.copy(request_from(record)),contract.copy(request)
  a.policy.preset=nil; b.policy.preset=nil
  return contract.deepEqual(a,b)
end

function M.transition(state, envelope, now, new_id)
  -- State is trusted after explicit load/save validation; do not serialize the
  -- entire snapshot on each request or on the one-second expiry timer.
  clock(now)
  local op=envelope.operation
  if op~="send" and op~="list" and op~="inspect" and op~="dismiss" and op~="expire" then reject("unsupported core operation") end
  local events=contract.array{}
  local response=contract.object{ok=true,operation=op,revision=state.revision}
  if op=="expire" then
    local any_expired=false
    for _, record in ipairs(state.active) do
      if expired(record,now) then any_expired=true; break end
    end
    if not any_expired then
      response.result="expired"
      return state,response,events
    end
  end
  -- Copy-on-write: unchanged records are immutable and can be shared. Only new
  -- or replaced records, response payloads, and renderer events need copying.
  local next_state=contract.object{version=state.version,revision=state.revision,active=state.active}
  if op=="send" then
    if not pcall(contract.validate_normalized,envelope.request) then reject("invalid normalized request") end
    if envelope.dry_run then
      response.result="dry_run"; response.request=contract.copy(envelope.request)
      return state,response,events
    end
  end

  -- Expire first, but only in the candidate. A failed save can retain old state.
  local live=contract.array{}
  for _, record in ipairs(next_state.active) do
    if expired(record,now) then events[#events+1]=contract.object{kind="remove",id=record.id,reason="expired"}
    else live[#live+1]=record end
  end
  next_state.active=live

  if op=="send" then
    local request=envelope.request
    local index,previous
    if request.key~=nil then
      for i,record in ipairs(live) do
        if record.source==request.source and record.key==request.key then index,previous=i,record; break end
      end
    end
    local elapsed=previous and (now-previous.updated_at)
    -- Divide instead of multiplying a potentially huge safe-integer duration.
    if previous and elapsed>=0 and elapsed/1000<request.policy.dedupe_seconds and same_request(previous,request) then
      response.result="suppressed"; response.id=previous.id
    else
      if not previous and #live>=MAX_ACTIVE then reject("active record limit reached") end
      local expiration=expires_at(now,request.policy.ttl_seconds)
      local record=contract.copy(request)
      if previous then
        if now<previous.created_at then reject("update timestamp precedes creation") end
        record.id=previous.id; record.created_at=previous.created_at
      else
        -- Deliberately do not pcall the generator: unexpected dependency errors
        -- are internal failures, not validation_error rejections.
        record.id=new_id()
        if not nonempty(record.id) or not pcall(contract.encode,record.id) then reject("invalid generated identifier") end
        for _, old in ipairs(state.active) do
          if old.id==record.id then reject("duplicate generated identifier") end
        end
        record.created_at=now
      end
      record.updated_at=now; record.expires_at=expiration
      response.result=previous and "updated" or "created"; response.id=record.id
      if not previous or not contract.deepEqual(previous,record) then
        live[index or (#live+1)]=record
        events[#events+1]=contract.object{kind="upsert",record=contract.copy(record)}
      end
    end
  elseif op=="list" then
    response.active=contract.array{}
    for _, record in ipairs(M.visible(next_state,now)) do
      if envelope.source==nil or record.source==envelope.source then response.active[#response.active+1]=record end
    end
  elseif op=="inspect" or op=="dismiss" then
    response.result="not_found"
    for i,record in ipairs(live) do
      if matches(record,envelope) then
        if op=="inspect" then
          response.result="found"; response.record=contract.copy(record)
        else
          response.result="dismissed"; response.id=record.id
          table.remove(live,i)
          events[#events+1]=contract.object{kind="remove",id=record.id,reason="dismissed"}
        end
        break
      end
    end
  else response.result="expired" end

  if #events>0 then
    if state.revision==MAX_SAFE_INTEGER then reject("snapshot revision limit reached") end
    next_state.revision=state.revision+1
  else next_state=state end
  response.revision=next_state.revision
  return next_state,response,events
end

return M
