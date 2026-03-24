local codewindow = require("codewindow")
local minimap_txt = require("codewindow.text")
local minimap_win = require("codewindow.window")

local api = vim.api

api.nvim_create_user_command("CodeWindowOpen", function()
  codewindow.open_minimap()
end, {})

api.nvim_create_user_command("CodeWindowClose", function()
  codewindow.close_minimap()
end, {})

api.nvim_create_user_command("CodeWindowToggle", function()
  codewindow.toggle_minimap()
end, {})

api.nvim_create_user_command("TokenHeatMapOpen", function()
  local config = require("codewindow.config").get()
  config.use_heatmap = true
  if not minimap_win.is_minimap_open() then
    codewindow.open_minimap()
  else
    local current_buffer = api.nvim_get_current_buf()
    local window = minimap_win.get_minimap_window()
    if window then
      minimap_txt.update_minimap(current_buffer, window)
    end
  end
end, {})

api.nvim_create_user_command("TokenHeatMapClose", function()
  local config = require("codewindow.config").get()
  config.use_heatmap = false
  if minimap_win.is_minimap_open() then
    local current_buffer = api.nvim_get_current_buf()
    local window = minimap_win.get_minimap_window()
    if window then
      minimap_txt.update_minimap(current_buffer, window)
    end
  end
end, {})

api.nvim_create_user_command("TokenHeatMapToggle", function()
  local config = require("codewindow.config").get()
  config.use_heatmap = not config.use_heatmap
  if minimap_win.is_minimap_open() then
    local current_buffer = api.nvim_get_current_buf()
    local window = minimap_win.get_minimap_window()
    if window then
      minimap_txt.update_minimap(current_buffer, window)
    end
  end
end, {})
