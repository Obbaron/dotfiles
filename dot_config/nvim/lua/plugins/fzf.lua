-- Fuzzy finder
require("fzf-lua").setup({})
vim.keymap.set("n", "<leader>ff", function() require("fzf-lua").files() end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function() require("fzf-lua").live_grep() end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", function() require("fzf-lua").buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", function() require("fzf-lua").helptags() end, { desc = "Help tags" })
