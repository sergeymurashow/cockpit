local appsSource = require("modules.launcher_sources.apps")
local layoutsSource = require("modules.launcher_sources.layouts")

local M = {}

local function log(fmt, ...)
	hs.printf("[launcher] " .. fmt, ...)
end

local state = {
	config = nil,
	chooser = nil,
	tabToolbar = nil,
	hotkey = nil,
	appWatcher = nil,
	route = nil,
	query = "",
	ignoreQueryCallback = false,
	routes = {},
	routesByPrefix = {},
	defaultRoute = nil,
}

local function normalizePrefix(prefix)
	if type(prefix) ~= "string" then
		return ""
	end
	return prefix
end

local function trimLeadingSpaces(text)
	return (text:gsub("^%s+", ""))
end

local function currentRoute()
	return state.route or state.defaultRoute
end

local function chooserPlaceholder()
	local route = currentRoute()
	if route and route.label then
		return route.label
	end
	local config = state.config or {}
	return config.placeholder or "Search"
end

local function queryForRoute(rawQuery, route)
	rawQuery = rawQuery or ""
	local prefix = route and normalizePrefix(route.prefix) or ""
	if prefix ~= "" and rawQuery:sub(1, 1) == prefix then
		return rawQuery:sub(2)
	end
	return rawQuery
end

local function setDisplayedQuery(rawQuery)
	if not state.chooser then
		return
	end

	-- hs.chooser accepts styled text for its query field. Keep the active
	-- route marker visible and accent it so it can be deleted/replaced.
	local query = rawQuery or ""
	local prefix = query:sub(1, 1)
	if state.routesByPrefix[prefix] and prefix ~= "" then
		local accent = (state.config and state.config.colors and state.config.colors.helpAccent)
			or { red = 0.22, green = 0.47, blue = 0.78, alpha = 1 }
		local ok = pcall(function()
			state.chooser:query(hs.styledtext.new(query, { color = accent }))
		end)
		if ok then
			return
		end
	end
	state.chooser:query(query)
end

local function tabRouteId(route)
	return route and route.id or nil
end

local function hideTabToolbar()
	if state.chooser and state.tabToolbar then
		state.chooser:attachedToolbar(nil)
	end
	if state.tabToolbar then
		state.tabToolbar:delete()
	end
	state.tabToolbar = nil
end

local function syncTabSelection(route)
	if state.tabToolbar then
		state.tabToolbar:selectedItem(tabRouteId(route or currentRoute() or state.defaultRoute))
	end
end

local function showTabToolbar()
	if not state.chooser then
		return
	end

	local config = state.config or {}
	local routes = state.routes or {}
	local items = {}

	for _, route in ipairs(routes) do
		items[#items + 1] = {
			id = tabRouteId(route),
			label = route.label or route.id or "mode",
			selectable = true,
			default = route == state.defaultRoute,
			tooltip = route.prefix ~= "" and string.format("%s  %s", route.prefix, route.label or "") or route.label or "",
			fn = function()
				state.route = route
				state.query = ""
				state.ignoreQueryCallback = true
				if state.chooser then
					setDisplayedQuery("")
					state.chooser:placeholderText(chooserPlaceholder())
				end
				refreshChoices()
				syncTabSelection(route)
			end,
		}
	end

	local toolbar = hs.webview.toolbar.new("launcher_tabs")
	toolbar:addItems(items)
	toolbar:displayMode("label")
	toolbar:sizeMode("regular")
	syncTabSelection(currentRoute() or state.defaultRoute)

	state.tabToolbar = toolbar
	state.chooser:attachedToolbar(toolbar)
end

local function activeRouteFromQuery(query, forceDefault)
	query = query or ""

	if query == "" then
		return state.defaultRoute, ""
	end

	local prefix = query:sub(1, 1)
	local route = state.routesByPrefix[prefix]
	if route then
		return route, query:sub(2)
	end

	if forceDefault then
		return state.defaultRoute, query
	end

	if state.route and state.route ~= state.defaultRoute then
		return state.route, query
	end

	return state.defaultRoute, query
end

