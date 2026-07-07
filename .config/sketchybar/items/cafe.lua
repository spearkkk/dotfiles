local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

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
    item:set({ icon = "􀸘", ["icon.color"] = colors.base04 })
  else
    item:set({ icon = "􀸙", ["icon.color"] = colors.base0a })
  end
end

local cafe = Sbar.add("item", "cafe", {
  position               = "right",
  icon                   = "􀸘",
  ["icon.font.size"]     = settings.icon_size,
  ["icon.color"]         = colors.base04,
  ["icon.padding_left"]  = settings.inner_padding,
  ["icon.padding_right"] = settings.inner_padding,
  ["label.drawing"]      = false,
  ["background.drawing"] = false,
  update_freq            = 10,
})

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
