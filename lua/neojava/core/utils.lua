local log = require('neo-tree.log')
local loop = vim.uv or vim.loop
local events = require('neo-tree.events')
local utils = require('neo-tree.utils')
local sep = utils.path_separator

local M = {}

M.SUCCEED_STATE = 'SUCCEED'
M.FAILED_STATE = 'FAILED'

local java_path_patterns = {
  'src' .. sep .. 'main' .. sep .. 'java',
  'src' .. sep .. 'test' .. sep .. 'java',
}

---Check if the path contains a java package
---@param path string
M.is_inside_java_package = function(path)
  return vim.tbl_contains(java_path_patterns, function(pattern)
    return path:find(pattern .. sep)
  end, { predicate = true })
end

---Check if the path the root of a java package
---@param path string
M.is_root_java_package = function(path)
  return vim.tbl_contains(java_path_patterns, function(pattern)
    return path:find(pattern .. '$')
  end, { predicate = true })
end

---Check if the path contains a java item
---@param path string
M.is_java_file_inside_package = function(path)
  return vim.tbl_contains(java_path_patterns, function(pattern)
    return path:find(pattern .. sep .. '.*%.java$')
  end, { predicate = true })
end

---Resolve the package name given a path
---@param path string
M.resolve_package_name = function(path)
  for _, pattern in ipairs(java_path_patterns) do
    local package_path = path:match(pattern .. sep .. '(.*)')
    if package_path then
      return package_path:gsub('(' .. sep .. ')', '.')
    end
  end
  return nil
end

---Resolve the base java path
---@param path string
M.resolve_package_base_path = function(path)
  for _, pattern in ipairs(java_path_patterns) do
    local _, end_position = path:find(pattern .. sep)
    if end_position then
      return path:sub(1, end_position)
    end
  end
  return nil
end

---Determine if a value is a valid java package name
---@param name string
M.is_valid_package_name = function(name)
  -- Check if it starts or ends with a dot
  if name:sub(1, 1) == '.' or name:sub(-1) == '.' then
    return false
  end
  -- Check for consecutive dots
  if name:find('%.%.') then
    return false
  end
  -- Check each segment must start with a letter and can only contain letters underscores and numbers
  for segment in name:gmatch('[^.]+') do
    if not segment:match('^[a-zA-Z_][a-z0-9_]*$') then
      return false
    end
  end
  return true
end

---Determine if a value is a valid java type name
---@param name string
M.is_valid_type_name = function(name)
  return name:match('^[A-Z][A-Za-z0-9_]*$')
end

---Resolve the java file name
---@param name string
---@return string
M.resolve_java_file_name = function(name)
  return name:match('%.java$') and name or name .. '.java'
end

---Create a folder and parent folders
---@param path string
---@param callback? function
---@return boolean
---@return string | nil
M.create_folder = function(path, callback)
  path = path:gsub(sep .. '$', '')
  -- Check if path already exists
  local stat = vim.loop.fs_stat(path)
  if stat and stat.type == 'directory' then
    return true
  end
  -- Recursively create parent directories

  local parent_path = utils.split_path(path)
  if parent_path then
    local parent_success, parent_err = M.create_folder(parent_path, callback)
    if not parent_success then
      return false, parent_err
    end
  end
  -- Create the final directory
  local success, err = vim.loop.fs_mkdir(path, 493)
  if not success then
    return false, string.format("Failed to create directory '%s': %s", path, err)
  end
  if callback then
    callback(path)
  end
  return true
end

---Create a file and write a content
---@param path string
---@param content? string
---@param callback? function
---FIX: return value
function M.create_file(path, content, callback)
  local complete = vim.schedule_wrap(function()
    events.fire_event(events.FILE_ADDED, path)
    if callback then
      callback(path)
    end
  end)

  local event_result = events.fire_event(events.BEFORE_FILE_ADD, path) or {}
  if event_result.handled then
    complete()
    return
  end

  -- Create and optionally write to the file
  local fd, err = loop.fs_open(path, 'w', 438)
  if not fd then
    log.warn(string.format("Failed to create file '%s': %s", path, err))
    return
  end

  -- Write content if provided
  if content then
    local write_success, write_err = loop.fs_write(fd, content, 0)
    if not write_success then
      loop.fs_close(fd)
      log.warn(string.format("Failed to write to file '%s': %s", path, write_err))
    end
  end

  -- Close the file handle
  local close_success, close_err = vim.loop.fs_close(fd)
  if not close_success then
    log.warn(string.format("Failed to close file '%s': %s", path, close_err))
  end
  complete()
end

---Determine if the path is a Maven pom.xml
---@param path string
---@return boolean
function M.is_maven_file(path)
  return path:find(sep .. 'pom%.xml$') and true or false
end

---Determine if the path is a Gradle
---@param path string
---@return boolean
function M.is_gradle_file(path)
  return (path:find(sep .. '.*build%.gradle') or path:find(sep .. '.*settings%.gradle')) and true
    or false
end

---Determine if the path is an anonymous class path
---@param path string
---@return boolean
function M.is_anonymous_class(path)
  return path:find('%$%d+%.class$') and true or false
end

---Determine if the path is a inner class
---@param path string
---@return boolean
function M.is_inner_class(path)
  return path:find('%$(.-)%.class$') and true or false
end

return M
