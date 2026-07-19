local M = {}

local state = {
	installedEntries = nil,
	installedConfig = nil,
	installedRoute = nil,
	watchers = {},
	rebuildTimer = nil,
}

local function styledText(text, color)
	return hs.styledtext.new(text, { color = color })
end

local function normalizeRoots(roots)
	local result = {}

	for _, root in ipairs(roots or {}) do
		if type(root) == "string" and root ~= "" then
			result[#result + 1] = root
		end
	end

	return result
end

local function displayNameForApp(path, info)
	if info then
		return info.CFBundleDisplayName
			or info.CFBundleName
			or info.CFBundleExecutable
			or info.CFBundleIdentifier
	end

	local name = hs.fs.displayName(path)
	if type(name) == "string" and name ~= "" then
		return name
	end

	local baseName = path:match("([^/]+)%.app$")
	return baseName or path
end

local function iconForApp(path, bundleID)
	if type(bundleID) == "string" and bundleID ~= "" then
		local image = hs.image.imageFromAppBundle(bundleID)
		if image then
			return image
		end
	end

	local image = hs.image.imageFromPath(path)
	if image then
		return image
	end

	return hs.image.iconForFileType("app")
end

local function appEntryFromPath(path, route, config)
	local info = hs.application.infoForBundlePath(path)
	if not info then
		return nil
	end

	local bundleID = info.CFBundleIdentifier
	local name = displayNameForApp(path, info)
	if type(name) ~= "string" or name == "" then
		return nil
	end

	local color = route.color or config.colors and config.colors.default or { red = 0.08, green = 0.1, blue = 0.12, alpha = 1 }
	local subtitle = route.subtitle or "Installed"

	return {
		text = styledText(name, color),
		subText = styledText(subtitle, color),
		image = iconForApp(path, bundleID),
		label = name,
		sortKey = name:lower(),
		bundleID = bundleID,
		path = path,
		routeId = route.id,
		source = "apps",
		scope = route.scope,
	}
end

local function scanDirectory(root, depth, maxDepth, route, config, seen, entries)
	local ok = pcall(function()
		for name in hs.fs.dir(root) do
			if name ~= "." and name ~= ".." then
				local path = root .. "/" .. name
				local mode = hs.fs.attributes(path, "mode")

				if mode == "directory" then
					if name:sub(-4) == ".app" then
						local entry = appEntryFromPath(path, route, config)
						if entry then
							local key = entry.bundleID or entry.path
							if not seen[key] then
								seen[key] = true
								entries[#entries + 1] = entry
							end
						end
					elseif depth < maxDepth then
						scanDirectory(path, depth + 1, maxDepth, route, config, seen, entries)
					end
				end
			end
		end
	end)

	if not ok then
		return
	end
end

local function rebuildInstalledEntries(config, route)
	local entries = {}
	local seen = {}
	local source = config.sources and config.sources.apps or {}
	local roots = normalizeRoots(source.roots)
	local maxDepth = tonumber(source.maxDepth) or 3

	for _, root in ipairs(roots) do
		scanDirectory(root, 1, maxDepth, route, config, seen, entries)
	end

	table.sort(entries, function(a, b)
		return a.sortKey < b.sortKey
	end)

	state.installedEntries = entries
end

local function stopWatchers()
	if state.rebuildTimer then
		state.rebuildTimer:stop()
		state.rebuildTimer = nil
	end

	for _, watcher in ipairs(state.watchers) do
		watcher:stop()
	end
	state.watchers = {}
end

local function scheduleRebuild()
	if state.rebuildTimer then
		state.rebuildTimer:stop()
	end

	state.rebuildTimer = hs.timer.doAfter(0.3, function()
		state.rebuildTimer = nil
		if state.installedConfig and state.installedRoute then
			rebuildInstalledEntries(state.installedConfig, state.installedRoute)
		end
	end)
end

local function startWatchers(config, route)
	stopWatchers()

	local source = config.sources and config.sources.apps or {}
	local roots = normalizeRoots(source.roots)

	state.watchers = {}
	for _, root in ipairs(roots) do
		local watcher = hs.pathwatcher.new(root, function()
			scheduleRebuild()
		end)
		watcher:start()
		state.watchers[#state.watchers + 1] = watcher
	end

	state.installedConfig = config
	state.installedRoute = route
end

local function runningEntries(route, config)
	local entries = {}
	local seen = {}
	local color = route.color or config.colors and config.colors.default or { red = 0.08, green = 0.1, blue = 0.12, alpha = 1 }
	local subtitle = route.subtitle or "Running"

	for _, app in ipairs(hs.application.runningApplications() or {}) do
		local name = nil
		pcall(function() name = app:name() end)
		if type(name) == "string" and name ~= "" then
			local bundleID = nil
			pcall(function() bundleID = app:bundleID() end)
			local key = bundleID or name:lower()
			if not seen[key] then
				seen[key] = true
				entries[#entries + 1] = {
					text = styledText(name, color),
					subText = styledText(subtitle, color),
					image = bundleID and hs.image.imageFromAppBundle(bundleID) or hs.image.iconForFileType("app"),
					label = name,
					sortKey = name:lower(),
					bundleID = bundleID,
					path = (function()
						local path = nil
						pcall(function() path = app:path() end)
						return path
					end)(),
					routeId = route.id,
					source = "apps",
					scope = route.scope,
				}
			end
		end
	end

	table.sort(entries, function(a, b)
		return a.sortKey < b.sortKey
	end)

	return entries
end

function M.prepare(config, route)
	startWatchers(config, route)
	rebuildInstalledEntries(config, route)
end

function M.entriesForRoute(config, route)
	if route.scope == "running" then
		return runningEntries(route, config)
	end

	return state.installedEntries or {}
end

function M.stop()
	stopWatchers()
	state.installedEntries = nil
	state.installedConfig = nil
	state.installedRoute = nil
end

function M.launch(entry)
	if not entry then
		return false
	end

	if type(entry.bundleID) == "string" and entry.bundleID ~= "" then
		return hs.application.launchOrFocusByBundleID(entry.bundleID)
	end

	if type(entry.path) == "string" and entry.path ~= "" then
		return hs.application.launchOrFocus(entry.path)
	end

	if type(entry.label) == "string" and entry.label ~= "" then
		return hs.application.launchOrFocus(entry.label)
	end

	return false
end

return M
