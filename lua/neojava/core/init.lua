local ArtifactsUI = require('neojava.core.artifacts_ui')
local neojava_core_utils = require('neojava.core.utils')
local NuiTree = require('nui.tree')
local neojava_core_maven = require('neojava.core.maven')
local M = {}

---@class Item
---@field id string
---@field name string
---@field path string
---@field loaded string
---@field parent_path string
---@field type string
---@field children? Item[]
---@field base? string
---@field ext? string
---@field exts? string[]
---@field name_lcase? string
---@field extra? any

---Sort all items
---@param items Item[]
local function sort_items(items)
  table.sort(items, function(a, b)
    if a.type == b.type then
      return string.lower(a.name) < string.lower(b.name)
    end
    return a.type == 'directory'
  end)
  for _, item in ipairs(items) do
    if item.children and #item.children ~= 0 then
      sort_items(item.children)
    end
  end
end

---Convert an item to node
---@param item Item
---@return NuiTree.Node
local function convert_item_to_node(item, level)
  local children = {}
  if item.children then
    for index, _child in ipairs(item.children) do
      local _child_node = convert_item_to_node(_child, level + 1)
      children[index] = _child_node
    end
  end
  local node = NuiTree.Node({
    id = item.id,
    name = item.name,
    type = item.type,
    loaded = true,
    extra = item.extra,
    level = level,
  }, children)
  return node
end

---Group the item and children by java package
---@param item any
---@param force? boolean
local function group_package(item, force)
  if item.children == nil then
    return item
  end
  local first_child = item.children[1]
  if
    #item.children == 1
    and first_child.type == 'directory'
    and (neojava_core_utils.is_inside_java_package(item.path) or force)
  then
    first_child.name = item.name .. '.' .. first_child.name
    return group_package(first_child, force)
  else
    for i, child in ipairs(item.children) do
      item.children[i] = group_package(child, force)
    end
    return item
  end
end

---Group the items by java package
---@param items any[]
M.group_package_items = function(items)
  local scan_mode = require('neo-tree').config['neojava'].scan_mode
  if scan_mode == 'deep' then
    for i, item in ipairs(items) do
      items[i] = group_package(item)
    end
    -- TODO: handle no deep scan
  end
end

---Setup tree items
---@param items any[]
---@param is_root? boolean
M.setup_tree_items = function(items, is_root)
  M.group_package_items(items)
  M.add_external_libraries_item(items, is_root)
end

M.add_external_libraries_item = function(items, is_root)
  if #items == 0 then
    return
  end
  local base_path = items[1].parent_path
  local _items = items
  if is_root then
    _items = items[1].children
  end
  local external_lib_item = {
    id = base_path .. '_external_libraries',
    name = 'External Libraries',
    type = 'directory',
    loaded = true,
    children = {},
    extra = { java_type = 'external_libraries' },
  }
  local _has_maven_file = false
  local _has_gradle_file = false
  for _, item in ipairs(_items) do
    if not _has_maven_file and neojava_core_utils.is_maven_file(item.path) then
      table.insert(external_lib_item.children, {
        id = base_path .. '_maven_libraries',
        name = 'Maven',
        type = 'directory',
        loaded = false,
        children = {},
        extra = { java_type = 'maven_libraries' },
      })
      _has_maven_file = true
    end
    if not _has_gradle_file and neojava_core_utils.is_gradle_file(item.path) then
      table.insert(external_lib_item.children, {
        id = base_path .. '_gradle_libraries',
        name = 'Gradle',
        type = 'directory',
        loaded = false,
        children = {},
        extra = { java_type = 'gradle_libraries' },
      })
      _has_gradle_file = true
    end
  end
  if _has_maven_file or _has_gradle_file then
    table.insert(_items, external_lib_item)
  end
end

M.load_maven_libraries = function(tree, node, callback)
  local base_path = tree:get_node(node:get_parent_id()):get_parent_id()
  node.extra.java_type_loading = true
  neojava_core_maven.load_maven_dependencies(base_path, function(_state, items)
    node.extra.java_type_loading = false
    if _state == neojava_core_utils.SUCCEED_STATE then
      sort_items(items)
      local nodes = {} ---@type NuiTree.Node[]
      for index, item in ipairs(items) do
        nodes[index] = NuiTree.Node({
          id = item.id,
          name = item.name,
          type = item.type,
          loaded = item.loaded,
          extra = vim.tbl_extend('force', item.extra, { java_type = 'maven_library' }),
          level = node.level + 1,
        })
      end
      vim.schedule(function()
        node.loaded = true
        tree:set_nodes(nodes, node:get_id())
        tree:render()
        callback(neojava_core_utils.SUCCEED_STATE)
      end)
    else
      callback(neojava_core_utils.FAILED_STATE)
    end
  end)
end

M.load_maven_library = function(tree, node, callback)
  local group_id = node.extra.group_id ---@type string
  local group_id_parts = neojava_core_maven.resove_group_id_parts(group_id)
  local artifact_id = node.extra.artifact_id ---@type string
  local version = node.extra.version ---@type string
  node.extra.java_type_loading = true
  neojava_core_maven.load_maven_jar(group_id, artifact_id, version, function(_state, items)
    node.extra.java_type_loading = false
    if _state == neojava_core_utils.SUCCEED_STATE then
      local _node_children = {}
      for index, item in ipairs(items) do
        if not item.parent_path and item.name == group_id_parts[1] then
          item = group_package(item, true)
        end
        items[index] = item
      end
      sort_items(items)
      for index, item in ipairs(items) do
        local _node_child = convert_item_to_node(item, node.level + 1)
        _node_children[index] = _node_child
      end
      vim.schedule(function()
        node.loaded = true
        tree:set_nodes(_node_children, node:get_id())
        tree:render()
        callback(neojava_core_utils.SUCCEED_STATE)
      end)
    else
      callback(neojava_core_utils.FAILED_STATE)
    end
  end)
end

M.create_artifact = function(directory, callback)
  local artifacts_ui = ArtifactsUI(directory, callback)
  artifacts_ui:mount()
end

return M
