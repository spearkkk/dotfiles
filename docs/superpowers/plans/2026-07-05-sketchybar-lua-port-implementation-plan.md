# SketchyBar Native Lua Port — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the bash-orchestrated + subprocess-Lua hybrid SketchyBar config with a fully native Lua config using `require("sketchybar")`, covering the 4 active items: battery, cafe, timestamp, pomodoro.

**Architecture:** All new files are written first while the old bash config continues to run. The cutover happens in one step when the new `sketchybarrc` replaces the old bash one and triggers a reload. Old files are deleted only after the new config is verified working.

**Tech Stack:** Lua 5.4, SketchyBar native Lua API (`require("sketchybar")`), standalone `lua` test runner (no external framework).

---

## File Map

**Created:**
- `.config/sketchybar/helpers/colors.lua` — color palette
- `.config/sketchybar/helpers/settings.lua` — sizing, fonts, padding
- `.config/sketchybar/helpers/utils.lua` — log, set_alpha, capture, icon_width
- `.config/sketchybar/core/bar.lua` — Sbar.bar({...})
- `.config/sketchybar/core/default.lua` — Sbar.default({...})
- `.config/sketchybar/init.lua` — wires core + items
- `.config/sketchybar/items/init.lua` — requires the four items
- `.config/sketchybar/items/cafe.lua`
- `.config/sketchybar/items/timestamp.lua`
- `.config/sketchybar/items/battery.lua`
- `.config/sketchybar/items/pomodoro.lua`
- `.config/sketchybar/tests/utils_spec.lua`

**Replaced (cutover step):**
- `.config/sketchybar/sketchybarrc` — bash → Lua entry point

**Deleted (after cutover verified):**
- `.config/sketchybar/colors.sh`
- `.config/sketchybar/theme.sh`
- `.config/sketchybar/icons.sh`
- `.config/sketchybar/items/battery.sh`
- `.config/sketchybar/items/cafe.sh`
- `.config/sketchybar/items/timestamp.sh`
- `.config/sketchybar/items/pomodoro.sh`
- `.config/sketchybar/plugins/battery.lua`
- `.config/sketchybar/plugins/cafe.lua`
- `.config/sketchybar/plugins/timestamp.lua`
- `.config/sketchybar/plugins/pomodoro.lua`
- `.config/sketchybar/lua/lib/sketchybar.lua`
- `.config/sketchybar/lua/lib/theme.lua`

**Kept untouched:** All other inactive `items/*.sh`, other `plugins/*.lua`, `plugins/calc_icon_width.lua`, `lua/lib/audio_devices.lua`, `tests/audio_devices_spec.lua`, `data/`, `ITEMS.md`, `backup-*/`.

---

## Task 1: helpers/colors.lua

**Files:**
- Create: `.config/sketchybar/helpers/colors.lua`

- [ ] **Step 1: Create the file**

```lua
local M = {}

M.base00 = "0xFF0A1F2E"
M.base01 = "0xFF142C3E"
M.base02 = "0xFF1C3A50"
M.base03 = "0xFF24425C"
M.base04 = "0xFF4A6E86"
M.base05 = "0xFFC6D8E4"
M.base06 = "0xFFD6E2E8"
M.base07 = "0xFFECF0F4"
M.base08 = "0xFFC47A72"
M.base09 = "0xFFC8945A"
M.base0a = "0xFFC8AE6A"
M.base0b = "0xFF68BE92"
M.base0c = "0xFF50C4C0"
M.base0d = "0xFF7896CC"
M.base0e = "0xFF9A7EC8"
M.base0f = "0xFF8C6040"
M.base10 = "0xFF071420"
M.base11 = "0xFFD08880"
M.base12 = "0xFFD4A870"
M.base13 = "0xFFD4BE82"
M.base14 = "0xFF80CCAA"
M.base15 = "0xFF68D4D0"
M.base16 = "0xFF90AED8"
M.base17 = "0xFFAE96D4"

M.background     = M.base00
M.background_alt = M.base01
M.foreground     = M.base05
M.accent         = M.base0d
M.border         = M.base03
M.bar_border     = M.base00

return M
```

- [ ] **Step 2: Verify it loads**

Run from `.config/sketchybar/`:
```
lua -e "package.path='./?.lua;' .. package.path; local c = require('helpers.colors'); print(c.background)"
```
Expected output: `0xFF0A1F2E`

- [ ] **Step 3: Commit**

