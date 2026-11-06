local root = assert(os.getenv("REPO_ROOT"))
local fixture = assert(vim.uv.fs_realpath(assert(os.getenv("NVIM_TEST_ROOT"))))
package.path = root .. "/home/.config/nvim/lua/?.lua;" .. package.path
vim.cmd("filetype plugin indent off")

local function write(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
end

-- Real filesystem roots and Java-version probing, but never real mise/JDK/LSP.
local bin = fixture .. "/bin"
write(bin .. "/java", { "#!/bin/sh", [[echo 'openjdk version "21.0.1"' >&2]] })
write(bin .. "/mise", { "#!/bin/sh", "printf '%s\\n' '" .. bin .. "/java'" })
write(bin .. "/jdtls", { "#!/bin/sh", "exit 99" })
for _, name in ipairs({ "java", "mise", "jdtls" }) do
  assert(vim.uv.fs_chmod(bin .. "/" .. name, 493)) -- 0755
end
vim.env.PATH = bin .. ":/usr/bin:/bin"
local project_a, project_b = fixture .. "/a/service", fixture .. "/b/service"
write(project_a .. "/pom.xml", { "<project/>" })
write(project_b .. "/build.gradle", { "// fixture" })

local attaches, starts, installed, installation_complete, missing, notifications
local function reset()
  vim.api.nvim_clear_autocmds({ event = "FileType" })
  vim.api.nvim_clear_autocmds({ event = "BufWinEnter" })
  if #vim.api.nvim_list_wins() > 1 then vim.cmd("only!") end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  end
  attaches, starts, missing, notifications = {}, {}, {}, {}
  vim.notify = function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end
  installed, installation_complete = nil, nil
  package.loaded["jdtls"] = {
    extendedClientCapabilities = {},
    start_or_attach = function(config)
      attaches[#attaches + 1] = { buf = vim.api.nvim_get_current_buf(), config = config }
    end,
  }
  package.loaded["nvim-treesitter"] = {
    install = function(langs)
      installed = langs
      return { await = function(_, callback) installation_complete = callback end }
    end,
  }
  vim.treesitter.start = function(buf, lang)
    buf = (not buf or buf == 0) and vim.api.nvim_get_current_buf() or buf
    lang = lang or vim.treesitter.language.get_lang(vim.bo[buf].filetype)
    if missing[lang] then error("fixture: parser unavailable") end
    starts[#starts + 1] = { buf = buf, lang = lang }
  end
  -- The pinned nvim-treesitter plugin registers these using the same native API.
  vim.treesitter.language.register("bash", "sh")
  vim.treesitter.language.register("javascript", "javascriptreact")
  vim.treesitter.language.register("tsx", "typescriptreact")
  vim.wo.foldmethod, vim.wo.foldexpr = "manual", "0"
end

local function buffer(path, ft)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_name(buf, path)
  vim.cmd("noautocmd setlocal filetype=" .. ft)
  vim.bo[buf].indentexpr = ""
  return buf
end

local function filetype(buf)
  vim.api.nvim_exec_autocmds("FileType", { buffer = buf, modeline = false })
end

local function setup(name)
  dofile(root .. "/home/.config/nvim/lua/config/plugins/" .. name .. ".lua")[1].config()
end

local function has_start(buf, lang)
  for _, start in ipairs(starts) do
    if start.buf == buf and start.lang == lang then return true end
  end
  return false
end

local tests = {
  { "Java attaches the initial and subsequent buffers in one project", function()
    local first = buffer(project_a .. "/First.java", "java")
    setup("jdtls")
    -- lazy.nvim replays FileType after loading an ft-triggered plugin.
    filetype(first)
    local second = buffer(project_a .. "/Second.java", "java")
    filetype(second)
    assert(#attaches == 2, "each Java FileType must attempt attachment")
    assert(attaches[1].buf == first and attaches[2].buf == second)
    assert(attaches[1].config.root_dir == project_a)
    assert(attaches[1].config.cmd[3] == bin .. "/java", "preserve mise JDK selection")
    assert(attaches[1].config.cmd[5] == attaches[2].config.cmd[5], "reuse per-project workspace")
  end },
  { "Java computes a separate root/workspace for each project", function()
    local first = buffer(project_a .. "/First.java", "java")
    setup("jdtls"); filetype(first)
    local second = buffer(project_b .. "/Second.java", "java")
    filetype(second)
    assert(#attaches == 2, "second project must attach")
    assert(attaches[2].config.root_dir == project_b)
    assert(attaches[1].config.cmd[5] ~= attaches[2].config.cmd[5], "same-named projects need distinct workspaces")
  end },
  { "Rootless first Java buffer does not prevent later attachment", function()
    local standalone = buffer(fixture .. "/Standalone.java", "java")
    setup("jdtls"); filetype(standalone)
    assert(#attaches == 0, "keep rootless buffers unattached")
    local project = buffer(project_a .. "/First.java", "java")
    filetype(project)
    assert(#attaches == 1 and attaches[1].buf == project, "rootless startup must not disable later Java buffers")
    filetype(buffer(fixture .. "/notes.txt", "text"))
    assert(#attaches == 1, "ignore non-Java buffers")
  end },
  { "Java configuration reload does not duplicate callbacks", function()
    buffer(fixture .. "/notes.txt", "text")
    setup("jdtls"); setup("jdtls")
    local buf = buffer(project_a .. "/First.java", "java")
    filetype(buf)
    assert(#attaches == 1 and attaches[1].buf == buf)
  end },
  { "Treesitter resolves FileType aliases to configured parsers", function()
    setup("treesitter")
    for ft, lang in pairs({ sh = "bash", typescriptreact = "tsx", javascriptreact = "javascript", help = "vimdoc", lua = "lua" }) do
      local buf = buffer(fixture .. "/example." .. ft, ft)
      filetype(buf)
      assert(has_start(buf, lang), "missing parser attachment for " .. ft)
      assert(vim.wo.foldmethod == "expr" and vim.bo[buf].indentexpr ~= "")
    end
    local before = #starts
    filetype(buffer(fixture .. "/notes.txt", "text"))
    assert(#starts == before, "unconfigured parser must not be started")
    assert(vim.deep_equal(installed, require("config.tooling").treesitter), "retain configured parser installation")
  end },
  { "Unavailable parser leaves folding and indentation unchanged", function()
    setup("treesitter")
    local buf = buffer(fixture .. "/example.lua", "lua")
    vim.wo.foldmethod, vim.wo.foldexpr = "marker", "0"
    vim.bo[buf].indentexpr = "-1"
    missing.lua = true
    filetype(buf)
    assert(vim.wo.foldmethod == "marker" and vim.wo.foldexpr == "0", "failed parser must not change folding")
    assert(vim.bo[buf].indentexpr == "-1", "failed parser must not change indentation")
  end },
  { "Async parser installation initializes already-open buffers", function()
    local buf = buffer(fixture .. "/example.lua", "lua")
    missing.lua = true
    setup("treesitter"); filetype(buf)
    assert(not has_start(buf, "lua"))
    assert(installation_complete, "register an asynchronous install completion callback")
    missing.lua = nil
    installation_complete(nil, true)
    assert(vim.wait(1000, function() return has_start(buf, "lua") end), "open buffer was not retried after installation")
    assert(vim.wo.foldmethod == "expr" and vim.bo[buf].indentexpr ~= "")
  end },
  { "Partial installation only enables available parsers and ignores deleted buffers", function()
    setup("treesitter")
    local deleted = buffer(fixture .. "/gone.lua", "lua")
    vim.api.nvim_buf_delete(deleted, { force = true })
    local unavailable = buffer(fixture .. "/missing.lua", "lua")
    local available = buffer(fixture .. "/ready.py", "python")
    missing.lua = true
    assert(installation_complete, "register install completion")
    installation_complete(nil, false)
    assert(vim.wait(1000, function() return has_start(available, "python") end))
    assert(not has_start(unavailable, "lua") and vim.bo[unavailable].indentexpr == "")
    assert(not has_start(deleted, "lua"))
  end },
  { "Parser installation initializes folds in every split showing the buffer", function()
    missing.lua = true
    setup("treesitter")
    local buf = buffer(fixture .. "/split.lua", "lua")
    filetype(buf)
    local first = vim.api.nvim_get_current_win()
    vim.cmd("split")
    local second = vim.api.nvim_get_current_win()
    assert(vim.api.nvim_win_get_buf(first) == buf and vim.api.nvim_win_get_buf(second) == buf)
    assert(vim.wo[first].foldmethod == "manual" and vim.wo[second].foldmethod == "manual")
    vim.cmd("vsplit")
    local unrelated = buffer(fixture .. "/notes.txt", "text")
    local other_win = vim.api.nvim_get_current_win()
    missing.lua = nil
    installation_complete(nil, true)
    assert(vim.wait(1000, function() return has_start(buf, "lua") end))
    for _, win in ipairs({ first, second }) do
      assert(vim.wo[win].foldmethod == "expr", "installation must initialize every existing split")
      assert(vim.wo[win].foldexpr == "v:lua.vim.treesitter.foldexpr()")
    end
    assert(vim.wo[other_win].foldmethod == "manual" and vim.bo[unrelated].indentexpr == "")
  end },
  { "Treesitter retries on window entry and configuration reload is idempotent", function()
    setup("treesitter"); setup("treesitter")
    local buf = buffer(fixture .. "/example.lua", "lua")
    starts = {}
    filetype(buf)
    assert(#starts == 1, "reload must not duplicate FileType callbacks")
    starts = {}
    vim.wo.foldmethod = "manual"
    vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = buf, modeline = false })
    assert(#starts == 1 and vim.wo.foldmethod == "expr", "window entry must initialize window-local folds")
  end },
  { "Treesitter installation errors are reported without disabling usable parsers", function()
    setup("treesitter")
    local buf = buffer(fixture .. "/ready.py", "python")
    installation_complete("fixture install error")
    assert(vim.wait(1000, function() return #notifications > 0 end), "installation error was swallowed")
    assert(notifications[1].message:find("fixture install error", 1, true))
    assert(notifications[1].level == vim.log.levels.WARN)
    assert(has_start(buf, "python"), "retain already-installed parsers after installation failure")
  end },
}

local failed = 0
for _, test in ipairs(tests) do
  reset()
  local ok, err = pcall(test[2])
  if ok then print("PASS: " .. test[1])
  else failed = failed + 1; print("FAIL: " .. test[1] .. "\n" .. tostring(err)) end
end
assert(failed == 0, tostring(failed) .. " initialization tests failed")
print("PASS: nvim initialization (" .. #tests .. " cases)")
