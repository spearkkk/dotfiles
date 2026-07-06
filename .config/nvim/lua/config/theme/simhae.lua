local M = {}

local palettes = {
  trench = {
    base00 = "#081520", base01 = "#0F2235", base02 = "#182C3E", base03 = "#20364A",
    base04 = "#4C6A88", base05 = "#BED0E2", base06 = "#DCE0E8", base07 = "#EEF0F4",
    base08 = "#C47A72", base09 = "#C8945A", base0A = "#C8AE6A", base0B = "#6AB898",
    base0C = "#58C0C8", base0D = "#7090CC", base0E = "#9A7EC8", base0F = "#8C6040",
    base10 = "#050E18", base11 = "#D08880", base12 = "#D4A870", base13 = "#D4BE82",
    base14 = "#82CCB0", base15 = "#72D0D8", base16 = "#8AAAD8", base17 = "#AE96D4",
  },
  hadal = {
    base00 = "#0D1B2A", base01 = "#162A40", base02 = "#1E3652", base03 = "#243C5A",
    base04 = "#4E6E8C", base05 = "#C8D8E8", base06 = "#D8E2EE", base07 = "#EDF1F6",
    base08 = "#C47A72", base09 = "#C8945A", base0A = "#C8AE6A", base0B = "#72B89A",
    base0C = "#6ABDC8", base0D = "#7090CC", base0E = "#9A7EC8", base0F = "#8C6040",
    base10 = "#081018", base11 = "#D08880", base12 = "#D4A870", base13 = "#D4BE82",
    base14 = "#88CCAE", base15 = "#80CDD8", base16 = "#8AAAD8", base17 = "#AE96D4",
  },
  pelagic = {
    base00 = "#0A1F2E", base01 = "#142C3E", base02 = "#1C3A50", base03 = "#24425C",
    base04 = "#4A6E86", base05 = "#C6D8E4", base06 = "#D6E2E8", base07 = "#ECF0F4",
    base08 = "#C47A72", base09 = "#C8945A", base0A = "#C8AE6A", base0B = "#68BE92",
    base0C = "#50C4C0", base0D = "#7896CC", base0E = "#9A7EC8", base0F = "#8C6040",
    base10 = "#071420", base11 = "#D08880", base12 = "#D4A870", base13 = "#D4BE82",
    base14 = "#80CCAA", base15 = "#68D4D0", base16 = "#90AED8", base17 = "#AE96D4",
  },
  benthic = {
    base00 = "#0C2030", base01 = "#162E42", base02 = "#1E3C54", base03 = "#26445E",
    base04 = "#4A7080", base05 = "#C8DAE2", base06 = "#D6E4E8", base07 = "#ECF1F3",
    base08 = "#C47A72", base09 = "#C8945A", base0A = "#C8AE6A", base0B = "#62BC8A",
    base0C = "#48C8BC", base0D = "#7896CC", base0E = "#9A7EC8", base0F = "#8C6040",
    base10 = "#071520", base11 = "#D08880", base12 = "#D4A870", base13 = "#D4BE82",
    base14 = "#7CCCA4", base15 = "#62D8D0", base16 = "#90AED8", base17 = "#AE96D4",
  },
}

