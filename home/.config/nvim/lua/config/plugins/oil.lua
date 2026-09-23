return {
  {
    "stevearc/oil.nvim",
    lazy = false,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      default_file_explorer = true,
      delete_to_trash = false,
      skip_confirm_for_simple_edits = false,
      prompt_save_on_select_new_entry = true,
      cleanup_delay_ms = 2000,
      constrain_cursor = "editable",
      watch_for_changes = true,
      columns = {
        "icon",
      },
      buf_options = {
        buflisted = false,
        bufhidden = "hide",
      },
      win_options = {
        wrap = false,
        number = false,
        relativenumber = false,
        signcolumn = "no",
        cursorcolumn = false,
        foldcolumn = "0",
        spell = false,
        list = false,
        conceallevel = 3,
        concealcursor = "nvic",
      },
      view_options = {
        show_hidden = true,
        natural_order = true,
        case_insensitive = true,
        sort = {
          { "type", "asc" },
          { "name", "asc" },
        },
        is_always_hidden = function(name, bufnr)
          return name == ".DS_Store" or name == ".."
        end,
      },
      preview_win = {
        update_on_cursor_moved = true,
        preview_method = "fast_scratch",
        disable_preview = function(filename)
          local ext = vim.fn.fnamemodify(filename, ":e"):lower()
          return vim.tbl_contains({
            "zip",
            "gz",
            "tar",
            "tgz",
            "bz2",
            "xz",
            "7z",
            "rar",
            "snappy",
            "parquet",
            "avro",
            "orc",
            "jar",
            "war",
            "class",
            "png",
            "jpg",
            "jpeg",
            "gif",
            "webp",
            "ico",
            "pdf",
          }, ext)
        end,
        win_options = {
          wrap = false,
          number = false,
          relativenumber = false,
          signcolumn = "no",
        },
      },
      confirmation = {
        border = "rounded",
      },
      progress = {
        border = "rounded",
      },
      keymaps_help = {
        border = "rounded",
      },
      use_default_keymaps = true,
      keymaps = {
        ["q"] = "actions.close",
      },
    },
    keys = {
      { "-", "<CMD>Oil<CR>", desc = "Open parent directory" },
    },
  },
}
