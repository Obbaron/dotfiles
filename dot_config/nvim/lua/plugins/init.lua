-- Plugins (built-in manager)
-- vim.pack.add must run before any plugin's setup() call
vim.pack.add({
    { src = "https://github.com/nvim-tree/nvim-web-devicons" },
    { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
    { src = "https://github.com/nvim-lualine/lualine.nvim" },
    { src = "https://github.com/ibhagwan/fzf-lua" },
    { src = "https://github.com/nvim-lua/plenary.nvim" },  -- yazi dep
    { src = "https://github.com/mikavilpas/yazi.nvim" },
    --{ src = "https://github.com/stevearc/oil.nvim" },
    { src = "https://github.com/goolord/alpha-nvim" },
    { src = "https://github.com/folke/which-key.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/christoomey/vim-tmux-navigator" },
})

require("plugins.colorscheme")
require("plugins.lualine")
require("plugins.fzf")
require("plugins.yazi")
require("plugins.which-key")
require("plugins.alpha")
require("plugins.lsp")
