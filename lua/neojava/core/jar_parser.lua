local Job = require('plenary.job')
local log = require('neo-tree.log')
local neojava_core_utils = require('neojava.core.utils')

---@class JARParser
local JARParser = {}
JARParser.__index = JARParser

---Create item given a path
---@param path string
local function create_item(path)
  local parts = {}
  for value in path:gmatch('([^/]+)') do
    table.insert(parts, value)
  end
  local name = parts[#parts]
  local parent = table.concat(parts, '/', 1, #parts - 1)
  local item = {
    id = path,
    name = name,
    path = path,
    loaded = false,
    parent_path = vim.trim(parent) ~= '' and parent .. '/' or nil,
  }
  local is_directory = path:find('/$')
  if is_directory then
    item.type = 'directory'
    item.children = {}
    item.extra = { java_type = 'jar_directory' }
  else
    item.type = 'file'
    item.base = name:match('^([-_,()%s%w%i]+)%.')
    item.ext = name:match('%.([-_,()%s%w%i]+)$')
    item.exts = name:match('^[-_,()%s%w%i]+%.(.*)')
    item.name_lcase = name:lower()
    item.extra = { java_type = name:match('%.class') and 'jar_class_file' or 'jar_file' }
  end
  return item
end

---Convert the path list to items
---@param paths string[]
local function convert_paths_to_items(paths)
  local indexed_items = {}
  for _, path in ipairs(paths) do
    if not indexed_items[path] then
      local item = create_item(path)
      indexed_items[path] = item
      if item.parent_path then
        local parent = indexed_items[item.parent_path]
        if not parent then
          parent = create_item(item.parent_path)
        end
        table.insert(parent.children, item)
      end
    end
  end
  return vim.tbl_filter(function(item)
    return item.parent_path == nil
  end, indexed_items)
end

---Parse the given jar file path
---@param path string
JARParser.parse = function(path, callback)
  local jar_executable = require('neo-tree').config['neojava'].jar_executable
  if not jar_executable then
    log.error('jar executable not found!!')
    return
  end
  local job = Job:new({ command = jar_executable, args = { 'tf', path } })
  if callback then
    job:after_success(function(j, code, signal)
      local paths = j:result()
      local items = convert_paths_to_items(paths)
      callback(neojava_core_utils.SUCCEED_STATE, items)
    end)
    job:after_failure(function(j, code, signal)
      callback(neojava_core_utils.FAILED_STATE, nil)
    end)
  end
  job:start()
end

return JARParser
