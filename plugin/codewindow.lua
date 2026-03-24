local codewindow = require("codewindow")
local minimap_txt = require("codewindow.text")
local minimap_win = require("codewindow.window")
local highlight = require("codewindow.highlight")

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

api.nvim_create_user_command("CodeWindow", function(args)
  local parts = vim.split(args.args, "%s+", { trimempty = true })
  local sub = parts[1] or "toggle"
  local handler = subcommands[sub]
  if not handler then
    vim.notify("CodeWindow: unknown subcommand '" .. sub .. "'", vim.log.levels.ERROR)
    return
  end

  local opts = { heatmap = false }
  for i = 2, #parts do
    local k, v = parts[i]:match("^(%w+)=(%w+)$")
    if k == "heatmap" then
      opts.heatmap = v == "true" or v == "1"
    end
  end

  handler(opts)
end, {
  nargs = "*",
  complete = function(lead, line)
    local parts = vim.split(line, "%s+", { trimempty = true })
    if #parts <= 2 and not line:match("%s$") then
      return vim.tbl_filter(function(s)
        return s:find(lead, 1, true) == 1
      end, sub_names)
    end
    return { "heatmap=true", "heatmap=false" }
  end,
})
