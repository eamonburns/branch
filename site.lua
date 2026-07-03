local Menu = branch.Menu
local Site = branch.Site

return Menu({
	title = "Lua Menu",

	Site({
		name = "GOOOGLE",
		url = "https://letmegooglethat.com/",
		key = "g",
	}),
	Site({
		name = "Lua site",
		url = "https://www.lua.org",
		key = "l",
	}),
})
