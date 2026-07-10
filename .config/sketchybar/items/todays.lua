local colors = require("helpers.colors")
local settings = require("helpers.settings")
local utils = require("helpers.utils")
local display = require("helpers.lib.display")
local blocklist = require("helpers.lib.blocklist")

local ITEM = "todays"
local CACHE_FILE = "/tmp/sketchybar_todays_v2.cache"
local REQUEST_FILE = "/tmp/sketchybar_todays_refresh_request"
local BLOCKLIST_PATH = (os.getenv("HOME") or "") .. "/.config/sketchybar/display_blocklist"
local LABEL_MAX_CHARS = 20
local POPUP_SLOTS = 16
local ITEM_WIDTH = 210
local BLINK_BG_ALPHA_DIM = 18
local BLINK_BG_ALPHA_BRIGHT = 34
local BLINK_BORDER_ALPHA_DIM = 55
local BLINK_BORDER_ALPHA_BRIGHT = 100

local row_items = {}
local popup_open = false
local hide_for_blocked_display = false
local last_label = ""
local next_event = nil
local events = {}
local blink_phase = false

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

local monitor_blocklist = blocklist.read(BLOCKLIST_PATH)

local function refresh_display_gate()
  local target_id = display.resolve_target_id()

  if target_id ~= "" then
    todays:set({ display = target_id })
  else
    todays:set({ display = "all" })
  end

  local target_name = display.monitor_name_by_id(target_id)
  hide_for_blocked_display = (target_name ~= "" and monitor_blocklist[target_name] == true)
end

Sbar.add("event", "calendar_change")

todays = Sbar.add("item", ITEM, {
  position = "q",
  width = ITEM_WIDTH,
  icon = {
    drawing = true,
    string = "􀖇",
    color = colors.base04,
    padding_left = 8,
    padding_right = 4,
    font = { style = "Regular", size = settings.icon_size },
  },
  label = {
    drawing = true,
    align = "left",
    color = colors.foreground,
    padding_left = 10,
    padding_right = 10,
    font = { style = "Regular", size = settings.label_size },
  },
  background = {
    drawing = true,
    color = colors.background_alt,
    padding_left = 6,
    padding_right = 6,
    height = settings.defaults.bg_height + 4,
    corner_radius = settings.defaults.corner_radius,
    border_width = 0,
    border_color = colors.base08,
    y_offset = settings.defaults.bg_y_offset,
  },
  update_freq = settings.update_freq_fast,
  popup = {
    align = "left",
    drawing = false,
    background = {
      drawing = true,
      color = utils.set_alpha(colors.background_alt, 90),
      border_width = 0,
      corner_radius = 4,
    },
  },
})

for i = 1, POPUP_SLOTS do
  local name = string.format("%s.event.%d", ITEM, i)
  row_items[i] = Sbar.add("item", name, {
    position = "popup." .. ITEM,
    drawing = false,
    icon = { drawing = false },
    label = {
      drawing = true,
      align = "left",
      padding_left = 6,
      padding_right = 6,
      color = colors.foreground,
      font = { size = settings.label_size - 1 },
    },
    background = { drawing = false },
  })
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
  end

  return true
end

local function rebuild_popup()
  for i = 1, POPUP_SLOTS do
    local evt = events[i]
    if not evt then
      row_items[i]:set({ drawing = false })
    else
      local state = state_for_event(evt)
      local color = (state == "upcoming") and colors.foreground or colors.base04
      row_items[i]:set({
        drawing = true,
        label = string.format("%s  %s", evt.start, evt.title),
        ["label.color"] = color,
      })
    end
  end
end

local function apply_style()
  if hide_for_blocked_display or not next_event then
    todays:set({ drawing = false, ["popup.drawing"] = false })
    popup_open = false
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
  local padded = trim_and_pad(raw, LABEL_MAX_CHARS)
  if padded ~= last_label then
    todays:set({ label = padded })
    last_label = padded
  end

  local cal = tostring(next_event.calendar or "")
  local cal_lc = cal:lower()
  local icon_color = colors.base04
  if cal:find("정창권", 1, true) then
    icon_color = colors.base0b
  elseif cal_lc:find("me", 1, true) then
    icon_color = colors.base0a
  end

  todays:set({
    drawing = true,
    icon = "􀖇",
    ["icon.color"] = icon_color,
    ["label.color"] = label_color,
    ["background.border_width"] = border_width,
    ["background.border_color"] = border_color,
    ["background.color"] = bg_color,
  })
end

local function open_calendar_today()
  os.execute([[
open -a Calendar >/dev/null 2>&1;
osascript -e 'tell application "Calendar" to activate' >/dev/null 2>&1;
osascript -e 'tell application "System Events" to keystroke "t" using {command down}' >/dev/null 2>&1
]])
end

local function refresh()
  read_cache()
  rebuild_popup()
  apply_style()
end

todays:subscribe({ "routine", "calendar_change", "forced", "display_change", "system_woke" }, function(env)
  local sender = (env and env.SENDER) or ""
  if sender == "display_change" or sender == "forced" or sender == "system_woke" then
    refresh_display_gate()
  end
  refresh()
end)

todays:subscribe("mouse.clicked", function(env)
  local button = tostring((env and env.BUTTON) or "")
  if button == "right" or button == "2" then
    open_calendar_today()
    return
  end

  popup_open = not popup_open
  todays:set({ ["popup.drawing"] = popup_open })
  if popup_open then
    rebuild_popup()
  end
end)

os.execute("touch " .. REQUEST_FILE .. " >/dev/null 2>&1")
refresh_display_gate()
refresh()
