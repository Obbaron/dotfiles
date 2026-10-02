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
