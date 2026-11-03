-- Transient presentation only. Durable records remain owned by the service.
-- All clocks, screen state, scheduling and drawing are injected for plain Lua tests.
local copy = require('nudge.contract').copy
local equal = require('nudge.contract').deepEqual
local M = {}
function M.new(deps)
  local backend = deps.backend
  local self = {kind='canvas', records={}, seen={}, visible={}, sequence=0,
    initialized=false, subscribed=false, stopped=false, current_error=nil, displayed={}}
  local apply
  local function cancel()
    if self.timer then self.timer:stop(); self.timer=nil end
  end
  local function async_apply()
    if not self.stopped then pcall(apply) end -- apply records a sanitized error
  end
  local function schedule()
    cancel()
    local deadline
    for _, entry in pairs(self.visible) do
      deadline=math.min(deadline or entry.deadline,entry.deadline)
    end
    if deadline then self.timer=deps.after(math.max(0,deadline-deps.clock()),async_apply) end
  end
  local function ordered()
    local entries={}
    for _, entry in pairs(self.visible) do entries[#entries+1]=entry end
    table.sort(entries,function(a,b) return a.sequence>b.sequence end)
    return entries
  end
  apply=function()
    if self.stopped then return end
    local ok=pcall(function()
      if not self.subscribed then backend.subscribe(async_apply); self.subscribed=true end
      local now=deps.clock()
      if not backend.available() then self.visible={} end
      local screens=backend.screens()
      local used,cards={},{}
      for index, entry in ipairs(ordered()) do
        local frame=screens[entry.screen]
        local slot=(used[entry.screen] or 0)+1
        if entry.deadline<=now or not frame or frame.w<=28
          or slot*174-10>frame.h-28 or index>3 then
          self.visible[entry.record.id]=nil
        else
          used[entry.screen]=slot
          local width=math.min(360,frame.w-28)
          cards[#cards+1]={record=entry.record,frame={x=frame.x+frame.w-14-width,
            y=frame.y+14+(slot-1)*174,w=width,h=164}}
        end
      end
      backend.paint(cards)
      self.displayed={}
      for _,card in ipairs(cards) do self.displayed[card.record.id]=true end
    end)
    local scheduled=pcall(schedule)
    if not ok or not scheduled then
      self.current_error='Toast presentation failed; reconciliation will be retried'
      self.displayed={}
      error(self.current_error,0)
    end
    self.current_error=nil
  end
  function self:restore(active)
    if self.stopped then return end
    local records={}
    for _, record in ipairs(active) do
      records[record.id]=copy(record)
      if not self.initialized then self.seen[record.id]=copy(record) end
    end
    for id,entry in pairs(self.visible) do
      -- Reconciliation must not resurrect or refresh a stale presentation.
      if not records[id] or not equal(entry.record,records[id]) then self.visible[id]=nil end
    end
    for id in pairs(self.seen) do if not records[id] then self.seen[id]=nil end end
    self.records=records; self.initialized=true
    apply()
  end
  function self:upsert(record)
    if self.stopped then return end
    self.records[record.id]=copy(record)
    if self.seen[record.id] and equal(self.seen[record.id],record) then return end
    self.seen[record.id]=copy(record)
    self.sequence=self.sequence+1
    local now=deps.clock()
    local duration=record.expires_at and math.min(3,(record.expires_at-deps.wall())/1000) or 3
    -- Blocked events are consumed, never queued for the user's return.
    self.visible[record.id]=nil
    if backend.available() and duration>0 then
      local screen=backend.current_screen()
      if screen then self.visible[record.id]={record=copy(record),screen=screen,
        sequence=self.sequence,deadline=now+duration} end
    end
    apply()
  end
  function self:remove(id)
    if self.stopped then return end
    self.records[id]=nil; self.seen[id]=nil; self.visible[id]=nil
    apply()
  end
  function self:count()
    local n=0; for _ in pairs(self.records) do n=n+1 end; return n
  end
  function self:status(id)
    local n=0
    for key in pairs(self.displayed) do
      local entry=self.visible[key]
      if entry and entry.deadline>deps.clock() then n=n+1 end
    end
    local entry=id and self.visible[id]
    return {displayed_count=n,presented=not self.current_error and not self.stopped and
      (id and (self.displayed[id]==true and entry~=nil and entry.deadline>deps.clock()) or (id==nil and n>0)) or false,
      error=self.current_error}
  end
  function self:stop()
    if self.stopped then return end
    self.stopped=true; cancel(); self.visible={}; self.displayed={}
    backend.stop()
  end
  return self
end
return M