```bash
git add .config/sketchybar/helpers/colors.lua
git commit -m "feat(sketchybar): add helpers/colors.lua"
```

---

## Task 2: helpers/settings.lua

**Files:**
- Create: `.config/sketchybar/helpers/settings.lua`

- [ ] **Step 1: Create the file**

```lua
local M = {}

M.bar = {
  height        = 33,
  margin        = 4,
  y_offset      = 4,
  corner_radius = 8,
  border_width  = 3,
  blur_radius   = 0,
  padding_left  = 4,
  padding_right = 4,
}

M.defaults = {
  bg_height     = 28,
  bg_y_offset   = 0,
  padding_left  = 6,
  padding_right = 6,
  corner_radius = 4,
  border_width  = 0,
}

M.font          = "SF Mono"
M.icon_size     = 14
M.label_size    = 14
M.inner_padding = 2
M.outer_padding = 6

return M
```

- [ ] **Step 2: Verify it loads**

```
lua -e "package.path='./?.lua;' .. package.path; local s = require('helpers.settings'); print(s.bar.height)"
```
Expected output: `33`

- [ ] **Step 3: Commit**

```bash
git add .config/sketchybar/helpers/settings.lua
git commit -m "feat(sketchybar): add helpers/settings.lua"
```

---

## Task 3: helpers/utils.lua + tests

**Files:**
- Create: `.config/sketchybar/helpers/utils.lua`
- Create: `.config/sketchybar/tests/utils_spec.lua`

- [ ] **Step 1: Write the failing test first**

Create `.config/sketchybar/tests/utils_spec.lua`:

```lua
local function current_dir()
  local p = io.popen("pwd")
  if not p then return "." end
  local out = p:read("*a") or "."
  p:close()
  return (out:gsub("%s+$", ""))
end

local function resolve_config_dir(argv0, source, cwd)
  local script_path = argv0 or ""
  if script_path == "" and source then
    script_path = source:gsub("^@", "")
  end
  if script_path == "" then
    script_path = (cwd or current_dir()) .. "/tests/utils_spec.lua"
  end
  if script_path:sub(1, 1) ~= "/" then
    script_path = (cwd or current_dir()) .. "/" .. script_path
  end
  return (script_path:gsub("/tests/[^/]+$", ""))
end

local script_source = debug.getinfo(1, "S").source
local config_dir = resolve_config_dir(arg and arg[0], script_source, current_dir())
package.path = config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path

-- Mock Sbar so icon_width fallback is exercised
Sbar = { query = function() return nil end }

local utils = require("helpers.utils")

local function assert_eq(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected=%s actual=%s", label, tostring(expected), tostring(actual)))
  end
end

-- set_alpha: 100% leaves alpha as FF
assert_eq(utils.set_alpha("0xFF0A1F2E", 100), "0xFF0A1F2E", "set_alpha 100%")

-- set_alpha: 0% sets alpha to 00
assert_eq(utils.set_alpha("0xFF0A1F2E", 0), "0x000A1F2E", "set_alpha 0%")

-- set_alpha: 50% rounds down to 7F (127)
assert_eq(utils.set_alpha("0xFF0A1F2E", 50), "0x7F0A1F2E", "set_alpha 50%")

-- set_alpha: strips existing alpha channel from 8-char input
assert_eq(utils.set_alpha("0xABFFFFFF", 100), "0xFFFFFFFF", "set_alpha strips old alpha")

-- set_alpha: clamps above 100
assert_eq(utils.set_alpha("0xFF0A1F2E", 150), "0xFF0A1F2E", "set_alpha clamps >100")

-- set_alpha: clamps below 0
assert_eq(utils.set_alpha("0xFF0A1F2E", -10), "0x000A1F2E", "set_alpha clamps <0")

-- capture: returns trimmed output
local result = utils.capture("echo hello")
assert_eq(result, "hello", "capture echo")

-- capture: returns empty string on bad command
local bad = utils.capture("__nonexistent_command__ 2>/dev/null")
assert_eq(type(bad), "string", "capture bad command returns string")

-- icon_width: falls back when Sbar.query returns nil
assert_eq(utils.icon_width(27, 45, 0.02025, 33), 33, "icon_width fallback")

-- log: writes to log file without error
local home = os.getenv("HOME") or "/tmp"
local log_path = home .. "/.sketchybar.log"
local before_size = (function()
  local f = io.open(log_path, "r")
  if not f then return 0 end
  local s = #f:read("*a")
  f:close()
  return s
end)()
utils.log("utils_spec: test log message")
local after_size = (function()
  local f = io.open(log_path, "r")
  if not f then return 0 end
  local s = #f:read("*a")
  f:close()
  return s
end)()
assert_eq(after_size > before_size, true, "log appends to file")

print("ok: utils_spec")
```

