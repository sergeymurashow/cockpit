local M = {}

local function log(fmt, ...)
	hs.printf("[layouts] " .. fmt, ...)
end

local normalizeString
local runOpenCommand

local function styledText(text, color)
	return hs.styledtext.new(text, { color = color })
end

local function routeColor(route, config)
	return route.color or (config.colors and config.colors.default) or {
		red = 0.08,
		green = 0.1,
		blue = 0.12,
		alpha = 1,
	}
end

local function normalizeString(value)
	if type(value) ~= "string" then
		return nil
	end

	value = value:gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then
		return nil
	end

	return value
end

local function browserSpec(config, browserName)
	local source = config.sources and config.sources.layouts or {}
	local browsers = source.browsers or {}
	if type(browserName) ~= "string" then
		return nil
	end

	return browsers[browserName:lower()] or browsers[browserName]
end

local workspaceSpaceMap = {}

local function screenForSpaceSpec(spec)
	if type(spec) == "table" and spec.name then
		return spec
	end

	if type(spec) ~= "string" then
		return hs.screen.primaryScreen()
	end

	local normalized = normalizeString(spec)
	if not normalized then
		return hs.screen.primaryScreen()
	end

	if normalized == "Main" or normalized == "Primary" then
		return hs.screen.primaryScreen()
	end

	return hs.screen.primaryScreen()
end

