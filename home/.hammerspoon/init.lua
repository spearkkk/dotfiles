require("hs.ipc")

-- A broken notification service must never disable window management/dimming.
if type(nudge)=="table" and nudge.stop then pcall(function() nudge:stop() end) end
local nudge_ok, nudge_service = pcall(function() return require("nudge").start() end)
if nudge_ok then
  nudge = nudge_service
else
  nudge = { handle_json = function()
    return '{"ok":false,"operation":"doctor","exit_code":4,"stored":false,"error":{"message":"Nudge failed to initialize; check its installation"}}'
  end }
end

require("modules.aerospace_alt_tab")
require("modules.inactive_display_dim")

local previous_shutdown = hs.shutdownCallback
hs.shutdownCallback = function()
  if nudge and nudge.stop then pcall(function() nudge:stop() end) end
  if previous_shutdown then pcall(previous_shutdown) end
end
