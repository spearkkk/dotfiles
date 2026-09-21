local function find_glow_preview_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "glowpreview" then
      return win
    end
  end
end

local function close_glow_preview(win)
  local current_win = vim.api.nvim_get_current_win()

  pcall(vim.api.nvim_set_current_win, win)
  pcall(vim.cmd, "Glow!")

  if vim.api.nvim_win_is_valid(current_win) then
    pcall(vim.api.nvim_set_current_win, current_win)
  end
end

local function toggle_glow_preview()
  local preview_win = find_glow_preview_win()

  if preview_win then
    close_glow_preview(preview_win)
    return
  end

  vim.cmd("Glow")
end

return {
  "ellisonleao/glow.nvim",
  cmd = "Glow",
  keys = {
    { "<leader>mp", toggle_glow_preview, desc = "Toggle markdown preview" },
  },
  opts = {
    border = "rounded",
    style = "dark",
    pager = false,
    width_ratio = 0.85,
    height_ratio = 0.85,
  },
}
