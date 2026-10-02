-- -- LSP -- --
-- Server settings live in lsp/<name>.lua (e.g. lsp/pyright.lua)

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
