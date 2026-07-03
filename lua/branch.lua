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
		error(("TODO: open external website: %s"):format(self.url))
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

	return _branch_new_menu(title, opts.key, table.unpack(opts))
end

_G.branch = branch
