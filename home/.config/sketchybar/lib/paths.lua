local M = {}

local home = os.getenv("HOME") or ""
local cache_home = os.getenv("XDG_CACHE_HOME")
if not cache_home or cache_home == "" then
  cache_home = home .. "/.cache"
end

M.cache_dir = cache_home .. "/sketchybar"

M.media_tsv = M.cache_dir .. "/media.tsv"
M.media_json = M.cache_dir .. "/media.json"
M.media_pid = M.cache_dir .. "/media.pid"
M.media_refresh_request = M.cache_dir .. "/media.refresh"

M.calendar_cache = M.cache_dir .. "/calendar.tsv"
M.calendar_pid = M.cache_dir .. "/calendar.pid"
M.calendar_refresh_request = M.cache_dir .. "/calendar.refresh"

return M
