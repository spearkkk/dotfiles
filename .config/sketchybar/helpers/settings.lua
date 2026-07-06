local M = {}

M.bar = {
  height        = 40,
  margin        = 4,
  y_offset      = 4,
  corner_radius = 8,
  border_width  = 3,
  blur_radius   = 0,
  padding_left  = 4,
  padding_right = 4,
}

M.defaults = {
  bg_height     = 26,
  bg_y_offset   = 0,
  padding_left  = 6,
  padding_right = 6,
  corner_radius = 4,
  border_width  = 0,
}

M.font          = "SF Mono"
M.icon_size     = 16
M.label_size    = 13
M.inner_padding = 2
M.outer_padding = 6

M.double_line_top_y = -7
M.double_line_bottom_y = 9
M.text_size_large = 14
M.text_size_small = 11
M.update_freq_fast = 1
M.update_freq_slow = 60

return M
