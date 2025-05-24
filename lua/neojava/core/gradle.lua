local utils = require('neo-tree.utils')
local JARParser = require('neojava.core.jar_parser')
local neojava_core_utils = require('neojava.core.utils')
local log = require('neo-tree.log')

local M = {}

M.load_dependencies = function(base_path, callback)
  local susscces, gradle_sources = pcall(require, 'gradle.sources')
  if not susscces then
    log.error('Unable to load Gralde libraries. Install the Maven plugin: oclay1st/gradle.nvim')
    callback({})
    return
  end
  gradle_sources.load_project_dependencies(base_path, false, function(_state, dependencies)
    if _state == 'FAILED' then
      callback(neojava_core_utils.FAILED_STATE, nil)
    else
      dependencies = dependencies or {}
      local items = {} ---@type Item[]
      local indexed_names = {}
      for _, dependency in ipairs(dependencies) do
        local name = dependency:get_compact_name()
        if not indexed_names[name] then
          local item = {
            id = dependency.id,
            name = name,
            type = 'directory',
            loaded = false,
            extra = {
              java_type = 'gradle_library',
              group = dependency.group,
              name = dependency.name,
              version = dependency.version,
            },
          }
          table.insert(items, item)
          indexed_names[name] = true
        end
      end
      callback(neojava_core_utils.SUCCEED_STATE, items)
    end
  end)
end

M.load_jar = function(group, name, version, callback)
  local susscces, gradle_utils = pcall(require, 'gradle.utils')
  if not susscces then
    log.error('Unable to load Gradle library. Install the Gradle plugin: oclay1st/gradle.nvim')
    callback({})
    return
  end
  local jar_path = gradle_utils.get_jar_file_path(group, name, version) --- @type string
  vim.print(jar_path)
  if jar_path == '' then
    log.error("JAR File doesn't exists")
    return
  end
  local function update_items(items)
    if not items or #items == 0 then
      return
    end
    for _, item in ipairs(items) do
      if item.extra.java_type == 'jar_class_file' and item.parent_path then
        local jar_name = name .. '-' .. version .. '.jar'
        local pkg = item.parent_path:gsub('/', '.')
        pkg = pkg:gsub('%.$', '')
        local encode_path = neojava_core_utils.uri_encode(jar_path)
        item.id = 'jdt://contents/'
          .. jar_name
          .. '/'
          .. pkg
          .. '/'
          .. item.name
          .. '?=demo4/'
          .. encode_path
          .. '%3C'
          .. pkg
          .. '('
          .. item.name
      else
        item.id = 'zipfile://' .. jar_path .. '::' .. item.path
      end
      update_items(item.children)
    end
  end
  JARParser.parse(jar_path, function(_state, items)
    if _state == neojava_core_utils.SUCCEED_STATE then
      update_items(items)
    end
    callback(_state, items)
  end)
end

return M
