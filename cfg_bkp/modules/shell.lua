local M = {}

local function run(command)
  if not command or command == "" then return end
  local task = hs.task.new("/bin/zsh", function(exitCode, _, stderr)
    if exitCode ~= 0 then
      hs.alert.show("Command failed")
      print(stderr)
    end
  end, { "-lic", command })

  if task then task:start() end
end

function M.bind(settings)
  hs.hotkey.bind(settings.hyper, "W", function() run(settings.commands.workspace) end)
  hs.hotkey.bind(settings.hyper, "L", function() run(settings.commands.lazydocker) end)
end

return M
