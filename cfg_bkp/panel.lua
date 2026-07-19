local M = {}

local webview = nil
local layoutHandler = nil

local controller = hs.webview.usercontent.new("devos")

local function panelFrame()
    local screen = hs.screen.mainScreen():frame()
    local width = 560
    local height = 650

    return {
        x = screen.x + (screen.w - width) / 2,
        y = screen.y + (screen.h - height) / 2,
        w = width,
        h = height,
    }
end

local function uiPath()
    return os.getenv("HOME")
        .. "/.local/share/devos/ui/index.html"
end

controller:setCallback(function(message)
    local body = message.body or {}

    if body.action == "close" then
        if webview then
            webview:hide()
        end

    elseif body.action == "layout" and layoutHandler then
        layoutHandler(body.target)
    end
end)

local function createPanel()
    if webview then
        return webview
    end

    local path = uiPath()

    webview = hs.webview.new(
        panelFrame(),
        {
            developerExtrasEnabled = true,
        },
        controller
    )

    webview
        :windowStyle({
            "titled",
            "closable",
            "utility",
        })
        :level(hs.drawing.windowLevels.floating)
        :allowTextEntry(true)

    if hs.fs.attributes(path) then
        webview:url("file://" .. path)
    else
        webview:html(string.format([[
            <!doctype html>
            <html>
            <body style="
                background:#171719;
                color:white;
                font-family:-apple-system;
                padding:32px;
            ">
                <h1>DevOS UI not found</h1>
                <p>%s</p>
            </body>
            </html>
        ]], path))
    end

    return webview
end

function M.preload()
    createPanel()

    -- WebView создаётся и начинает загружать UI,
    -- но остаётся скрытым.
    print("[DevOS] panel preloaded")
end

function M.toggle()
    local panel = createPanel()

    if panel:isVisible() then
        panel:hide()
        return
    end

    panel:frame(panelFrame())
    panel:show()
    panel:bringToFront(true)
end

function M.setLayoutHandler(handler)
    layoutHandler = handler
end

return M
