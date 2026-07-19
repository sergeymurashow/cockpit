local M = {}

M.units = {
  left       = { x = 0, y = 0, w = 0.5, h = 1 },
  right      = { x = 0.5, y = 0, w = 0.5, h = 1 },
  full       = { x = 0, y = 0, w = 1, h = 1 },
  center     = { x = 0.1, y = 0.05, w = 0.8, h = 0.9 },
  leftThird  = { x = 0, y = 0, w = 1/3, h = 1 },
  midThird   = { x = 1/3, y = 0, w = 1/3, h = 1 },
  rightThird = { x = 2/3, y = 0, w = 1/3, h = 1 },
}

local function moveFocused(unit)
  local win = hs.window.focusedWindow()
  if not win then
    hs.alert.show("No focused window")
    return
  end
  win:move(unit, nil, true)
end

function M.bind(settings)
  local h = settings.hyper
  hs.hotkey.bind(h, "Left",  function() moveFocused(M.units.left) end)
  hs.hotkey.bind(h, "Right", function() moveFocused(M.units.right) end)
  hs.hotkey.bind(h, "Up",    function() moveFocused(M.units.full) end)
  hs.hotkey.bind(h, "Down",  function() moveFocused(M.units.center) end)
  hs.hotkey.bind(h, "1", function() moveFocused(M.units.leftThird) end)
  hs.hotkey.bind(h, "2", function() moveFocused(M.units.midThird) end)
  hs.hotkey.bind(h, "3", function() moveFocused(M.units.rightThird) end)

  hs.hotkey.bind(h, "N", function()
    local win = hs.window.focusedWindow()
    if win then win:moveOneScreenWest() end
  end)

  hs.hotkey.bind(h, "P", function()
    local win = hs.window.focusedWindow()
    if win then win:moveOneScreenEast() end
  end)
end

return M
