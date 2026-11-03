-- Headless renderer. Never displays, plays audio, or logs notification contents.
local contract = require('nudge.contract')
local M = {}
function M.new()
  local self = {kind='debug', records={}}
  function self:restore(active)
    local records = {}
    for _, record in ipairs(active) do records[record.id] = contract.copy(record) end
    self.records = records
  end
  function self:upsert(record) self.records[record.id] = contract.copy(record) end
  function self:remove(id) self.records[id] = nil end
  function self:count()
    local count = 0
    for _ in pairs(self.records) do count = count + 1 end
    return count
  end
  return self
end
return M
