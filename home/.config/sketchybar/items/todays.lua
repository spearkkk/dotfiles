local colors = require("lib.colors")
local settings = require("lib.settings")
local utils = require("lib.utils")
local paths = require("lib.paths")
local display = require("lib.display")

local ITEM = "todays"
local DETAIL_ITEM = "sketchibar.todays"
local detail_binary = utils.shell_quote((os.getenv("HOME") or "") .. "/.local/bin/sketchibar")
local CACHE_FILE = paths.calendar_cache
local REQUEST_FILE = paths.calendar_refresh_request
local LABEL_MAX_CHARS = 20
local BLINK_BG_ALPHA_DIM = 18
local BLINK_BG_ALPHA_BRIGHT = 34
local BLINK_BORDER_ALPHA_DIM = 55
local BLINK_BORDER_ALPHA_BRIGHT = 100

local display_state = { status = "error", reason = "query_failed", allowed_ids = {}, generation = 0 }
local next_event = nil
local events = {}
local blink_phase = false
local detail_signature, detail_busy, detail_pending

local function trim(s)
  return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function split_tabs(line)
  local out = {}
  line = tostring(line or "")
  for token in (line .. "\t"):gmatch("(.-)\t") do
    out[#out + 1] = token
  end
  return out
end

local function to_minutes(hhmm)
  local h, m = tostring(hhmm or ""):match("^(%d%d):(%d%d)$")
  if not h or not m then
    return nil
  end
  return tonumber(h) * 60 + tonumber(m)
end

local function is_hhmm(v)
  return tostring(v or ""):match("^%d%d:%d%d$") ~= nil
end

local function now_minutes()
  local t = os.date("*t")
  return (t.hour * 60) + t.min
end

local function state_for_event(evt)
  local nowm = now_minutes()
  local sm = to_minutes(evt.start)
  local em = to_minutes(evt["end"])
  if not sm or not em then
    return "unknown"
  end
  if nowm >= em then
    return "past"
  end
  if nowm >= sm then
    return "ongoing"
  end
  return "upcoming"
end

local function utf8_chars(s)
  local out = {}
  for _, cp in utf8.codes(s or "") do
    out[#out + 1] = utf8.char(cp)
  end
  return out
end

local function trim_and_pad(s, max_chars)
  local chars = utf8_chars(s)
  local out = {}
  local n = math.min(#chars, max_chars)
  for i = 1, n do
    out[#out + 1] = chars[i]
  end
  while #out < max_chars do
    out[#out + 1] = " "
  end
  return table.concat(out, "")
end

local function split_trailing_paren_suffix(s)
  s = tostring(s or "")
  if s == "" or s:sub(-1) ~= ")" then
    return s, ""
  end

  local depth = 0
  local open_idx = nil
  for i = #s, 1, -1 do
    local ch = s:sub(i, i)
    if ch == ")" then
      depth = depth + 1
    elseif ch == "(" then
      depth = depth - 1
      if depth == 0 then
        open_idx = i
        break
      end
    end
  end

  if not open_idx or open_idx <= 2 then
    return s, ""
  end
  if s:sub(open_idx - 1, open_idx - 1) ~= " " then
    return s, ""
  end

  local base = trim(s:sub(1, open_idx - 2))
  local suffix = trim(s:sub(open_idx + 1, #s - 1))
  if base == "" or suffix == "" then
    return s, ""
  end
  return base, suffix
end

Sbar.add("event", "calendar_change")

-- The visible item lives in the display-only detail bar (see sketchibarrc). This
-- hidden item only receives events; the main bar never draws it.
local todays = Sbar.add("item", ITEM, {
  drawing = false,
  position = "left",
  width = 0,
  update_freq = settings.update_freq_fast,
})

local publish_detail
publish_detail = function(attrs)
  local keys = {}
  for key in pairs(attrs) do keys[#keys + 1] = key end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    local value = attrs[key]
    if type(value) == "boolean" then value = value and "on" or "off" end
    parts[#parts + 1] = utils.shell_quote(key .. "=" .. tostring(value))
  end
  local signature = table.concat(parts, " ")
  if signature == detail_signature then return end
  if detail_busy then detail_pending = attrs return end
  detail_busy = true
  detail_signature = signature
  local scheduled = pcall(Sbar.exec,
    detail_binary .. " --set " .. DETAIL_ITEM .. " " .. signature .. " >/dev/null 2>&1",
    function(_, exit_code)
      detail_busy = false
      -- Detail bar not running: retry on the next refresh instead of caching the failure.
      if exit_code ~= 0 then detail_signature = nil end
      local pending = detail_pending
      detail_pending = nil
      if pending then publish_detail(pending) end
    end)
  if not scheduled then
    detail_busy, detail_signature = false, nil
    utils.log("todays: could not schedule detail update")
  end
end

local function read_cache()
  local f = io.open(CACHE_FILE, "r")
  if not f then
    return false
  end

  events = {}
  next_event = nil

  local first = f:read("*l") or ""
  local header = split_tabs(first)
  local ok = (header[2] == "true")

  for line in f:lines() do
    if trim(line) ~= "" then
      local cols = split_tabs(line)
      local c1 = trim(cols[1])
      local c2 = trim(cols[2])
      local c3 = trim(cols[3])
      local c4 = trim(cols[4])

      if is_hhmm(c1) and is_hhmm(c2) and c3 ~= "" then
        local title = c3
        local calendar = c4 or ""
        if calendar == "" then
          title, calendar = split_trailing_paren_suffix(title)
        end

        events[#events + 1] = {
          start = c1,
          ["end"] = c2,
          title = title,
          calendar = calendar,
        }
      end
    end
  end
  f:close()

  if ok then
    local nowm = now_minutes()
    for _, evt in ipairs(events) do
      local endm = to_minutes(evt["end"])
      if endm and endm > nowm then
        next_event = evt
        break
      end
    end
    -- Descend into strictly contained, unfinished events; equal intervals
    -- retain their original order. Continue for nested events at any depth.
    while next_event do
      local outer_start = to_minutes(next_event.start)
      local outer_end = to_minutes(next_event["end"])
      local contained
      for _, evt in ipairs(events) do
        local startm = to_minutes(evt.start)
        local endm = to_minutes(evt["end"])
        if startm and endm and outer_start and outer_end
            and endm > nowm and endm > startm
            and startm >= outer_start and endm <= outer_end
            and (startm > outer_start or endm < outer_end) then
          contained = evt
          break
        end
      end
      if not contained then break end
      next_event = contained
    end
  end

  return true
end

local function apply_style()
  local attrs = display.attributes(display_state, next_event ~= nil)
  display.log_visibility(ITEM, display_state, next_event and "ready" or "no_upcoming_event", attrs.drawing)
  if not attrs.drawing then
    publish_detail(attrs)
    return
  end

  local label_color = colors.foreground
  local border_color = colors.base08
  local border_width = 0
  local bg_color = colors.background_alt
  local state = state_for_event(next_event)
  local is_near_3 = false

  if state == "ongoing" then
    bg_color = utils.set_alpha(colors.base08, 26)
    border_color = colors.base08
    border_width = 2
  else
    local nowm = now_minutes()
    local startm = to_minutes(next_event.start) or nowm
    local diff = startm - nowm
    if diff <= 3 and diff >= 0 then
      is_near_3 = true
      bg_color = utils.set_alpha(colors.base0a, BLINK_BG_ALPHA_BRIGHT)
    elseif diff <= 10 and diff >= 0 then
      bg_color = utils.set_alpha(colors.base0a, 26)
    elseif diff <= 30 and diff >= 0 then
      bg_color = utils.set_alpha(colors.base0b, 24)
    end
  end

  if is_near_3 then
    blink_phase = not blink_phase
    bg_color = utils.set_alpha(colors.base0a, blink_phase and BLINK_BG_ALPHA_BRIGHT or BLINK_BG_ALPHA_DIM)
    border_color = utils.set_alpha(colors.base0a, blink_phase and BLINK_BORDER_ALPHA_BRIGHT or BLINK_BORDER_ALPHA_DIM)
    border_width = 2
  else
    blink_phase = false
  end

  local raw = string.format("%s  %s", next_event.start, next_event.title)
  attrs.label = trim_and_pad(raw, LABEL_MAX_CHARS)
  attrs["label.color"] = label_color
  attrs["background.border_width"] = border_width
  attrs["background.border_color"] = border_color
  attrs["background.color"] = bg_color
  publish_detail(attrs)
end

local function refresh()
  read_cache()
  apply_style()
end

todays:subscribe({ "routine", "calendar_change", "forced", "system_woke" }, refresh)

-- The `sketchibar` wrapper triggers this after the detail bar restarts or is shown;
-- its item then starts blank, so forget what was last sent and publish again.
Sbar.add("event", "sketchibar_visibility")
todays:subscribe("sketchibar_visibility", function()
  detail_signature = nil
  refresh()
end)

os.execute("mkdir -p " .. utils.shell_quote(paths.cache_dir) .. "; touch " .. utils.shell_quote(REQUEST_FILE) .. " >/dev/null 2>&1")
display.subscribe(ITEM, function(state)
  display_state = state
  apply_style()
end)
refresh()
