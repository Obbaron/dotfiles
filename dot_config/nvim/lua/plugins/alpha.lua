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
