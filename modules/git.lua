local M = {}
local providers = require("modules.git.providers")

local state = { tasks = {}, cache = {} }

local function quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function run(path, args, callback)
	local command = "git -C " .. quote(path)
	for _, arg in ipairs(args) do command = command .. " " .. quote(arg) end
	local task = hs.task.new("/bin/zsh", callback, { "-lc", command })
	if task then state.tasks[#state.tasks + 1] = task; task:start() end
	return task
end

local function lines(raw)
	local result = {}
	for line in (raw or ""):gmatch("[^\n]+") do result[#result + 1] = line end
	return result
end

local function parseCommit(line)
	local hash, shortHash, author, date, subject = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(.*)$")
	if not hash then return nil end
	return { hash = hash, short_hash = shortHash, author = author, date = date, subject = subject }
end

function M.describe(project, callback)
	local path = project.path or project.root
	if not path then callback({ available = false, error = "project path is missing" }); return end
	local cached = state.cache[path]
	if cached and os.time() - cached.timestamp < 15 then
		callback(cached.value)
		return
	end
	local command = "set +e; printf '\001valid\\n'; git -C " .. quote(path) .. " rev-parse --is-inside-work-tree 2>/dev/null; printf '\001branch\\n'; git -C " .. quote(path) .. " branch --show-current 2>/dev/null; printf '\001remote\\n'; git -C " .. quote(path) .. " remote get-url origin 2>/dev/null; printf '\001status\\n'; git -C " .. quote(path) .. " status --short 2>/dev/null; printf '\001log\\n'; git -C " .. quote(path) .. " log -8 --date=iso-strict --pretty=format:%H%x09%h%x09%an%x09%ad%x09%s 2>/dev/null; printf '\001end\\n'"
	local task = hs.task.new("/bin/zsh", function(_, stdout)
		local sections = {}
		for name, body in (stdout or ""):gmatch("\001([^\n]+)\n(.-)\n\001") do sections[name] = body:gsub("%s+$", "") end
		if sections.valid ~= "true" then
			local value = { available = false, error = "not a git repository" }
			state.cache[path] = { timestamp = os.time(), value = value }
			callback(value)
			return
		end
		local changes, commits = {}, {}
		for _, line in ipairs(lines(sections.status)) do
			local code, file = line:match("^(..)%s+(.*)$")
			changes[#changes + 1] = { code = code or "??", file = file or line }
		end
		for _, line in ipairs(lines(sections.log)) do
			local commit = parseCommit(line)
			if commit then commits[#commits + 1] = commit end
		end
		local value = {
			available = true,
			branch = sections.branch or "",
			remote = providers.detect(sections.remote or ""),
			changes = changes,
			commits = commits,
		}
		state.cache[path] = { timestamp = os.time(), value = value }
		callback(value)
	end, { "-lc", command })
	if task then
		state.tasks[#state.tasks + 1] = task
		task:start()
	else
		callback({ available = false, error = "cannot start git inspection" })
	end
end

return M
