-- Hammerspoon-only effects behind the transient renderer's injected backend.
local fit=require('nudge.renderers.text')
local M={}
local labels={info='ⓘ 정보',success='✓ 성공',warning='! 주의',error='× 오류'}
local function tint(base,accent)
  local color={alpha=1}
  for i,key in ipairs{'red','green','blue'} do
    local offset=i*2
    color[key]=(tonumber(base.hex:sub(offset,offset+1),16)*.86+
      tonumber(accent.hex:sub(offset,offset+1),16)*.14)/255
  end
  return color
end
function M.new(h,theme)
  local backend,canvases,watchers,blocked={},{},{},{}
  local colors=theme.colors
  local status_colors={info=colors.info,success=colors.success,warning=colors.warn,error=colors.error}
  function backend.available()
    if next(blocked) then return false end
    local session=h.caffeinate.sessionProperties()
    return session~=nil and not session.CGSSessionScreenIsLocked and session.kCGSSessionOnConsoleKey~=false
  end
  function backend.current_screen()
    local win=h.window.focusedWindow()
    local screen=(win and win:screen()) or h.mouse.getCurrentScreen() or h.screen.mainScreen()
    return screen and screen:id()
  end
  function backend.screens()
    local screens={}
    for _,screen in ipairs(h.screen.allScreens()) do screens[screen:id()]=screen:frame() end
    return screens
  end
  function backend.subscribe(callback)
    if #watchers>0 then return end
    local ok=pcall(function()
      local screen=h.screen.watcher.new(callback);watchers[#watchers+1]=screen;screen:start()
      local w=h.caffeinate.watcher
      local changes={}
      for _,pair in ipairs{
        {'screensDidLock','screensDidUnlock'}, {'screensDidSleep','screensDidWake'},
        {'systemWillSleep','systemDidWake'}, {'screensaverDidStart','screensaverDidStop'},
        {'sessionDidResignActive','sessionDidBecomeActive'},
      } do
        if w[pair[1]] then changes[w[pair[1]]]={pair[1],true} end
        if w[pair[2]] then changes[w[pair[2]]]={pair[1],false} end
      end
      local watcher=w.new(function(event)
        local change=changes[event]
        if change then blocked[change[1]]=change[2] or nil;callback() end
      end)
      watchers[#watchers+1]=watcher;watcher:start()
    end)
    if not ok then
      for _,watcher in ipairs(watchers) do pcall(function() watcher:stop() end) end
      watchers={};error('Toast watcher setup failed',0)
    end
  end
  local function draw(canvas,card)
    local r,w=card.record,card.frame.w
    local status=assert(status_colors[r.severity],'Unsupported presentation severity')
    local outline={x=1,y=1,w=w-2,h=162}
    local radii={xRadius=12,yRadius=12}
    local elements={
      {type='rectangle',action='fill',frame=outline,roundedRectRadii=radii,fillColor=colors.surface},
      {type='rectangle',action='clip',frame=outline,roundedRectRadii=radii},
      {id='heading',type='rectangle',action='fill',frame={x=2,y=2,w=w-4,h=82},fillColor=tint(colors.surface,status)},
      {type='resetClip'},
      {id='border',type='rectangle',action='stroke',frame=outline,roundedRectRadii=radii,strokeColor=status,strokeWidth=2},
    }
    local function text(id,value,x,y,width,size,limit,color,bold)
      local font=bold and 'HelveticaNeue-Medium' or 'Helvetica Neue'
      local function measure(s)
        return canvas:minimumTextSize(h.styledtext.new(s,{font={name=font,size=size}})).w
      end
      local lines=fit.lines(value,math.max(0,width),limit,measure)
      for i,line in ipairs(lines) do
        elements[#elements+1]={id=id..(limit>1 and i or ''),type='text',text=line,
          frame={x=x,y=y+(i-1)*20,w=math.max(0,width),h=size==10 and 16 or 20},
          textColor=color,textFont=font,textSize=size,textLineBreak='clip',textAlignment='left'}
      end
      return measure(lines[1] or '')
    end
    local label=labels[r.severity]
    local label_width=text('severity',label,18,13,w-36,10,1,status,false)
    local meta=fit.single(r.source):upper()
    if r.content.subtitle and r.content.subtitle~='' then meta=meta..' · '..fit.single(r.content.subtitle) end
    text('metadata',meta,18+label_width+12,13,w-36-label_width-12,10,1,colors.fg,false)
    text('title',r.content.title,18,33,w-36,15,2,colors.strong,true)
    if r.content.body then text('body',r.content.body,18,93,w-36,12,3,colors.fg,false) end
    canvas:replaceElements(table.unpack(elements))
  end
  function backend.paint(cards)
    local wanted={}
    for _,card in ipairs(cards) do wanted[card.record.id]=true end
    for id,canvas in pairs(canvases) do
      if not wanted[id] then canvas:delete();canvases[id]=nil end
    end
    for _,card in ipairs(cards) do
      local id=card.record.id
      local canvas=canvases[id]
      if not canvas then
        canvas=assert(h.canvas.new(card.frame),'Cannot allocate toast canvas');canvases[id]=canvas
      end
      -- Reapply even after partial setup failure. A retry must never show a
      -- window with default (activating) mouse behavior.
      canvas:level(h.canvas.windowLevels.overlay+1)
      canvas:behavior({'canJoinAllSpaces','fullScreenAuxiliary'})
      canvas:clickActivating(false)
      canvas:canvasMouseEvents(false,false,false,false)
      canvas:frame(card.frame);draw(canvas,card);canvas:show()
    end
  end
  function backend.stop()
    local failed=false
    for _,watcher in ipairs(watchers) do
      if not pcall(function() watcher:stop() end) then failed=true end
    end
    watchers={}
    for id,canvas in pairs(canvases) do
      if pcall(function() canvas:delete() end) then canvases[id]=nil
      else failed=true;pcall(function() canvas:hide() end) end
    end
    if failed then error('Toast cleanup failed',0) end
  end
  return backend
end
return M
