---@diagnostic disable: undefined-global

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "tests/minimal_init.lua" })
      child.lua([[
        _G._config = { use_heatmap = false }
        _G._calls = {}
        _G._heatmap_setup = 0

        package.loaded['codewindow.config'] = {
          get = function()
            return _G._config
          end,
        }
        package.loaded['codewindow'] = {
          open_minimap = function()
            table.insert(_G._calls, 'open')
          end,
          close_minimap = function()
            table.insert(_G._calls, 'close')
          end,
          toggle_minimap = function()
            table.insert(_G._calls, 'toggle')
          end,
        }
        package.loaded['codewindow.text'] = {
          update_minimap = function()
            table.insert(_G._calls, 'update')
          end,
        }
        package.loaded['codewindow.window'] = {
          is_minimap_open = function()
            return false
          end,
          get_minimap_window = function()
            return nil
          end,
        }
        package.loaded['codewindow.heatmap'] = {
          setup = function()
            _G._heatmap_setup = _G._heatmap_setup + 1
          end,
        }

        vim.cmd('source ' .. vim.fn.fnameescape(vim.fn.getcwd() .. '/plugin/codewindow.lua'))
      ]])
    end,
    post_once = child.stop,
  },
})

T["commands"] = MiniTest.new_set()

T["commands"]["registers TokenMap"] = function()
  MiniTest.expect.equality(child.fn.exists(":TokenMap"), 2)
end

T["commands"]["TokenMap toggles with heatmap enabled"] = function()
  child.cmd("TokenMap")
  MiniTest.expect.equality(child.lua_get("_G._config.use_heatmap"), true)
  MiniTest.expect.equality(child.lua_get("_G._heatmap_setup"), 1)
  MiniTest.expect.equality(child.lua_get("_G._calls"), { "toggle" })
end

T["commands"]["TokenMap forces heatmap when arguments say otherwise"] = function()
  child.cmd("TokenMap open heatmap=false")
  MiniTest.expect.equality(child.lua_get("_G._config.use_heatmap"), true)
  MiniTest.expect.equality(child.lua_get("_G._heatmap_setup"), 1)
  MiniTest.expect.equality(child.lua_get("_G._calls"), { "open" })
end

T["commands"]["CodeWindow still accepts explicit heatmap option"] = function()
  child.cmd("CodeWindow open heatmap=true")
  MiniTest.expect.equality(child.lua_get("_G._config.use_heatmap"), true)
  MiniTest.expect.equality(child.lua_get("_G._heatmap_setup"), 1)
  MiniTest.expect.equality(child.lua_get("_G._calls"), { "open" })
end

return T
