-- PowerShell shell integration
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
