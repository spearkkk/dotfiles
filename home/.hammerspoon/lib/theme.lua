-- Generated from: share/themes/simhae/palette.yaml
-- Main palette: pelagic
-- Do not edit manually. Regenerate with: setup/set-theme.sh

local M = {}

M.colors = {
  bg = { hex = "#0A1F2E", alpha = 1 },
  surface = { hex = "#142C3E", alpha = 1 },
  surface_alt = { hex = "#1C3A50", alpha = 1 },
  fg = { hex = "#C6D8E4", alpha = 1 },
  muted = { hex = "#4A6E86", alpha = 1 },
  accent = { hex = "#50C4C0", alpha = 1 },
  warn = { hex = "#C8AE6A", alpha = 1 },
  error = { hex = "#C47A72", alpha = 1 },
}

M.aerospace_alt_tab = {
  background = M.colors.surface,
  border = { hex = M.colors.muted.hex, alpha = 0.90 },
  icon = M.colors.warn,
  text = M.colors.fg,
  empty = M.colors.muted,
  selected = { hex = M.colors.warn.hex, alpha = 0.22 },
}

M.inactive_display_dim = {
  overlay = { hex = M.colors.muted.hex, alpha = 0.45 },
}

return M
