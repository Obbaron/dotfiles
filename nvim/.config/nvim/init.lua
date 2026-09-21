-- Leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Scrolling / cursor
vim.opt.scrolloff = 999
vim.opt.sidescrolloff = 8

-- Indentation
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true

-- Search
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.incsearch = true

-- Mouse / clipboard
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus" -- use system clipboard

-- Splits
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Files: persistent undo, no swap/backup clutter
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.confirm = true

-- Timing
vim.opt.updatetime = 250
vim.opt.timeoutlen = 500

-- UI
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.cursorline = true
vim.opt.laststatus = 3           -- single global statusline across splits
vim.opt.colorcolumn = "80"       -- visual ruler
vim.opt.pumheight = 10           -- cap completion popup height
vim.opt.completeopt = "menuone,noselect"
vim.opt.inccommand = "split"     -- live preview of :substitute & friends
vim.opt.virtualedit = "block"    -- free cursor movement in visual-block mode

vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevelstart = 99

-- Whitespace display
vim.opt.list = true
vim.opt.listchars = {
    tab = "» ",
    trail = "·",
    nbsp = "␣",
}

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

-- Plugins (built-in manager)
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

-- Colorscheme
local ok, catppuccin = pcall(require, "catppuccin")
if ok then
    catppuccin.setup({
        flavour = "mocha",
        -- Black background instead of mocha's default (#1e1e2e):
        -- color_overrides = { mocha = { base = "#000000", mantle = "#000000", crust = "#000000" } },
    })
    vim.cmd.colorscheme("catppuccin")
end

-- Statusline
require("lualine").setup({
    options = {
        theme = "auto",
        globalstatus = true,
    },
})

-- Fuzzy finder
require("fzf-lua").setup({})
vim.keymap.set("n", "<leader>ff", function() require("fzf-lua").files() end, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", function() require("fzf-lua").live_grep() end, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", function() require("fzf-lua").buffers() end, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fh", function() require("fzf-lua").helptags() end, { desc = "Help tags" })

-- File explorer
require("yazi").setup({
    open_for_directories = true,  -- replaces netrw
})
vim.keymap.set("n", "-", "<cmd>Yazi<CR>", { desc = "Open yazi (current file)" })
vim.keymap.set("n", "<leader>y", "<cmd>Yazi cwd<CR>", { desc = "Open yazi (cwd)" })

--  require("oil").setup({
--     default_file_explorer = true,
--     view_options = { show_hidden = true },
-- })
-- vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
-- vim.keymap.set("n", "<leader>y", function() require("oil").toggle_float() end, { desc = "File explorer (float)" })

-- -- WHICH-KEY -- --
local wk = require("which-key")
wk.setup({
    preset = "modern",  -- "classic" | "modern" | "helix"
})

-- Leader group labels (keys themselves carry their own `desc`)
wk.add({
    { "<leader>f", group = "find" },
    { "<leader>r", group = "rename" },  -- buffer-local (LSP): <leader>rn
    { "<leader>c", group = "code" },    -- buffer-local (LSP): <leader>ca
})

-- -- DASHBOARD -- --
local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

dashboard.section.header.val = {
    [[ _   _ _____ _____     _____ __  __ ]],
    [[| \ | | ____/ _ \ \   / /_ _|  \/  |]],
    [[|  \| |  _|| | | \ \ / / | || |\/| |]],
    [[| |\  | |__| |_| |\ V /  | || |  | |]],
    [[|_| \_|_____\___/  \_/  |___|_|  |_|]],
}

dashboard.section.buttons.val = {
    dashboard.button("f", "  Find file",     "<cmd>lua require('fzf-lua').files()<cr>"),
    dashboard.button("r", "  Recent files",  "<cmd>lua require('fzf-lua').oldfiles()<cr>"),
    dashboard.button("g", "  Find text",     "<cmd>lua require('fzf-lua').live_grep()<cr>"),
    dashboard.button("e", "  File explorer", "<cmd>Yazi<cr>"),
    dashboard.button("n", "  New file",      "<cmd>ene | startinsert<cr>"),
    dashboard.button("c", "  Config",        "<cmd>edit $MYVIMRC<cr>"),
    dashboard.button("q", "  Quit",          "<cmd>qa<cr>"),
}

alpha.setup(dashboard.config)

-- -- LSP -- --
vim.lsp.config("pyright", {
    settings = {
        python = {
            analysis = {
                typeCheckingMode = "basic",   -- "off" | "basic" | "strict"
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
            },
        },
    },
})


-- Enable only LSPs whose binaries are installed
local lsp_servers = {
    pyright = "pyright-langserver",
    ruff    = "ruff",
}
local available = {}
for server, bin in pairs(lsp_servers) do
    if vim.fn.executable(bin) == 1 then  -- fn.executable == 'command -v'
        table.insert(available, server)
    end
end
if #available > 0 then
    vim.lsp.enable(available)
end

-- Inline diagnostics
vim.diagnostic.config({
    virtual_text = true,
    severity_sort = true,
})

-- Buffer-local LSP keymaps + completion
vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP keymaps & completion",
    callback = function(args)
        local buf = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        local map = function(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = buf, desc = desc })
        end
        map("gd", vim.lsp.buf.definition, "Go to definition")
        map("gD", vim.lsp.buf.declaration, "Go to declaration")
        map("<leader>rn", vim.lsp.buf.rename, "Rename")
        map("<leader>ca", vim.lsp.buf.code_action, "Code action")

        if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
        end

        -- Autocompletion
        if client and client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, buf, { autotrigger = true })
        end
    end,
})

-- -- AUTOCOMMANDS -- --

-- Briefly highlight text on yank
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight on yank",
    callback = function()
        vim.hl.on_yank()
    end,
})

-- Restore last cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
    desc = "Restore cursor position",
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end,
})

-- Strip trailing whitespace on save
vim.api.nvim_create_autocmd("BufWritePre", {
    desc = "Trim trailing whitespace",
    callback = function()
        local save = vim.fn.winsaveview()
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.winrestview(save)
    end,
})

-- Format on save via ruff
vim.api.nvim_create_autocmd("BufWritePre", {
    desc = "Format on save (ruff)",
    callback = function(args)
        vim.lsp.buf.format({
            bufnr = args.buf,
            async = false,
            filter = function(client)
                return client.name == "ruff"
            end,
        })
    end,
})

-- Windows / PowerShell shell integration
if vim.fn.has("win32") == 1 then
    local powershell_opts = {
        shell = vim.fn.executable("pwsh") == 1 and "pwsh" or "powershell",
        shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;",
        shellredir = "2>&1 | %%{ \"$_\" } | Out-File %s; exit $LastExitCode",
        shellpipe = "2>&1 | %%{ \"$_\" } | Tee-Object %s; exit $LastExitCode",
        shellquote = "",
        shellxquote = "",
    }
    for option, value in pairs(powershell_opts) do
        vim.opt[option] = value
    end
end
