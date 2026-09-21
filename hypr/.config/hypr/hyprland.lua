-- hyprland.lua

package.path = package.path .. ";" ..
    (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/?.lua"

require("env")
require("settings")
require("devices")
require("keybinds")
require("hover_close")
require("monitors")
require("animations")
require("rules")
require("autostart")


-- For Noctalia Color templates
require("noctalia").apply_theme()
