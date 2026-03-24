---@diagnostic disable: undefined-global

local child = MiniTest.new_child_neovim()

local fixture_dir = vim.fn.fnamemodify('tests/fixtures', ':p')

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'tests/minimal_init.lua' })
      child.lua('vim.env.TIKTOKEN_CACHE_DIR = "' .. fixture_dir .. '"')
      child.lua([[
        package.loaded['codewindow.config'] = nil
        package.loaded['codewindow.heatmap'] = nil
      ]])
    end,
    post_once = child.stop,
  },
})

T['compute'] = MiniTest.new_set()

T['compute']['returns nil for empty lines'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    _G._result = hm.compute({})
  ]])
  MiniTest.expect.equality(child.lua_get('_G._result'), vim.NIL)
end

T['compute']['returns 2D grid with correct dimensions'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local lines = {}
    for i = 1, 12 do lines[i] = string.rep('x', 160) end
    local density = hm.compute(lines)
    _G._rows = #density
    _G._cols = #density[1]
  ]])
  MiniTest.expect.equality(child.lua_get('_G._rows'), 3) -- ceil(12/4)
  MiniTest.expect.equality(child.lua_get('_G._cols'), 20) -- default minimap_width
end

T['compute']['all levels in range 1..10'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local lines = {}
    for i = 1, 40 do lines[i] = string.rep('word ', i * 5) end
    local density = hm.compute(lines)
    _G._in_range = true
    for _, row in ipairs(density) do
      for _, v in ipairs(row) do
        if v < 1 or v > 10 then _G._in_range = false end
      end
    end
  ]])
  MiniTest.expect.equality(child.lua_get('_G._in_range'), true)
end

T['compute']['sparse vs dense columns produce different densities'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    -- 4 lines: first 8 chars sparse, chars 9-16 dense
    local lines = {}
    for i = 1, 4 do
      lines[i] = 'x       ' .. 'complex_variable_name += function_call(arg1, arg2)'
    end
    local density = hm.compute(lines)
    _G._col1 = density[1][1]  -- sparse region
    _G._col2 = density[1][2]  -- dense region
  ]])
  local col1 = child.lua_get('_G._col1')
  local col2 = child.lua_get('_G._col2')
  -- Dense column should have higher or equal density
  MiniTest.expect.equality(col1 <= col2, true)
end

T['compute']['empty cells get density 1'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    -- Short lines: only first few columns have content, rest are empty
    local lines = { 'hi', 'hi', 'hi', 'hi' }
    local density = hm.compute(lines)
    -- Last column (col 20) should be empty → density 1
    _G._last_col = density[1][20]
  ]])
  MiniTest.expect.equality(child.lua_get('_G._last_col'), 1)
end

T['compute']['uniform content has low variance'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local line = string.rep('abcdefgh ', 20)
    local lines = { line, line, line, line, line, line, line, line }
    local density = hm.compute(lines)
    -- Uniform content should not produce extreme spread
    local lo, hi = 10, 1
    for x = 1, 20 do
      local v = density[1][x]
      if v ~= 1 then
        if v < lo then lo = v end
        if v > hi then hi = v end
      end
    end
    _G._spread = hi - lo
  ]])
  -- Token boundary effects may cause slight variation, but spread should be small
  local spread = child.lua_get('_G._spread')
  MiniTest.expect.equality(spread <= 3, true)
end

T['compute']['single line returns grid'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local density = hm.compute({ 'hello world foo bar baz qux' })
    _G._is_table = type(density[1]) == 'table'
    _G._has_cols = #density[1] == 20
  ]])
  MiniTest.expect.equality(child.lua_get('_G._is_table'), true)
  MiniTest.expect.equality(child.lua_get('_G._has_cols'), true)
end

-- Unhappy paths

T['init degradation'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'tests/minimal_init.lua' })
      child.lua([[
        package.loaded['tiktoken_core'] = nil
        package.preload['tiktoken_core'] = function()
          error('tiktoken_core not available')
        end
        package.loaded['codewindow.heatmap'] = nil
        package.loaded['codewindow.config'] = nil
      ]])
    end,
  },
})

T['init degradation']['compute returns nil when tiktoken missing'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    _G._result = hm.compute({ 'hello world' })
  ]])
  MiniTest.expect.equality(child.lua_get('_G._result'), vim.NIL)
end

T['init degradation']['repeated calls still return nil after init failure'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    hm.compute({ 'first attempt' })
    _G._result = hm.compute({ 'second attempt' })
  ]])
  MiniTest.expect.equality(child.lua_get('_G._result'), vim.NIL)
end

T['bad vocab'] = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'tests/minimal_init.lua' })
      child.lua([[
        vim.env.TIKTOKEN_CACHE_DIR = vim.fn.tempname()
        vim.fn.mkdir(vim.env.TIKTOKEN_CACHE_DIR, 'p')
        package.loaded['codewindow.heatmap'] = nil
        package.loaded['codewindow.config'] = nil
      ]])
    end,
  },
})

T['bad vocab']['compute returns nil when vocab file missing'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    _G._result = hm.compute({ 'hello world' })
  ]])
  MiniTest.expect.equality(child.lua_get('_G._result'), vim.NIL)
end

return T