- [ ] **Step 2: Run the test — expect failure**

Run from `.config/sketchybar/`:
```
lua tests/utils_spec.lua
```
Expected: error like `module 'helpers.utils' not found`

- [ ] **Step 3: Create helpers/utils.lua**

```lua
local M = {}

local log_path = (os.getenv("HOME") or "") .. "/.sketchybar.log"

function M.log(msg)
  local f = io.open(log_path, "a")
  if not f then return end
  f:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), tostring(msg)))
  f:close()
end

function M.set_alpha(hex, percent)
  local h = tostring(hex or ""):gsub("^#", ""):gsub("^0[xX]", "")
  if #h == 8 then h = h:sub(-6) end  -- keep last 6 hex chars (strip alpha prefix)
  h = h:upper()
  if #h ~= 6 then h = "C6D8E4" end
  local p = math.max(0, math.min(100, tonumber(percent) or 100))
  local a = math.floor(p * 255 / 100)
  return string.format("0x%02X%s", a, h)
end

function M.capture(cmd)
  local p = io.popen(cmd)
  if not p then return "" end
  local out = p:read("*a") or ""
  p:close()
  return (out:gsub("%s+$", ""))
end

function M.icon_width(min, max, ratio, fallback)
  local ok, displays = pcall(function() return Sbar.query("displays") end)
  if not ok or type(displays) ~= "table" then return fallback end
  -- displays is keyed by string "1", "2", … for each display index
  local first = displays["1"] or displays[1]
  if type(first) ~= "table" then return fallback end
  local w = (first.bounds and first.bounds.w) or first.width
  if type(w) ~= "number" then return fallback end
  return math.max(min, math.min(max, math.floor(w * ratio)))
end

return M
```

- [ ] **Step 4: Run the test — expect pass**

```
lua tests/utils_spec.lua
```
Expected: `ok: utils_spec`

- [ ] **Step 5: Commit**

```bash
git add .config/sketchybar/helpers/utils.lua .config/sketchybar/tests/utils_spec.lua
git commit -m "feat(sketchybar): add helpers/utils.lua with tests"
```

---

## Task 4: Entry point, init, and core

**Files:**
- Create: `.config/sketchybar/init.lua`
- Create: `.config/sketchybar/core/bar.lua`
- Create: `.config/sketchybar/core/default.lua`
- Create: `.config/sketchybar/items/init.lua`

> Do NOT touch `sketchybarrc` yet — the old bash config must keep running until all items are ready.

- [ ] **Step 1: Create init.lua**

```lua
require("core.bar")
require("core.default")
require("items")
```

- [ ] **Step 2: Create core/bar.lua**

```lua
local colors   = require("helpers.colors")
local settings = require("helpers.settings")

Sbar.bar({
  position      = "top",
  height        = settings.bar.height,
  margin        = settings.bar.margin,
  y_offset      = settings.bar.y_offset,
  corner_radius = settings.bar.corner_radius,
  border_width  = settings.bar.border_width,
  blur_radius   = settings.bar.blur_radius,
  padding_left  = settings.bar.padding_left,
  padding_right = settings.bar.padding_right,
  color         = colors.background,
  border_color  = colors.bar_border,
})
```

- [ ] **Step 3: Create core/default.lua**

```lua
local colors   = require("helpers.colors")
local settings = require("helpers.settings")

Sbar.default({
  ["background.height"]        = settings.defaults.bg_height,
  ["background.y_offset"]      = settings.defaults.bg_y_offset,
  ["background.padding_left"]  = settings.defaults.padding_left,
  ["background.padding_right"] = settings.defaults.padding_right,
  ["background.corner_radius"] = settings.defaults.corner_radius,
  ["background.border_width"]  = settings.defaults.border_width,
  ["background.color"]         = colors.background_alt,
  ["label.color"]              = colors.foreground,
  ["icon.color"]               = colors.foreground,
  ["label.font"]               = settings.font,
  ["icon.font"]                = settings.font,
  ["label.font.size"]          = settings.label_size,
  ["icon.font.size"]           = settings.icon_size,
})
```

