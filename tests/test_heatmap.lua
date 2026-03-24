---@diagnostic disable: undefined-global

local child = MiniTest.new_child_neovim()

-- Resolve fixture path from this file's location
local fixture_dir = vim.fn.fnamemodify(vim.fn.expand('<sfile>'), ':p:h') .. '/fixtures'

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

T['compute']['returns table of length ceil(lines/4)'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local lines = {}
    for i = 1, 12 do lines[i] = 'foo bar baz' end
    _G._result = hm.compute(lines)
    _G._len = #_G._result
  ]])
  MiniTest.expect.equality(child.lua_get('_G._len'), 3)
end

T['compute']['all levels in range 1..10'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local lines = {}
    for i = 1, 40 do lines[i] = string.rep('word ', i) end
    local density = hm.compute(lines)
    _G._in_range = true
    for _, v in ipairs(density) do
      if v < 1 or v > 10 then _G._in_range = false end
    end
  ]])
  MiniTest.expect.equality(child.lua_get('_G._in_range'), true)
end

T['compute']['varied token counts produce non-uniform density'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local lines = {}
    for i = 1, 4 do lines[i] = 'x' end
    for i = 5, 8 do lines[i] = string.rep('word ', 20) end
    for i = 9, 12 do lines[i] = string.rep('word ', 50) end
    local density = hm.compute(lines)
    _G._d1 = density[1]
    _G._d3 = density[3]
    _G._monotonic = (density[1] <= density[2]) and (density[2] <= density[3])
  ]])
  local d1 = child.lua_get('_G._d1')
  local d3 = child.lua_get('_G._d3')
  MiniTest.expect.no_equality(d1, d3)
  MiniTest.expect.equality(child.lua_get('_G._monotonic'), true)
end

T['compute']['empty lines get uniform density'] = function()
  -- tiktoken encodes newlines from table.concat, so empty lines are non-zero tokens
  -- all chunks equal → range=0 → density=5
  child.lua([[
    local hm = require('codewindow.heatmap')
    local density = hm.compute({ '', '', '', '' })
    _G._result = density[1]
  ]])
  MiniTest.expect.equality(child.lua_get('_G._result'), 5)
end

T['compute']['all equal counts produce uniform mid density'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local lines = {}
    for i = 1, 8 do lines[i] = 'a b c' end
    local density = hm.compute(lines)
    _G._all_five = (density[1] == 5) and (density[2] == 5)
  ]])
  MiniTest.expect.equality(child.lua_get('_G._all_five'), true)
end

T['compute']['single line returns density >= 1'] = function()
  child.lua([[
    local hm = require('codewindow.heatmap')
    local density = hm.compute({ 'hello world foo bar' })
    _G._result = density[1]
  ]])
  local v = child.lua_get('_G._result')
  MiniTest.expect.equality(type(v) == 'number' and v >= 1 and v <= 10, true)
end

T['compute']['whitespace-only lines get uniform density'] = function()
  -- tiktoken tokenizes spaces, so all chunks have equal non-zero counts → density=5
  child.lua([[
    local hm = require('codewindow.heatmap')
    local lines = {}
    for i = 1, 8 do lines[i] = '   ' end
    local density = hm.compute(lines)
    _G._all_five = (density[1] == 5) and (density[2] == 5)
  ]])
  MiniTest.expect.equality(child.lua_get('_G._all_five'), true)
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
