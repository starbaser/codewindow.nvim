local M = {}

local api = vim.api

local tiktoken = nil
local encoder_ready = false
local init_failed = false

local CL100K_PATTERN = "(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\\r\\n\\p{L}\\p{N}]?\\p{L}+|\\p{N}{1,3}"
  .. "| ?[^\\s\\p{L}\\p{N}]+[\\r\\n]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+"

local heatmap_palette = {
  "#3b4252",
  "#4c566a",
  "#5e81ac",
  "#5e9eaf",
  "#6abf69",
  "#b5bd68",
  "#e5c07b",
  "#e09050",
  "#d45d5d",
  "#ff4040",
}

function M.setup()
  for i, hex in ipairs(heatmap_palette) do
    api.nvim_set_hl(0, "CodewindowHeatmap" .. i, { fg = hex, default = true })
  end
end

local function init_encoder()
  if init_failed then
    return false
  end

  local ok, mod = pcall(require, "tiktoken_core")
  if not ok then
    vim.notify("codewindow: tiktoken_core not found, heatmap disabled", vim.log.levels.WARN)
    init_failed = true
    return false
  end

  local config = require("codewindow.config").get()
  local path = config.heatmap_encoder_path

  local f = io.open(path, "r")
  if not f then
    vim.notify("codewindow: tiktoken vocab not found at " .. path .. ", heatmap disabled", vim.log.levels.WARN)
    init_failed = true
    return false
  end
  f:close()

  local init_ok, err = pcall(mod.new, path, config.heatmap_special_tokens or {}, CL100K_PATTERN)
  if not init_ok then
    vim.notify("codewindow: tiktoken init failed: " .. tostring(err), vim.log.levels.WARN)
    init_failed = true
    return false
  end

  tiktoken = mod
  encoder_ready = true
  return true
end

function M.compute(lines)
  if not encoder_ready and not init_encoder() then
    return nil
  end

  local minimap_height = math.ceil(#lines / 4)
  if minimap_height == 0 then
    return nil
  end

  local counts = {}
  local nonzero = {}

  for y = 1, minimap_height do
    local start_line = (y - 1) * 4 + 1
    local end_line = math.min(y * 4, #lines)
    local chunk = table.concat(lines, "\n", start_line, end_line)
    local tokens = tiktoken.encode(chunk)
    local count = #tokens
    counts[y] = count
    if count > 0 then
      table.insert(nonzero, count)
    end
  end

  local density = {}

  if #nonzero == 0 then
    for y = 1, minimap_height do
      density[y] = 1
    end
    return density
  end

  local lo, hi

  if #nonzero < 3 then
    table.sort(nonzero)
    lo = nonzero[1]
    hi = nonzero[#nonzero]
  else
    table.sort(nonzero)
    lo = nonzero[math.max(1, math.floor(#nonzero * 0.10))]
    hi = nonzero[math.min(#nonzero, math.ceil(#nonzero * 0.90))]
  end

  local range = hi - lo

  for y = 1, minimap_height do
    if counts[y] == 0 then
      density[y] = 1
    elseif range == 0 then
      density[y] = 5
    else
      local clamped = math.max(lo, math.min(counts[y], hi))
      local norm = (clamped - lo) / range
      density[y] = math.max(1, math.min(10, math.floor(norm * 9) + 1))
    end
  end

  return density
end

return M
