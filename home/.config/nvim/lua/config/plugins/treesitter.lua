local tooling = require("config.tooling")

return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")

      local langs = tooling.treesitter

      local function attach(buf)
        if not vim.api.nvim_buf_is_loaded(buf) then return end
        local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
        if not vim.tbl_contains(langs, lang) then return end

        -- A fresh install can still be compiling this parser. Preserve the
        -- buffer's existing fallback options until highlighting can start.
        if not pcall(vim.treesitter.start, buf, lang) then return end
        vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == buf then
            vim.wo[win].foldexpr = "v:lua.vim.treesitter.foldexpr()"
            vim.wo[win].foldmethod = "expr"
          end
        end
      end

      vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
        group = vim.api.nvim_create_augroup("DotfilesTreesitter", { clear = true }),
        callback = function(event)
          attach(event.buf)
        end,
      })

      -- Never wait synchronously for downloads/compilation. Also retry open
      -- buffers after a partial install; attach checks each parser separately.
      treesitter.install(langs):await(vim.schedule_wrap(function(err)
        if err then
          vim.notify("Treesitter parser installation failed: " .. tostring(err), vim.log.levels.WARN)
        end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          attach(buf)
        end
      end))
    end,
  },
}
