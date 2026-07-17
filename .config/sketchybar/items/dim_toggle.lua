local colors = require("helpers.colors")
local settings = require("helpers.settings")

local ON_COLOR = colors.base04 -- matches inactive_display_dim.lua's mask color, without alpha
local OFF_COLOR = colors.base03

local state = true

local item = Sbar.add("item", "dim_toggle", {
  position = "right",
  icon = {
    string = "􀤳",
    color = ON_COLOR,
    font = { size = settings.icon_size },
    padding_left = settings.inner_padding,
    padding_right = settings.inner_padding,
  },
  label = { drawing = false },
  background = { drawing = false },
})

local function apply(new_state)
  state = new_state
  os.execute(string.format("open -g 'hammerspoon://dimset?state=%s' >/dev/null 2>&1 &", state and "on" or "off"))
  item:set({ ["icon.color"] = state and ON_COLOR or OFF_COLOR })
end

item:subscribe("mouse.clicked", function(_)
  apply(not state)
end)

apply(true)