local function ensureWorkspaceSpaces(config)
	local source = config.sources and config.sources.layouts or {}
	local specs = source.spaces or {}
	local groups = {}

	log("ensure workspace spaces")

	for _, spec in ipairs(specs) do
		if type(spec) == "table" then
			local screenKey = normalizeString(spec.screen) or "Primary"
			groups[screenKey] = groups[screenKey] or {}
			groups[screenKey][#groups[screenKey] + 1] = spec
		end
	end

	workspaceSpaceMap = {}

	for screenKey, items in pairs(groups) do
		local screen = screenForSpaceSpec(screenKey)
		local spaces = hs.spaces.spacesForScreen(screen) or {}
		local userSpaces = {}

		for _, spaceID in ipairs(spaces) do
			local ok, spaceType = pcall(hs.spaces.spaceType, spaceID)
			if ok and spaceType == "user" then
				userSpaces[#userSpaces + 1] = spaceID
			end
		end

		spaces = userSpaces
		local missing = #items - #spaces
		log("screen=%s existing=%d needed=%d", tostring(screenKey), #spaces, #items)

		if missing > 0 then
			for index = 1, missing do
				local closeMC = index == missing
				log("adding space on screen=%s step=%d/%d", tostring(screenKey), index, missing)
				hs.spaces.addSpaceToScreen(screen, closeMC)
				spaces = hs.spaces.spacesForScreen(screen) or spaces
			end
		end

		for index, spec in ipairs(items) do
			local spaceID = spaces[index]
			if spaceID then
				workspaceSpaceMap[spec.id or spec.name or tostring(index)] = spaceID
			end
		end
	end

	return workspaceSpaceMap
end

local function resolveWorkspaceSpaceID(config, value)
	if value == nil then
		return nil
	end

	if type(value) == "number" then
		return value
	end

	if type(value) == "string" then
		local normalized = normalizeString(value)
		if not normalized then
			return nil
		end

		local asNumber = tonumber(normalized)
		if asNumber then
			return asNumber
		end

		if workspaceSpaceMap[normalized] then
			return workspaceSpaceMap[normalized]
		end

		local source = config.sources and config.sources.layouts or {}
		for _, spec in ipairs(source.spaces or {}) do
			if type(spec) == "table" then
				local id = normalizeString(spec.id or spec.name)
				if id == normalized then
					return workspaceSpaceMap[id]
				end
			end
		end
	end

	return nil
end

local chromeProfileMap = nil

local function loadChromeProfileMap()
	if chromeProfileMap then
		return chromeProfileMap
	end

	local map = {}
	local localStatePath = os.getenv("HOME") .. "/Library/Application Support/Google/Chrome/Local State"
	local handle = io.open(localStatePath, "r")
	if not handle then
		chromeProfileMap = map
		return map
	end

	local raw = handle:read("*a")
	handle:close()

	local ok, decoded = pcall(hs.json.decode, raw)
	if ok and type(decoded) == "table" then
		local infoCache = decoded.profile and decoded.profile.info_cache or {}
		for directoryName, profileData in pairs(infoCache) do
			if type(directoryName) == "string" and type(profileData) == "table" then
				local displayName = normalizeString(profileData.name)
				if displayName then
					map[displayName:lower()] = directoryName
				end

				map[directoryName:lower()] = directoryName
			end
		end
	end

	chromeProfileMap = map
	return map
end

local function chromeProfileDirectory(profileName)
	local normalized = normalizeString(profileName)
	if not normalized then
		return nil
	end

	if normalized == "Default" or normalized:match("^Profile%s+%d+$") then
		return normalized
	end

	local map = loadChromeProfileMap()
	return map[normalized:lower()] or normalized
end

local function orderedScreens()
	local screens = hs.screen.allScreens() or {}

	table.sort(screens, function(a, b)
		local af = a:fullFrame()
		local bf = b:fullFrame()

		if af.x == bf.x then
			if af.y == bf.y then
				return (a:name() or "") < (b:name() or "")
			end
			return af.y < bf.y
		end

		return af.x < bf.x
	end)

	return screens
end

local function resolveScreen(value)
	if type(value) == "userdata" and value.name then
		return value
	end

	local index = tonumber(value)
	if not index then
		return nil
	end

	return orderedScreens()[index]
end

local function windowsForMatcher(appMatcher)
	local windows = {}
	if type(appMatcher) ~= "table" then
		return windows
	end

	local appName = normalizeString(appMatcher.name)
	if appName then
		local ok, wf = pcall(hs.window.filter.new, { appName })
		if ok and wf then
			local okWindows, filtered = pcall(function()
				return wf:getWindows()
			end)
			if okWindows and type(filtered) == "table" then
				windows = filtered
			end
		end
	end

	local titleContains = normalizeString(appMatcher.titleContains)
	if titleContains then
		local lowered = titleContains:lower()
		local filtered = {}
		for _, win in ipairs(windows) do
			local title = nil
			pcall(function()
				title = win:title()
			end)
			if type(title) == "string" and title:lower():find(lowered, 1, true) then
				filtered[#filtered + 1] = win
			end
		end
		windows = filtered
	end

	if #windows > 0 then
		return windows
	end

	local allWindows = hs.window.allWindows() or {}
	for _, win in ipairs(allWindows) do
		local app = nil
		local ok = pcall(function()
			app = win:application()
		end)
		if ok and app then
			local matched = false
			if type(appMatcher.bundleID) == "string" and appMatcher.bundleID ~= "" then
				local bundleID = nil
				pcall(function()
					bundleID = app:bundleID()
				end)
				if bundleID == appMatcher.bundleID then
					matched = true
				end
			end
			if not matched and appName then
				local name = nil
				pcall(function()
					name = app:name()
				end)
				if name == appName then
					matched = true
				end
			end
			if matched and titleContains then
				local title = nil
				pcall(function()
					title = win:title()
				end)
				if not (type(title) == "string" and title:lower():find(titleContains:lower(), 1, true)) then
					matched = false
				end
			end
			if matched then
				windows[#windows + 1] = win
			end
		end
	end

	return windows
end

local function isAppRunning(appMatcher)
	if type(appMatcher) ~= "table" then
		return false
	end

	local bundleID = normalizeString(appMatcher.bundleID)
	if bundleID then
		local ok, apps = pcall(hs.application.applicationsForBundleID, bundleID)
		return ok and type(apps) == "table" and #apps > 0
	end

	local appName = normalizeString(appMatcher.name)
	if appName then
		for _, app in ipairs(hs.application.runningApplications()) do
			local name = nil
			pcall(function()
				name = app:name()
			end)
			if name == appName then
				return true
			end
		end
	end

	return false
end

local function moveWindowsToSpace(windows, spaceID, fullscreen)
	if not spaceID then
		log("space %s not found", tostring(spaceID))
		return false
	end

	local moved = false
	for _, win in ipairs(windows or {}) do
		if win then
			local winID = nil
			local beforeSpaces = nil
			pcall(function()
				winID = win:id()
				beforeSpaces = hs.spaces.windowSpaces(win)
			end)

			pcall(function()
				local ok, err = hs.spaces.moveWindowToSpace(win, spaceID, true)
				log(
					"moveWindowToSpace window=%s target=%s ok=%s err=%s before=%s",
					tostring(winID),
					tostring(spaceID),
					tostring(ok),
					tostring(err),
					hs.inspect(beforeSpaces)
				)
				if ok then
					moved = true
				end
			end)

			if fullscreen then
				pcall(function()
					win:setFullScreen(true)
					log("set fullscreen on space %s", tostring(spaceID))
					moved = true
				end)
			end

			local afterSpaces = nil
			pcall(function()
				afterSpaces = hs.spaces.windowSpaces(win)
			end)
			log("window=%s after=%s", tostring(winID), hs.inspect(afterSpaces))
		end
	end

	return moved
end

local function appWindowsForMatcher(appMatcher)
	return windowsForMatcher(appMatcher)
end

local function moveWindowsWhenAvailable(appMatcher, spaceID, fullscreen)
	if not spaceID or type(appMatcher) ~= "table" then
		log("skip move: space=%s matcher=%s", tostring(spaceID), type(appMatcher))
		return
	end

	local attempts = 0
	local maxAttempts = 12

	local function tick()
		attempts = attempts + 1
		local windows = appWindowsForMatcher(appMatcher)
		log(
			"attempt %d space=%s matcher=%s windows=%d",
			attempts,
			tostring(spaceID),
			type(appMatcher.bundleID) == "string" and appMatcher.bundleID or (appMatcher.name or "?"),
			#windows
		)
		if moveWindowsToSpace(windows, spaceID, fullscreen) then
			return
		end

		if attempts < maxAttempts then
			hs.timer.doAfter(0.5, tick)
		end
	end

	hs.timer.doAfter(0.5, tick)
end

local function launchOrFocusApp(item)
	if normalizeString(item.bundleID) then
		return hs.application.launchOrFocusByBundleID(item.bundleID)
	end

	if normalizeString(item.appPath) then
		return hs.application.launchOrFocus(item.appPath)
	end

	if normalizeString(item.path) then
		return hs.application.launchOrFocus(item.path)
	end

	if normalizeString(item.app or item.name) then
		return hs.application.launchOrFocus(item.app or item.name)
	end

	return false
end

local function launchByOpen(appPath, extraArgs)
	local args = { "-na" }
	local normalizedAppPath = normalizeString(appPath)

	if normalizedAppPath then
		args[#args + 1] = normalizedAppPath
	else
		log("missing app path")
		return false
	end

	args[#args + 1] = "--args"

	for _, arg in ipairs(extraArgs or {}) do
		if arg ~= nil and arg ~= "" then
			args[#args + 1] = arg
		end
	end

	log("open command: %s", table.concat(args, " "))
	return runOpenCommand(args)
end

runOpenCommand = function(args)
	local task = hs.task.new("/usr/bin/open", nil, args)
	if not task then
		return false
	end

	return task:start() ~= nil
end

local function launchApp(appName, appPath)
	appName = normalizeString(appName)
	appPath = normalizeString(appPath)

	if appPath then
		return hs.application.launchOrFocus(appPath)
	end

	if appName then
		log("launch app by name: %s", appName)
		return hs.application.launchOrFocus(appName)
	end

	return false
end

local function launchAppWithSpace(item, config)
	local spaceID = resolveWorkspaceSpaceID(config, item.space or item.desktop or item.screen)
	local appMatcher = {
		bundleID = item.bundleID,
		name = item.app or item.name,
		titleContains = item.titleContains,
	}
	local launched = false

	if isAppRunning(appMatcher) then
		log(
			"app already running bundleID=%s name=%s screen=%s fullscreen=%s",
			tostring(item.bundleID),
			tostring(item.app or item.name),
			tostring(spaceID),
			tostring(item.fullscreen or item.fullScreen)
		)
		launched = true
	else
		log(
			"launch app bundleID=%s path=%s name=%s space=%s fullscreen=%s",
			tostring(item.bundleID),
			tostring(item.appPath or item.path),
			tostring(item.app or item.name),
			tostring(spaceID),
			tostring(item.fullscreen or item.fullScreen)
		)
		launched = launchOrFocusApp(item)
	end

	if spaceID then
		moveWindowsWhenAvailable(appMatcher, spaceID, item.fullscreen or item.fullScreen)
	end

	return launched
end

local function launchBrowserUrl(browser, target)
	local spec = browserSpec(browser.config, browser.name)
	if not spec then
		return false
	end

	local args = { "-na" }
	local appPath = normalizeString(spec.appPath)
	local appName = normalizeString(spec.app)

	if appPath then
		args[#args + 1] = appPath
	elseif appName then
		args[#args + 1] = appName
	else
		return false
	end

	args[#args + 1] = "--args"

	local newWindowArg = normalizeString(spec.newWindowArg)
	if newWindowArg then
		args[#args + 1] = newWindowArg
	end

	local profileArg = normalizeString(spec.profileArg)
	local profile = chromeProfileDirectory(browser.profile)
	if profileArg and profile then
		args[#args + 1] = profileArg .. "=" .. profile
	end

	local url = normalizeString(target)
	if url then
		args[#args + 1] = url
	end

	return runOpenCommand(args)
end

local function launchSafariUrl(browser, target)
	local spec = browserSpec(browser.config, browser.name)
	if not spec then
		return false
	end

	local args = { "-na" }
	local appPath = normalizeString(spec.appPath)
	local appName = normalizeString(spec.app)

	if appPath then
		args[#args + 1] = appPath
	elseif appName then
		args[#args + 1] = appName
	else
		return false
	end

	local url = normalizeString(target)
	if url then
		args[#args + 1] = url
	end

	if normalizeString(browser.profile) then
		hs.alert.show("Safari profiles do not have a reliable CLI switch here")
	end

	return runOpenCommand(args)
end

local function launchBrowser(item, config)
	local browserName = normalizeString(item.browser)
	if not browserName then
		return false
	end

	local browser = {
		name = browserName,
		profile = item.profile,
		config = config,
	}
	local spec = browserSpec(config, browserName)
	local spaceID = resolveWorkspaceSpaceID(config, item.space or item.desktop or item.screen)
	local appMatcher = {
		bundleID = spec and spec.bundleID,
		name = spec and spec.app or item.browser,
		titleContains = item.titleContains,
	}

	local target = item.url or item.target or item.appPath
	if browserName == "chrome" or browserName == "chromium" or browserName == "google chrome" then
		if isAppRunning(appMatcher) and not normalizeString(target) then
			log("browser already running browser=%s profile=%s space=%s", browserName, tostring(item.profile), tostring(spaceID))
			if spaceID then
				moveWindowsWhenAvailable(appMatcher, spaceID, item.fullscreen or item.fullScreen)
			end
			return true
		end

		log("launch browser=%s profile=%s space=%s target=%s", browserName, tostring(item.profile), tostring(spaceID), tostring(target))
		local ok = launchBrowserUrl(browser, target)
		if spaceID then
			moveWindowsWhenAvailable(appMatcher, spaceID, item.fullscreen or item.fullScreen)
		end
		return ok
	end

	if browserName == "safari" then
		log("launch safari space=%s target=%s", tostring(spaceID), tostring(target))
		local ok = launchSafariUrl(browser, target)
		if spaceID then
			moveWindowsWhenAvailable(appMatcher, spaceID, item.fullscreen or item.fullScreen)
		end
		return ok
	end

	return false
end

local function launchTerminal(item, config)
	local spec = {}
	local appPath = item.appPath or spec.appPath or "/Applications/cmux.app"
	local spaceID = resolveWorkspaceSpaceID(config, item.space or item.desktop or item.screen)
	local command = normalizeString(item.command)
	local args = {}
	local appMatcher = {
		bundleID = item.bundleID or spec.bundleID,
		name = item.app or spec.app or "cmux",
		titleContains = item.titleContains,
	}

	if command then
		args[#args + 1] = "-e"
		args[#args + 1] = command
	end

	if isAppRunning(appMatcher) then
		log("terminal already running appPath=%s space=%s fullscreen=%s command=%s", tostring(appPath), tostring(spaceID), tostring(item.fullscreen or item.fullScreen), tostring(command))
		if spaceID then
			moveWindowsWhenAvailable(appMatcher, spaceID, item.fullscreen or item.fullScreen)
		end
		return true
	end

	log("launch terminal appPath=%s space=%s fullscreen=%s command=%s", tostring(appPath), tostring(spaceID), tostring(item.fullscreen or item.fullScreen), tostring(command))
	local launched = launchByOpen(appPath, args)

	if spaceID then
		moveWindowsWhenAvailable(appMatcher, spaceID, item.fullscreen or item.fullScreen)
	end

	return launched
end

local function launchItem(item, config)
	if type(item) ~= "table" then
		return false
	end

	local kind = normalizeString(item.kind or item.type)
	log("launch item kind=%s label=%s", tostring(kind), tostring(item.label or item.app or item.browser or item.name or item.id))
	if kind == "app" then
		return launchAppWithSpace(item, config)
	end

	if kind == "browser" then
		return launchBrowser(item, config)
	end

	if kind == "terminal" or kind == "command" then
		return launchTerminal(item, config)
	end

	if kind == "url" then
		return hs.urlevent.openURL(item.url or item.target or item.value or "")
	end

	return false
end

function M.entriesForRoute(config, route)
	local entries = {}
	local source = config.sources and config.sources.layouts or {}
	local color = routeColor(route or {}, config)

	for _, entry in ipairs(source.entries or {}) do
		if type(entry) == "table" then
			local label = normalizeString(entry.label or entry.id)
			if label then
				entries[#entries + 1] = {
					text = styledText(label, color),
					subText = styledText(entry.description or "Layout", color),
					label = label,
					sortKey = label:lower(),
					id = entry.id or label,
					layout = entry,
					source = "layouts",
					kind = "layout",
				}
			end
		end
	end

	return entries
end

function M.prepare(config)
	return config
end

function M.launch(choice, config)
	local entry = choice and choice.layout or choice
	if type(entry) ~= "table" then
		log("no layout entry")
		return false
	end

	log("launch layout id=%s label=%s", tostring(entry.id), tostring(entry.label))
	ensureWorkspaceSpaces(config or {})
	local ok = true
	local items = entry.items or {}
	for _, item in ipairs(items) do
		ok = launchItem(item, config) and ok
	end

	return ok
end

return M
