local codewindow = require("codewindow")
local minimap_txt = require("codewindow.text")
local minimap_win = require("codewindow.window")

local api = vim.api

local function set_heatmap(enable)
  local config = require("codewindow.config").get()
  if config.use_heatmap == enable then
    return
  end
  config.use_heatmap = enable
  if enable then
    require("codewindow.heatmap").setup()
  end
  if minimap_win.is_minimap_open() then
    local buf = api.nvim_get_current_buf()
    local window = minimap_win.get_minimap_window()
    if window then
      minimap_txt.update_minimap(buf, window)
    end
  end
end

local subcommands = {
  open = function(opts)
    set_heatmap(opts.heatmap)
    codewindow.open_minimap()
  end,
  close = function()
    codewindow.close_minimap()
  end,
  toggle = function(opts)
    set_heatmap(opts.heatmap)
    codewindow.toggle_minimap()
  end,
}

local sub_names = vim.tbl_keys(subcommands)
table.sort(sub_names)

local function run_command(raw_args, default_heatmap, force_heatmap)
  local parts = vim.split(raw_args, "%s+", { trimempty = true })
  local sub = parts[1]
  local param_start = 2

  if not sub or not subcommands[sub] then
    sub = "toggle"
    param_start = 1
  end

  local opts = { heatmap = default_heatmap }
  for i = param_start, #parts do
    local k, v = parts[i]:match("^(%w+)=(%w+)$")
    if k == "heatmap" then
      opts.heatmap = v == "true" or v == "1"
    end
  end
  if force_heatmap then
    opts.heatmap = true
  end

  local handler = subcommands[sub]

  handler(opts)
end

local function complete_command(lead, line, include_options)
  local parts = vim.split(line, "%s+", { trimempty = true })
  if #parts <= 2 and not line:match("%s$") then
    return vim.tbl_filter(function(s)
      return s:find(lead, 1, true) == 1
    end, sub_names)
  end
  if include_options then
    return { "heatmap=true", "heatmap=false" }
  end
  return {}
end

api.nvim_create_user_command("CodeWindow", function(args)
  run_command(args.args, false, false)
end, {
  nargs = "*",
  complete = function(lead, line)
    return complete_command(lead, line, true)
  end,
})

api.nvim_create_user_command("TokenMap", function(args)
  run_command(args.args, true, true)
end, {
  nargs = "*",
  complete = function(lead, line)
    return complete_command(lead, line, false)
  end,
})
