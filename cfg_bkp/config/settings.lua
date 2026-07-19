local M = {}

M.hyper = { "ctrl", "alt" }
M.windowAnimationDuration = 0
M.autoApplyScreenLayout = false
M.screenChangeDelaySeconds = 2

M.apps = {
  ghostty  = { key = "T", names = { "Ghostty" } },
  zed      = { key = "E", names = { "Zed" } },
  teams    = { key = "M", names = { "Microsoft Teams", "Microsoft Teams (work or school)" } },
  slack    = { key = "S", names = { "Slack" } },
  telegram = { key = "G", names = { "Telegram 2", "Telegram" } },
  dbeaver  = { key = "D", names = { "DBeaver", "DBeaver Community" } },
  chrome   = { key = "C", names = { "Google Chrome" } },
  outlook  = { key = "O", names = { "Microsoft Outlook", "Outlook" } },
}

M.commands = {
  workspace = [[
    open -a Ghostty
    sleep 0.4
    osascript -e 'tell application "System Events" to keystroke "tmux new-session -A -s main"'
    osascript -e 'tell application "System Events" to key code 36'
  ]],
  lazydocker = [[
    open -na Ghostty
    sleep 0.4
    osascript -e 'tell application "System Events" to keystroke "lazydocker"'
    osascript -e 'tell application "System Events" to key code 36'
  ]],
}

M.layoutApps = {
  editor = "zed",
  terminal = "ghostty",
  browser = "chrome",
  chat = "slack",
  mail = "outlook",
}

return M
