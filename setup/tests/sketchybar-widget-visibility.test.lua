-- Real base items + display controller + bounded query. Only OS/IPC boundaries
-- are synthetic; no live cache, shell command, profile or UI is accessed.
local root = assert(arg[1], "BASE root required")
assert(not arg[2], "accepts BASE root only")
package.path = root .. "/home/.config/sketchybar/?.lua;" .. root .. "/home/.config/sketchybar/?/init.lua"
local home = "/tmp/sketchybar-widget-visibility-synthetic"
local calendar_path = home .. "/.cache/sketchybar/calendar.tsv"
local media_path = home .. "/.cache/sketchybar/media.tsv"
local real_date = os.date
local refs, requests, files, reads, logs, commands, now, minutes, creation_order, detail_todays
local temporary_serial = 0
local function is_permit_path(path)
  return type(path)=="string" and path:match("^/tmp/sketchybar%-widget%-visibility%-permit%-%d+[%w.]*$") ~= nil
end
local names = {"todays", "media_spacer", "media_label", "media_icon", "media_group"}

local function merge(target, props, prefix)
  for key,value in pairs(props) do
    local path = (prefix or "") .. key
    if type(value)=="table" then merge(target, value, path .. ".")
    else target[path]=value end
  end
end
local function event(name, sender, extra)
  local callback = assert(refs[name].callbacks[sender], name .. " missing " .. sender)
  local env = extra or {}; env.SENDER=sender
  callback(env)
end
local function snapshot(ids, labels)
  local rows = {}
  for i,id in ipairs(ids) do rows[i]={identity="fixture-"..i, name=labels[i], sketchybar_id=id} end
  return {status="ready", displays=rows, topology_key=table.concat(ids, ",")}
end
local allowed = snapshot({2,1,3}, {"Allowed", "Blocked", "Allowed2"})
local excluded = snapshot({1}, {"Blocked"})
local function complete(payload)
  local request = assert(table.remove(requests,1), "missing real controller query")
  -- Model the real helper boundary: atomically claim permission, then publish
  -- cleanup proof before delivering its bridge callback. All files are virtual.
  assert(os.rename(request.permit, request.permit .. ".claimed"))
  local proof=assert(io.open(request.permit .. ".done.tmp", "w"))
  proof:write("ok\n"); proof:close()
  assert(os.rename(request.permit .. ".done.tmp", request.permit .. ".done"))
  request.callback({ok=true, reason="ok", exit_code=0, payload=payload},0)
end
local function topology(payload, sender)
  event("dotfiles.display_policy", sender or "display_change", {INFO="ignored-focus-id"})
  complete(payload)
end
local function media(playing, title, age)
  files[media_path]=string.format("%d\ttrue\t%s\t%s\tPRIVATE_ARTIST", now-(age or 0), tostring(playing), title or "PRIVATE_TRACK_abcdefghijklmnopqrstuvwxyz")
end
local function calendar()
  files[calendar_path]="1000\ttrue\n10:10\t11:00\tPRIVATE_EVENT\tPRIVATE_CALENDAR\n"
end
-- The calendar item is drawn by the detail bar; what the hidden controller published is its state.
local function todays_state()
  local state = {}
  for key,value in pairs(detail_todays) do state[key]=value end
  state.drawing = state.drawing=="on"
  return state
end
local function visible(want, ids)
  for _,name in ipairs(names) do
    local props = name=="todays" and todays_state() or refs[name].props
    assert(props.drawing==want, name .. " drawing expected " .. tostring(want))
    if ids then assert(props.display==ids, name .. " association expected " .. ids) end
  end
end
local function media_visible(want, ids)
  for _,name in ipairs({"media_spacer", "media_label", "media_icon", "media_group"}) do
    assert(refs[name].props.drawing==want, name .. " drawing expected " .. tostring(want))
    if ids then assert(refs[name].props.display==ids, name .. " association expected " .. ids) end
  end
end
local function reason(widget, code)
  for i=#logs,1,-1 do
    if logs[i]:find("widget="..widget.." ",1,true) then
      assert(logs[i]:find("content_reason="..code.." ",1,true), logs[i]); return
    end
  end
  error("missing visibility log for " .. widget)
