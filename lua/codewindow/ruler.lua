local M = {}

local api = vim.api

local function left_pad(value, width)
  local padding = width - #value
  if padding <= 0 then
    return value
  end
  return string.rep(" ", padding) .. value
end

local function compact_number(value, width)
  local raw = tostring(value)
  if #raw <= width then
    return left_pad(raw, width)
  end

  local units = {
    { value = 1000000000, suffix = "g" },
    { value = 1000000, suffix = "m" },
    { value = 1000, suffix = "k" },
  }

  for _, unit in ipairs(units) do
    if value >= unit.value then
      local label = tostring(math.floor(value / unit.value)) .. unit.suffix
      if #label <= width then
        return left_pad(label, width)
      end
    end
  end

  return raw:sub(#raw - width + 1)
end

local function get_parent_height(window)
  if window and api.nvim_win_is_valid(window.parent_win or -1) then
    return api.nvim_win_get_height(window.parent_win)
  end
  return vim.o.lines
end

local function get_interval(window)
  local config = require("codewindow.config").get()
  local explicit_interval = tonumber(config.ruler_interval)
  if explicit_interval and explicit_interval > 0 then
    return math.floor(explicit_interval)
  end

  local height = math.max(1, get_parent_height(window))
  return math.max(10, math.ceil(height / 10) * 10)
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

  ruler[1] = compact_number(1, width)

  local interval = get_interval(window)
  local tick_interval = get_tick_interval(interval)
  local tick = left_pad(".", width)

  for line = tick_interval, #lines, tick_interval do
    if line % interval ~= 0 then
      local row = math.ceil(line / 4)
      ruler[row] = tick
    end
  end

  for line = interval, #lines, interval do
    local row = math.ceil(line / 4)
    ruler[row] = compact_number(line, width)
  end

  return ruler
end

return M
