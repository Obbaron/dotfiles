-- Ruff overrides. Merged on top of nvim-lspconfig's default ruff config.
return {
    -- Only start inside a project (needs Neovim 0.11.1+).
    workspace_required = true,

    root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile" },
}
