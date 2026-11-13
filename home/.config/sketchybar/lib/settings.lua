local M = {}

M.bar = {
  height        = 40,
  margin        = 0,
  topmost       = "on",
  y_offset      = 0,
  corner_radius = 0,
  border_width  = 3,
  blur_radius   = 0,
  padding_left  = 4,
  padding_right = 4,
}

M.defaults = {
  bg_height     = 26,
  bg_y_offset   = 0,
  padding_left  = 4,
  padding_right = 4,
  corner_radius = 4,
  border_width  = 0,
}

M.font          = "SF Pro"
M.icon_font     = "tabler-icons"
M.icon_size     = 20
M.icon_cell_width = 26
M.label_size    = 13
M.inner_padding = 2
M.outer_padding = 4

M.double_line_top_y = -7
M.double_line_bottom_y = 9
M.text_size_large = 14
M.text_size_small = 11
M.update_freq_fast = 1
M.update_freq_slow = 60
M.cafe_max_awake_seconds = 24 * 60 * 60
M.pomodoro_work_seconds = 25 * 60
M.pomodoro_short_break_seconds = 5 * 60
M.pomodoro_long_break_seconds = 15 * 60
M.pomodoro_long_break_every = 4
M.pomodoro_sound_work_done = "Glass"
M.pomodoro_sound_break_done = "Ping"
M.pomodoro_sound_long_break = "Hero"

return M