local function buildChoices()
	local route = currentRoute()
	if not route then
		return {}
	end

	local source
	if route.source == "apps" then
		source = appsSource.entriesForRoute(state.config, route)
	elseif route.source == "layouts" then
		source = layoutsSource.entriesForRoute(state.config, route)
	else
		source = {}
	end

	local choices = {}
	local query = queryForRoute(state.query or "", route)
	if query == "?" or query:match("^%?%s") then
		local help = state.config and state.config.prefixHelp or {}
		local colors = (state.config and state.config.colors) or {}
		local hotkey = state.config and state.config.hotkey or {}
		local hotkeyText = table.concat(hotkey.mods or {}, "+")
		if hotkey.key then
			hotkeyText = hotkeyText ~= "" and (hotkeyText .. "+" .. hotkey.key) or hotkey.key
		end
		choices[#choices + 1] = {
			text = styledText("Launcher", colors.help),
			subText = styledText("" .. hotkeyText .. " = open launcher; Esc = close", colors.help),
			label = "Launcher",
			source = "help",
		}
		for _, item in ipairs(help.items or {}) do
			choices[#choices + 1] = {
				text = styledText(item.prefix ~= "" and item.prefix or "(none)", colors.helpAccent),
				subText = styledText((item.label or "mode") .. " — " .. (item.description or ""), colors.help),
				label = item.label or item.prefix or "mode",
				source = "help",
			}
		end
		return choices
	end
	local loweredQuery = query:lower()

	for _, entry in ipairs(source) do
			if loweredQuery == ""
				or (type(entry.label) == "string" and entry.label:lower():find(loweredQuery, 1, true))
				or (type(entry.subText) == "string" and entry.subText:lower():find(loweredQuery, 1, true))
			then
				choices[#choices + 1] = entry
			end
		end

	return choices
end

local function refreshChoices()
	if state.chooser then
		state.chooser:choices(buildChoices())
	end
end

local function applyRouteFromQuery(rawQuery, forceDefault)
	local route, stripped = activeRouteFromQuery(rawQuery, forceDefault)
	local routeChanged = route ~= state.route
	state.route = route
	state.query = rawQuery or ""

	if routeChanged then
		if state.chooser then
			state.chooser:placeholderText(chooserPlaceholder())
		end
		syncTabSelection(route)
	end

	refreshChoices()

	if state.chooser and not state.ignoreQueryCallback then
		state.ignoreQueryCallback = true
		setDisplayedQuery(rawQuery or "")
	end
end

local function onQueryChanged(rawQuery)
	rawQuery = rawQuery or ""
	if state.ignoreQueryCallback then
		state.ignoreQueryCallback = false
		if rawQuery == "" then
			state.route = state.defaultRoute
			state.query = ""
			if state.chooser then
				state.chooser:placeholderText(chooserPlaceholder())
			end
			syncTabSelection(state.defaultRoute)
			refreshChoices()
			return
		end
		state.query = rawQuery
		refreshChoices()
		return
	end

	-- Deleting an active marker leaves its route, even if search text remains.
	local activePrefix = state.route and normalizePrefix(state.route.prefix) or ""
	local wasPrefixed = activePrefix ~= "" and (state.query or ""):sub(1, 1) == activePrefix
	local stillPrefixed = activePrefix ~= "" and rawQuery:sub(1, 1) == activePrefix
	applyRouteFromQuery(rawQuery, rawQuery == "" or (wasPrefixed and not stillPrefixed))
end

local function onInvalidChoice(choice)
	if not choice or not choice.prefixRow then
		return
	end

	if choice.prefix == "" then
		applyRouteFromQuery("", true)
		return
	end

	applyRouteFromQuery(choice.prefix or "")
end

local function launchChoice(choice)
	if not choice then
		log("launchChoice: nil choice")
		return
	end
	if choice.source == "help" then
		return
	end

	local route = currentRoute()
	log(
		"launchChoice route=%s choice=%s hasLayout=%s source=%s",
		tostring(route and route.id),
		tostring(choice.label or choice.id or choice.text),
		tostring(choice.layout ~= nil),
		tostring(choice.source)
	)

	if choice.layout then
		layoutsSource.launch(choice, state.config)
		return
	end

	if choice.source == "apps" or (route and route.source == "apps") then
		appsSource.launch(choice)
		return
	end

	layoutsSource.launch(choice, state.config)
end

local function createChooser()
	state.chooser = hs.chooser.new(function(choice)
		if not choice then
			return
		end

		launchChoice(choice)
		if state.chooser then
			state.chooser:hide()
		end
	end)

	state.chooser:queryChangedCallback(onQueryChanged)
	state.chooser:invalidCallback(onInvalidChoice)
	state.chooser:hideCallback(function()
		state.route = state.defaultRoute
		state.query = ""
		state.ignoreQueryCallback = false
		hideTabToolbar()
	end)
end

local function startAppWatcher()
	state.appWatcher = hs.application.watcher.new(function(appName, eventType)
		if appName == "Hammerspoon" and eventType == hs.application.watcher.deactivated and state.chooser then
			state.chooser:hide()
		end
	end)

	state.appWatcher:start()
end

local function startHotkey(spec, callback)
	if type(spec) ~= "table" or type(spec.mods) ~= "table" or type(spec.key) ~= "string" then
		return nil
	end

	return hs.hotkey.bind(spec.mods, spec.key, callback)
end

local function openChooser()
	if not state.chooser then
		log("openChooser: chooser missing")
		return
	end

	log("openChooser")
	applyRouteFromQuery("", true)
	state.chooser:placeholderText(chooserPlaceholder())
	showTabToolbar()
	refreshChoices()
	state.chooser:show()
end

function M.start(config)
	config = config or {}
	M.stop()

	state.config = config
	state.routes = {}
	state.routesByPrefix = {}
	state.defaultRoute = config.routes and config.routes.default or nil
	state.route = state.defaultRoute
	state.query = ""
	state.ignoreQueryCallback = false

	if state.defaultRoute then
		state.routes[#state.routes + 1] = state.defaultRoute
		state.routesByPrefix[normalizePrefix(state.defaultRoute.prefix)] = state.defaultRoute
	end

	for _, route in ipairs(config.routes and config.routes.list or {}) do
		state.routes[#state.routes + 1] = route
		state.routesByPrefix[normalizePrefix(route.prefix)] = route
	end

	appsSource.prepare(config, state.defaultRoute or {})
	createChooser()
	startAppWatcher()

	state.hotkey = startHotkey(config.hotkey, openChooser)
end

function M.stop()
	if state.hotkey then
		state.hotkey:delete()
		state.hotkey = nil
	end

	appsSource.stop()

	if state.appWatcher then
		state.appWatcher:stop()
		state.appWatcher = nil
	end

	if state.chooser then
		state.chooser:hide()
		state.chooser = nil
	end

	hideTabToolbar()

	state.route = nil
	state.query = ""
	state.ignoreQueryCallback = false
end

return M
