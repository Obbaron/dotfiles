-- Niri close button.
-- Shows the focused window's title and closes that window on click.
-- Hides itself when no window is focused, so it never points at nothing.

function update()
  -- Poll the focused window twice a second. Raise this if you want it gentler;
  -- see the README note about switching to niri's event-stream for zero polling.
  noctalia.setUpdateInterval(500)

  noctalia.runAsync("niri msg --json focused-window", function(out)
    local title
    if out then
      -- Pull "title":"..." out of the JSON. The trailing [,}] anchor lets this
      -- survive titles that themselves contain quotes.
      title = out:match('"title"%s*:%s*"(.-)"%s*[,}]')
    end

    if title and #title > 0 then
      -- Unescape the JSON string escapes we're likely to hit.
      title = title:gsub('\\"', '"'):gsub('\\\\', '\\')

      local max = tonumber(barWidget.getConfig("max_length")) or 40
      local shown = title
      if #shown > max then
        shown = shown:sub(1, max - 1) .. "…"
      end

      barWidget.setGlyph(barWidget.getConfig("glyph"))
      barWidget.setText(shown)
      barWidget.setTooltip("Close: " .. title)
      barWidget.setVisible(true)
    else
      -- No focused window (output was null/empty) -> hide the button.
      barWidget.setVisible(false)
    end
  end)
end

function onClick()
  noctalia.runAsync("niri msg action close-window")
end
