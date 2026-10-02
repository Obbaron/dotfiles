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

-- Strip trailing whitespace on save (must stay above format-on-save)
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
