---@diagnostic disable: undefined-global

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ "-u", "tests/minimal_init.lua" })
      child.lua([[
        package.loaded['codewindow.config'] = nil
        package.loaded['codewindow.utils'] = nil
        package.loaded['codewindow.highlight'] = nil
        package.loaded['codewindow.errors'] = nil
        package.loaded['codewindow.git'] = nil
        package.loaded['codewindow.ruler'] = nil
        package.loaded['codewindow.text'] = nil

        package.loaded['codewindow.highlight'] = {
          extract_highlighting = function() return nil end,
          apply_highlight = function() end,
          display_cursor = function() end,
          display_screen_bounds = function() end,
          setup = function() end,
        }
        package.loaded['codewindow.errors'] = {
          get_lsp_errors = function() return {} end,
        }
        package.loaded['codewindow.git'] = {
          parse_git_diff = function() return {} end,
        }
      ]])
    end,
    post_once = child.stop,
  },
})

T["update_minimap"] = MiniTest.new_set()

T["update_minimap"]["writes correct number of lines"] = function()
  child.lua([[
    local src_buf = vim.api.nvim_create_buf(false, true)
    local src_lines = {}
    for i = 1, 8 do src_lines[i] = 'hello world line ' .. i end
    vim.api.nvim_buf_set_lines(src_buf, 0, -1, true, src_lines)

    local mm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('modifiable', true, { buf = mm_buf })

    local fake_window = {
      buffer = mm_buf,
      window = vim.api.nvim_get_current_win(),
      parent_win = vim.api.nvim_get_current_win(),
    }

    require('codewindow.text').update_minimap(src_buf, fake_window)
    _G._line_count = vim.api.nvim_buf_line_count(mm_buf)
  ]])
  MiniTest.expect.equality(child.lua_get("_G._line_count"), 2)
end

T["update_minimap"]["non-whitespace produces non-blank braille"] = function()
  child.lua([[
    local src_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(src_buf, 0, -1, true, {
      'function hello() return 42 end',
      'local x = 1',
      'local y = 2',
      'return x + y',
    })
    local mm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('modifiable', true, { buf = mm_buf })
    local fake_window = {
      buffer = mm_buf,
      window = vim.api.nvim_get_current_win(),
      parent_win = vim.api.nvim_get_current_win(),
    }
    require('codewindow.text').update_minimap(src_buf, fake_window)
    local lines = vim.api.nvim_buf_get_lines(mm_buf, 0, -1, true)
    _G._has_content = lines[1] ~= nil and #lines[1] > 0
  ]])
  MiniTest.expect.equality(child.lua_get("_G._has_content"), true)
end

T["update_minimap"]["writes ruler labels in reserved gutter"] = function()
  child.lua([[
    require('codewindow.config').setup({
      minimap_width = 2,
      ruler_width = 3,
      ruler_gap = 1,
      ruler_side = 'right',
      ruler_interval = 4,
      show_ruler = true,
      use_lsp = false,
      use_git = false,
    })

    local src_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(src_buf, 0, -1, true, {
      'first',
      'second',
      'third',
      'fourth',
    })
    local mm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('modifiable', true, { buf = mm_buf })
    local fake_window = {
      buffer = mm_buf,
      window = vim.api.nvim_get_current_win(),
      parent_win = vim.api.nvim_get_current_win(),
    }

    require('codewindow.text').update_minimap(src_buf, fake_window)
    local line = vim.api.nvim_buf_get_lines(mm_buf, 0, 1, true)[1]
    _G._ruler = line:sub(-3)
    _G._display_width = vim.fn.strdisplaywidth(line)
  ]])

  MiniTest.expect.equality(child.lua_get("_G._ruler"), "  4")
  MiniTest.expect.equality(child.lua_get("_G._display_width"), 10)
end

T["update_minimap"]["widens ruler gutter for decimal labels"] = function()
  child.lua([[
    require('codewindow.config').setup({
      minimap_width = 2,
      ruler_width = 3,
      ruler_gap = 1,
      ruler_side = 'right',
      ruler_interval = 32,
      show_ruler = true,
      use_lsp = false,
      use_git = false,
    })

    local src_buf = vim.api.nvim_create_buf(false, true)
    local src_lines = {}
    for i = 1, 2100 do
      src_lines[i] = 'line ' .. i
    end
    vim.api.nvim_buf_set_lines(src_buf, 0, -1, true, src_lines)

    local mm_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('modifiable', true, { buf = mm_buf })
    local fake_window = {
      buffer = mm_buf,
      window = vim.api.nvim_get_current_win(),
      parent_win = vim.api.nvim_get_current_win(),
    }

    require('codewindow.text').update_minimap(src_buf, fake_window)
    local line = vim.api.nvim_buf_get_lines(mm_buf, 511, 512, true)[1]
    _G._ruler = line:sub(-5)
    _G._display_width = vim.fn.strdisplaywidth(line)
  ]])

  MiniTest.expect.equality(child.lua_get("_G._ruler"), "2.05k")
  MiniTest.expect.equality(child.lua_get("_G._display_width"), 12)
end

return T
