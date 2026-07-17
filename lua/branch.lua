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

  if opts.key and type(opts.key) ~= "string" then
    error("Menu: opts.key is not a string", 2)
  end

  if not opts[1] then
    error("Menu: no menu items", 2)
  end

  return _branch_new_menu(title, opts.key, unpack(opts))
end

---Information for form fields. Describes how they should be displayed,
---validated, and modified. Can only be created using internal functions.
---@class branch.Field

---@param opts { name: string, id: string, type: "number"|"string"|"boolean", validate?: fun(input: string): (boolean, string?), modify?: fun(input: string): string }
---@return branch.Field
function branch.Field(opts)
  if type(opts) ~= "table" then
    error("Field: opts is not a table", 2)
  end

  if type(opts.name) ~= "string" then
    error("Field: opts.name is not a string", 2)
  end

  if type(opts.id) ~= "string" then
    error("Field: opts.id is not a string", 2)
  end

  if opts.type ~= "number" and opts.type ~= "string" and opts.type ~= "boolean" then
    error('Field: opts.type is not "number"|"string"|"boolean"', 2)
  end

  if opts.validate and type(opts.validate) ~= "function" then
    error("Field: opts.validate is not function", 2)
  end

  if opts.modify and type(opts.modify) ~= "function" then
    error("Field: opts.modify is not function", 2)
  end

  return _branch_new_field(opts.name, opts.id, opts.type, opts.validate, opts.modify)
end

---@param opts { title: string, key?: string, callback: fun(fields: table<string, string>): (branch.Item), [integer]: branch.Field }
---@return branch.Item
function branch.Form(opts)
  if type(opts) ~= "table" then
    error("Form: opts is not a table", 2)
  end

  if type(opts.title) ~= "string" then
    error("Form: opts.title is not a string", 2)
  end

  if opts.key and type(opts.key) ~= "string" then
    error("Form: opts.key is not a string", 2)
  end

  if type(opts.callback) ~= "function" then
    error("Form: opts.callback is not function", 2)
  end

  if not opts[1] then
    error("Form: no fields", 2)
  end

  return _branch_new_form(opts.title, opts.key, opts.callback, unpack(opts))
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
