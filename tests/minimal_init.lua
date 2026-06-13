-- Minimal init for codewindow.nvim tests.
-- Adds lua/ to package.path so require('codewindow.*') resolves.
-- Does NOT add to rtp to avoid auto-sourcing plugin/.

local repo_root = vim.fn.fnamemodify(vim.fn.expand("<sfile>"), ":h:h")
local lua_dir = repo_root .. "/lua"
package.path = lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path

local loaders = package.loaders or package.searchers
if loaders and loaders[2] and loaders[3] then
  local source = debug.getinfo(loaders[2], "S").source
  if source == "@vim/_init_packages.lua" then
    table.insert(loaders, 2, table.remove(loaders, 3))
  end
end

require("mini.test").setup({})
