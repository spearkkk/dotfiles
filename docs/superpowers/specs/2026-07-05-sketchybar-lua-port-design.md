# SketchyBar Native Lua Port — Design Spec

**Date:** 2026-07-05
**Scope:** Port the 4 active SketchyBar items (battery, cafe, timestamp, pomodoro) from the current bash-orchestrated + subprocess-Lua hybrid to a fully native Lua config using `require("sketchybar")`.

---

## 1. Motivation

The current setup is a hybrid: `sketchybarrc` is a bash script that sources item shell scripts, which register items via `sketchybar --add` CLI calls, while plugins are separate Lua scripts spawned as OS processes on each event. This means every callback is a full process fork, environment variables are used as a configuration channel, and shared logic (set_alpha, capture, shell_quote) is copy-pasted across files.

The native Lua API runs everything in one process with one event loop. Items register themselves, callbacks are Lua functions, and `Sbar.set()` replaces `os.execute("sketchybar --set ...")`.

---

## 2. Directory Structure

Target layout mirrors the khaneliman/khanelinix reference repo exactly:

```
.config/sketchybar/
├── sketchybarrc          ← Lua entry point
├── init.lua              ← wires core + items
├── core/
│   ├── bar.lua           ← Sbar.bar({...})
│   └── default.lua       ← Sbar.default({...})
├── helpers/
│   ├── colors.lua        ← color palette
│   ├── settings.lua      ← sizing, fonts, padding
│   └── utils.lua         ← set_alpha, capture, icon_width
└── items/
    ├── init.lua          ← requires all four items
    ├── battery.lua
    ├── cafe.lua
    ├── timestamp.lua
    └── pomodoro.lua
```

---

## 3. Files Deleted (clean slate)

These files are replaced entirely by the new structure:

- `sketchybarrc` (bash)
- `colors.sh`, `theme.sh`, `icons.sh`
- `items/battery.sh`, `items/cafe.sh`, `items/timestamp.sh`, `items/pomodoro.sh`
- `plugins/battery.lua`, `plugins/cafe.lua`, `plugins/timestamp.lua`, `plugins/pomodoro.lua`
- `plugins/calc_icon_width.lua`
- `lua/lib/sketchybar.lua`, `lua/lib/theme.lua`

### Files kept untouched (not in scope)

All other inactive `items/*.sh` and `plugins/*.lua`, plus `lua/lib/audio_devices.lua`, `tests/`, `data/`, `ITEMS.md`, `backup-*/`.

---

## 4. Entry Point & Core

### `sketchybarrc`

```lua
#!/usr/bin/env lua
Sbar = require("sketchybar")
Sbar.begin_config()
require("init")
Sbar.hotload(true)
Sbar.end_config()
Sbar.event_loop()
```

`Sbar` is a process-global so item files can call it without re-importing.

### `init.lua`

```lua
require("core.bar")
require("core.default")
require("items")
```

### `core/bar.lua`

Port of the `BAR=(...)` block. Imports `helpers.colors` and `helpers.settings`, calls `Sbar.bar({...})`.

### `core/default.lua`

Port of the `DEFAULT=(...)` block. Imports same helpers, calls `Sbar.default({...})`. Sets font, sizes, padding, and background colors for all items.

---

## 5. Helpers

### `helpers/colors.lua`

Direct port of `colors.sh`. Returns a table with BASE00–BASE17 as Lua strings (`"0xFFRRGGBB"`) plus named aliases: `background`, `background_alt`, `foreground`, `accent`, `border`, `bar_border`.

### `helpers/settings.lua`

Direct port of `theme.sh`. Returns a table with:
- `bar` sub-table: height, margin, y_offset, corner_radius, border_width, blur_radius, padding_left, padding_right
- `defaults` sub-table: bg_height, bg_y_offset, padding_left, padding_right, corner_radius, border_width
- Top-level: `font`, `icon_size`, `label_size`, `inner_padding`, `outer_padding`

### `helpers/utils.lua`

Three pure functions:

**`set_alpha(hex, percent)`** — port of the bash `set_alpha` function. Takes a `"0xFFRRGGBB"` string and an integer 0–100, returns a new hex string with the alpha channel replaced.

**`capture(cmd)`** — thin wrapper around `io.popen`. Returns trimmed stdout or `""` on failure.

**`icon_width(min, max, ratio, fallback)`** — queries display width via `Sbar.query("displays")`. Computes `math.max(min, math.min(max, width * ratio))`. Returns `fallback` if the query fails or returns no usable display info.

---

## 6. Items

Item names drop the `lua.` prefix used in the hybrid setup. All items use `Sbar.add()`, `Sbar.set()`, and `Sbar.subscribe()`.

### `items/cafe.lua`

Single item at center position. Two subscriptions:

