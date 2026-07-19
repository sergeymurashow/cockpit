local M = {}

local projects = require("modules.projects")
local aiSessions = require("modules.ai_sessions")
local git = require("modules.git")
local workspaces = require("modules.workspaces")
local cmux = require("modules.workspaces.cmux")

workspaces.register(cmux)

local state = {
	config = nil,
	webview = nil,	usercontent = nil,	hotkey = nil,
}

local function sendToPage(message)
	if state.webview then
		local encoded = hs.json.encode(message) or "{}"
		state.webview:evaluateJavaScript("window.cockpitMessage(" .. encoded .. ")")
	end
end

local function publish(workspaces, live, errorMessage)
	local ok, items = pcall(projects.load, state.config or {})
	if not ok then
		sendToPage({ type = "error", message = "project discovery failed: " .. tostring(items) })
		return
	end
	projects.attachWorkspaces(items, workspaces or {})
	aiSessions.attach(items)
	if #items > 0 or not errorMessage then
		sendToPage({ type = "projects", projects = items, workspaces = workspaces or {}, live = live })
		local pending = #items
		for _, project in ipairs(items) do
			git.describe(project, function(info)
				project.git = info
				pending = pending - 1
				if pending == 0 then
					sendToPage({ type = "projects", projects = items, workspaces = workspaces or {}, live = live })
				end
			end)
		end
	else
		sendToPage({ type = "error", message = errorMessage })
	end
end

local function listWorkspaces()
	workspaces.list(function(items, live, errorMessage, providerID)
		publish(items, live, errorMessage or (providerID .. " workspace list unavailable"))
	end)
end

local function openProject(path)
	if type(path) ~= "string" or path == "" then return end
	local task = hs.task.new("/usr/bin/open", nil, { "-a", "Zed", path })
	if task then task:start() end
end

local function handleMessage(message)
	if type(message) == "table" and message.body ~= nil then message = message.body end
	if type(message) == "string" then
		local ok, decoded = pcall(hs.json.decode, message)
		if ok then message = decoded end
	end
	if type(message) ~= "table" then return end
	if message.action == "refresh" then
		listWorkspaces()
	elseif message.action == "selectWorkspace" then
		workspaces.select(message.id)
	elseif message.action == "openCmux" then
		local task
		if type(message.path) == "string" and message.path ~= "" then
			task = hs.task.new("/usr/bin/open", nil, { "-a", "cmux", message.path })
		else
			hs.application.launchOrFocus("cmux")
		end
		if task then task:start() end
	elseif message.action == "openProject" then
		openProject(message.path)
	elseif message.action == "addProject" then
		local selected = hs.dialog.chooseFileOrFolder("Выберите папку проекта", os.getenv("HOME"), false, true, false)
		local path = type(selected) == "table" and selected[1] or selected
		local project, err = projects.add(path)
		if project then
			listWorkspaces()
		else
			hs.alert.show(err or "Не удалось добавить проект")
		end
	elseif message.action == "configureSlack" then
		hs.alert.show("Slack доступен для Claude через connector")
	elseif message.action == "deleteTasks" then
		local items = projects.load(state.config or {})
		for _, project in ipairs(items) do
			if project.path == message.path then
				local remove = {}
				for _, id in ipairs(message.ids or {}) do remove[id] = true end
				local remaining = {}
				for _, task in ipairs(project.tasks or {}) do
					if not remove[task.id] then remaining[#remaining + 1] = task end
				end
				projects.setTasks(project.path, remaining)
				break
			end
		end
		listWorkspaces()
	elseif message.action == "startTasks" then
		local items = projects.load(state.config or {})
		for _, project in ipairs(items) do
			if project.path == message.path then
				local ok, err = aiSessions.send(project, message.command or "")
				if not ok then hs.alert.show(err or "AI command unavailable") end
				break
			end
		end
	elseif message.action == "close" and state.webview then
		state.webview:hide()
	end
end

local function handleNavigation(action, _, details)
	if action ~= "navigationAction" or type(details) ~= "table" then return true end
	local request = details.request or {}
	local url = request.URL or request.url or ""
	if type(url) ~= "string" then return true end
	local command, query = url:match("^cockpit://([^?]+)%?(.*)$")
	if not command then command, query = url:match("^cockpit://(.+)$"), "" end
	if not command then return true end
	local params = {}
	for key, value in query:gmatch("([^=&]+)=([^&]*)") do
		params[key] = value:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
	end
	if command == "refresh" then
		handleMessage({ action = "refresh" })
	elseif command == "close" then
		handleMessage({ action = "close" })
	elseif command == "select" then
		handleMessage({ action = "selectWorkspace", id = params.id })
	end
	return false
end

local function frameFor(config)
	local screen = hs.screen.mainScreen():frame()
	local width = math.min(config.width or 980, screen.w - 80)
	local height = math.min(config.height or 700, screen.h - 100)
	return { x = screen.x + (screen.w - width) / 2, y = screen.y + (screen.h - height) / 2, w = width, h = height }
end

local function createWebview(config)
	local htmlPath = hs.configdir .. "/ui/cockpit.html"
	local file = io.open(htmlPath, "r")
	if not file then hs.alert.show("Cockpit UI file not found"); return end
	local html = file:read("*a"); file:close()
	state.usercontent = hs.webview.usercontent.new("cockpit")
	state.usercontent:setCallback(handleMessage)
	state.webview = hs.webview.new(frameFor(config), { developerExtrasEnabled = true, javaScriptEnabled = true }, state.usercontent)
	state.webview:windowStyle(15)
	state.webview:allowTextEntry(true)
	state.webview:darkMode(true)
	state.webview:closeOnEscape(true)
	state.webview:windowTitle("Project Cockpit")
	state.webview:html(html, "file://" .. hs.configdir .. "/ui/")
	state.webview:windowCallback(function(action)
		if action == "closing" then state.webview = nil end
	end)
end

local function toggle()
	if not state.webview then
		local ok, err = pcall(createWebview, state.config or {})
		if not ok then
			hs.alert.show("Cockpit UI error: " .. tostring(err):sub(1, 180))
			return
		end
	end
	if not state.webview then return end
	if state.webview:isVisible() then state.webview:hide(); return end
	state.webview:show()
	hs.timer.doAfter(0.15, listWorkspaces)
end

function M.start(config)
	M.stop()
	state.config = config or {}
	workspaces.configure(state.config.workspace or state.config.workspaces)
	state.hotkey = hs.hotkey.bind(state.config.hotkey.mods, state.config.hotkey.key, toggle)
	local ok, err = pcall(createWebview, state.config)
	if not ok then
		hs.alert.show("Cockpit startup error: " .. tostring(err):sub(1, 180))
	end
	if state.webview then
		state.webview:hide()
	end
end

function M.stop()
	if state.hotkey then state.hotkey:delete(); state.hotkey = nil end
	if state.webview then state.webview:delete(); state.webview = nil end
	state.usercontent = nil
end

return M
