return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = function()
      local actions = require("telescope.actions")

      return {
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            horizontal = {
              preview_cutoff = 1,
              preview_width = 0.55,
            },
          },
          file_ignore_patterns = {
            "%.git/",
            "node_modules/",
            "target/",
            "build/",
            "dist/",
            "out/",
            "coverage/",
            "%.gradle/",
            "%.idea/",
            "%.next/",
            "%.nuxt/",
            "%.turbo/",
            "%.cache/",
            "__pycache__/",
            "%.pytest_cache/",
            "%.mypy_cache/",
            "%.ruff_cache/",
            "%.tox/",
            "%.venv/",
            "venv/",
            "%.class$",
            "%.jar$",
            "%.war$",
          },
          vimgrep_arguments = {
            "rg",
            "--color=never",
            "--no-heading",
            "--with-filename",
            "--line-number",
            "--column",
            "--smart-case",
            "--hidden",
            "--glob",
            "!**/.git/*",
            "--glob",
            "!**/node_modules/*",
            "--glob",
            "!**/target/*",
            "--glob",
            "!**/build/*",
            "--glob",
            "!**/dist/*",
            "--glob",
            "!**/out/*",
            "--glob",
            "!**/coverage/*",
            "--glob",
            "!**/.gradle/*",
            "--glob",
            "!**/.idea/*",
            "--glob",
            "!**/.next/*",
            "--glob",
            "!**/.nuxt/*",
            "--glob",
            "!**/.turbo/*",
            "--glob",
            "!**/.cache/*",
            "--glob",
            "!**/__pycache__/*",
            "--glob",
            "!**/.pytest_cache/*",
            "--glob",
            "!**/.mypy_cache/*",
            "--glob",
            "!**/.ruff_cache/*",
            "--glob",
            "!**/.tox/*",
            "--glob",
            "!**/.venv/*",
            "--glob",
            "!**/venv/*",
            "--glob",
            "!**/*.class",
            "--glob",
            "!**/*.jar",
            "--glob",
            "!**/*.war",
          },
          mappings = {
            i = {
              ["<esc>"] = actions.close,
            },
          },
        },
      }
    end,
    keys = {
      {
        "<leader>ff",
        function()
          local builtin = require("telescope.builtin")

          if vim.fn.system("git rev-parse --is-inside-work-tree"):match("true") then
            builtin.git_files({ show_untracked = true })
          else
            builtin.find_files({ hidden = true })
          end
        end,
        desc = "Find files",
      },
      {
        "<leader>fb",
        function()
          require("telescope.builtin").buffers({
            sort_mru = true,
            ignore_current_buffer = true,
          })
        end,
        desc = "Buffers",
      },
      {
        "<leader>fr",
        function()
          require("telescope.builtin").oldfiles({ cwd_only = true })
        end,
        desc = "Recent files",
      },
      {
        "<leader>fg",
        function()
          require("telescope.builtin").live_grep()
        end,
        desc = "Live grep",
      },
      {
        "<leader>fw",
        function()
          require("telescope.builtin").grep_string()
        end,
        desc = "Find word under cursor",
      },
      {
        "<leader>f/",
        function()
          require("telescope.builtin").current_buffer_fuzzy_find()
        end,
        desc = "Search in current buffer",
      },
      {
        "<leader>fl",
        function()
          require("telescope.builtin").resume()
        end,
        desc = "Resume last picker",
      },
    },
  },
}
