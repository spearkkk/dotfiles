-- Host audio effects only. Requests are validated by the shared contract.
local M = {}

function M.host_backend(h, home)
  local directories={home..'/Library/Sounds','/Library/Sounds',
    '/Network/Library/Sounds','/System/Library/Sounds'}
  return {
    getByFile=function(path) return h.sound.getByFile(path) end,
    getByName=function(name)
      -- getByName shares native NSSound objects, delegates and finalizers. Load
      -- independent unnamed objects instead, using the documented search paths.
      -- Never construct a path from the caller's sound name.
      for _,directory in ipairs(directories) do
        local ok,audio=pcall(function()
          local files={}
          for filename in h.fs.dir(directory) do files[#files+1]=filename end
          table.sort(files)
          for _,filename in ipairs(files) do
            if filename:match('^(.*)%.[^.]+$')==name then
              local sound=h.sound.getByFile(directory..'/'..filename)
              if sound then return sound end
            end
          end
        end)
        if ok and audio then return audio end
      end
    end,
  }
end

function M.new(backend)
  local self = {active={},stopped=false}
  local warning = 'Sound playback failed'
  local function release(audio, stop)
    self.active[audio]=nil
    pcall(function() audio:setCallback(nil) end)
    if stop then pcall(function() audio:stop() end) end
  end
  function self:play(spec)
    if self.stopped then return false end
    local audio
    local ok, started = pcall(function()
      if spec.name then audio=backend.getByName(spec.name)
      else audio=backend.getByFile(spec.file) end
      if not audio then return false end
      self.active[audio]=true
      audio:loopSound(false)
      audio:setCallback(function(completed)
        release(audio,false)
        if not completed and not self.stopped then self.last_error=warning end
      end)
      return audio:play()
    end)
    if not ok or not started then
      self.last_error=warning
      if audio then release(audio,true) end
      return false
    end
    return true
  end
  function self:status() return {last_error=self.last_error} end
  function self:stop()
    if self.stopped then return end
    self.stopped=true
    for audio in pairs(self.active) do release(audio,true) end
  end
  return self
end
return M
