local M = {}
local state = { tasks = {} }
local cmux = require("modules.workspaces.cmux")

local function quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

function M.attach(projects)
	for _, project in ipairs(projects) do
		local active, primary = {}, project.ai and project.ai.primary or nil
		local primarySession = project.ai and project.ai.primary_session or nil
		for _, workspace in ipairs(project.workspaces or {}) do
			for _, agent in ipairs(workspace.agents or {}) do
				active[#active + 1] = agent
				local candidate = agent.kind or agent.name
				if type(candidate) == "string" and candidate:lower():find("claude", 1, true) then candidate = "claude" end
				primary = primary or candidate
				primarySession = primarySession or agent
			end
		end
		project.ai = project.ai or {}
		project.ai.primary = primary or "unknown"
		project.ai.active = active
		project.ai.primary_session = primarySession
	end
	return projects
end

function M.send(project, command)
	if not project or not command or command == "" then return nil, "empty AI command" end
	local session = project.ai and project.ai.primary_session
	if session then
		local ok, err = cmux.send({ surfaceId = session.surfaceId, onError = function(message) hs.alert.show(message) end }, command)
		if ok then hs.alert.show("Команда отправлена в primary AI session"); return true end
		return nil, err
	end
	return nil, "primary AI session is not connected to cmux"
end

return M
