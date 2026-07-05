local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local function caffeinate_pid()
  return utils.capture("pgrep -x caffeinate | head -n 1")
end

local function update(item)
  local pid = caffeinate_pid()
  if pid == "" then
    item:set({ icon = "􀸘", ["icon.color"] = colors.base04 })
  else
    item:set({ icon = "􀸙", ["icon.color"] = colors.base0a })
  end
end

local cafe = Sbar.add("item", "cafe", "e", {
  icon                   = "􀸘",
  width                  = utils.icon_width(27, 45, 0.02025, 33),
  ["icon.padding_left"]  = 0,
  ["icon.padding_right"] = settings.outer_padding,
  ["label.drawing"]      = false,
  ["background.drawing"] = false,
  update_freq            = 10,
})

utils.log("cafe: loaded")

cafe:subscribe("routine", function(env)
  update(cafe)
end)

cafe:subscribe("mouse.clicked", function(env)
  local pid = caffeinate_pid()
  if pid == "" then
    os.execute("nohup caffeinate -dimsu >/dev/null 2>&1 &")
    utils.log("cafe: started caffeinate")
  else
    os.execute("kill " .. pid .. " >/dev/null 2>&1")
    utils.log("cafe: stopped caffeinate")
  end
  update(cafe)
end)