- `routine` (update_freq=10): runs `capture("pgrep -x caffeinate")`, sets icon (`􀸘` off / `􀸙` on) and `icon.color` (`colors.base04` off / `colors.base0a` on).
- `mouse.clicked`: toggles caffeinate via `os.execute("nohup caffeinate -dimsu >/dev/null 2>&1 &")` or `os.execute("kill " .. pid)`, then calls the same update logic inline.

### `items/timestamp.lua`

Two items + one bracket:
- `timestamp_time` — right position, no icon, update_freq=1
- `timestamp_date` — right position, calendar icon (`􀉉`), no subscription of its own
- bracket `timestamp_group` around both, with `background.color = colors.background`

One shared update function uses `capture("TZ=Asia/Seoul date '+%H:%M:%S'")` and `capture("TZ=Asia/Seoul date '+%Y-%m-%d'")` and sets both items' labels. Only `timestamp_time` subscribes to `routine`; that single callback updates both.

### `items/battery.lua`

One item + one popup child:
- `battery` — right position, width from `icon_width(27, 45, 0.02025, 33)`
- `battery_popup` — child of `popup.battery`

Module-level variable `popup_opened_at = nil` tracks when the popup was opened.

Subscriptions on `battery`:
- `system_woke`, `power_source_change`: runs `capture("pmset -g batt")`, parses percentage and charging state, sets icon and `icon.color`.
- `mouse.clicked`: toggles popup open/close using `Sbar.animate("sin", 15, ...)`. Sets `popup_opened_at = os.time()` on open, `nil` on close.
- `routine` (update_freq=1): if `popup_opened_at` is set and `os.time() - popup_opened_at >= 2`, closes popup and clears `popup_opened_at`. Also refreshes battery status on each tick.

### `items/pomodoro.lua`

Four items + one bracket:
- `pomodoro_work` — center, work icon (`􀠸`), width from `icon_width(27, 45, 0.02025, 33)`
- `pomodoro_work_popup` — child of `popup.pomodoro_work`
- `pomodoro_break` — center, break icon (`􀼙`), same width, initially `drawing=false`
- `pomodoro_break_popup` — child of `popup.pomodoro_break`
- bracket `pomodoro_group` around both

**State** (module-level Lua variables):
```lua
local mode       = "none"   -- "none" | "work" | "break"
local start_time = nil      -- os.time() value when current phase started
local WORK_SECS  = 25 * 60
local BREAK_SECS = 5 * 60
```

`duration` is not stored separately — it is always derived at call time: `WORK_SECS` when `mode == "work"`, `BREAK_SECS` when `mode == "break"`.

State is persisted to `~/.pomodoro/pomo_state` using pure `io.open/write` (two lines: mode and start_time as a Unix timestamp string). State is loaded from this file at **module load time** (when `items/pomodoro.lua` is `require()`d), so it survives hot-reloads. The routine callback reads only the in-memory module variables, never the file.

**`routine` subscription** (update_freq=1) on both items, shared callback:
1. If `mode == "none"`: return early.
2. Compute `duration = (mode == "work") and WORK_SECS or BREAK_SECS`.
3. Compute `remaining = duration - (os.time() - start_time)`.
4. If `remaining <= 0`: switch mode (work→break, break→work), reset `start_time`, persist state, update item visibility and popup labels.
5. Otherwise: format `remaining` as `"MM:SS"`, update the active popup label.

**`mouse.clicked` subscription** on both items:
- Left click on the active item: if that mode is running, stop it (set `mode = "none"`, clear `start_time`); if no mode is running, start it.
- Left click on the inactive item: stop current mode, start the clicked item's mode.
- Right click: force-start the other mode regardless of current state.

No background subprocesses, no `afplay`, no `terminal-notifier`. The countdown is entirely driven by the `routine` tick.

---

## 7. Item Naming

| Old name (hybrid)          | New name (native Lua)   |
|---------------------------|-------------------------|
| `lua.battery`             | `battery`               |
| `lua.battery.popup`       | `battery_popup`         |
| `lua.cafe`                | `cafe`                  |
| `lua.timestamp.time`      | `timestamp_time`        |
| `lua.timestamp.date`      | `timestamp_date`        |
| `lua.timestamp_group`     | `timestamp_group`       |
| `lua.pomodoro_work`       | `pomodoro_work`         |
| `lua.pomodoro_work.popup` | `pomodoro_work_popup`   |
| `lua.pomodoro_break`      | `pomodoro_break`        |
| `lua.pomodoro_break.popup`| `pomodoro_break_popup`  |
| `lua.pomodoro`            | `pomodoro_group`        |

---

## 8. What Does Not Change

- Color palette values (BASE00–BASE17) — same hex values, just in a Lua table
- Bar geometry and default item styling — same values, different format
- Pomodoro timer durations (25 min work / 5 min break)
- Timestamp timezone (Asia/Seoul)
- Icon glyphs (SF Symbols)
- Battery popup auto-close behavior (2-second timeout)
- Cafe caffeinate toggle behavior
