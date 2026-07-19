local M = {}

local function findRunningApp(names)
  for _, name in ipairs(names) do
    local app = hs.application.get(name)
    if app then return app end
  end
  return nil
end

local function launchOrFocus(names)
  local app = findRunningApp(names)
  if app then
    app:activate(true)
    return true
  end

  for _, name in ipairs(names) do
    if hs.application.launchOrFocus(name) then return true end
  end

  hs.alert.show("Application not found: " .. table.concat(names, " / "))
  return false
end

function M.bind(settings)
  for _, spec in pairs(settings.apps) do
    hs.hotkey.bind(settings.hyper, spec.key, function()
      launchOrFocus(spec.names)
    end)
  end
end

function M.get(settings, id)
  local spec = settings.apps[id]
  if not spec then return nil end
  return findRunningApp(spec.names)
end

return M
