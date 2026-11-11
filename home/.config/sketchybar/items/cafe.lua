local icons = require("lib.icons")
local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")

local function caffeinate_pid()
  -- Ignore caffeinate processes spawned by Claude CLI sessions.
  return utils.capture([[
for pid in $(pgrep -x caffeinate 2>/dev/null); do
  ppid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  parent="$(ps -o command= -p "$ppid" 2>/dev/null)"
  case "$parent" in
    *"claude --resume"*) continue ;;
  esac
  echo "$pid"
  break
done
]])
end

local function update(item)
  local pid = caffeinate_pid()
  if pid == "" then
    item:set({ icon = icons.square_rounded_minus, ["icon.color"] = colors.base04 })
  else
    item:set({ icon = icons.square_rounded, ["icon.color"] = colors.base0a })
  end
end

local cafe = Sbar.add("item", "cafe", {
  position               = "right",
  width                  = settings.icon_cell_width,
  padding_left           = settings.defaults.padding_left,
  padding_right          = settings.defaults.padding_right,
  icon                   = icons.square_rounded_minus,
  ["icon.align"]         = "center",
  ["icon.font.size"]     = settings.icon_size,
  ["icon.color"]         = colors.base04,
  ["icon.padding_left"]  = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  ["label.drawing"]      = false,
  ["background.drawing"] = false,
  ["popup.height"] = 22,
  ["popup.align"] = "center",
  ["popup.y_offset"] = -4,
  ["popup.background.height"] = 20,
  ["popup.background.color"] = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_color"] = colors.border,
  ["popup.background.border_width"] = 2,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.drawing"] = true,
  update_freq            = 60,
})

local remaining = Sbar.add("item", "cafe_remaining", {
  position = "popup.cafe",
  icon = { drawing = false },
  label = {
    drawing = true,
    color = colors.foreground,
    font = { size = 12 },
    padding_left = settings.inner_padding,
    padding_right = settings.inner_padding,
  },
  background = { drawing = false },
})

-- Run the same process selection as the status indicator, but outside the
-- event loop and under a timeout. Only the selected PID's assertion counts.
local hover_script = [[
pid=
for candidate in $(/usr/bin/pgrep -x caffeinate 2>/dev/null); do
  ppid=$(/bin/ps -o ppid= -p "$candidate" 2>/dev/null | /usr/bin/tr -d ' ')
  parent=$(/bin/ps -o command= -p "$ppid" 2>/dev/null)
  case "$parent" in *"claude --resume"*) continue ;; esac
  pid=$candidate
  break
done
if [ -z "$pid" ]; then printf 'PID=none\n'; exit 0; fi
printf 'PID=%s\n' "$pid"
/usr/bin/pmset -g assertions
]]

local function remaining_label(raw)
  if type(raw) ~= "string" then return "--" end
  if raw:match("^PID=none\n?$") then return "Off" end
  local pid, text = raw:match("^PID=(%d+)\n(.*)$")
  if not pid then return "--" end
  local matching = false
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    local owner = line:match("^%s*pid%s+(%d+)%(")
    if owner then matching = owner == pid end
    local secs = matching and tonumber(line:match("Timeout will fire in (%d+) secs"))
    if secs then
      if secs > 0 and secs < 60 then return "<1m" end
      local minutes = math.floor(secs / 60)
      local hours = math.floor(minutes / 60)
      return hours > 0 and string.format("%dh %dm", hours, minutes % 60)
        or string.format("%dm", minutes)
    end
  end
  return "--"
end

local hovering, in_flight = false, false
local function open_popup()
  hovering = true
  remaining:set({ label = "--" })
  cafe:set({ ["popup.drawing"] = true })
  if in_flight then return end
  in_flight = true
  -- Launch agents may not inherit Homebrew's bin directory in PATH.
  local command = [[if [ -x /opt/homebrew/bin/uu-timeout ]; then timeout=/opt/homebrew/bin/uu-timeout;
elif [ -x /usr/local/bin/uu-timeout ]; then timeout=/usr/local/bin/uu-timeout;
else exit 127; fi; "$timeout" -k 1s 4s /bin/sh -c ]]
    .. utils.shell_quote(hover_script) .. " 2>/dev/null"
  local scheduled = pcall(Sbar.exec, command, function(output, exit_code)
    in_flight = false
    if hovering then remaining:set({ label = exit_code == 0 and remaining_label(output) or "--" }) end
  end)
  if not scheduled then in_flight = false end
end

cafe:subscribe("mouse.entered", open_popup)
cafe:subscribe({ "mouse.exited", "mouse.exited.global" }, function()
  hovering = false
  cafe:set({ ["popup.drawing"] = false })
end)

utils.log("cafe: loaded")
update(cafe)

cafe:subscribe("routine", function(env)
  update(cafe)
end)

cafe:subscribe("mouse.clicked", function(env)
  local pid = caffeinate_pid()
  if pid == "" then
    os.execute("nohup caffeinate -dimsu -t " .. settings.cafe_max_awake_seconds .. " >/dev/null 2>&1 &")
    utils.log("cafe: started caffeinate, max_seconds=" .. settings.cafe_max_awake_seconds)
  else
    os.execute("kill " .. pid .. " >/dev/null 2>&1")
    utils.log("cafe: stopped caffeinate")
  end
  update(cafe)
end)
