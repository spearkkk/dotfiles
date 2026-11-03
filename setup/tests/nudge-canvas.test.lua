package.path='home/.hammerspoon/?.lua;home/.hammerspoon/?/init.lua;'..package.path
local ok,Canvas=pcall(require,'nudge.renderers.canvas');assert(ok,'Canvas backend is not implemented')
local theme=require('lib.theme')
local drawings,watchers={},{}
local frame={x=-100,y=20,w=1000,h=800}
local screen={id=function() return 7 end,frame=function() return frame end}
local locked=false
local h={canvas={windowLevels={overlay=100}},styledtext={},caffeinate={watcher={}},screen={},window={},mouse={}}
function h.styledtext.new(text,style) return {text=text,style=style} end
function h.canvas.new(f)
  local c={box=f}
  function c:frame(v) self.box=v;return self end
  function c:level(v) self.layer=v;return self end
  function c:behavior(v) if self.fail_behavior then self.fail_behavior=false;error('setup failed') end;self.behaviors=v;return self end
  function c:clickActivating(v) self.activating=v;return self end
  function c:canvasMouseEvents(...) self.mouse={...};return self end
  function c:replaceElements(...) self.elements={...};return self end
  function c:minimumTextSize(text) return {w=utf8.len(text.text)*text.style.font.size/2,h=20} end
  function c:show() self.shown=true;return self end
  function c:hide() self.shown=false;return self end
  function c:delete() self.deleted=true;self.shown=false end
  drawings[#drawings+1]=c;return c
end
function h.screen.allScreens() return {screen} end
function h.screen.mainScreen() return screen end
function h.window.focusedWindow() return {screen=function() return screen end} end
function h.mouse.getCurrentScreen() return screen end
function h.caffeinate.sessionProperties() return {CGSSessionScreenIsLocked=locked,kCGSSessionOnConsoleKey=true} end
local function watch(cb)
  local w={cb=cb};function w:start() self.started=true;return self end
  function w:stop() self.stopped=true end
  watchers[#watchers+1]=w;return w
end
h.screen.watcher={new=watch};h.caffeinate.watcher.new=watch
for i,name in ipairs{'screensDidLock','screensDidUnlock','screensDidSleep','screensDidWake',
  'systemWillSleep','systemDidWake','screensaverDidStart','screensaverDidStop',
  'sessionDidResignActive','sessionDidBecomeActive'} do h.caffeinate.watcher[name]=i end
local backend=Canvas.new(h,theme)
local changes=0;backend.subscribe(function() changes=changes+1 end)
assert(#watchers==2 and watchers[1].started and watchers[2].started)
assert(backend.current_screen()==7 and backend.screens()[7].x==-100 and backend.available())
local card={record={id='one',severity='success',source='build',content={title='한글 완료',subtitle='project-alpha',body='one\ntwo\nthree\nfour'}},frame={x=526,y=34,w=360,h=164}}
backend.paint{card}
local canvas=drawings[1]
assert(canvas.box.h==164 and canvas.shown and canvas.layer==101 and canvas.activating==false)
assert(canvas.mouse[1]==false and canvas.mouse[4]==false)
assert(canvas.behaviors[1]=='canJoinAllSpaces' and canvas.behaviors[2]=='fullScreenAuxiliary')
local elements=canvas.elements;local metadata,body,border,heading=false,{},false,false
for _,e in ipairs(elements) do
  if e.id=='border' then assert(e.strokeWidth==2 and e.strokeColor.hex=='#68BE92');border=true end
  if e.id=='heading' then assert(e.frame.h==82 and e.fillColor.red>0);heading=true end
  if e.id=='metadata' then assert(e.text:find('BUILD',1,true) and e.text:find('project-alpha',1,true));metadata=true end
  if e.id and e.id:match('^body') then body[#body+1]=e.text end
end
assert(metadata and border and heading and #body==3 and body[3]=='three…')
card.record.content={title='no body'};backend.paint{card};assert(#drawings==1 and canvas.box.h==164)
for _,e in ipairs(canvas.elements) do assert(not (e.id and e.id:match('^body'))) end
backend.paint{};assert(canvas.deleted)
locked=true;assert(not backend.available());locked=false
watchers[2].cb(h.caffeinate.watcher.systemWillSleep);assert(not backend.available())
watchers[2].cb(h.caffeinate.watcher.screensDidLock)
watchers[2].cb(h.caffeinate.watcher.systemDidWake);assert(not backend.available())
watchers[2].cb(h.caffeinate.watcher.screensDidUnlock);assert(backend.available() and changes==4)
-- Partially configured canvases must be configured again before a retry shows them.
local original_new=h.canvas.new
h.canvas.new=function(f) local c=original_new(f);c.fail_behavior=true;return c end
local success=pcall(function() backend.paint{card} end)
assert(not success)
local partial=drawings[#drawings]
backend.paint{card}
assert(partial.activating==false and partial.mouse[1]==false and partial.shown)
backend.stop();assert(watchers[1].stopped and watchers[2].stopped)
print('PASS: nudge-canvas (layout, Pelagic colors, clipping, passive windows, session watchers, cleanup)')
