local ArtifactsUI = require('neojava.core.artifacts_ui')
local neojava_core_utils = require('neojava.core.utils')
local M = {}

---Group the node and children by java package
---@param node any
local function group_package(node)
  if node.children == nil then
    return node
  end
  local first_child = node.children[1]
  if
    #node.children == 1
    and first_child.type == 'directory'
    and neojava_core_utils.is_inside_java_package(node.path)
  then
    first_child.name = node.name .. '.' .. first_child.name
    return group_package(first_child)
  else
    for i, child in ipairs(node.children) do
      node.children[i] = group_package(child)
    end
    return node
  end
end

---Group the nodes by java package
---@param items any[]
M.group_package_nodes = function(items)
  local scan_mode = require('neo-tree').config['neojava'].scan_mode
  if scan_mode == 'deep' then
    for i, item in ipairs(items) do
      items[i] = group_package(item)
    end
    -- TODO: handle no deep scan
  end
end

M.setup_tree_nodes = function(items)
  M.group_package_nodes(items)
end

M.create_artifact = function(directory, callback)
  local artifacts_ui = ArtifactsUI(directory, callback)
  artifacts_ui:mount()
end

return M
