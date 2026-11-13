local icons = require("lib.icons")
local colors   = require("lib.colors")
local settings = require("lib.settings")
local utils    = require("lib.utils")
local last_pid
local toggle_busy = false
local detail_binary = utils.shell_quote((os.getenv("HOME") or "") .. "/.local/bin/sketchibar")

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

local function update(item, force)
  local pid = caffeinate_pid()
  if pid == "" then
    item:set({ icon = icons.square_rounded_minus, ["icon.color"] = colors.base04 })
  else
    item:set({ icon = icons.square_rounded, ["icon.color"] = colors.base0a })
  end
  if force or pid ~= last_pid then
    last_pid = pid
    -- Each bar has its own event endpoint. The optional detail bar owns its
    -- query; never wait for it or send an optimistic on/off value.
    pcall(Sbar.exec, detail_binary .. " --trigger cafe_changed >/dev/null 2>&1", function() end)
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
  update_freq            = 60,
})

utils.log("cafe: loaded")
update(cafe)

cafe:subscribe("routine", function(env)
  if not toggle_busy then update(cafe) end
end)

cafe:subscribe("mouse.clicked", function(env)
  if toggle_busy then return end
  local pid = caffeinate_pid()
  if pid ~= "" and not pid:match("^%d+$") then
    utils.log("cafe: refused invalid process identity")
    return
  end
  local command
  if pid == "" then
    command = "nohup /usr/bin/caffeinate -dimsu -t " .. settings.cafe_max_awake_seconds .. [[ >/dev/null 2>&1 &
pid=$!
attempt=0
while [ "$attempt" -lt 20 ]; do
  kill -0 "$pid" 2>/dev/null || exit 1
  /usr/bin/pmset -g assertions | /usr/bin/grep -F "pid $pid(caffeinate)" >/dev/null && exit 0
  sleep 0.1
  attempt=$((attempt + 1))
done
exit 1
]]
  else
    command = "pid=" .. pid .. "\n" .. [[
kill "$pid" 2>/dev/null || exit 1
attempt=0
while [ "$attempt" -lt 20 ]; do
  kill -0 "$pid" 2>/dev/null || exit 0
  sleep 0.1
  attempt=$((attempt + 1))
done
exit 1
]]
  end
  toggle_busy = true
  local scheduled = pcall(Sbar.exec, command, function(_, exit_code)
    toggle_busy = false
    if exit_code ~= 0 then utils.log("cafe: toggle did not confirm process readiness") end
    update(cafe, true)
  end)
  if not scheduled then
    toggle_busy = false
    utils.log("cafe: could not schedule toggle")
    update(cafe, true)
  end
end)
