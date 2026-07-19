return {
	hotkey = { mods = { "alt", "cmd" }, key = "i" },
	width = 980,
	height = 700,
	workspace = {
		provider = "cmux",
	},
	discovery = {
		roots = {
			"/Users/sergeimurashov/.hammerspoon",
			"/Users/sergeimurashov/Documents/Codets",
		},
		maxDepth = 3,
	},
	legacy_projects = {
		{
			id = "hammerspoon",
			name = "Hammerspoon",
			path = "/Users/sergeimurashov/.hammerspoon",
			tasks = {
				{
					id = "workspace-adapter",
					title = "Вынести cmux-код в отдельный adapter",
					description = "Сделать cmux дополнением, которое предоставляет workspace и активные панели.",
					status = "done",
				},
				{
					id = "project-discovery",
					title = "Создать registry и discovery проектов",
					description = "Определять project root, название и метаданные по файловой системе.",
					status = "done",
				},
				{
					id = "workspace-matching",
					title = "Перенести matching workspace → project в Lua",
					description = "Связывать workspace с проектом до передачи данных в UI.",
					status = "done",
				},
				{
					id = "ai-sessions",
					title = "Добавить primary AI и active sessions",
					description = "Показывать основной AI проекта и реально активные AI-сессии.",
					status = "done",
				},
				{
					id = "project-first-ui",
					title = "Перевести UI на project-first модель",
					description = "Сделать проект главным объектом, а cmux — дополнительной информацией.",
					status = "done",
				},
				{
					id = "auto-discovery",
					title = "Добавить автоматическое сканирование проектов",
					description = "Находить новые проекты без ручного внесения каждого пути в конфигурацию.",
					status = "done",
				},
				{
					id = "workspace-provider-interface",
					title = "Добавить интерфейс terminal/workspace providers",
					description = "Отделить Cockpit от конкретного терминала; cmux использовать как первый адаптер.",
					status = "done",
				},
				{
					id = "manual-project-add",
					title = "Добавить ручное создание проекта",
					description = "Выбирать папку через интерфейс и сохранять её как проект.",
					status = "done",
				},
				{
					id = "project-registry-persistence",
					title = "Сделать persistent project registry",
					description = "Хранить добавленные проекты отдельно от Lua-конфигурации.",
					status = "done",
				},
				{
					id = "project-detail-page",
					title = "Сделать страницу проекта",
					description = "Показывать AI, сессии, workspace, Git и связанные сервисы в одном месте.",
					status = "done",
				},
				{
					id = "git-read-model",
					title = "Добавить Git read-only данные",
					description = "Показывать ветку, статус, последние коммиты и открытые MR/PR.",
					status = "done",
				},
				{
					id = "git-provider-interface",
					title = "Добавить Git provider interface",
					description = "Поддержать GitLab и GitHub через отдельные провайдеры.",
					status = "done",
				},
				{
					id = "safe-mr-workflow",
					title = "Реализовать безопасный MR/PR workflow",
					description = "Всегда работать в отдельной ветке от origin/main, показать diff, затем push и MR/PR.",
					status = "todo",
				},
				{
					id = "slack-link",
					title = "Добавить привязку Slack",
					description = "Связывать проект с каналом и показывать релевантную рабочую информацию.",
					status = "done",
				},
				{
					id = "cockpit-performance-refactor",
					title = "Сделать performance refactor Cockpit",
					description = "Убрать лишние полные перерисовки, кэшировать данные и разделить обновление проектов по источникам.",
					status = "done",
				},
				{
					id = "ai-command-transport",
					title = "Подключить transport команд в AI-сессии",
					description = "Передавать команды в активную сессию через provider, не привязываясь к cmux.",
					status = "done",
				},
				{
					id = "claude-slack-connector",
					title = "Подключить Slack через Claude connector",
					description = "Использовать Slack только через доступный Claude connector, без универсальной имитации интеграции.",
					status = "todo",
				},
			},
		},
		{ id = "agents", name = "Agents", path = "/Users/sergeimurashov/Documents/Codets/agents" },
		{ id = "infra", name = "Infra", path = "/Users/sergeimurashov/Documents/Codets/infra" },
		{ id = "ksqldb-offline-leadgen", name = "ksqldb offline leadgen", path = "/Users/sergeimurashov/Documents/Codets/Baf Analytics/ksqldb-offline-leadgen" },
	},
}
