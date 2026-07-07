local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

-- Use text icons for input source state.
local EN_ICON = "A"
local KO_ICON = "가"
local FIXED_WIDTH = 24
local UPDATE_FREQ = 5

local function current_input_source()
  local out = utils.capture("defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null")
  if out == "" then
    return "en"
  end

  -- Common Korean IME ids on macOS
  if out:find("com.apple.inputmethod.Korean", 1, true)
      or out:find("2SetKorean", 1, true)
      or out:find("Korean", 1, true) then
    return "ko"
  end

  -- Common English layouts
  if out:find("com.apple.keylayout.ABC", 1, true)
      or out:find("com.apple.keylayout.US", 1, true)
      or out:find("U.S.", 1, true)
      or out:find("ABC", 1, true) then
    return "en"
  end

  return "en"
end

local input_source = Sbar.add("item", "input_source", {
  position = "right",
  width = FIXED_WIDTH,
  update_freq = UPDATE_FREQ,
  icon = {
    drawing = true,
    align = "center",
    color = colors.foreground,
    font = {
      size = settings.icon_size,
    },
    y_offset = -1,
    padding_left = 0,
    padding_right = 0,
  },
  ["icon.font.style"] = "Bold",
  label = {
    drawing = false,
  },
  background = {
    drawing = false,
  },
})

local function update_input_source()
  local src = current_input_source()
  if src == "ko" then
    input_source:set({
      icon = KO_ICON,
      ["icon.font.size"] = settings.icon_size - 2,
    })
  else
    input_source:set({
      icon = EN_ICON,
      ["icon.font.size"] = settings.icon_size,
    })
  end
end

local function switch_input_source()
  local src = current_input_source()
  local target = (src == "ko") and "com.apple.keylayout.ABC" or "com.apple.inputmethod.Korean.2SetKorean"

  -- Prefer im-select for deterministic source switching.
  os.execute("im-select " .. target .. " >/dev/null 2>&1")

  os.execute("sleep 0.08")
  update_input_source()
end

input_source:subscribe({ "routine", "forced" }, update_input_source)
input_source:subscribe("mouse.clicked", function(_)
  switch_input_source()
end)

update_input_source()
