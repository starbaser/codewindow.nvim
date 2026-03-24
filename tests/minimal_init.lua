-- Minimal init for codewindow.nvim tests.
-- Adds lua/ to package.path so require('codewindow.*') resolves.
-- Does NOT add to rtp to avoid auto-sourcing plugin/.

local repo_root = vim.fn.fnamemodify(vim.fn.expand('<sfile>'), ':h:h')
local lua_dir = repo_root .. '/lua'
package.path = lua_dir .. '/?.lua;' .. lua_dir .. '/?/init.lua;' .. package.path

require('mini.test').setup({})
