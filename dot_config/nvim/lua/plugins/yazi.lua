-- File explorer
require("yazi").setup({
    open_for_directories = true,  -- replaces netrw
})
vim.keymap.set("n", "-", "<cmd>Yazi<CR>", { desc = "Open yazi (current file)" })
vim.keymap.set("n", "<leader>y", "<cmd>Yazi cwd<CR>", { desc = "Open yazi (cwd)" })

-- Alternative: oil.nvim (also uncomment it in plugins/init.lua)
--  require("oil").setup({
--     default_file_explorer = true,
--     view_options = { show_hidden = true },
-- })
-- vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
-- vim.keymap.set("n", "<leader>y", function() require("oil").toggle_float() end, { desc = "File explorer (float)" })
