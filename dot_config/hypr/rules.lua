-- rules.lua

hl.window_rule({ match = { class = "^(pavucontrol)$" },          float = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true })
hl.window_rule({ match = { class = "^(blueman-manager)$" },      float = true })
hl.window_rule({ match = { title = "^(Open File)$" },            float = true })
hl.window_rule({ match = { title = "^(Save As)$" },              float = true })
hl.window_rule({ match = { class = "^xarchiver$" },              float = true })

hl.window_rule({ match = { class = "dev.noctalia.Noctalia" }, float = true, size = { 1080, 920 } })

hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true, persistent = true })
