-- autostart.lua

hl.on("hyprland.start", function()
  -- daemon returns once shell is initialized
  -- polkit agent starts asynchronously just after UI
  hl.exec_cmd("noctalia --daemon")
  ht.exec_cmd("/usr/lib/kdeconnectd")
  hl.exec_cmd("vicinae server")
end)
