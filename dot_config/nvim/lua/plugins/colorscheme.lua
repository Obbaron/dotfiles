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
