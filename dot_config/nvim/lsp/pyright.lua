-- Pyright overrides. Merged on top of nvim-lspconfig's default pyright config
-- (cmd, filetypes, root_markers) when vim.lsp.enable("pyright") runs.
return {
    -- Only start inside a project (needs Neovim 0.11.1+). Without this, pyright
    -- would also start in single-file mode for any stray .py file.
    workspace_required = true,

    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", "pyrightconfig.json" },

    settings = {
        python = {
            analysis = {
                typeCheckingMode = "basic",   -- "off" | "basic" | "strict"
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
            },
        },
    },
}
