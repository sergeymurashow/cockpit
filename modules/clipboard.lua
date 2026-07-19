local M = {}

local state = {
	history = {},
	historyMaxEntries = 50,
	historyIgnoreNextChange = false,
	pasteTargetApp = nil,
	appWatcher = nil,
	pasteboardWatcher = nil,
	chooser = nil,
	config = nil,
	historyHotkey = nil,
	pasteNowTap = nil,
}

local function styledText(text, color)
	return hs.styledtext.new(text, { color = color })
end

local function clipboardPreview(text)
	text = tostring(text):gsub("%s+", " ")
	if #text > 80 then
		return text:sub(1, 80) .. "…"
	end
	return text
end

local function clipboardEntryKey(entry)
	return entry.kind .. ":" .. entry.clipboardValue
end

local function serializeClipboardHistory()
	local serialized = {}

	for _, entry in ipairs(state.history) do
		serialized[#serialized + 1] = {
			kind = entry.kind,
			text = entry.text,
			subText = entry.subText,
			clipboardValue = entry.clipboardValue,
		}
	end

	return serialized
end

local function saveClipboardHistory()
	hs.settings.set(state.config.historySettingsKey, serializeClipboardHistory())
end

local function restoreClipboardEntry(entry)
	state.historyIgnoreNextChange = true

	if entry.kind == "image" then
		hs.pasteboard.writeObjects(hs.image.imageFromURL(entry.clipboardValue))
	elseif entry.kind == "url" or entry.kind == "file" or entry.kind == "folder" then
		hs.pasteboard.writeObjects({ { url = entry.clipboardValue } })
	else
		hs.pasteboard.setContents(entry.clipboardValue)
	end

	hs.alert.show("Clipboard restored")
end

local function pasteClipboardEntry(entry)
	restoreClipboardEntry(entry)

	local targetApp = state.pasteTargetApp or hs.application.frontmostApplication()
	if targetApp then
		targetApp:activate(true)
		hs.timer.doAfter(0.1, function()
			hs.eventtap.keyStroke({ "cmd" }, "v", 0, targetApp)
		end)
	end

	hs.timer.doAfter(0.15, function()
		if state.chooser then
			state.chooser:hide()
		end
	end)
end

