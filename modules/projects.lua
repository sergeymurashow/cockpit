local M = {}

local markerDirectory = ".cockpit"
local markerFile = "project.json"

local function projectId(path)
	return path:gsub("[^%w]+", "-"):gsub("^-", ""):gsub("-$", "")
end

local function normalize(path)
	if type(path) ~= "string" or path == "" then return nil end
	path = path:gsub("/+", "/")
	if #path > 1 then path = path:gsub("/$", "") end
	return path
end

local function contains(root, path)
	root, path = normalize(root), normalize(path)
	return root and path and (path == root or path:sub(1, #root + 1) == root .. "/")
end

local function readName(path)
	local file = io.open(path .. "/package.json", "r")
	if file then
		local ok, data = pcall(hs.json.decode, file:read("*a"))
		file:close()
		if ok and type(data) == "table" and type(data.name) == "string" then return data.name end
	end
	return path:match("([^/]+)$") or path
end

local function markerPath(path)
	return path .. "/" .. markerDirectory .. "/" .. markerFile
end

local function hasMarker(path)
	return hs.fs.attributes(markerPath(path), "mode") == "file"
end

local function readMarker(path)
	local file = io.open(markerPath(path), "r")
	if not file then return nil end
	local raw = file:read("*a")
	file:close()
	local ok, data = pcall(hs.json.decode, raw)
	if not ok or type(data) ~= "table" then return nil, "invalid project marker" end
	return data
end

local function writeMarker(path, data)
	local directory = path .. "/" .. markerDirectory
	if not hs.fs.attributes(directory, "mode") then
		local ok = hs.fs.mkdir(directory)
		if not ok and not hs.fs.attributes(directory, "mode") then return nil, "cannot create .cockpit directory" end
	end
	local file, err = io.open(markerPath(path), "w")
	if not file then return nil, err or "cannot write project marker" end
	file:write(hs.json.encode(data) or "{}")
	file:close()
	return true
end

local function discover(root, maxDepth, result)
	root = normalize(root)
	if not root or not hs.fs.attributes(root, "mode") then return end
	local function visit(path, depth)
		if depth > maxDepth then return end
		local projectMarker, markerError = readMarker(path)
		if markerError then
			hs.printf("Cockpit: ignoring invalid project marker at %s: %s", path, markerError)
			return
		end
		if projectMarker then
			result[path] = { path = path, name = projectMarker.name or readName(path), ai = projectMarker.ai, discovered = true }
			return
		end
		for name in hs.fs.dir(path) do
			if name ~= "." and name ~= ".." and name:sub(1, 1) ~= "." then
				local child = path .. "/" .. name
				if hs.fs.attributes(child, "mode") == "directory" then visit(child, depth + 1) end
			end
		end
	end
	visit(root, 0)
end

local function merge(config)
	local result, byPath = {}, {}
	local configured = hs.settings.get("cockpit.projects") or {}
	for _, item in ipairs(configured) do
		local path = normalize(item.path or item.root)
		local projectMarker = path and readMarker(path)
		if path and projectMarker then
			local project = {}
			for key, value in pairs(item) do project[key] = value end
			for key, value in pairs(projectMarker) do project[key] = value end
			project.path, project.root = path, path
			project.id = project.id or projectId(path)
			project.name = project.name or readName(path)
			project.tasks = project.tasks or {}
			local override = (hs.settings.get("cockpit.project_overrides") or {})[path]
			if override then
				for key, value in pairs(override) do project[key] = value end
			end
			result[#result + 1], byPath[path] = project, project
		end
	end
	local found = {}
	for _, root in ipairs((config.discovery or {}).roots or {}) do
		discover(root, (config.discovery or {}).maxDepth or 2, found)
	end
	for path, item in pairs(found) do
		if not byPath[path] then
			item.id = projectId(path)
			item.root = path
			local override = (hs.settings.get("cockpit.project_overrides") or {})[path]
			item.tasks = (override and override.tasks) or {}
			if override then
				for key, value in pairs(override) do item[key] = value end
			end
			item.ai = item.ai or {}
			result[#result + 1], byPath[path] = item, item
		end
	end
	return result
end

function M.load(config)
	M.migrateLegacy(config or {})
	return merge(config or {})
end

function M.migrateLegacy(config)
	local migrated = hs.settings.get("cockpit.marker_migration_v1")
	if migrated then return end
	local overrides = hs.settings.get("cockpit.project_overrides") or {}
	for _, legacy in ipairs(config.legacy_projects or config.projects or {}) do
		local path = normalize(legacy.path or legacy.root)
		if path and hs.fs.attributes(path, "mode") == "directory" then
			local projectMarker = readMarker(path)
			if not projectMarker and not hasMarker(path) then
				writeMarker(path, {
					name = legacy.name or readName(path),
					ai = legacy.ai or { provider = "codex", launcher = "omx" },
				})
			end
			if legacy.tasks and #legacy.tasks > 0 then
				overrides[path] = overrides[path] or {}
				overrides[path].tasks = legacy.tasks
			end
		end
	end
	hs.settings.set("cockpit.project_overrides", overrides)
	hs.settings.set("cockpit.marker_migration_v1", true)
end

function M.add(path)
	path = normalize(path)
	if not path or hs.fs.attributes(path, "mode") ~= "directory" then
		return nil, "selected path is not a directory"
	end
	local stored = hs.settings.get("cockpit.projects") or {}
	for _, item in ipairs(stored) do
		if normalize(item.path or item.root) == path then return item end
	end
	local ok, err = writeMarker(path, {
		name = readName(path),
		ai = { provider = "codex", launcher = "omx" },
	})
	if not ok then return nil, err end
	local item = { id = projectId(path), name = readName(path), path = path, tasks = {}, ai = { provider = "codex", launcher = "omx" } }
	stored[#stored + 1] = item
	hs.settings.set("cockpit.projects", stored)
	return item
end

function M.setSlack(path, slack)
	path = normalize(path)
	if not path then return nil, "project path is missing" end
	local overrides = hs.settings.get("cockpit.project_overrides") or {}
	overrides[path] = overrides[path] or {}
	overrides[path].slack = slack
	hs.settings.set("cockpit.project_overrides", overrides)
	return true
end

function M.setTasks(path, tasks)
	path = normalize(path)
	if not path then return nil, "project path is missing" end
	local overrides = hs.settings.get("cockpit.project_overrides") or {}
	overrides[path] = overrides[path] or {}
	overrides[path].tasks = tasks or {}
	hs.settings.set("cockpit.project_overrides", overrides)
	return true
end

function M.attachWorkspaces(projects, workspaces)
	for _, project in ipairs(projects) do
		project.workspaces = {}
		for _, workspace in ipairs(workspaces or {}) do
			if contains(project.root, workspace.current_directory or workspace.cwd or workspace.working_directory) then
				project.workspaces[#project.workspaces + 1] = workspace
			end
		end
	end
	return projects
end

return M
