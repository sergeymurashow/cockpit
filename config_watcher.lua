local M = {}

function M.start()
	local configDir = os.getenv("HOME") .. "/.hammerspoon"

	local function reloadConfig(files)
		local shouldReload = false

		for _, file in ipairs(files) do
			if file:match("%.lua$") then
				shouldReload = true
				break
			end
		end

		if shouldReload then
			hs.alert.show("Reloading Hammerspoon config")
			hs.timer.doAfter(0.2, function()
				hs.reload()
			end)
		end
	end

	configWatcher = hs.pathwatcher.new(configDir, reloadConfig)
	configWatcher:start()
end

return M
