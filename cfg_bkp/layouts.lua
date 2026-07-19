local M = {}

local function appWindow(name)
  local app = hs.application.get(name)
  return app and app:mainWindow() or nil
end

local function place(name, screen, unit)
  local win = appWindow(name)
  if not win or not screen then return end
  win:moveToScreen(screen, false, true)
  win:move(unit, screen, true)
end

function M.apply(target)
  local screens = hs.screen.allScreens()
  table.sort(screens, function(a, b) return a:frame().x < b:frame().x end)

  if target == "single" or #screens == 1 then
    local screen = hs.screen.mainScreen()
    place("Zed", screen, { x = 0, y = 0, w = 0.55, h = 1 })
    place("Ghostty", screen, { x = 0.55, y = 0, w = 0.45, h = 1 })
    hs.alert.show("Single monitor layout")
    return
  end

  local left = screens[1]
  local right = screens[#screens]
  place("Zed", left, { x = 0, y = 0, w = 1, h = 1 })
  place("Ghostty", right, { x = 0, y = 0, w = 0.5, h = 1 })
  place("Google Chrome", right, { x = 0.5, y = 0, w = 0.5, h = 1 })
  hs.alert.show("Dual monitor layout")
end

return M
