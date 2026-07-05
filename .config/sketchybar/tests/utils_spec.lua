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
