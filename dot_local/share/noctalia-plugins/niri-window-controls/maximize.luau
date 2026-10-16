-- Niri maximize-column button. Toggles the maximized state of the focused column.

function update()
  noctalia.setUpdateInterval(60000)  -- static glyph; refresh rarely
  barWidget.setGlyph(barWidget.getConfig("glyph"))
  barWidget.setTooltip("Maximize column")
end

function onClick()
  noctalia.runAsync("niri msg action maximize-column")
end
