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
  Form {
    title = "Notification",
    key = "n",
    callback = function(fields)
      return Cmd {
        command = "notify-send",
        arguments = { fields.summary, fields.body },
      }
    end,

    Field {
      name = "Summary",
      id = "summary",
      type = "string",
      validate = function(input)
        if input:match("s") then
          return false, "why would you ever think there should be an S in the summary!??!?!?!??!?!?!?"
        end
        return true
      end,
      modify = function(s)
        return s .. " (summary)"
      end,
    },
    Field {
      name = "Body",
      id = "body",
      type = "string",
      modify = function(b)
        return b .. " (body)"
      end,
    },
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
