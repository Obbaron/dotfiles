-- env.lua

local v = require("vars")

-- Cursor size (see vars.lua)
hl.env("XCURSOR_SIZE", v.cursor_size)
hl.env("HYPRCURSOR_SIZE", v.cursor_size)

-- Nudge Qt/GTK/Firefox toward native Wayland
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- NVIDIA card
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("GBM_BACKEND", "nvidia-drm")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
