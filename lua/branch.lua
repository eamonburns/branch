local branch = {}

---Information for menu items. Describes how they should be displayed and
---activated. Can only be created using internal functions.
---@class branch.Item

---@param opts { url: string, name?: string, key?: string }
---@return branch.Item
function branch.Site(opts)
  if type(opts) ~= "table" then
    error("Site: opts is not a table", 2)
  end

  local url = opts.url
  if type(url) ~= "string" then
    error("Site: opts.url is not a string", 2)
  end

  local self = {
    url = url,
  }

  return _branch_new_item(opts.name or url, opts.key, function()
    _branch_open_url(self.url)
  end)
end

---@param opts { command: string, arguments?: string[], name?: string, key?: string }
---@return branch.Item
function branch.Cmd(opts)
  if type(opts) ~= "table" then
    error("Cmd: opts is not a table", 2)
  end

  if type(opts.command) ~= "string" then
    error("Cmd: opts.command is not a string", 2)
  end

  opts.arguments = opts.arguments or {}

  if type(opts.arguments) ~= "table" then
    error("Cmd: opts.arguments is not a list of strings", 2)
  end
  for _, a in ipairs(opts.arguments) do
    if type(a) ~= "string" then
      error("Cmd: opts.arguments is not a list of strings", 2)
    end
  end

  if opts.name and type(opts.name) ~= "string" then
    error("Cmd: opts.name is not a string", 2)
  end

  if opts.key and type(opts.key) ~= "string" then
    error("Cmd: opts.key is not a string", 2)
  end

  local name = opts.name or table.concat({ opts.command, unpack(opts.arguments) }, " ")

  local self = {
    command = opts.command,
    arguments = opts.arguments,
  }

  return _branch_new_item(name, opts.key, function()
    _branch_exec(self.command, unpack(self.arguments))
  end)
end

---@param opts { title: string, key?: string, [integer]: branch.Item }
---@return branch.Item
function branch.Menu(opts)
  if type(opts) ~= "table" then
    error("Menu: opts is not a table", 2)
  end

  local title = opts.title
  if type(title) ~= "string" then
    error("Menu: opts.title is not a string", 2)
  end

  if not opts[1] then
    error("Menu: no menu items", 2)
  end

  return _branch_new_menu(title, opts.key, unpack(opts))
end

---@param opts { name: string, key?: string }
---@return branch.Item
function branch.None(opts)
  if type(opts) ~= "table" then
    error("None: opts is not a table", 2)
  end

  local name = opts.name
  if type(name) ~= "string" then
    error("None: opts.name is not a string", 2)
  end

  return _branch_new_none(name, opts.key)
end
_G.branch = branch