local function set_hl(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

local function bool(v)
  local s = tostring(v or ""):lower()
  return v == true or v == 1 or s == "1" or s == "true" or s == "yes" or s == "on"
end

function M.get_palette(variant)
  return palettes[variant] or palettes.pelagic
end

local function resolve_opts(opts)
  opts = opts or {}
  return {
    variant = opts.variant or vim.g.simhae_variant or "pelagic",
    contrast = opts.contrast or vim.g.simhae_background or "medium", -- hard|medium|soft
    foreground = opts.foreground or vim.g.simhae_foreground or "material", -- material|mix|original
    transparent = bool(opts.transparent_background or vim.g.simhae_transparent),
    enable_italic = bool(opts.enable_italic or vim.g.simhae_enable_italic or 1),
    disable_italic_comment = bool(opts.disable_italic_comment or vim.g.simhae_disable_italic_comment or 0),
    enable_bold = bool(opts.enable_bold or vim.g.simhae_enable_bold or 1),
    diagnostic_text = bool(opts.diagnostic_text or vim.g.simhae_diagnostic_text_highlight or 0),
  }
end

local function pick_bg(c, contrast)
  if contrast == "hard" then
    return c.base10
  elseif contrast == "soft" then
    return c.base01
  end
  return c.base00
end

local function pick_fg(c, mode)
  if mode == "mix" then
    return c.base06
  elseif mode == "original" then
    return c.base05
  end
  return c.base05
end

function M.load(opts)
  local o = resolve_opts(opts)
  local c = M.get_palette(o.variant)

  vim.o.termguicolors = true
  vim.g.colors_name = "simhae"

  local base_bg = pick_bg(c, o.contrast)
  local bg = o.transparent and "NONE" or base_bg
  local float_bg = c.base01
  local fg = pick_fg(c, o.foreground)

  set_hl("Normal", { fg = fg, bg = bg })
  set_hl("NormalFloat", { fg = fg, bg = float_bg })
  set_hl("FloatBorder", { fg = c.base03, bg = float_bg })
  set_hl("SignColumn", { fg = c.base04, bg = bg })
  set_hl("LineNr", { fg = c.base03, bg = bg })
  set_hl("CursorLineNr", { fg = c.base0A, bg = bg, bold = o.enable_bold })
  set_hl("CursorLine", { bg = c.base01 })
  set_hl("Visual", { bg = c.base02 })
  set_hl("Search", { fg = c.base00, bg = c.base0A })
  set_hl("IncSearch", { fg = c.base00, bg = c.base09 })
  set_hl("Pmenu", { fg = fg, bg = c.base01 })
  set_hl("PmenuSel", { fg = c.base00, bg = c.base0D })
  set_hl("StatusLine", { fg = fg, bg = c.base02 })
  set_hl("StatusLineNC", { fg = c.base04, bg = c.base01 })
  set_hl("VertSplit", { fg = c.base03, bg = c.base03 })
  set_hl("WinSeparator", { fg = c.base03, bg = c.base03 })
  set_hl("EndOfBuffer", { fg = c.base01, bg = bg })
  set_hl("Folded", { fg = c.base04, bg = c.base01 })
  set_hl("FoldColumn", { fg = c.base04, bg = bg })

  set_hl("Comment", { fg = c.base04, italic = o.enable_italic and not o.disable_italic_comment })
  set_hl("Constant", { fg = c.base09 })
  set_hl("String", { fg = c.base0B })
  set_hl("Character", { fg = c.base0B })
  set_hl("Number", { fg = c.base09 })
  set_hl("Boolean", { fg = c.base09 })
  set_hl("Identifier", { fg = fg })
  set_hl("Function", { fg = c.base0D })
  set_hl("Statement", { fg = c.base0E })
  set_hl("Conditional", { fg = c.base0E })
  set_hl("Repeat", { fg = c.base0E })
  set_hl("Operator", { fg = c.base0C })
  set_hl("Keyword", { fg = c.base0E })
  set_hl("Type", { fg = c.base0A })
  set_hl("Special", { fg = c.base0C })
  set_hl("PreProc", { fg = c.base0A })
  set_hl("Todo", { fg = c.base00, bg = c.base0A, bold = o.enable_bold })

  set_hl("DiagnosticError", { fg = c.base08 })
  set_hl("DiagnosticWarn", { fg = c.base0A })
  set_hl("DiagnosticInfo", { fg = c.base0D })
  set_hl("DiagnosticHint", { fg = c.base0C })
  set_hl("DiagnosticOk", { fg = c.base0B })
  if o.diagnostic_text then
    set_hl("DiagnosticVirtualTextError", { fg = c.base08, bg = c.base01 })
    set_hl("DiagnosticVirtualTextWarn", { fg = c.base0A, bg = c.base01 })
    set_hl("DiagnosticVirtualTextInfo", { fg = c.base0D, bg = c.base01 })
    set_hl("DiagnosticVirtualTextHint", { fg = c.base0C, bg = c.base01 })
  else
    set_hl("DiagnosticVirtualTextError", { fg = c.base08, bg = "NONE" })
    set_hl("DiagnosticVirtualTextWarn", { fg = c.base0A, bg = "NONE" })
    set_hl("DiagnosticVirtualTextInfo", { fg = c.base0D, bg = "NONE" })
    set_hl("DiagnosticVirtualTextHint", { fg = c.base0C, bg = "NONE" })
  end

  set_hl("DiffAdd", { fg = c.base0B, bg = c.base01 })
  set_hl("DiffChange", { fg = c.base0A, bg = c.base01 })
  set_hl("DiffDelete", { fg = c.base08, bg = c.base01 })
  set_hl("DiffText", { fg = c.base0D, bg = c.base02 })

  vim.g.terminal_color_0 = c.base00
  vim.g.terminal_color_1 = c.base08
  vim.g.terminal_color_2 = c.base0B
  vim.g.terminal_color_3 = c.base0A
  vim.g.terminal_color_4 = c.base0D
  vim.g.terminal_color_5 = c.base0E
  vim.g.terminal_color_6 = c.base0C
  vim.g.terminal_color_7 = c.base05
  vim.g.terminal_color_8 = c.base03
  vim.g.terminal_color_9 = c.base11
  vim.g.terminal_color_10 = c.base14
  vim.g.terminal_color_11 = c.base13
  vim.g.terminal_color_12 = c.base16
  vim.g.terminal_color_13 = c.base17
  vim.g.terminal_color_14 = c.base15
  vim.g.terminal_color_15 = c.base07
end

function M.lualine_theme(opts)
  local o = resolve_opts(opts)
  local c = M.get_palette(o.variant)
  local bg = pick_bg(c, o.contrast)
  local fg = pick_fg(c, o.foreground)
  local inactive_bg = c.base01
  local inactive_fg = c.base04
  local bold = o.enable_bold and "bold" or "none"

  return {
    normal = {
      a = { bg = c.base0D, fg = bg, gui = bold },
      b = { bg = bg, fg = fg },
      c = { bg = bg, fg = fg },
    },
    insert = {
      a = { bg = c.base0B, fg = bg, gui = bold },
      b = { bg = bg, fg = fg },
      c = { bg = bg, fg = fg },
    },
    visual = {
      a = { bg = c.base0E, fg = bg, gui = bold },
      b = { bg = bg, fg = fg },
      c = { bg = bg, fg = fg },
    },
    command = {
      a = { bg = c.base0A, fg = bg, gui = bold },
      b = { bg = bg, fg = fg },
      c = { bg = bg, fg = fg },
    },
    replace = {
      a = { bg = c.base08, fg = bg, gui = bold },
      b = { bg = bg, fg = fg },
      c = { bg = bg, fg = fg },
    },
    inactive = {
      a = { bg = inactive_bg, fg = inactive_fg, gui = bold },
      b = { bg = inactive_bg, fg = inactive_fg },
      c = { bg = inactive_bg, fg = inactive_fg },
    },
  }
end

return M
