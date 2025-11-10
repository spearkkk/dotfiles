vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode" })

keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- increment/decrement numbers
-- keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
-- keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>tt", "<C-w>v", { desc = "Open vertically" }) -- split window vertically
keymap.set("n", "<leader>tT", "<C-w>s", { desc = "Open horizontally" }) -- split window horizontally
keymap.set("n", "<leader>tr", "<C-w>=", { desc = "Make equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>tw", "<cmd>close<CR>", { desc = "Close current winndow" }) -- close current split window

-- keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
-- keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
-- keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
-- keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
-- keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- indentation
keymap.set('v', '<', '<gv')
keymap.set('v', '>', '>gv')

-- ignore delete character and line 
keymap.set({"n", "x"}, "x", '"_x')
keymap.set("n", "d", '"_d')
keymap.set("n", "dd", '"_dd')

