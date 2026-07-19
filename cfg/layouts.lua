return {
	-- Workspaces are named Mission Control spaces on the primary screen.
	-- They are created on demand in the listed order.
	spaces = {
		{ id = "work", screen = "Primary" },
		{ id = "terminal", screen = "Primary" },
		{ id = "chat", screen = "Primary" },
	},

	-- Browser definitions used by layout items.
	browsers = {
		chrome = {
			app = "Google Chrome",
			appPath = "/Applications/Google Chrome.app",
			bundleID = "com.google.Chrome",
			-- Chrome understands profile-directory values like:
			-- Default, Profile 1, Profile 2, etc.
			profileArg = "--profile-directory",
			newWindowArg = "--new-window",
			notes = "You can write either the Chrome profile display name or directory name. The launcher resolves display names from Chrome's Local State file.",
		},
		safari = {
			app = "Safari",
			appPath = "/Applications/Safari.app",
			bundleID = "com.apple.Safari",
			notes = "Safari profiles exist in the UI, but I do not know a clean documented CLI selector for them. Treat profile here as a label for now.",
		},
	},

	-- Each entry becomes one chooser item under the layouts route.
	-- Put items in the exact order you want them executed.
	entries = {
		{
			id = "desk",
			label = "Desk",
			description = "Workspace 1: Chrome Salmon, Slack, Teams; workspace 2: cmux tmux; workspace 3: Telegram 2 and Chrome Your Chrome",
			items = {
				{
					kind = "browser",
					browser = "chrome",
					profile = "Salmon",
					space = "work",
				},
				{
					kind = "app",
					app = "Slack",
					space = "work",
				},
				{
					kind = "app",
					app = "Microsoft Teams",
					space = "work",
				},
				{
					kind = "terminal",
					app = "cmux",
					appPath = "/Applications/cmux.app",
					command = "tmux attach",
					space = "terminal",
				},
				{
					kind = "app",
					app = "Telegram",
					appPath = "/Applications/Telegram 2.app",
					bundleID = "com.tdesktop.Telegram",
					space = "chat",
				},
				{
					kind = "browser",
					browser = "chrome",
					profile = "Your Chrome",
					space = "chat",
				},
			},
		},
	},
}
