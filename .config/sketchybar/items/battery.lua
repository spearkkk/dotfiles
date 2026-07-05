local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local popup_opened_at = nil
local last_pct        = nil
local last_charging   = nil

local battery = Sbar.add("item", "battery", "right", {
  width                              = utils.icon_width(27, 45, 0.02025, 33),
  ["label.drawing"]                  = false,
  ["background.drawing"]             = false,
  ["popup.height"]                   = 22,
  ["popup.align"]                    = "center",
  ["popup.y_offset"]                 = -4,
  ["popup.background.height"]        = 20,
  ["popup.background.color"]         = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.corner_radius"] = 4,
  ["popup.background.border_width"]  = 0,
  ["popup.background.drawing"]       = true,
  update_freq                        = 1,
})

local battery_popup = Sbar.add("item", "battery_popup", "popup.battery", {
  ["icon.drawing"]        = false,
  label                   = "--",
  ["label.font.size"]     = 12,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
  drawing                 = false,
})

local function update_battery()
  local batt       = utils.capture("pmset -g batt")
  local pct        = batt:match("(%d+)%%")
  if not pct then return end
  local percentage = tonumber(pct) or 0
  local charging   = batt:find("AC Power", 1, true) ~= nil

  local icon
  if charging then                 icon = "􀢋"
  elseif percentage >= 90 then     icon = "􀛨"
  elseif percentage >= 60 then     icon = "􀺸"
  elseif percentage >= 30 then     icon = "􀺶"
  elseif percentage >= 10 then     icon = "􀛩"
  else                             icon = "􀛪"
  end

  local color
  if percentage > 50 then          color = colors.base0b
  elseif percentage > 20 then      color = colors.base09
  else                             color = colors.base08
  end

  battery:set({ icon = icon, ["icon.color"] = color })
  battery_popup:set({ label = string.format("Battery %d%%", percentage) })
  if percentage ~= last_pct or charging ~= last_charging then
    utils.log(string.format("battery: %d%% charging=%s", percentage, tostring(charging)))
    last_pct      = percentage
    last_charging = charging
  end
end

local function close_popup()
  Sbar.animate("sin", 12)
  battery_popup:set({ ["label.color"] = utils.set_alpha(colors.foreground, 0), y_offset = 2 })
  battery:set({ ["popup.drawing"] = false })
  battery_popup:set({ drawing = false, ["label.color"] = colors.foreground, y_offset = 0 })
  popup_opened_at = nil
  utils.log("battery: popup closed")
end

local function open_popup()
  battery:set({ ["popup.drawing"] = true })
  battery_popup:set({ drawing = true, ["label.color"] = utils.set_alpha(colors.foreground, 0), y_offset = 2 })
  Sbar.animate("sin", 15)
  battery_popup:set({ ["label.color"] = colors.foreground, y_offset = 0 })
  popup_opened_at = os.time()
  utils.log("battery: popup opened")
end

utils.log("battery: loaded")
update_battery()

battery:subscribe({ "system_woke", "power_source_change" }, function(env)
  update_battery()
end)

battery:subscribe("routine", function(env)
  if popup_opened_at and os.time() - popup_opened_at >= 2 then
    close_popup()
  end
  update_battery()
end)

battery:subscribe("mouse.clicked", function(env)
  if popup_opened_at then
    close_popup()
  else
    open_popup()
  end
end)
