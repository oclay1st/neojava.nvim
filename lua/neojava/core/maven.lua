local log = require('neo-tree.log')
local utils = require('neo-tree.utils')
local neojava_core_utils = require('neojava.core.utils')
local JARParser = require('neojava.core.jar_parser')

local M = {}

M.load_dependencies = function(maven_base_path, callback)
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
              java_type = 'maven_library',
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

M.load_jar = function(group_id, artifact_id, version, callback)
  local susscces, maven_utils = pcall(require, 'maven.utils')
  if not susscces then
    log.error('Unable to load Maven libraries. Install the Maven plugin: oclay1st/maven.nvim')
    callback({})
    return
  end
  local jar_path = maven_utils.get_jar_file_path(group_id, artifact_id, version) --- @type string
  local function update_items(items)
    if not items or #items == 0 then
      return
    end
    for _, item in ipairs(items) do
      if item.extra.java_type == 'jar_class_file' and item.parent_path then
        local jar_name = artifact_id .. '-' .. version .. '.jar'
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

-- jdt://contents/spring-web-6.1.8.jar/org.springframework.http/MediaType.class?=demo4/%5C/home%5C/oclay%5C/.m2%5C/repository%5C/org%5C/springframework%5C/spring-web%5C/6.1.8%5C/spring-web-6.1.8.jar=/maven.pomderived=/true=/=/javadoc_location=/jar:file:%5C/home%5C/oclay%5C/.m2%5C/repository%5C/org%5C/springframework%5C/spring-web%5C/6.1.8%5C/spring-web-6.1.8-javadoc.jar%5C!%5C/=/=/maven.groupId=/org.springframework=/=/maven.artifactId=/spring-web=/=/maven.version=/6.1.8=/=/maven.scope=/compile=/=/maven.pomderived=/true=/%3Corg.springframework.http(MediaType.class
M.resolve_maven_jar_class_path = function()
  --
end

return M
