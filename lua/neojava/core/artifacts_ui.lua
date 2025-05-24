local Object = require('nui.object')
local Menu = require('nui.menu')
local Text = require('nui.text')
local popups = require('neo-tree.ui.popups')
local highlights = require('neo-tree.ui.highlights')
local Input = require('nui.input')
local Line = require('nui.line')
local neojava_core_templates = require('neojava.core.templates')
local neojava_core_utils = require('neojava.core.utils')
local log = require('neo-tree.log')
local utils = require('neo-tree.utils')
local event = require('nui.utils.autocmd').event
local loop = vim.uv or vim.loop

---@class ArtifactsUI
---@field _artifact_type string
---@field _artifact_name string
---@field _options_component NuiMenu
---@field _input_component NuiInput
---@field _options_width number
---@field _input_width number
---@field _col_position number
local ArtifactsUI = Object('ArtifactsUI')

---Create a new instance of the ArtifactsUI
---@param directory string
---@param on_create function
function ArtifactsUI:init(directory, on_create)
  self.directory = directory
  self._options_width = 30
  self._input_width = 45
  self._col_position = 6
  self.on_create = on_create
end

---@private Create the options component
function ArtifactsUI:_create_options_component()
  local items = {
    { icon = '󰌗', hl = 'Type', type = 'Class' },
    { icon = '󰌗', hl = 'Type', type = 'Record' },
    { icon = '', hl = 'Type', type = 'Interface' },
    { icon = '󰒻', hl = '@number', type = 'Enum' },
    { icon = '󰌗', hl = 'Type', type = 'Annotation' },
    { icon = '󰏖', hl = 'Label', type = 'Package' },
    { icon = '󰈙', hl = 'Tag', type = 'File' },
  }

  local menu_items = {}
  for _, item in pairs(items) do
    local line = Line()
    line:append(' ' .. item.icon, item.hl)
    line:append(' ' .. item.type)
    table.insert(menu_items, Menu.item(line, { type = item.type }))
  end
  local opts = popups.popup_options('Create an artifact:', self._options_width)
  opts.zindex = 60
  opts.position.col = self._col_position
  opts.size = {
    height = #menu_items,
    width = self._options_width,
  }

  self._options_component = Menu(opts, {
    lines = menu_items,
    max_width = self._options_width,
    keymap = {
      focus_next = { 'j', '<Down>', '<Tab>' },
      focus_prev = { 'k', '<Up>', '<S-Tab>' },
      close = { '<Esc>', '<C-c>' },
      submit = { '<CR>', '<Space>' },
    },
    on_submit = function(item)
      self._artifact_type = item.type
      self:_create_input_component()
      self._input_component:show()
    end,
  })
  self._options_component:on({ event.BufLeave, event.BufDelete }, function()
    self._options_component:unmount()
  end, { once = true })
end
---@private Create the input component
function ArtifactsUI:_create_input_component()
  local opts = popups.popup_options('Enter the name of the ' .. self._artifact_type:lower() .. ':')
  opts.size = self._input_width
  local input_opts = {
    prompt = Text(' ', highlights.SPECIAL),
    on_change = function(value)
      self._artifact_name = value
    end,
  }
  if self._artifact_type == 'Package' then
    input_opts.default_value = neojava_core_utils.resolve_package_name(self.directory)
  end
  self._input_component = Input(opts, input_opts)
  self._input_component:map('n', '<enter>', function()
    if self:_create_artifact() then
      self:_quit_all()
    end
  end)
  self._input_component:map('i', '<enter>', function()
    if self:_create_artifact() then
      self:_quit_all()
    end
    vim.cmd('stopinsert')
  end)
  self._input_component:map('n', '<esc>', function()
    self:_quit_all()
  end)
  self._input_component:map('n', '<bs>', function()
    self._input_component:unmount()
    self._options_component:show()
  end)
end

---@private Handle option submit
function ArtifactsUI:_create_artifact()
  if not self._artifact_name or vim.trim(self._artifact_name) == '' then
    log.warn('Invalid ' .. self._artifact_type:lower() .. ' name!!')
    return false
  end
  if self._artifact_type == 'Package' then
    return self:_create_packge()
  end
  if self._artifact_type == 'File' then
    return self:_create_plain_file()
  end
  return self:_create_java_file()
end

function ArtifactsUI:_create_packge()
  if not neojava_core_utils.is_valid_package_name(self._artifact_name) then
    log.warn('Invalid Package name!!')
    return false
  end
  local base_path = neojava_core_utils.resolve_package_base_path(self.directory)
  local path = base_path .. self._artifact_name:gsub('%.', utils.path_separator)
  return neojava_core_utils.create_folder(path, self.on_create)
end

function ArtifactsUI:_create_plain_file()
  local path = self.directory .. utils.path_separator .. self._artifact_name
  if loop.fs_stat(path) then
    log.warn('File already exists')
    return false
  end
  neojava_core_utils.create_file(path, nil, self.on_create)
  return true
end

function ArtifactsUI:_create_java_file()
  local java_file_name = neojava_core_utils.resolve_java_file_name(self._artifact_name)
  local path = self.directory .. utils.path_separator .. java_file_name
  if loop.fs_stat(path) then
    log.warn(
      'File already exists for ' .. self._artifact_type:lower() .. ':' .. self._artifact_name
    )
    return false
  end
  local name = self._artifact_name:gsub('%.java$', '')
  if not neojava_core_utils.is_valid_type_name(name) then
    log.warn('Invalid ' .. self._artifact_type:lower() .. ' name!!')
    return false
  end
  local text = ''
  local package_name = neojava_core_utils.resolve_package_name(self.directory)
  if self._artifact_type == 'Class' then
    text = neojava_core_templates.create_class(package_name, name)
  end
  if self._artifact_type == 'Record' then
    text = neojava_core_templates.create_record(package_name, name)
  end
  if self._artifact_type == 'Interface' then
    text = neojava_core_templates.create_interface(package_name, name)
  end
  if self._artifact_type == 'Annotation' then
    text = neojava_core_templates.create_annotation(package_name, name)
  end
  if self._artifact_type == 'Enum' then
    text = neojava_core_templates.create_enum(package_name, name)
  end
  neojava_core_utils.create_file(path, text, self.on_create)
  return true
end

function ArtifactsUI:_quit_all()
  self._options_component:unmount()
  if self._input_component then
    self._input_component:unmount()
  end
end

function ArtifactsUI:mount()
  self:_create_options_component()
  --Create the input component
  self._options_component:show()
end

return ArtifactsUI
