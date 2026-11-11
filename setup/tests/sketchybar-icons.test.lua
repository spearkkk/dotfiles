local root = 'home/.config/sketchybar/'
package.path = root .. '?.lua;' .. package.path
local icons = require('lib.icons')
assert(icons.brand_apple == utf8.char(0xec17))
assert(icons.square_rounded_letter_q == utf8.char(0xf5be))
assert(icons.marquee == utf8.char(0xec77))
assert(icons.alphabet_korean == utf8.char(0xff2c))
assert(icons.timeline_event_exclamation == utf8.char(0xf662))
assert(icons.brand_spotify == utf8.char(0xed03))
assert(icons.opacity == utf8.char(0x102cb))

local settings = require('lib.settings')
local default_options
Sbar = { default = function(values) default_options = values end }
dofile(root .. 'core/default.lua')
assert(default_options['label.font'] == 'SF Pro', 'use SF Pro for bar text')
assert(default_options['icon.font'] == 'tabler-icons', 'keep Tabler for bar icons')
assert(settings.icon_font == 'tabler-icons', 'use the Tabler font')
assert(settings.icon_size == 20, 'use 20pt icons')
assert(settings.defaults.padding_left == 4 and settings.defaults.padding_right == 4, 'reduce item spacing')
local colors = require('lib.colors')
local capture = ''
local utils = { capture = function() return capture end, set_alpha = function(color) return color end }
package.loaded['lib.utils'] = utils
local items = {}
Sbar = { add = function(_, name, options)
  local item = { options = options, values = {}, callbacks = {} }
  function item:set(v) for k, value in pairs(v) do self.values[k] = value end end
  function item:subscribe(events, cb)
    if type(events) == 'string' then events = { events } end
    for _, event in ipairs(events) do self.callbacks[event] = cb end
  end
  items[name] = item
  return item
end }

capture = 'Now drawing from Battery Power\n -InternalBattery-0 5%; discharging;'
dofile(root .. 'items/battery.lua')
local batt = items.battery_icon
assert(batt.options.width == 22 and batt.options.icon.align == 'center', 'pull preceding items 4pt closer to battery')
assert(batt.options.icon.font.size == 22 and batt.options.y_offset == 0, 'vertical battery uses 22pt')
assert(batt.options.icon.y_offset == 0, 'do not raise the battery glyph above neighboring icons')
assert(batt.options.padding_left == 4 and batt.options.padding_right == 4, 'battery has symmetric item spacing')
assert(batt.options.icon.padding_left == 2 and batt.options.icon.padding_right == 2, 'battery has normal icon spacing')
assert(items.battery_percent.options.position == 'popup.battery_icon', 'battery percentage is in popup')
assert(items.battery_percent.options.label.font.size == 12, 'popup label uses pomodoro sizing')
assert(batt.options['popup.background.border_color'] == colors.border, 'battery uses the theme border')
assert(batt.callbacks['mouse.entered'] and batt.callbacks['mouse.exited'], 'battery hover handlers installed')
batt.callbacks['mouse.entered'](); assert(batt.values['popup.drawing'] == true)
batt.callbacks['mouse.exited'](); assert(batt.values['popup.drawing'] == false)
for _, c in ipairs({{4, utf8.char(0xff15)}, {5, utf8.char(0xff1c)}, {29, utf8.char(0xff1c)},
  {30, utf8.char(0xff1b)}, {60, utf8.char(0xff1a)}, {90, utf8.char(0xff19)}}) do
  capture = 'Battery Power\n' .. c[1] .. '%'
  batt.callbacks.routine()
  assert(batt.values.icon == c[2], 'battery icon at ' .. c[1] .. '%')
end
capture = 'AC Power\n4%'
batt.callbacks.routine()
assert(batt.values.icon == utf8.char(0xff17), 'vertical charging takes priority')

capture = 'com.apple.keylayout.ABC'
dofile(root .. 'items/input_source.lua')
local input = items.input_source
assert(input.options.width == 26 and input.options.icon.align == 'center', 'center input in a 26px cell')
assert(input.options.icon.padding_left == 2 and input.options.icon.padding_right == 2, 'input uses common icon padding')
assert(input.options.padding_left == 4 and input.options.padding_right == 4, 'input uses common item padding')
assert(input.values.icon == utf8.char(0xeb54), 'use the world icon')
assert(input.values['icon.font.size'] == 20 and input.options.icon.y_offset == 0, 'world uses the common icon size')
assert(input.values['icon.color'] == colors.foreground, 'English color')
capture = 'com.apple.inputmethod.Korean'
input.callbacks.routine()
assert(input.values.icon == utf8.char(0xeb54), 'Korean keeps the same world icon')
assert(input.values['icon.font.size'] == 20, 'Korean keeps the same world size')
assert(input.values['icon.color'] == colors.base04, 'Korean dim color')
capture = 'com.apple.keylayout.ABC'
input.callbacks.routine()
assert(input.values['icon.font.size'] == 20, 'restore world size after switching languages')
assert(input.values.icon == utf8.char(0xeb54) and input.values['icon.color'] == colors.foreground, 'switching back restores English color')
print('PASS: Tabler icons, battery thresholds and input colors')

