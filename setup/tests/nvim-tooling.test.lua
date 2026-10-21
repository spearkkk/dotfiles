local repo_root = assert(os.getenv("REPO_ROOT"), "REPO_ROOT is required")

package.path = table.concat({
  repo_root .. "/home/.config/nvim/lua/?.lua",
  repo_root .. "/home/.config/nvim/lua/?/init.lua",
  package.path,
}, ";")

local function contains(values, expected)
  for _, value in ipairs(values) do
    if value == expected then
      return true
    end
  end
  return false
end

local tooling = require("config.tooling")

for _, tool in ipairs({
  "taplo",
  "basedpyright",
  "ruff",
  "fish-lsp",
  "shellcheck",
  "shfmt",
  "kotlin-language-server",
  "ktlint",
}) do
  assert(contains(tooling.mason, tool), "missing Mason tool: " .. tool)
end

for filetype, formatter in pairs({
  toml = "taplo",
  python = "ruff_format",
  fish = "fish_indent",
  sh = "shfmt",
  bash = "shfmt",
  kotlin = "ktlint",
}) do
  local configured = assert(tooling.formatters_by_ft[filetype], "missing formatter filetype: " .. filetype)
  assert(contains(configured, formatter), string.format("missing %s formatter for %s", formatter, filetype))
end

assert(contains(tooling.treesitter, "kotlin"), "missing Kotlin Treesitter parser")

local conform_specs = dofile(repo_root .. "/home/.config/nvim/lua/config/plugins/conform.lua")
assert(conform_specs[1].opts.formatters_by_ft == tooling.formatters_by_ft, "Conform must use the shared formatter map")

local lsp_specs = dofile(repo_root .. "/home/.config/nvim/lua/config/plugins/lsp/init.lua")
local installer
for _, spec in ipairs(lsp_specs) do
  if spec[1] == "WhoIsSethDaniel/mason-tool-installer.nvim" then
    installer = spec
    break
  end
end
assert(installer, "mason-tool-installer.nvim is not configured")
assert(installer.opts.ensure_installed == tooling.mason, "Mason installer must use the shared tool list")

local lsp
for _, spec in ipairs(lsp_specs) do
  if spec[1] == "neovim/nvim-lspconfig" then
    lsp = spec
    break
  end
end
assert(lsp, "nvim-lspconfig is not configured")

local configured = {}
local mason_setup
local original_lsp_config = vim.lsp.config
vim.lsp.config = function(name, opts)
  configured[name] = opts
end
package.loaded["blink.cmp"] = {
  get_lsp_capabilities = function()
    return {}
  end,
}
package.loaded["mason-lspconfig"] = {
  setup = function(opts)
    mason_setup = opts
  end,
}

lsp.config()
vim.lsp.config = original_lsp_config

assert(mason_setup, "mason-lspconfig setup was not called")
assert(mason_setup.automatic_enable.exclude[1] == "jdtls", "jdtls must remain excluded from automatic enable")
assert(configured.ruff and configured.ruff.on_attach, "Ruff hover suppression is not configured")

local fake_ruff = { server_capabilities = { hoverProvider = true } }
configured.ruff.on_attach(fake_ruff)
assert(fake_ruff.server_capabilities.hoverProvider == false, "Ruff hover must be disabled in favor of BasedPyright")

print("PASS: nvim-tooling")
