local M = {}

local api = vim.api

local function left_pad(value, width)
  local padding = width - #value
  if padding <= 0 then
    return value
  end
  return string.rep(" ", padding) .. value
end

local base36_digits = "0123456789abcdefghijklmnopqrstuvwxyz"

local function to_base36(value)
  if value == 0 then
    return "0"
  end

  local encoded = ""
  while value > 0 do
    local digit = value % 36
    encoded = base36_digits:sub(digit + 1, digit + 1) .. encoded
    value = math.floor(value / 36)
  end
  return encoded
end

local function zero_pad(value, width)
  local padding = width - #value
  if padding <= 0 then
    return value
  end
  return string.rep("0", padding) .. value
end

local units = {
  { value = 1000000000, suffix = "g" },
  { value = 1000000, suffix = "m" },
  { value = 1000, suffix = "k" },
}

local function get_unit(value)
  for _, unit in ipairs(units) do
    if value >= unit.value then
      return unit
    end
  end
  return nil
end

local function compact_floor_label(value, width)
  local raw = tostring(value)
  if #raw <= width then
    return left_pad(raw, width)
  end

  local unit = get_unit(value)
  if not unit then
    return nil
  end

  local label = tostring(math.floor(value / unit.value)) .. unit.suffix
  if #label <= width then
    return left_pad(label, width)
  end
  return nil
end

local function compact_precision_label(value, width, precision)
  local raw = tostring(value)
  if #raw <= width then
    return left_pad(raw, width)
  end

  local unit = get_unit(value)
  if not unit then
    return nil
  end

  local label = string.format("%." .. precision .. "f", value / unit.value) .. unit.suffix
  if #label <= width then
    return left_pad(label, width)
  end
  return nil
end

local function compact_bucket_label(value, width)
  local raw = tostring(value)
  if #raw <= width then
    return left_pad(raw, width)
  end

  local unit = get_unit(value)
  if not unit then
    return nil
  end

  local prefix = tostring(math.floor(value / unit.value)) .. unit.suffix
  local bucket_width = width - #prefix
  if bucket_width <= 0 then
    return nil
  end

  local bucket_count = 36 ^ bucket_width
  local bucket = math.floor((value % unit.value) / unit.value * bucket_count)
  bucket = math.min(bucket_count - 1, bucket)
  return prefix .. zero_pad(to_base36(bucket), bucket_width)
end

local function base36_label(value, width)
  local label = to_base36(value)
  if #label <= width then
    return left_pad(label, width)
  end
  return nil
end

local function labels_are_unique(labels)
  local seen = {}
  for _, label in ipairs(labels) do
    if seen[label] then
      return false
    end
    seen[label] = true
  end
  return true
end

local function try_format_values(values, formatter)
  local labels = {}
  for i, value in ipairs(values) do
    local label = formatter(value)
    if label == nil then
      return nil
    end
    labels[i] = label
  end
  if labels_are_unique(labels) then
    return labels
  end
  return nil
end

local function format_values(values, width)
  local labels = try_format_values(values, function(value)
    return compact_floor_label(value, width)
  end)
  if labels then
    return labels
  end

  for precision = 1, 3 do
    labels = try_format_values(values, function(value)
      return compact_precision_label(value, width, precision)
    end)
    if labels then
      return labels
    end
  end

  labels = try_format_values(values, function(value)
    return compact_bucket_label(value, width)
  end)
  if labels then
    return labels
  end

  labels = try_format_values(values, function(value)
    return base36_label(value, width)
  end)
  if labels then
    return labels
  end

  labels = {}
  for i, value in ipairs(values) do
    labels[i] = tostring(value)
  end
  return labels
end

local function get_parent_height(window)
  if window and api.nvim_win_is_valid(window.parent_win or -1) then
    return api.nvim_win_get_height(window.parent_win)
  end
  return vim.o.lines
end

local function centerable_interval(raw_interval)
  local row_interval = math.max(2, math.ceil(raw_interval / 4))
  if row_interval % 2 == 1 then
    row_interval = row_interval + 1
  end
  return row_interval * 4
end

local function get_interval(window)
  local config = require("codewindow.config").get()
  local explicit_interval = tonumber(config.ruler_interval)
  if explicit_interval and explicit_interval > 0 then
    return math.floor(explicit_interval)
  end

  local height = math.max(1, get_parent_height(window))
  return centerable_interval(math.max(10, math.ceil(height / 10) * 10))
end

local function get_tick_interval(interval)
  local config = require("codewindow.config").get()
  local explicit_interval = tonumber(config.ruler_tick_interval)
  if explicit_interval and explicit_interval > 0 then
    return math.floor(explicit_interval)
  end

  return math.max(4, math.floor(interval / 2))
end

function M.render(lines, window)
  local utils = require("codewindow.utils")
  local width = utils.ruler_width()
  if width == 0 then
    return {}
  end

  local minimap_height = math.ceil(#lines / 4)
  local empty = string.rep(" ", width)
  local ruler = {}
  for y = 1, minimap_height do
    ruler[y] = empty
  end

  if minimap_height == 0 then
    return ruler
  end

  local interval = get_interval(window)
  local tick_interval = get_tick_interval(interval)
  local tick = left_pad(".", width)
  local label_values = { 1 }
  for line = interval, #lines, interval do
    label_values[#label_values + 1] = line
  end
  local labels = format_values(label_values, width)

  for line = tick_interval, #lines, tick_interval do
    if line % interval ~= 0 then
      local row = math.ceil(line / 4)
      ruler[row] = tick
    end
  end

  ruler[1] = labels[1]
  for line = interval, #lines, interval do
    local row = math.ceil(line / 4)
    ruler[row] = labels[(line / interval) + 1]
  end

  return ruler
end

return M
