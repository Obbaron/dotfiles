-- hover_close.lua

local ZONE   = 36                                     -- hot-square size, pixels
local RED    = "rgba(ff3333ff)"                       -- border while hovering
local NORMAL = "rgba(89b4faff) rgba(cba6f7ff) 45deg"  -- KEEP IN SYNC with settings.lua
local POLL   = 60                                     -- ms between cursor checks

-- Cursor inside the top-right hot square of window w?
local function in_hot_zone(w, c)
  local right = w.at.x + w.size.x
  local top   = w.at.y
  return c.x >= (right - ZONE) and c.x <= right
     and c.y >= top            and c.y <= (top + ZONE)
end

local function set_border(addr, color)
  hl.dispatch(hl.dsp.window.set_prop({ prop = "border_color", value = color, window = addr }))
end

local painted = nil  -- address of the window currently painted red (or nil)

local function restore()
  if painted and hl.get_window(painted) then
    set_border(painted, NORMAL)
  end
  painted = nil
end

hl.bind("mouse:272", function()
  local w = hl.get_active_window()
  if w and in_hot_zone(w, hl.get_cursor_pos()) then
    restore()                                    -- clear red before it vanishes
    hl.dispatch(hl.dsp.window.close({ window = w.address }))
  end
end, { mouse = true, non_consuming = true })

-- Border feedback
hl.timer(function()
  local w   = hl.get_active_window()
  local hot = w and in_hot_zone(w, hl.get_cursor_pos())

  if hot then
    if painted ~= w.address then   -- entered a (new) window's zone
      restore()
      set_border(w.address, RED)
      painted = w.address
    end
  elseif painted then              -- left the zone
    restore()
  end
end, { timeout = POLL, type = "repeat" })
