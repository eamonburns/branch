---Definitions for Zig functions

---@param name string # Display name
---@param key? string # Key to activate item
---@param activate fun() # Function to be called when activated
---@return branch.Item
function _branch_new_item(name, key, activate) ---@diagnostic disable-line: unused-local
  error("_branch_new_item should be defined by host")
end

---@param name string # Display name
---@param key? string # Key to activate item
---@param ... branch.Item # List of items in the menu
---@return branch.Item
function _branch_new_menu(name, key, ...) ---@diagnostic disable-line: unused-local,unused-vararg
  error("_branch_new_menu should be defined by host")
end

---@param name string # Display name
---@param key? string # Key to activate item
---@return branch.Item
function _branch_new_none(name, key) ---@diagnostic disable-line: unused-local
  error("_branch_new_none should be defined by host")
end

---@param url string # URL to open
function _branch_open_url(url) ---@diagnostic disable-line: unused-local
  error("_branch_open_url should be defined by host")
end

---@param command string # Command to run
---@param ... string # Arguments to pass to command
function _branch_exec(command, ...) ---@diagnostic disable-line: unused-local,unused-vararg
  error("_branch_exec should be defined by host")
end