end
local function reset(empty)
  for name in pairs(package.loaded) do
    if name:match("^lib%.") or name:match("^items%.") then package.loaded[name]=nil end
  end
  _G.__dotfiles_display_policy=nil; _G.todays=nil
  refs, requests, files, reads, logs, commands = {}, {}, {}, {}, {}, {}
  detail_todays = {}
  creation_order = {}
  now, minutes = 10000, 600
  files[home.."/.config/sketchybar/display_blocklist"]="Blocked\n"
  os.getenv=function(key) if key=="HOME" then return home end end
  os.time=function() return now end
  os.date=function(format)
    if format=="*t" then return {hour=math.floor(minutes/60), min=minutes%60} end
    return real_date(format, now)
  end
  os.execute=function(command) commands[#commands+1]=command; return true end
  os.tmpname=function()
    temporary_serial=temporary_serial+1
    local path="/tmp/sketchybar-widget-visibility-permit-" .. temporary_serial
    files[path]="" -- POSIX os.tmpname reserves an empty file, not just a name.
    return path
  end
  os.rename=function(source, target)
    assert(is_permit_path(source) and is_permit_path(target), "non-permit rename forbidden")
    if files[source]==nil then return nil,"synthetic missing",2 end
    files[target],files[source]=files[source],nil
    return true
  end
  os.remove=function(path)
    assert(is_permit_path(path), "non-permit removal forbidden")
    if files[path]==nil then return nil,"synthetic missing",2 end
    files[path]=nil
    return true
  end
  io.popen=function() error("synchronous/focused display query forbidden") end
  io.open=function(path, mode)
    if is_permit_path(path) then
      mode=mode or "r"
      assert(mode=="r" or mode=="w", "unexpected permit open mode")
      if mode=="w" then files[path]="" end
      if files[path]==nil then return nil,"synthetic missing",2 end
      local offset=1
      return {
        read=function(_,count)
          assert(mode=="r" and type(count)=="number", "expected bounded completion-proof read")
          if offset>#files[path] then return nil end
          local text=files[path]:sub(offset,offset+count-1)
          offset=offset+#text
          return text
        end,
        write=function(self,text)
          assert(mode=="w", "permit is not writable")
          files[path]=files[path] .. text
          return self
        end,
        close=function() return true end,
      }
    end
    if path==home.."/.sketchybar.log" then
      assert(mode=="a")
      return {write=function(_,line) logs[#logs+1]=line end, close=function() end}
    end
    assert(mode=="r", "filesystem writes forbidden: " .. tostring(path))
    assert(path==calendar_path or path==media_path or path==home.."/.config/sketchybar/display_blocklist"
      or path=="/opt/homebrew/bin/nowplaying-cli", "unexpected filesystem read: " .. path)
    reads[path]=(reads[path] or 0)+1
    local contents=files[path]
    if contents==nil then return nil,"synthetic missing",2 end
    local offset=1
    return {
      read=function(_,format)
        if contents==false then return nil,"synthetic read error" end
        if format=="*a" then return contents end
        local line,ending=contents:match("([^\n]*)\n?()",offset)
        offset=ending
        return line
      end,
      lines=function()
        return function()
          if offset>#contents then return nil end
          local line,ending=contents:match("([^\n]*)\n?()",offset); offset=ending; return line
        end
      end,
      close=function() end,
    }
  end
  Sbar={
    add=function(kind,name,props,bracket_props)
      if kind=="event" then return end
      creation_order[#creation_order+1] = name
      props=bracket_props or props
      assert(not refs[name], "duplicate item: "..name)
      if name=="todays" or name:match("^media_") then
        assert(props.drawing==false, "W01: "..name.." must be explicitly hidden at declaration, before data")
      end
      local item={props={}, callbacks={}, sets={}}
      merge(item.props, props)
      function item:set(update)
        assert(update.display~="all", "must never broaden to all displays")
        self.sets[#self.sets+1]=update; merge(self.props,update)
      end
      function item:subscribe(events, callback)
        if type(events)=="string" then events={events} end
        for _,e in ipairs(events) do self.callbacks[e]=callback end
      end
      refs[name]=item; return item
    end,
    exec=function(command,callback)
      if command:find("/.local/bin/sketchibar' --set sketchibar.todays ",1,true) or command:find("/.local/bin/sketchibar --set sketchibar.todays ",1,true) then
        for pair in command:gmatch("'([^']*=[^']*)'") do
          local key,value=pair:match("^([^=]+)=(.*)$"); detail_todays[key]=value
        end
        if callback then callback("",0) end
        return
      end
      assert(command:find("sketchybar-bounded-query",1,true) and command:find("sketchybar-display-snapshot",1,true), "unexpected external query")
      local permit=assert(command:match("%-%-permit '([^']+)'"), "query launch must carry a permit")
      assert(is_permit_path(permit) and files[permit]~=nil, "query must reserve permission before launch")
      requests[#requests+1]={command=command,callback=callback,permit=permit}
    end,
    query=function() error("focused display query forbidden") end,
  }
  if not empty then calendar(); media(true) end
  require("items.todays"); require("items.media")
  assert(refs.media_spacer.props.width==8 and refs.media_spacer.props.position=="right", "now playing uses an 8px spacer")
  local positions={}
  for i,name in ipairs(creation_order) do positions[name]=i end
  assert(positions.media_spacer < positions.media_label, "spacer appears to the right of now playing")
  -- P01: only base modules are available; no work importer or subprocess.
  for name in pairs(package.loaded) do assert(not name:match("^profile"), "base imported work profile") end
  assert(#commands==1 and commands[1]:find("calendar.refresh",1,true), "unexpected collector/work execution")
  assert(#requests==1, "items must share one real display controller")
  for _,name in ipairs(names) do assert(not refs[name].callbacks.display_change, "controller alone owns display_change") end
end

local tests = {
  {"W01: explicit initial hide, no content and excluded startup", function()
    reset(true); visible(false); complete(allowed); visible(false,"2,3")
    reason("todays","no_upcoming_event"); reason("media","cache_missing")
    reset(); visible(false); complete(excluded); visible(false)
    reason("todays","ready"); reason("media","ready")
  end},
  {"D01-D07/W03: focus, ID swap while visible and recovery", function()
    reset(); complete(allowed); visible(true,"2,3")
    event("media_label","routine") -- consume one content tick, independent of display notifications
    local label=refs.media_label.props.label
    local calendar_reads,media_reads=reads[calendar_path],reads[media_path]
    local log_count=#logs
    for _=1,3 do topology(allowed) end
    visible(true,"2,3")
    assert(#logs==log_count, "unchanged focus must not repeat visibility logs")
    topology(snapshot({1,2,4},{"Allowed","Blocked","Allowed2"}))
    visible(true,"1,4")
    assert(refs.media_label.props.label==label, "display callback must not advance marquee")
    assert(reads[calendar_path]==calendar_reads and reads[media_path]==media_reads, "display callback must not reread content")
    topology(excluded); visible(false)
    topology(allowed); visible(true,"2,3")
    assert(refs.media_label.props.label==label, "hide/show must preserve scroll position")
    event("media_label","routine")
    assert(refs.media_label.props.label=="RIVATE_TRACK_abcdefghijk", "display callbacks must preserve next marquee tick")
  end},
  {"W03: hidden content updates render the newest track on recovery", function()
    reset(); complete(allowed)
    event("media_label","routine")
    topology(excluded)
    media(true,"NEW_PRIVATE_TRACK"); event("media_label","media_change")
    media_visible(false)
    topology(allowed); media_visible(true,"2,3")
    assert(refs.media_label.props.label=="NEW_PRIVATE_TRACK - PRIV", "recovery rendered stale track")
  end},
  {"W02: malformed cache fields never reach the marquee decoder", function()
    reset(); complete(allowed)
    for _,value in ipairs({now.."\ttrue\tinvalid\tPRIVATE_TRACK\t", now.."\ttrue\ttrue\t"..string.char(255).."\t"}) do
      files[media_path]=value; event("media_label","media_change")
      media_visible(false); reason("media","cache_invalid")
    end
  end},
  {"W02: upcoming, ongoing and ended calendar", function()
    reset(); complete(allowed); assert(todays_state().drawing)
    minutes=620; event("todays","routine"); assert(todays_state().drawing)
    minutes=660; event("todays","routine"); assert(not todays_state().drawing)
    reason("todays","no_upcoming_event")
    topology(snapshot({4,1},{"Allowed","Blocked"})); assert(not todays_state().drawing)
  end},
  {"calendar event is drawn by the detail bar; the controller has no hover, popup or click", function()
    reset(); complete(allowed)
    assert(refs.todays.props.drawing==false, "main-bar controller must stay hidden")
    assert(refs.todays.callbacks['mouse.entered']==nil and refs.todays.callbacks['mouse.exited']==nil
      and refs.todays.callbacks['mouse.clicked']==nil, "todays has no mouse behavior")
    assert(refs['todays.event.1']==nil, 'todays has no popup rows')
    assert(todays_state().label:find('PRIVATE_EVENT',1,true), "label is published to the detail bar")
  end},
  {"nested calendar event takes priority until it ends", function()
    reset(); complete(allowed)
    files[calendar_path] = '1000\ttrue\n09:00\t18:00\tOuter\tC\n14:00\t15:00\tInner\tC\n'
    for _, now_minutes in ipairs({600, 840, 899}) do
      minutes=now_minutes; event('todays','routine')
      assert(todays_state().label:find('Inner',1,true), 'inner event should win before and during it')
    end
    minutes=900; event('todays','routine')
    assert(todays_state().label:find('Outer',1,true), 'outer event returns when inner ends')
  end},
  {"calendar containment handles equal boundaries, deeper nesting and partial overlaps", function()
    reset(); complete(allowed)
    local cases = {
      {'09:00\t18:00\tOuter\tC\n09:00\t15:00\tInner\tC\n', 'Inner'},
      {'09:00\t18:00\tOuter\tC\n14:00\t18:00\tInner\tC\n', 'Inner'},
      {'09:00\t18:00\tOuter\tC\n14:00\t16:00\tMiddle\tC\n14:30\t15:00\tInner\tC\n', 'Inner'},
      {'09:00\t15:00\tFirst\tC\n14:00\t18:00\tSecond\tC\n', 'First'},
      {'09:00\t15:00\tFirst\tC\n09:00\t15:00\tSame\tC\n', 'First'},
      {'09:00\t18:00\tOuter\tC\n09:30\t09:59\tPast\tC\n', 'Outer'},
    }
    for _,case in ipairs(cases) do
      files[calendar_path]='1000\ttrue\n'..case[1]; minutes=600; event('todays','routine')
      assert(todays_state().label:find(case[2],1,true), 'unexpected selection for '..case[2])
    end
  end},
  {"W02: pause timeout survives focus and topology changes", function()
    reset(); complete(allowed)
    media(false); event("media_label","media_change"); media_visible(true)
    now=now+59; media(false); event("media_label","media_change"); media_visible(true)
    local label=refs.media_label.props.label
    topology(excluded); topology(allowed); media_visible(true)
    assert(refs.media_label.props.label==label)
    now=now+1
    topology(snapshot({4,1},{"Allowed","Blocked"})); media_visible(false,"4")
    reason("media","paused_timeout")
    media(false); event("media_label","media_change"); media_visible(false)
    media(true); event("media_label","media_change"); media_visible(true,"4")
  end},
  {"W02: 30-second cache boundary and distinct failure reasons", function()
    reset(); complete(allowed)
    media(true,nil,30); event("media_label","media_change"); media_visible(true); reason("media","ready")
    media(true,nil,31); event("media_label","media_change"); media_visible(false); reason("media","cache_stale")
    for _,value in ipairs({"malformed PRIVATE_INVALID", false, "0\ttrue\ttrue\tPRIVATE_TRACK\tPRIVATE_ARTIST"}) do
      files[media_path]=value; event("media_label","media_change"); media_visible(false); reason("media","cache_invalid")
    end
    files[media_path]=nil; event("media_label","media_change"); reason("media","cache_missing")
    media(true,""); event("media_label","media_change"); media_visible(false); reason("media","no_media")
    files[media_path]=now.."\tfalse\tfalse\t\t"; event("media_label","media_change"); reason("media","no_media")
    media(true); event("media_label","media_change"); media_visible(true,"2,3")
  end},
  {"P02: privacy-safe deduplicated display and content diagnostics", function()
    reset(); complete(allowed)
    for _=1,3 do event("media_label","routine"); event("todays","routine") end
    local count=#logs
    event("media_label","routine"); event("todays","routine")
    assert(#logs==count, "same content reason must not log on every tick")
    files[media_path]="PRIVATE_INVALID"; event("media_label","media_change")
    topology(excluded)
    local joined=table.concat(logs,"\n")
    assert(not joined:find("PRIVATE_",1,true), "private cache data leaked")
    assert(not joined:find("subscriber_failed",1,true), "synchronous subscription used incomplete item declarations")
    assert(joined:find("display_reason=all_excluded content_reason=cache_invalid visible=false",1,true))
    reason("todays","ready"); reason("media","cache_invalid")
  end},
}
local failed=0
for _,test in ipairs(tests) do
  local ok,err=pcall(test[2])
  if ok then print("PASS: "..test[1]) else failed=failed+1; print("FAIL: "..test[1].."\n  "..tostring(err)) end
end
assert(failed==0, tostring(failed).." widget visibility tests failed")
print("PASS: W01-W03/P01/P02 real base widgets, display controller and bounded query")
