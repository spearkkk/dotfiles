vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode" })

vim.api.nvim_create_autocmd("FileType", {
  pattern = "TelescopePrompt",
  callback = function(event)
    vim.keymap.set("i", "jk", "jk", {
      buffer = event.buf,
      nowait = true,
      desc = "Type jk in Telescope prompt",
    })
  end,
})

-- keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" }) -- disabled: rebuild leader mappings later

-- increment/decrement numbers
-- keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
-- keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
-- keymap.set("n", "<leader>tt", "<C-w>v", { desc = "Open vertically" }) -- disabled: rebuild leader mappings later
-- keymap.set("n", "<leader>tT", "<C-w>s", { desc = "Open horizontally" }) -- disabled: rebuild leader mappings later
-- keymap.set("n", "<leader>tr", "<C-w>=", { desc = "Make equal size" }) -- disabled: rebuild leader mappings later
-- keymap.set("n", "<leader>tw", "<cmd>close<CR>", { desc = "Close current winndow" }) -- disabled: rebuild leader mappings later

-- keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
-- keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
-- keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
-- keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
-- keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- indentation
keymap.set('v', '<', '<gv')
keymap.set('v', '>', '>gv')

-- ignore delete character and line
-- keymap.set({"n", "x"}, "x", '"_x') -- disabled: use Vim default delete behavior
-- keymap.set("n", "d", '"_d') -- disabled: use Vim default delete behavior
-- keymap.set("n", "dd", '"_dd') -- disabled: use Vim default delete behavior