utils.shell_quote = function(s) return "'" .. s .. "'" end
utils.log = function() end
capture = 'Q'
dofile(root .. 'items/aerospace.lua')
for i = 1, 5 do
  local ws = items['aerospace.ws.' .. i]
  local expected = { utf8.char(0xf5be), utf8.char(0xf5c4), utf8.char(0xf5b2), utf8.char(0xf5bf), utf8.char(0xfc97) }
  assert(ws.options.icon == expected[i])
  if i == 5 then assert(ws.options['icon.font'] == nil, 'backtick uses the default Tabler font') end
  assert(ws.options.width == 26 and ws.options['icon.align'] == 'center', 'workspace icons use equal centered cells')
  assert(ws.options['icon.width'] == 26, 'workspace glyphs are centered inside a fixed-width icon')
  assert(ws.values['icon.font.size'] == (i == 1 and 24 or 18))
  assert(ws.values['icon.color'] == (i == 1 and colors.base0a or colors.base04))
end
items['aerospace.ws.3'].callbacks.aerospace_workspace_change({FOCUSED_WORKSPACE = 'E'})
assert(items['aerospace.ws.1'].values['icon.font.size'] == 18)
assert(items['aerospace.ws.3'].values['icon.font.size'] == 24)
items['aerospace.ws.5'].callbacks.aerospace_workspace_change({FOCUSED_WORKSPACE = '`'})
assert(items['aerospace.ws.5'].values['icon.font.size'] == 24 and items['aerospace.ws.5'].values['icon.color'] == colors.base0a)

capture = ''
dofile(root .. 'items/cafe.lua')
local cafe = items.cafe
assert(cafe.values.icon == utf8.char(0xf63e) and cafe.values['icon.color'] == colors.base04, 'inactive wake prevention uses rounded minus')
capture = '123'
cafe.callbacks.routine()
assert(cafe.values.icon == utf8.char(0xf59a) and cafe.values['icon.color'] == colors.base0a, 'active wake prevention uses rounded square')
print('PASS: workspace focus and caffeine state')

local output_device, mute = 'MacBook Pro Speakers', false
utils.set_alpha = function(c) return c end
utils.capture = function(cmd)
  if cmd:find('command -v', 1, true) then return '/fake/SwitchAudioSource' end
  if cmd:find('-t output -c', 1, true) then return output_device end
  if cmd:find('-t output -a', 1, true) then return 'MacBook Pro Speakers\nAirPods\nAirPods\n' end
  if cmd:find('osascript', 1, true) then return mute and '50,true' or '50,false' end
  return ''
end
dofile(root .. 'items/sound_output.lua')
local sound = items.sound_output
assert(sound.options['popup.background.border_color'] == colors.border, 'speaker popup uses the theme border')
assert(sound.options['popup.background.border_width'] == 2, 'speaker popup border matches weather')
for _, case in ipairs({ {'MacBook Pro Speakers', icons.device_laptop},
  {'Sony WH-1000XM5', icons.headphones}, {'AirPods', icons.device_airpods},
  {'LG HDR 4K', icons.device_desktop}, {'Other USB speaker', icons.volume} }) do
  output_device = case[1]; mute = false; sound.callbacks.routine()
  assert(sound.values.icon == case[2], 'show output device: ' .. case[1])
  mute = true; sound.callbacks.routine()
  assert(sound.values.icon == icons.volume_off, 'mute overrides device: ' .. case[1])
