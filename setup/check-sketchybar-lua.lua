-- Load this exact binary, never a fallback from the user's package.cpath.
-- Run in a disposable Lua process; do not configure a bar or run its loop.
assert(_VERSION == "Lua 5.4", "SketchyBar requires Lua 5.4")
local path = assert(arg[1], "expected the bridge binary path")
local loader = assert(package.loadlib(path, "luaopen_sketchybar"))
local bridge = loader()
assert(type(bridge) == "table", "SketchyBar module did not return a table")
for _, name in ipairs({
  "add", "remove", "set", "bar", "default", "animate", "subscribe", "query",
  "event_loop", "hotload", "set_bar_name", "trigger", "push", "exec", "delay",
  "begin_config", "end_config",
}) do
  assert(type(bridge[name]) == "function", "SketchyBar API missing: " .. name)
end
print("PASS: SketchyBar Lua 5.4 bridge loads (no bar commands or event loop)")
