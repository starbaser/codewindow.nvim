---@diagnostic disable: undefined-global

local original_modules
local active_highlighters
local original_node_range
local buffer

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      original_modules = {
        config = package.loaded["codewindow.config"],
        utils = package.loaded["codewindow.utils"],
        highlight = package.loaded["codewindow.highlight"],
      }
    end,
    pre_case = function()
      package.loaded["codewindow.config"] = nil
      package.loaded["codewindow.utils"] = nil
      package.loaded["codewindow.highlight"] = nil
      require("codewindow.config").setup({ minimap_width = 2 })

      active_highlighters = require("vim.treesitter.highlighter").active
      buffer = vim.api.nvim_create_buf(false, true)
      original_node_range = vim.treesitter.get_node_range
      vim.treesitter.get_node_range = function(node)
        return unpack(node.range)
      end
    end,
    post_case = function()
      active_highlighters[buffer] = nil
      vim.treesitter.get_node_range = original_node_range
      vim.api.nvim_buf_delete(buffer, { force = true })
    end,
    post_once = function()
      package.loaded["codewindow.config"] = original_modules.config
      package.loaded["codewindow.utils"] = original_modules.utils
      package.loaded["codewindow.highlight"] = original_modules.highlight
    end,
  },
})

local function extract(captures, matches)
  local raw_query = {
    iter_matches = function()
      local index = 0
      return function()
        index = index + 1
        local match = matches[index]
        if match then
          return match.pattern, match.captures, {}
        end
      end
    end,
  }
  local query = {
    _query = { captures = captures },
    hl_cache = { [1] = 1, [2] = 2 },
    query = function()
      return raw_query
    end,
  }
  local syntax_tree = {
    root = function()
      return {}
    end,
  }
  local language_tree = {
    lang = function()
      return "baml"
    end,
  }

  active_highlighters[buffer] = {
    bufnr = buffer,
    tree = {
      for_each_tree = function(_, callback)
        callback(syntax_tree, language_tree)
      end,
    },
    get_query = function()
      return query
    end,
  }

  local lines = { "identifier" }
  return require("codewindow.highlight").extract_highlighting(buffer, lines)
end

T["extract_highlighting"] = MiniTest.new_set()

T["extract_highlighting"]["uses a later specific capture instead of its fallback"] = function()
  local highlights = extract({ "variable", "function.method" }, {
    { pattern = 2, captures = { [2] = { { range = { 0, 0, 0, 8 } } } } },
    { pattern = 1, captures = { [1] = { { range = { 0, 0, 0, 8 } } } } },
  })

  MiniTest.expect.equality(highlights[1][1], { "function.method" })
end

T["extract_highlighting"]["keeps a fallback capture when no later match overrides it"] = function()
  local highlights = extract({ "variable", "function.method" }, {
    { pattern = 1, captures = { [1] = { { range = { 0, 0, 0, 8 } } } } },
  })

  MiniTest.expect.equality(highlights[1][1], { "variable" })
end

return T
