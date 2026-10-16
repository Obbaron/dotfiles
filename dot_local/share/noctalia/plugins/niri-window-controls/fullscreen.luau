-- Niri fullscreen button. Toggles fullscreen on the focused window.

function update()
  noctalia.setUpdateInterval(60000)  -- static glyph; refresh rarely
  barWidget.setGlyph(barWidget.getConfig("glyph"))
  barWidget.setTooltip("Toggle fullscreen")
end

function onClick()
  noctalia.runAsync("niri msg action fullscreen-window")
end
