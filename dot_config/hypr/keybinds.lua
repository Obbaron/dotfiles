-- keybinds.lua
local v   = require("vars")
local mod = v.mod
local ipc = "noctalia msg "

-- launchers
hl.bind(mod .. "+RETURN",       hl.dsp.exec_cmd(v.term),                                    { description = "Launch terminal" })
hl.bind(mod .. "+SHIFT+RETURN", hl.dsp.exec_cmd(v.browser),                                 { description = "Launch browser" })
hl.bind(mod .. "+E",            hl.dsp.exec_cmd(v.filemanager),                             { description = "Launch file manager" })
-- noctalia panels
hl.bind(mod .. "+SPACE",  hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"),             { description = "Toggle Noctalia launcher" })
hl.bind(mod .. "+period", hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"),       { description = "Toggle Noctalia control center" })
hl.bind(mod .. "+comma",  hl.dsp.exec_cmd(ipc .. "settings-toggle"),                   { description = "Toggle Noctalia settings" })

-- window control
hl.bind(mod .. "+Q",       hl.dsp.window.close(),                            { description = "Close active window" })
hl.bind(mod .. "+SHIFT+Q", hl.dsp.window.kill(),                             { description = "Force-kill active window" })
hl.bind(mod .. "+V",       hl.dsp.window.float({ action = "toggle" }),       { description = "Toggle floating" })
hl.bind(mod .. "+F",       hl.dsp.window.fullscreen({ action = "toggle" }),  { description = "Toggle fullscreen" })
hl.bind(mod .. "+P",       hl.dsp.window.pseudo(),                           { description = "Toggle pseudotile" })
hl.bind(mod .. "+C",       hl.dsp.window.center(),                           { description = "Center floating window" })
hl.bind(mod .. "+SHIFT+escape", hl.dsp.exit(),                               { description = "Exit Hyprland (log out)" })

-- move focus
hl.bind(mod .. "+left",  hl.dsp.focus({ direction = "left" }),  { description = "Focus left" })
hl.bind(mod .. "+right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mod .. "+up",    hl.dsp.focus({ direction = "up" }),    { description = "Focus up" })
hl.bind(mod .. "+down",  hl.dsp.focus({ direction = "down" }),  { description = "Focus down" })
hl.bind(mod .. "+H", hl.dsp.focus({ direction = "left" }),  { description = "Focus left (vim)" })
hl.bind(mod .. "+L", hl.dsp.focus({ direction = "right" }), { description = "Focus right (vim)" })
hl.bind(mod .. "+K", hl.dsp.focus({ direction = "up" }),    { description = "Focus up (vim)" })
hl.bind(mod .. "+J", hl.dsp.focus({ direction = "down" }),  { description = "Focus down (vim)" })

-- move window
hl.bind(mod .. "+SHIFT+left",  hl.dsp.window.move({ direction = "left" }),  { description = "Move window left" })
hl.bind(mod .. "+SHIFT+right", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(mod .. "+SHIFT+up",    hl.dsp.window.move({ direction = "up" }),    { description = "Move window up" })
hl.bind(mod .. "+SHIFT+down",  hl.dsp.window.move({ direction = "down" }),  { description = "Move window down" })
hl.bind(mod .. "+SHIFT+H", hl.dsp.window.move({ direction = "left" }),  { description = "Move window left (vim)" })
hl.bind(mod .. "+SHIFT+L", hl.dsp.window.move({ direction = "right" }), { description = "Move window right (vim)" })
hl.bind(mod .. "+SHIFT+K", hl.dsp.window.move({ direction = "up" }),    { description = "Move window up (vim)" })
hl.bind(mod .. "+SHIFT+J", hl.dsp.window.move({ direction = "down" }),  { description = "Move window down (vim)" })

-- workspaces
local WORKSPACES = 9
for i = 1, WORKSPACES do
  local ws = tostring(i)
  hl.bind(mod .. "+" .. ws,       hl.dsp.focus({ workspace = ws }),       { description = "Focus workspace " .. ws })
  hl.bind(mod .. "+SHIFT+" .. ws, hl.dsp.window.move({ workspace = ws }), { description = "Move window to workspace " .. ws })
end

-- scratchpad
hl.bind(mod .. "+0",       hl.dsp.workspace.toggle_special("magic"),            { description = "Toggle scratchpad" })
hl.bind(mod .. "+SHIFT+0", hl.dsp.window.move({ workspace = "special:magic" }), { description = "Move window to scratchpad" })

-- resize submap
-- press it, then arrows resize, Escape/Enter leaves.
hl.define_submap("resize", function()
  hl.bind("left",   hl.dsp.window.resize({ x = -40, y = 0 }),  { description = "Shrink width" })
  hl.bind("right",  hl.dsp.window.resize({ x = 40,  y = 0 }),  { description = "Grow width" })
  hl.bind("up",     hl.dsp.window.resize({ x = 0,   y = -40 }),{ description = "Shrink height" })
  hl.bind("down",   hl.dsp.window.resize({ x = 0,   y = 40 }), { description = "Grow height" })
  hl.bind("Escape", hl.dsp.submap("default"), { description = "Leave resize mode" })
  hl.bind("RETURN", hl.dsp.submap("default"), { description = "Leave resize mode" })
end)
hl.bind(mod .. "+SHIFT+R", hl.dsp.submap("resize"), { description = "Enter resize mode" })

-- media & volume keys
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. "volume-up"),       { locked = true, repeating = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. "volume-down"),     { locked = true, repeating = true, description = "Volume down" })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. "volume-mute"),     { locked = true, description = "Mute audio" })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. "brightness-up"),   { locked = true, repeating = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down"), { locked = true, repeating = true, description = "Brightness down" })

-- screenshot
hl.bind("Print", hl.dsp.exec_cmd(ipc .. "screenshot-fullscreen"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(ipc .. "screenshot-region"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(ipc .. "screenshot-annotate"))

-- mouse binds
hl.bind(mod .. "+mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window with mouse" })
