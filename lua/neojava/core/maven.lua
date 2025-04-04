local log = require('neo-tree.log')
local utils = require('neo-tree.utils')
local neojava_core_utils = require('neojava.core.utils')
local JARParser = require('neojava.core.jar_parser')

local M = {}

M.load_maven_dependencies = function(maven_base_path, callback)
  local susscces, maven_sources = pcall(require, 'maven.sources')
  if not susscces then
    log.error('Unable to load Maven libraries. Install the Maven plugin: oclay1st/maven.nvim')
    callback({})
    return
  end
  local pom_xml_path = maven_base_path .. utils.path_separator .. 'pom.xml'
  maven_sources.load_project_dependencies(pom_xml_path, false, function(_state, dependencies)
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
              group_id = dependency.group_id,
              artifact_id = dependency.artifact_id,
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

M.load_maven_jar = function(group_id, artifact_id, version, callback)
  local susscces, maven_utils = pcall(require, 'maven.utils')
  if not susscces then
    log.error('Unable to load Maven libraries. Install the Maven plugin: oclay1st/maven.nvim')
    callback({})
    return
  end
  local jar_path = maven_utils.get_jar_file_path(group_id, artifact_id, version)
  JARParser.parse(jar_path, callback)
end

---Get the group id parts
---@param group_id string
M.resove_group_id_parts = function(group_id)
  local parts = {}
  for part in group_id:gmatch('([^.]+)') do
    table.insert(parts, part)
  end
  return parts
end

return M
