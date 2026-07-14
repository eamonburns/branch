local Menu = branch.Menu
local Site = branch.Site
local Cmd = branch.Cmd
local None = branch.None

return Menu {
	title = "Lua Menu",

	Cmd {
		command = "wt.exe",
		key = "c",
	},

	None { name = "first", key = "f" },
	None { name = "second", key = "s" },
	Menu {
		title = "third",
		key = "t",

		None { name = "alpha", key = "a" },
		None { name = "beta", key = "b" },
	},
	Site {
		name = "fourth",
		key = "g",
		url = "https://google.com",
	},
	Site {
		name = "brave",
		key = "b",
		url = "https://search.brave.com/search?q=${query}",
		-- TODO: Form
		-- url = Form {
		-- 	...
		-- },
	},
	Site {
		name = "GOOOGLE",
		url = "https://letmegooglethat.com/",
		key = "g",
	},
	Site {
		name = "Lua site",
		url = "https://www.lua.org",
		key = "l",
	},
}
