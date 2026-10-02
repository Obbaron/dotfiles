-- -- KEYMAPS -- --

-- Esc removes search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Move between split windows
vim.keymap.set("n", "<C-h>", ":wincmd h<CR>", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", ":wincmd j<CR>", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", ":wincmd k<CR>", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", ":wincmd l<CR>", { desc = "Window right" })

-- Save / Quit
vim.keymap.set("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })
vim.keymap.set("n", "<leader>h", "<cmd>split<CR>", { desc = "Horizontal split" })
vim.keymap.set("n", "<leader>v", "<cmd>vsplit<CR>", { desc = "Vertical split" })

-- Move selected lines up/down and re-indent
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Stay in visual mode while indenting
vim.keymap.set("v", "<", "<gv", { desc = "Indent left" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right" })

-- Stay in normal mode using o/O
vim.keymap.set("n", "<leader>o", "o<Esc>", { desc = "Blank line below" })
vim.keymap.set("n", "<leader>O", "O<Esc>", { desc = "Blank line above" })

-- Delete to void register (don't overwrite clipboard)
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete (void register)" })
vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste over (keep register)" })

-- Buffers
vim.keymap.set("n", "<leader>n", "<cmd>ene | startinsert<CR>", { desc = "New buffer" })
vim.keymap.set("n", "<leader>x", "<cmd>bdelete<CR>", { desc = "Close buffer" })
vim.keymap.set("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
