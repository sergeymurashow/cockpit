local apps = require("modules.apps")
local windows = require("modules.windows")

local M = {}
local watcher
local timer

local function appWindow(settings, id)
  local app = apps.get(settings, id)
  if not app then return nil end
  return app:mainWindow()
end

local function place(settings, id, screen, unit)
  local win = appWindow(settings, id)
  if not win or not screen then return end
  win:moveToScreen(screen, false, true)
  win:move(unit, screen, true)
end

local function sortedScreens()
  local list = hs.screen.allScreens()
  table.sort(list, function(a, b) return a:frame().x < b:frame().x end)
  return list
end

local function applySingle(settings)
  local screen = hs.screen.mainScreen()
  place(settings, settings.layoutApps.editor, screen, windows.units.left)
  place(settings, settings.layoutApps.terminal, screen, windows.units.right)
  hs.alert.show("Single-monitor layout")
end

local function applyDual(settings)
  local screens = sortedScreens()
  local left = screens[1]
  local right = screens[#screens]

  place(settings, settings.layoutApps.editor, left, windows.units.full)
  place(settings, settings.layoutApps.terminal, right, windows.units.left)
  place(settings, settings.layoutApps.browser, right, windows.units.right)

  hs.alert.show("Dual-monitor layout")
end

function M.apply(settings)
  if #hs.screen.allScreens() <= 1 then applySingle(settings) else applyDual(settings) end
end

function M.start(settings)
  hs.hotkey.bind(settings.hyper, "A", function() M.apply(settings) end)

  watcher = hs.screen.watcher.new(function()
    if not settings.autoApplyScreenLayout then return end
    if timer then timer:stop() end
    timer = hs.timer.doAfter(settings.screenChangeDelaySeconds, function()
      M.apply(settings)
      timer = nil
    end)
  end)

  watcher:start()
end

return M
