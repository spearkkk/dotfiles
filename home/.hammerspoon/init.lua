require("hs.ipc")

-- A broken notification service must never disable window management/dimming.
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
