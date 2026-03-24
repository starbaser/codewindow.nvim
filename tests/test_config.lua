---@diagnostic disable: undefined-global

local T = MiniTest.new_set()

local function fresh_config()
  package.loaded['codewindow.config'] = nil
  return require('codewindow.config')
end

T['get'] = MiniTest.new_set()

T['get']['returns defaults on fresh load'] = function()
  local cfg = fresh_config()
  local c = cfg.get()
  MiniTest.expect.equality(c.minimap_width, 20)
  MiniTest.expect.equality(c.use_heatmap, false)
  MiniTest.expect.equality(c.use_treesitter, true)
  MiniTest.expect.equality(c.use_lsp, true)
  MiniTest.expect.equality(c.use_git, true)
end

T['get']['returns same table by reference'] = function()
  local cfg = fresh_config()
  local a = cfg.get()
  local b = cfg.get()
  MiniTest.expect.equality(a == b, true)
end

T['setup'] = MiniTest.new_set()

T['setup']['merges partial config'] = function()
  local cfg = fresh_config()
  cfg.setup({ minimap_width = 30 })
  MiniTest.expect.equality(cfg.get().minimap_width, 30)
  MiniTest.expect.equality(cfg.get().use_lsp, true)
end

T['setup']['returns the merged config'] = function()
  local cfg = fresh_config()
  local result = cfg.setup({ z_index = 5 })
  MiniTest.expect.equality(result.z_index, 5)
end

T['setup']['nil input returns defaults unchanged'] = function()
  local cfg = fresh_config()
  local result = cfg.setup(nil)
  MiniTest.expect.equality(result.minimap_width, 20)
end

T['setup']['persists across get() calls'] = function()
  local cfg = fresh_config()
  cfg.setup({ auto_enable = true })
  MiniTest.expect.equality(cfg.get().auto_enable, true)
end

return T
