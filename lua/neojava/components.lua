-- This file contains the built-in components. Each componment is a function
-- that takes the following arguments:
--      config: A table containing the configuration provided by the user
--              when declaring this component in their renderer config.
--      node:   A NuiNode object for the currently focused node.
--      state:  The current state of the source providing the items.
--
-- The function should return either a table, or a list of tables, each of which
-- contains the following keys:
--    text:      The text to display for this item.
--    highlight: The highlight group to apply to this text.

local highlights = require('neo-tree.ui.highlights')
local common = require('neo-tree.sources.common.components')
local neojava_core_utils = require('neojava.core.utils')

local M = {}

M.name = function(config, node, state)
  local name = common.name(config, node, state)
  if node.path and neojava_core_utils.is_java_file_inside_package(node.path) then
    name.text = string.gsub(name.text, '%.java$', '')
  end
  if node.extra and node.extra.java_type == 'jar_class_file' then
    name.text = string.gsub(name.text, '%.class$', '')
  end
  return name
end

---@param config neotree.Component.Common.Icon
M.icon = function(config, node, state)
  local icon = common.icon(config, node, state)
  if node.extra then
    if node.extra.java_type == 'external_libraries' then
      icon.text = ''
    end
    if node.extra.java_type == 'maven_libraries' then
      icon.text = ''
    end
    if node.extra.java_type == 'gradle_libraries' then
      icon.text = ''
    end
    if node.extra.java_type == 'maven_library' or node.extra.java_type == 'gradle_library' then
      icon.text = ''
    end
  end
  return icon
end

M.current_filter = function(config, node, state)
  local filter = node.search_pattern or ''
  if filter == '' then
    return {}
  end
  return {
    {
      text = 'Find',
      highlight = highlights.DIM_TEXT,
    },
    {
      text = string.format('"%s"', filter),
      highlight = config.highlight or highlights.FILTER_TERM,
    },
    {
      text = 'in',
      highlight = highlights.DIM_TEXT,
    },
  }
end

return vim.tbl_deep_extend('force', common, M)
