local M = {}

local function repositoryFromRemote(remote)
	local value = (remote or ""):gsub("%.git%s*$", "")
	return value:match("[:/]([^/]+/[^/]+)$")
end

function M.detect(remote)
	local host = (remote or ""):match("@([^:/:]+)") or (remote or ""):match("https?://([^/]+)")
	local lowered = (host or ""):lower()
	local id = lowered:find("gitlab", 1, true) and "gitlab" or lowered:find("github", 1, true) and "github" or "unknown"
	local repository = repositoryFromRemote(remote)
	local provider = {
		id = id,
		name = id == "unknown" and "Git" or (id == "gitlab" and "GitLab" or "GitHub"),
		remote = remote,
		repository = repository,
		change_label = id == "github" and "PR" or "MR",
	}
	if id == "gitlab" and repository then provider.web_url = "https://" .. host .. "/" .. repository end
	if id == "github" and repository then provider.web_url = "https://github.com/" .. repository end
	return provider
end

return M
