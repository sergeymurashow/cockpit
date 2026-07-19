return {
	hotkey = { mods = { "alt" }, key = "Space" },
	placeholder = "Search applications",
	itemSuffix = "Enter = launch",

	prefixHelp = {
		title = "Prefixes",
		items = {
			{ prefix = "/", label = "Running apps", description = "Search running apps alphabetically" },
			{ prefix = "!", label = "Layouts", description = "Apply workspace layouts" },
			{ prefix = "", label = "Installed apps", description = "Default mode" },
		},
	},

	routes = {
		default = {
			id = "installed_apps",
			prefix = "",
			label = "Installed apps",
			source = "apps",
			scope = "installed",
			subtitle = "Installed",
			sort = "name",
			color = { red = 0.08, green = 0.1, blue = 0.12, alpha = 1 },
		},
		list = {
			{
				id = "running_apps",
				prefix = "/",
				label = "Running apps",
				source = "apps",
				scope = "running",
				subtitle = "Running",
				sort = "name",
				color = { red = 0.12, green = 0.36, blue = 0.62, alpha = 1 },
			},
			{
				id = "layouts",
				prefix = "!",
				label = "Layouts",
				source = "layouts",
				scope = "default",
				subtitle = "Layouts",
				sort = "manual",
				color = { red = 0.1, green = 0.45, blue = 0.18, alpha = 1 },
			},
		},
	},

	colors = {
		help = { red = 0.36, green = 0.38, blue = 0.42, alpha = 1 },
		helpAccent = { red = 0.22, green = 0.47, blue = 0.78, alpha = 1 },
	},

	sources = {
		apps = {
			roots = {
				"/Applications",
				"/System/Applications",
				"/System/Applications/Utilities",
				os.getenv("HOME") .. "/Applications",
			},
			maxDepth = 3,
		},
		layouts = require("cfg.layouts"),
	},
}