- [ ] **Step 4: Create items/init.lua** (stub — items will be added in later tasks)

```lua
require("items.cafe")
require("items.timestamp")
require("items.battery")
require("items.pomodoro")
```

- [ ] **Step 5: Commit**

```bash
git add .config/sketchybar/init.lua .config/sketchybar/core/ .config/sketchybar/items/init.lua
git commit -m "feat(sketchybar): add entry init, core/bar, core/default, items/init stub"
```

---

## Task 5: items/cafe.lua

**Files:**
- Create: `.config/sketchybar/items/cafe.lua`

- [ ] **Step 1: Create items/cafe.lua**

```lua
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
```

- [ ] **Step 2: Commit**

```bash
git add .config/sketchybar/items/cafe.lua
git commit -m "feat(sketchybar): add items/cafe.lua"
```

---

## Task 6: items/timestamp.lua

**Files:**
- Create: `.config/sketchybar/items/timestamp.lua`

- [ ] **Step 1: Create items/timestamp.lua**

```lua
local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local function update(time_item, date_item)
  local clock = utils.capture("TZ=Asia/Seoul date '+%H:%M:%S'")
  local date  = utils.capture("TZ=Asia/Seoul date '+%Y-%m-%d'")
  time_item:set({ label = clock })
  date_item:set({ label = date })
end

local timestamp_time = Sbar.add("item", "timestamp_time", "right", {
  ["icon.drawing"]       = false,
  ["label.padding_left"] = settings.inner_padding,
  ["background.drawing"] = false,
  update_freq            = 1,
})

local timestamp_date = Sbar.add("item", "timestamp_date", "right", {
  icon                    = "􀉉",
  ["icon.padding_right"]  = settings.inner_padding,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
})

Sbar.add("bracket", "timestamp_group", { "timestamp_time", "timestamp_date" }, {
  drawing                = true,
  ["background.color"]   = colors.background,
  ["background.drawing"] = true,
})

utils.log("timestamp: loaded")

timestamp_time:subscribe("routine", function(env)
  update(timestamp_time, timestamp_date)
end)
```

- [ ] **Step 2: Commit**

```bash
git add .config/sketchybar/items/timestamp.lua
git commit -m "feat(sketchybar): add items/timestamp.lua"
```

---

## Task 7: items/battery.lua

**Files:**
- Create: `.config/sketchybar/items/battery.lua`

- [ ] **Step 1: Create items/battery.lua**

```lua
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
```

- [ ] **Step 2: Commit**

```bash
git add .config/sketchybar/items/battery.lua
git commit -m "feat(sketchybar): add items/battery.lua"
```

---

## Task 8: items/pomodoro.lua

**Files:**
- Create: `.config/sketchybar/items/pomodoro.lua`

- [ ] **Step 1: Create items/pomodoro.lua**