end
assert(sound.callbacks['mouse.entered'] and sound.callbacks['mouse.exited'] and sound.callbacks['mouse.exited.global'], 'speaker popup responds to hover and leaving bar or popup')
assert(not sound.callbacks['mouse.clicked'], 'speaker icon no longer toggles popup on click')
output_device = 'MacBook Pro Speakers'
sound.callbacks['mouse.entered']()
assert(sound.values['popup.drawing'] == true, 'hover opens speaker popup')
assert(items['sound_output.device.1'].values.label == 'MacBook Pro Speakers')
assert(items['sound_output.device.2'].values.label == 'AirPods')
assert(items['sound_output.device.3'].values.drawing == false, 'duplicate output devices are hidden')
assert(items['sound_output.device.2'].values.click_script:find("-t output -s 'AirPods'", 1, true), 'popup devices remain selectable')
sound.callbacks.routine()
assert(sound.values['popup.drawing'] == true, 'routine refresh does not close an active hover popup')
sound.callbacks['mouse.exited']()
assert(sound.values['popup.drawing'] == false and items['sound_output.device.1'].values.drawing == false, 'leaving the speaker closes and clears popup')
sound.callbacks['mouse.entered']()
sound.callbacks['mouse.exited.global']()
assert(sound.values['popup.drawing'] == false, 'leaving bar and popup closes popup')
print('PASS: output-device and mute icons')

dofile(root .. 'items/timestamp.lua')
local time_opts = items.timestamp_time.options
local date_opts = items.timestamp_date.options
assert(time_opts.width == 54 and date_opts.width == 30, 'overlap clock cells to reduce the gap before weather')
assert(time_opts.padding_right == 8 and date_opts.padding_right == -46, 'preserve date and time placement')
assert(date_opts.icon.string == icons.calendar and date_opts.label.drawing, 'retain the date and its calendar icon')

dofile(root .. 'items/wifi.lua')
dofile(root .. 'items/settings.lua')
dofile(root .. 'items/dim_toggle.lua')
for _, name in ipairs({'wifi', 'settings', 'cafe', 'sound_output', 'dim_toggle'}) do
  local opts = items[name].options
  local icon = type(opts.icon) == 'table' and opts.icon or {}
  assert(opts.width == 26, name .. ' uses the common icon cell width')
  assert((opts['icon.align'] or icon.align) == 'center', name .. ' is centered')
  assert((opts['icon.padding_left'] or icon.padding_left) == 2 and (opts['icon.padding_right'] or icon.padding_right) == 2, name .. ' has symmetric icon padding')
  assert(opts.padding_left == 4 and opts.padding_right == 4, name .. ' has symmetric item padding')
end

-- Today's widget must keep its event label and popup while hiding the icon.
local fake_cache = { read = function() return 'header\ttrue' end,
  lines = function()
    local done = false
    return function() if not done then done = true; return '10:00\t11:00\tExample meeting\tPersonal' end end
  end,
  close = function() end }
local display = { attributes = function(_, has_event) return { drawing = has_event } end,
  log_visibility = function() end, subscribe = function(_, cb) cb({}) end }
local libs = { ['lib.icons']=icons, ['lib.colors']=colors, ['lib.settings']=settings,
  ['lib.utils']=utils, ['lib.paths']={calendar_cache='fixture', calendar_refresh_request='fixture', cache_dir='fixture'},
  ['lib.display']=display }
local env = setmetatable({ Sbar = Sbar, require = function(n) return assert(libs[n], n) end,
  io = { open = function() return fake_cache end },
  os = { date = function() return {hour=9, min=0} end, execute = function() return true end } }, {__index=_G})
assert(loadfile(root .. 'items/todays.lua', 't', env))()
local todays = items.todays
assert(todays.options.icon.drawing == false, 'todays must not show an icon')
assert(todays.values.label:find('Example meet', 1, true), 'preserve event label')
assert(todays.values.icon == nil, 'refresh must not restore icon')
assert(todays.callbacks['mouse.entered'] and todays.callbacks['mouse.exited'] and todays.callbacks['mouse.exited.global'], 'popup opens on hover')
assert(todays.callbacks['mouse.clicked'], 'preserve calendar shortcut')
print('PASS: todays event remains visible without an icon')

-- Media has a separate text item; only its icon gets the common cell.
libs['lib.paths'] = {media_tsv = 'fixture', media_refresh_request = 'fixture'}
local media_env = setmetatable({ Sbar = Sbar, require = function(n) return assert(libs[n], n) end,
  io = { open = function() return nil end } }, {__index=_G})
assert(loadfile(root .. 'items/media.lua', 't', media_env))()
local media = items.media_icon.options
assert(media.width == 26 and media['icon.align'] == 'center', 'center media icon in a 26px cell')
assert(media.padding_left == 4 and media.padding_right == 4, 'media uses common item padding')
assert(media['icon.padding_left'] == 2 and media['icon.padding_right'] == 2, 'media uses common icon padding')
