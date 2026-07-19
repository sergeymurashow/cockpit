local M = {}

local state = {
	providers = {},
	configured = nil,
}

function M.register(provider)
	if type(provider) ~= "table" or type(provider.list) ~= "function" then
		return nil, "invalid workspace provider"
	end
	state.providers[provider.id or provider.name or tostring(#state.providers + 1)] = provider
	return provider
end

function M.configure(config)
	state.configured = config and (config.provider or config.workspaceProvider) or nil
end

function M.current()
	if state.configured and state.providers[state.configured] then
		return state.providers[state.configured]
	end
	for _, provider in pairs(state.providers) do
		if type(provider.isAvailable) ~= "function" or provider.isAvailable() then
			return provider
		end
	end
	return nil
end

function M.list(callback)
	local provider = M.current()
	if not provider then
		callback({}, false, "no workspace provider available")
		return
	end
	provider.list(function(items, live, err)
		callback(items or {}, live == true, err, provider.id or provider.name)
	end)
end

function M.select(id)
	local provider = M.current()
	if provider and type(provider.select) == "function" then
		return provider.select(id)
	end
	return nil, "no workspace provider available"
end

return M