```lua
local colors   = require("helpers.colors")
local settings = require("helpers.settings")
local utils    = require("helpers.utils")

local WORK_SECS  = 25 * 60
local BREAK_SECS = 5 * 60
local pomo_dir   = (os.getenv("HOME") or "") .. "/.pomodoro"
local state_file = pomo_dir .. "/pomo_state"

local mode       = "none"
local start_time = nil

os.execute("mkdir -p " .. pomo_dir)

local function save_state()
  local f = io.open(state_file, "w")
  if not f then return end
  f:write(mode .. "\n")
  f:write(tostring(start_time or "") .. "\n")
  f:close()
end

local function load_state()
  local f = io.open(state_file, "r")
  if not f then return end
  local m = f:read("*l") or "none"
  local t = f:read("*l")
  f:close()
  if m == "work" or m == "break" then
    mode = m
    start_time = tonumber(t)
  end
end

local function format_time(secs)
  local m = math.floor(secs / 60)
  local s = secs % 60
  return string.format("%02d:%02d", m, s)
end

local width = utils.icon_width(27, 45, 0.02025, 33)

local pomodoro_work = Sbar.add("item", "pomodoro_work", "e", {
  icon                               = "􀠸",
  width                              = width,
  ["icon.padding_left"]              = settings.outer_padding,
  ["icon.padding_right"]             = 0,
  ["label.drawing"]                  = false,
  ["background.drawing"]             = false,
  drawing                            = true,
  update_freq                        = 1,
  ["popup.height"]                   = 22,
  ["popup.align"]                    = "center",
  ["popup.y_offset"]                 = -4,
  ["popup.background.height"]        = 20,
  ["popup.background.color"]         = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_color"]  = colors.base0a,
  ["popup.background.border_width"]  = 2,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.drawing"]       = true,
})

local pomodoro_work_popup = Sbar.add("item", "pomodoro_work_popup", "popup.pomodoro_work", {
  ["icon.drawing"]        = false,
  label                   = "",
  ["label.font.size"]     = 12,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
  drawing                 = false,
})

local pomodoro_break = Sbar.add("item", "pomodoro_break", "e", {
  icon                               = "􀼙",
  width                              = width,
  ["icon.padding_left"]              = settings.outer_padding,
  ["icon.padding_right"]             = 0,
  ["label.drawing"]                  = false,
  ["background.drawing"]             = false,
  drawing                            = false,
  update_freq                        = 1,
  ["popup.height"]                   = 22,
  ["popup.align"]                    = "center",
  ["popup.y_offset"]                 = -4,
  ["popup.background.height"]        = 20,
  ["popup.background.color"]         = utils.set_alpha(colors.background_alt, 80),
  ["popup.background.border_color"]  = colors.base0a,
  ["popup.background.border_width"]  = 2,
  ["popup.background.corner_radius"] = 4,
  ["popup.background.drawing"]       = true,
})

local pomodoro_break_popup = Sbar.add("item", "pomodoro_break_popup", "popup.pomodoro_break", {
  ["icon.drawing"]        = false,
  label                   = "",
  ["label.font.size"]     = 12,
  ["label.padding_left"]  = settings.inner_padding,
  ["label.padding_right"] = settings.inner_padding,
  ["background.drawing"]  = false,
  drawing                 = false,
})

Sbar.add("bracket", "pomodoro_group", { "pomodoro_break", "pomodoro_work" }, {
  drawing                = false,
  ["padding_left"]       = 0,
  ["padding_right"]      = 0,
  ["background.drawing"] = false,
})

local function stop_timer()
  mode = "none"
  start_time = nil
  save_state()
  pomodoro_work:set({
    drawing            = true,
    ["icon.color"]     = colors.foreground,
    ["popup.drawing"]  = false,
  })
  pomodoro_work_popup:set({ drawing = false, label = "" })
  pomodoro_break:set({
    drawing            = false,
    ["icon.color"]     = colors.foreground,
    ["popup.drawing"]  = false,
  })
  pomodoro_break_popup:set({ drawing = false, label = "" })
  utils.log("pomodoro: stopped")
end

local function start_mode(m)
  mode = m
  start_time = os.time()
  save_state()
  if m == "work" then
    local label = format_time(WORK_SECS)
    pomodoro_work:set({ drawing = true, ["icon.color"] = colors.base0d, ["popup.drawing"] = true })
    pomodoro_work_popup:set({ drawing = true, label = label })
    pomodoro_break:set({ drawing = false, ["popup.drawing"] = false })
    pomodoro_break_popup:set({ drawing = false, label = "" })
  else
    local label = format_time(BREAK_SECS)
    pomodoro_break:set({ drawing = true, ["icon.color"] = colors.base0c, ["popup.drawing"] = true })
    pomodoro_break_popup:set({ drawing = true, label = label })
    pomodoro_work:set({ drawing = false, ["popup.drawing"] = false })
    pomodoro_work_popup:set({ drawing = false, label = "" })
  end
  utils.log("pomodoro: started " .. m)
end

local function on_routine()
  if mode == "none" then return end
  local duration  = (mode == "work") and WORK_SECS or BREAK_SECS
  local remaining = duration - (os.time() - (start_time or os.time()))
  if remaining <= 0 then
    local next_mode = (mode == "work") and "break" or "work"
    utils.log("pomodoro: " .. mode .. " done, switching to " .. next_mode)
    start_mode(next_mode)
    return
  end
  local label = format_time(remaining)
  if mode == "work" then
    pomodoro_work_popup:set({ label = label })
  else
    pomodoro_break_popup:set({ label = label })
  end
end

local function on_click(item_mode, env)
  local button = (env.BUTTON or ""):lower()
  local right  = (button == "right" or button == "secondary")
  if right then
    local other = (item_mode == "work") and "break" or "work"
    start_mode(other)
    return
  end
  if mode == item_mode then
    stop_timer()
  else
    start_mode(item_mode)
  end
end

-- Restore state from disk on load
load_state()
if mode == "work" then
  pomodoro_work:set({ drawing = true, ["icon.color"] = colors.base0d, ["popup.drawing"] = true })
  pomodoro_work_popup:set({ drawing = true })
elseif mode == "break" then
  pomodoro_break:set({ drawing = true, ["icon.color"] = colors.base0c, ["popup.drawing"] = true })
  pomodoro_break_popup:set({ drawing = true })
end

utils.log("pomodoro: loaded, mode=" .. mode)

pomodoro_work:subscribe("routine", function(env) on_routine() end)
pomodoro_break:subscribe("routine", function(env) on_routine() end)
pomodoro_work:subscribe("mouse.clicked", function(env) on_click("work", env) end)
pomodoro_break:subscribe("mouse.clicked", function(env) on_click("break", env) end)
```

