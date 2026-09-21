-- settings.lua

hl.config({
  general = {
    gaps_in     = 5,
    gaps_out    = 10,
    border_size = 2,
    layout      = "dwindle",
    resize_on_border = true,

    -- Border colours. `col` is a NESTED table (this is the official form from
    col = {
      active_border   = { colors = { "rgba(89b4faee)", "rgba(cba6f7ee)" }, angle = 45 },
      inactive_border = "rgba(45475aaa)",
    },
  },

  decoration = {
    rounding = 10,
    active_opacity   = 1.0,
    inactive_opacity = 0.9,
    blur   = { enabled = true, size = 3, passes = 1 },
    shadow = { enabled = true, range = 4, color = "rgba(1a1a1aee)" },
  },

  input = {
    kb_layout    = "gb",
    follow_mouse = 1,
    sensitivity  = 0,      -- -1.0 to 1.0
    touchpad = { natural_scroll = true },
  },

  dwindle = {
    preserve_split = true,
  },

  misc = {
    disable_hyprland_logo = true,
  },
})
