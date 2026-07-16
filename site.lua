local Menu = branch.Menu
local Field = branch.Field
local Form = branch.Form
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
  Form {
    title = "brave",
    key = "b",
    callback = function(fields)
      return Site {
        url = ("https://search.brave.com/search?q=%s"):format(fields.query),
      }
    end,

    Field {
      name = "Query",
      id = "query",
      type = "string",
    },
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
