local M = {}

local function interpolate(str, variables)
  return (str:gsub('{(%w+)}', variables))
end

M.create_class = function(package_name, class_name)
  local template = 'package {package};\n\npublic class {class} {\n\n}'
  return interpolate(template, {
    package = package_name,
    class = class_name,
  })
end

M.create_record = function(package_name, record_name)
  local template = 'package {package};\n\npublic record {record}() {\n\n}'
  return interpolate(template, {
    package = package_name,
    record = record_name,
  })
end

M.create_enum = function(package_name, enum_name)
  local template = 'package {package};\n\npublic enum {enum} {\n\n}'
  return interpolate(template, {
    package = package_name,
    enum = enum_name,
  })
end

M.create_interface = function(package_name, interface_name)
  local template = 'package {package};\n\npublic interface {interface} {\n\n}'
  return interpolate(template, {
    package = package_name,
    interface = interface_name,
  })
end

M.create_annotation = function(package_name, annotation_name)
  local template = 'package {package};\n\npublic @interface {annotation} {\n\n}'
  return interpolate(template, {
    package = package_name,
    annotation = annotation_name,
  })
end

return M