local function normalizeURLs(value)
	local result = {}

	local function append(item)
		if type(item) == "string" and item ~= "" then
			result[#result + 1] = item
			return
		end

		if type(item) == "table" then
			if type(item.url) == "string" and item.url ~= "" then
				result[#result + 1] = item.url
				return
			end

			for _, nested in ipairs(item) do
				append(nested)
			end
		end
	end

	append(value)

	if #result > 0 then
		return result
	end

	return nil
end

local function extractPasteboardURLs()
	local urls = normalizeURLs(hs.pasteboard.readURL(true))
	if urls then
		return urls
	end

	local contents = hs.pasteboard.getContents()
	if type(contents) == "string" and contents ~= "" then
		local lowered = contents:lower()
		if lowered:match("^https?://")
			or lowered:match("^file://")
			or lowered:match("^ftp://")
		then
			return { contents }
		end

		if lowered:match("^/") then
			local mode = hs.fs.attributes(contents, "mode")
			if mode == "directory" or mode == "file" then
				return { "file://" .. contents }
			end
		end
	end

	return nil
end

local function currentChooserEntry()
	if not state.chooser then
		return nil
	end

	return state.chooser:selectedRowContents()
end

local function addClipboardEntry(entry)
	local entryKey = clipboardEntryKey(entry)

	for i = #state.history, 1, -1 do
		if clipboardEntryKey(state.history[i]) == entryKey then
			table.remove(state.history, i)
		end
	end

	table.insert(state.history, 1, entry)

	while #state.history > state.historyMaxEntries do
		table.remove(state.history)
	end

	saveClipboardHistory()
end

local function saveClipboard(entry)
	if state.historyIgnoreNextChange then
		state.historyIgnoreNextChange = false
		return
	end

	addClipboardEntry(entry)
end

local function loadClipboardHistory()
	local stored = hs.settings.get(state.config.historySettingsKey)
	if type(stored) ~= "table" then
		return
	end

	for _, entry in ipairs(stored) do
		if type(entry) == "table"
			and type(entry.kind) == "string"
			and type(entry.clipboardValue) == "string"
			and type(entry.text) == "string"
		then
			state.history[#state.history + 1] = entry
		end
	end
end

local function showClipboardHistory()
	state.pasteTargetApp = hs.application.frontmostApplication()

	local choices = {}
	for index, entry in ipairs(state.history) do
		local color = state.config.kindColors[entry.kind] or state.config.kindColors.text
		local choice = {
			text = styledText(entry.text, color),
			subText = styledText(string.format("%s #%d  |  %s", entry.subText, index, state.config.itemSuffix), color),
			clipboardValue = entry.clipboardValue,
			kind = entry.kind,
		}

		if entry.kind == "image" then
			choice.image = entry.image
		elseif entry.kind == "url" or entry.kind == "file" or entry.kind == "folder" then
			choice.image = hs.image.imageFromName("NSFolder")
				or hs.image.imageFromName("NSTouchBarFolderTemplate")
				or hs.image.imageFromName("NSTouchBarFolderIcon")
		end

		choices[#choices + 1] = choice
	end

	state.chooser:choices(choices)
	state.chooser:selectedRow(1)
	if state.pasteNowTap and not state.pasteNowTap:isEnabled() then
		state.pasteNowTap:start()
	end
	state.chooser:show()
end

local function handlePasteNowShortcut(event)
	if not state.chooser or not state.chooser:isVisible() then
		return false
	end

	if event:getKeyCode() ~= hs.keycodes.map["return"] then
		return false
	end

	local flags = event:getFlags()
	if not flags or not flags:containExactly({ "cmd" }) then
		return false
	end

	local choice = currentChooserEntry()
	if choice and choice.clipboardValue then
		pasteClipboardEntry(choice)
		return true
	end

	return false
end

local function createChooser()
	state.chooser = hs.chooser.new(function(choice)
		if not choice then
			return
		end

		restoreClipboardEntry(choice)
		if state.chooser then
			state.chooser:hide()
		end
	end)

	state.chooser:hideCallback(function()
		if state.pasteNowTap and state.pasteNowTap:isEnabled() then
			state.pasteNowTap:stop()
		end
		state.pasteTargetApp = nil
	end)
end

local function createPasteNowTap()
	if state.pasteNowTap then
		state.pasteNowTap:stop()
		state.pasteNowTap = nil
	end

	state.pasteNowTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, handlePasteNowShortcut)
end

local function startAppWatcher()
	state.appWatcher = hs.application.watcher.new(function(appName, eventType)
		if appName == "Hammerspoon" and eventType == hs.application.watcher.deactivated and state.chooser then
			state.chooser:hide()
		end
	end)

	state.appWatcher:start()
end

local function startPasteboardWatcher()
	state.pasteboardWatcher = hs.pasteboard.watcher.new(function()
		local urls = extractPasteboardURLs()
		if type(urls) == "table" then
			for _, rawURL in ipairs(urls) do
				local url = type(rawURL) == "table" and rawURL.url or rawURL
				local urlParts = hs.http.urlParts(url) or {}
				local label = url
				local subtitle = "URL"
				local kind = "url"

				if urlParts.isFileURL then
					local path = urlParts.fileSystemRepresentation or urlParts.path or url
					local mode = hs.fs.attributes(path, "mode")
					local name = hs.fs.displayName(path)

					label = name or urlParts.lastPathComponent or url
					if mode == "directory" then
						subtitle = "Folder"
						kind = "folder"
					else
						subtitle = "File"
						kind = "file"
					end
				else
					label = urlParts.lastPathComponent or url
					subtitle = urlParts.scheme or "URL"
				end

				saveClipboard({
					kind = kind,
					text = label,
					subText = subtitle,
					clipboardValue = url,
				})
			end
			return
		end

		local image = hs.pasteboard.readImage()
		if image then
			local imageURL = image:encodeAsURLString(true)
			saveClipboard({
				kind = "image",
				text = "Image",
				subText = "Clipboard image",
				clipboardValue = imageURL,
				image = image,
			})
			return
		end

		local stringValue = hs.pasteboard.readString()
		if type(stringValue) ~= "string" or stringValue == "" then
			return
		end

		saveClipboard({
			kind = "text",
			text = clipboardPreview(stringValue),
			subText = "Clipboard text",
			clipboardValue = stringValue,
		})
	end)
end

local function startHotkey(spec, callback)
	if type(spec) ~= "table" or type(spec.mods) ~= "table" or type(spec.key) ~= "string" then
		return nil
	end

	return hs.hotkey.bind(spec.mods, spec.key, callback)
end

function M.start(config)
	config = config or {}
	M.stop()

	state.config = config
	state.historyMaxEntries = config.maxEntries or state.historyMaxEntries
	state.history = {}
	state.historyIgnoreNextChange = false
	state.pasteTargetApp = nil

	loadClipboardHistory()
	createChooser()
	createPasteNowTap()
	startAppWatcher()
	startPasteboardWatcher()
	state.historyHotkey = startHotkey(config.historyHotkey, showClipboardHistory)
end

function M.stop()
	if state.historyHotkey then
		state.historyHotkey:delete()
		state.historyHotkey = nil
	end

	if state.pasteboardWatcher then
		state.pasteboardWatcher:stop()
		state.pasteboardWatcher = nil
	end

	if state.appWatcher then
		state.appWatcher:stop()
		state.appWatcher = nil
	end

	if state.chooser then
		state.chooser:hide()
		state.chooser = nil
	end

	if state.pasteNowTap then
		state.pasteNowTap:stop()
		state.pasteNowTap = nil
	end

	state.pasteTargetApp = nil
end

return M
