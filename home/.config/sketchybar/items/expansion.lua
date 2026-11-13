local utils = require("lib.utils")
local detail_binary = utils.shell_quote((os.getenv("HOME") or "") .. "/.local/bin/sketchibar")
local main_inside = false
local generation = 0
local command_busy = false
local pending_hidden
local pointer_query = [[/usr/bin/osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); var p = $.CGEventGetLocation($.CGEventCreate(null)); JSON.stringify({x:p.x, y:p.y});']]

-- Keep the approved 80pt backplate unchanged. Native hidden is a boolean, not
-- an animatable property. Serialize IPC so an older hide cannot beat a new show.
local flush
flush = function()
  if command_busy or pending_hidden == nil then return end
  local hidden = pending_hidden
  pending_hidden = nil
  command_busy = true
  local command = detail_binary .. " --bar hidden=" .. (hidden and "on" or "off") .. " >/dev/null 2>&1"
  -- Both bars share window layer 3 so the macOS menu bar (layer 24) can show
  -- above them. Re-asserting topmost raises the main bar over the detail backplate.
  if not hidden then command = command .. "; sketchybar --bar topmost=window >/dev/null 2>&1" end
  local scheduled = pcall(Sbar.exec, command,
    function()
      command_busy = false
      flush()
    end)
  if not scheduled then
    command_busy = false
    utils.log("expansion: could not schedule visibility command")
    flush()
  end
end

local function set_hidden(hidden)
  pending_hidden = hidden
  flush()
end

local function close_later()
  if main_inside then return end
  generation = generation + 1
  local token = generation
  local reconcile
  local function retry(attempt)
    if token ~= generation or main_inside then return end
    if attempt >= 3 then
      utils.log("expansion: cursor/bar reconciliation unavailable after retries")
      return
    end
    local scheduled = pcall(Sbar.exec, "/bin/sleep 0.2", function() reconcile(attempt + 1) end)
    if not scheduled then retry(3) end
  end
  reconcile = function(attempt)
    if token ~= generation or main_inside then return end
    -- The 80pt backplate overlaps the main bar. Native tracking may suppress
    -- another detail enter on a main→detail roundtrip, and relay subprocesses
    -- may arrive out of order. Cursor geometry, not relay order, decides close.
    local scheduled = pcall(Sbar.exec, pointer_query, function(point, code)
      if token ~= generation or main_inside then return end
      if code ~= 0 or type(point) ~= "table" or type(point.x) ~= "number" or type(point.y) ~= "number" then retry(attempt);return end
      local queried = pcall(Sbar.exec, detail_binary .. " --query bar 2>/dev/null", function(bar, exit_code)
        if token ~= generation or main_inside then return end
        if exit_code ~= 0 or type(bar) ~= "table" or type(bar.height) ~= "number" then retry(attempt);return end
        local ok, displays = pcall(Sbar.query, "displays")
        if not ok or type(displays) ~= "table" then retry(attempt);return end
        local has_frame = false
        for _, display in pairs(displays) do
          local frame = display.frame
          if type(frame) == "table" then
            has_frame = true
            local margin, offset = bar.margin or 0, bar.y_offset or 0
            local top = bar.position == "bottom" and frame.y + frame.h - bar.height - offset or frame.y + offset
            if point.x >= frame.x + margin and point.x < frame.x + frame.w - margin
              and point.y >= top and point.y < top + bar.height then return end
          end
        end
        if not has_frame then retry(attempt);return end
        set_hidden(true)
      end)
      if not queried then retry(attempt) end
    end)
    if not scheduled then retry(attempt) end
  end
  local function close_if_outside() reconcile(0) end
  local scheduled = pcall(Sbar.exec, "/bin/sleep 0.3", close_if_outside)
  if not scheduled then close_if_outside() end
end

Sbar.add("event", "sketchibar_hover")
local controller = Sbar.add("item", "expansion_hover", {
  position = "left",
  drawing = false,
  updates = "on",
})

controller:subscribe("mouse.entered.global", function()
  main_inside = true
  generation = generation + 1
  set_hidden(false)
end)
controller:subscribe("mouse.exited.global", function()
  main_inside = false
  close_later()
end)
controller:subscribe("sketchibar_hover", function(env)
  if env.ACTION == "enter" then
    generation = generation + 1
    set_hidden(false) -- Also supersede a hide already queued/in flight.
    close_later() -- Reconcile even a late enter relayed after the real exit.
  elseif env.ACTION == "exit" then
    close_later()
  end
end)

-- Optional bar must already be running; a hover never launches a new process.
set_hidden(true)