- [ ] **Step 2: Commit**

```bash
git add .config/sketchybar/items/pomodoro.lua
git commit -m "feat(sketchybar): add items/pomodoro.lua"
```

---

## Task 9: Cutover — replace sketchybarrc

> All new files exist. Replace the bash `sketchybarrc` with the Lua entry point and reload.

**Files:**
- Replace: `.config/sketchybar/sketchybarrc`

- [ ] **Step 1: Write the new sketchybarrc**

```lua
#!/usr/bin/env lua
Sbar = require("sketchybar")
Sbar.begin_config()
require("init")
Sbar.hotload(true)
Sbar.end_config()
Sbar.event_loop()
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x .config/sketchybar/sketchybarrc
```

- [ ] **Step 3: Reload SketchyBar**

```fish
sketchybar --reload
```

- [ ] **Step 4: Watch startup logs**

```fish
tail -f ~/.sketchybar.log
```

Expected: lines like
```
[2026-07-05 14:00:01] cafe: loaded
[2026-07-05 14:00:01] timestamp: loaded
[2026-07-05 14:00:01] battery: loaded
[2026-07-05 14:00:01] battery: 87% charging=false
[2026-07-05 14:00:01] pomodoro: loaded, mode=none
```

- [ ] **Step 5: Verify bar visually**

Check that the bar shows: pomodoro icon (center), cafe icon (center), timestamp date+time (right), battery icon (right). Interact with each:
- Click cafe → caffeinate toggles (icon changes from `􀸘` to `􀸙`)
- Click battery → popup appears with percentage, auto-closes in 2 seconds
- Click pomodoro work icon → countdown starts, popup shows `25:00` counting down
- Right-click pomodoro work icon → switches to break mode (`05:00`)
- Click active pomodoro icon → stops timer

- [ ] **Step 6: Commit**

```bash
git add .config/sketchybar/sketchybarrc
git commit -m "feat(sketchybar): switch to native Lua entry point"
```

---

## Task 10: Delete old files

> Only run this after Task 9 is verified working.

**Files deleted:** colors.sh, theme.sh, icons.sh, items/battery.sh, items/cafe.sh, items/timestamp.sh, items/pomodoro.sh, plugins/battery.lua, plugins/cafe.lua, plugins/timestamp.lua, plugins/pomodoro.lua, lua/lib/sketchybar.lua, lua/lib/theme.lua

- [ ] **Step 1: Delete the bash config files**

```bash
rm .config/sketchybar/colors.sh \
   .config/sketchybar/theme.sh \
   .config/sketchybar/icons.sh \
   .config/sketchybar/items/battery.sh \
   .config/sketchybar/items/cafe.sh \
   .config/sketchybar/items/timestamp.sh \
   .config/sketchybar/items/pomodoro.sh
```

- [ ] **Step 2: Delete the old subprocess-style Lua plugins**

```bash
rm .config/sketchybar/plugins/battery.lua \
   .config/sketchybar/plugins/cafe.lua \
   .config/sketchybar/plugins/timestamp.lua \
   .config/sketchybar/plugins/pomodoro.lua \
   .config/sketchybar/lua/lib/sketchybar.lua \
   .config/sketchybar/lua/lib/theme.lua
```

- [ ] **Step 3: Reload once more to confirm nothing broke**

```fish
sketchybar --reload
tail -f ~/.sketchybar.log
```

Expected: same startup log lines as Task 9, no errors.

- [ ] **Step 4: Commit**

```bash
git add -A .config/sketchybar/
git commit -m "chore(sketchybar): remove old bash and subprocess-lua files"
```
