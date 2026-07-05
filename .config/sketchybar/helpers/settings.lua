local M = {}

M.bar = {
  height        = 33,
  margin        = 4,
  y_offset      = 4,
  corner_radius = 8,
  border_width  = 3,
  blur_radius   = 0,
  padding_left  = 4,
  padding_right = 4,
}

M.defaults = {
  bg_height     = 28,
  bg_y_offset   = 0,
  padding_left  = 6,
  padding_right = 6,
  corner_radius = 4,
  border_width  = 0,
}

M.font          = "SF Mono"
M.icon_size     = 14
M.label_size    = 14
M.inner_padding = 2
M.outer_padding = 6

return M
