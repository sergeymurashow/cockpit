local M = {}

M.id = "cmux"
M.name = "cmux"

local state = { tasks = {} }

local function binary()
	local candidates = {
		"/Applications/cmux.app/Contents/Resources/bin/cmux",
		"/usr/local/bin/cmux",
		"/opt/homebrew/bin/cmux",
	}
	for _, path in ipairs(candidates) do
		if hs.fs.attributes(path, "mode") == "file" then
			return path
		end
	end
	return "cmux"
end

local function socketPath()
	local candidates = {
		os.getenv("HOME") .. "/.local/state/cmux/cmux.sock",
		"/tmp/cmux.sock",
	}
	for _, path in ipairs(candidates) do
		if hs.fs.attributes(path, "mode") == "socket" then
			return path
		end
	end
	return candidates[1]
end

local function quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function run(args, callback)
	local command = "CMUX_SOCKET_MODE=allowAll CMUX_SOCKET_PATH=" .. quote(socketPath()) .. " exec " .. quote(binary())
	for _, arg in ipairs(args or {}) do
		command = command .. " " .. quote(arg)
	end
	local task = hs.task.new("/bin/zsh", callback, { "-lc", command })
	if task then
		state.tasks[#state.tasks + 1] = task
	end
	return task
end

local function sessionSnapshotPath()
	local directory = os.getenv("HOME") .. "/Library/Application Support/cmux"
	if hs.fs.attributes(directory, "mode") ~= "directory" then return nil end
	local currentPath, currentModification
	for name in hs.fs.dir(directory) do
		if name:match("^session%-.*%.json$") and not name:match("%-previous%.json$") then
			local path = directory .. "/" .. name
			local modification = hs.fs.attributes(path, "modification") or 0
			if not currentModification or modification >= currentModification then
				currentPath, currentModification = path, modification
			end
		end
	end
	return currentPath
end

local function snapshot()
	local path = sessionSnapshotPath()
	if not path then return nil, "cmux session snapshot not found" end
	local file = io.open(path, "r")
	if not file then return nil, "cannot read cmux session snapshot" end
	local raw = file:read("*a")
	file:close()
	local ok, decoded = pcall(hs.json.decode, raw)
	if not ok or type(decoded) ~= "table" then return nil, "invalid cmux session snapshot" end

	local result = {}
	for _, window in ipairs(decoded.windows or {}) do
		local manager = window.tabManager or {}
		for index, workspace in ipairs(manager.workspaces or {}) do
			local panels, panelInfo, agents = workspace.panels or {}, {}, {}
			local panel = panels[1] or {}
			local notifications = panel.notifications or {}
			local notification = notifications[#notifications]
			for _, item in ipairs(panels) do
				local agent = item.terminal and item.terminal.agent or nil
				panelInfo[#panelInfo + 1] = {
					ref = item.surfaceId or item.surface_id or item.id,
					title = item.title or item.directory or item.type or "Surface",
					directory = item.directory or (item.terminal and item.terminal.workingDirectory),
					type = item.type,
				}
				if agent then
					local kind = agent.kind or "unknown"
					local launcher = kind:lower():find("claude", 1, true) and "omc" or "omx"
					agents[#agents + 1] = {
						name = agent.launchCommand and agent.launchCommand.launcher or agent.kind or "Agent",
						kind = kind,
						launcher = launcher,
						model = agent.model or (agent.launchCommand and agent.launchCommand.model) or "unknown",
						sessionId = agent.sessionId,
						directory = agent.workingDirectory,
						surfaceId = item.surfaceId or item.surface_id or item.id,
					}
				end
			end
			result[#result + 1] = {
				ref = workspace.workspaceId or ("snapshot:" .. tostring(index)),
				title = panel.title or workspace.processTitle or workspace.currentDirectory or ("Workspace " .. tostring(index)),
				current_directory = workspace.currentDirectory or panel.directory,
				latest_conversation_message = notification and notification.body or nil,
				status = workspace.statusEntries and workspace.statusEntries[1] and workspace.statusEntries[1].value or nil,
				panels = panelInfo,
				agents = agents,
			}
		end
	end
	return result
end

local function normalizeLive(workspaces)
	for _, workspace in ipairs(workspaces or {}) do
		workspace.agents = {}
		for _, panel in ipairs(workspace.panels or {}) do
			local agent = panel.terminal and panel.terminal.agent
			if agent then
				local kind = agent.kind or "unknown"
				local launcher = kind:lower():find("claude", 1, true) and "omc" or "omx"
				agent.surfaceId = agent.surfaceId or agent.surface_id or panel.surfaceId or panel.surface_id or panel.id
				workspace.agents[#workspace.agents + 1] = {
					name = agent.launchCommand and agent.launchCommand.launcher or agent.kind or "Agent",
					kind = kind,
					launcher = launcher,
					model = agent.model or (agent.launchCommand and agent.launchCommand.model) or "unknown",
					sessionId = agent.sessionId,
					directory = agent.workingDirectory,
					surfaceId = agent.surfaceId,
				}
			end
		end
	end
	return workspaces
end

function M.list(callback)
	local task = run({ "workspace", "list", "--json", "--id-format", "refs" }, function(exitCode, stdout)
		if exitCode == 0 then
			local ok, decoded = pcall(hs.json.decode, stdout or "")
			if ok and type(decoded) == "table" and type(decoded.workspaces) == "table" then
				callback(normalizeLive(decoded.workspaces), true)
				return
			end
		end
		local workspaces, err = snapshot()
		callback(workspaces, false, err)
	end)
	if not task or not task:start() then
		local workspaces, err = snapshot()
		callback(workspaces, false, err)
	end
end

function M.select(workspaceID)
	if type(workspaceID) ~= "string" or workspaceID == "" then return end
	local task = run({ "workspace", "select", "--workspace", workspaceID })
	if task then task:start() end
end

function M.send(session, text)
	if type(session) ~= "table" or not session.surfaceId or type(text) ~= "string" or text == "" then
		return nil, "cmux primary session target is missing"
	end
	local task = run({ "send", "--surface", session.surfaceId, text }, function(exitCode, _, stderr)
		if exitCode ~= 0 and session.onError then session.onError(stderr or "cmux send failed") end
	end)
	if task then task:start(); return true end
	return nil, "cannot start cmux send"
end

return M
