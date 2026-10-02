-- -- OPTIONS -- --

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
