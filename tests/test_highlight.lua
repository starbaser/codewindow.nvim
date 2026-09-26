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

local function extract(captures, matches, lines)
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

  return require("codewindow.highlight").extract_highlighting(buffer, lines or { "identifier" })
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

T["extract_highlighting"]["votes by occupied braille dots rather than token length"] = function()
  local highlights = extract({ "variable", "type" }, {
    { pattern = 1, captures = { [1] = { { range = { 0, 0, 0, 8 } } } } },
    { pattern = 2, captures = { [2] = { { range = { 1, 0, 1, 1 } } } } },
    { pattern = 2, captures = { [2] = { { range = { 2, 0, 2, 1 } } } } },
    { pattern = 2, captures = { [2] = { { range = { 3, 0, 3, 1 } } } } },
  }, { "abcdefgh", "t", "t", "t" })

  MiniTest.expect.equality(highlights[1][1], { "type" })
end

T["extract_highlighting"]["keeps multiline capture bounds on each source line"] = function()
  local highlights = extract({ "string" }, {
    { pattern = 1, captures = { [1] = { { range = { 0, 8, 4, 2 } } } } },
  }, { "abcdefghij", "abcdefghij", "abcdefghij", "abcdefghij", "abcdefghij" })

  MiniTest.expect.equality(highlights[2][1], { "string" })
  MiniTest.expect.equality(highlights[2][2], {})
end

T["extract_highlighting"]["chooses one deterministic group for a tied glyph"] = function()
  local highlights = extract({ "variable", "function.method" }, {
    { pattern = 1, captures = { [1] = { { range = { 0, 0, 0, 4 } } } } },
    { pattern = 2, captures = { [2] = { { range = { 0, 4, 0, 8 } } } } },
  }, { "abcdefgh" })

  MiniTest.expect.equality(highlights[1][1], { "function.method" })
end

local function textured_grid(width, height, alternate)
  require("codewindow.config").setup({ minimap_width = width })
  local matches = {}
  local lines = {}
  for row = 0, height * 4 - 1 do
    lines[#lines + 1] = string.rep("x", width * 8)
    for glyph = 0, width - 1 do
      for half = 0, 1 do
        local capture = alternate(glyph + 1, math.floor(row / 4) + 1, half, row % 4) and 2 or 1
        local start_col = glyph * 8 + half * 4
        matches[#matches + 1] = {
          pattern = capture,
          captures = { [capture] = { { range = { row, start_col, row, start_col + 4 } } } },
        }
      end
    end
  end
  return extract({ "type", "variable" }, matches, lines)
end

T["extract_highlighting"]["shows a local minority color between uniform neighbors"] = function()
  local highlights = textured_grid(3, 1, function(x, _, half, row)
    return x == 2 and half == 1 and row < 2
  end)
  MiniTest.expect.equality(highlights[1][1], { "type" })
  MiniTest.expect.equality(highlights[1][2], { "variable" })
  MiniTest.expect.equality(highlights[1][3], { "type" })
end

T["extract_highlighting"]["preserves an isolated color in a two-dimensional neighborhood"] = function()
  local highlights = textured_grid(3, 3, function(x, y, half, row)
    return x == 2 and y == 2 and half == 1 and row < 2
  end)
  MiniTest.expect.equality(highlights[2][2], { "variable" })
  MiniTest.expect.equality(highlights[1][2], { "type" })
  MiniTest.expect.equality(highlights[2][1], { "type" })
  MiniTest.expect.equality(highlights[3][2], { "type" })
end

T["extract_highlighting"]["dithers a repeated motif down the line without a solid stripe"] = function()
  local highlights = textured_grid(3, 4, function(x, _, half, row)
    return x == 2 and half == 1 and row < 2
  end)
  local shown = 0
  for y = 1, 4 do
    MiniTest.expect.equality(highlights[y][1], { "type" })
    MiniTest.expect.equality(highlights[y][3], { "type" })
    if highlights[y][2][1] == "variable" then
      shown = shown + 1
    end
  end
  MiniTest.expect.equality(shown, 1)
end

T["extract_highlighting"]["disperses repeated mixed colors in two dimensions"] = function()
  local highlights = textured_grid(4, 4, function(_, _, half, row)
    return half == 1 and row < 2
  end)
  local shown, rows, columns = 0, {}, {}
  for y = 1, 4 do
    for x = 1, 4 do
      if highlights[y][x][1] == "variable" then
        shown = shown + 1
        rows[y] = (rows[y] or 0) + 1
        columns[x] = (columns[x] or 0) + 1
      end
    end
  end
  MiniTest.expect.equality(shown, 4)
  for index = 1, 4 do
    MiniTest.expect.equality(rows[index], 1)
    MiniTest.expect.equality(columns[index], 1)
  end
end

T["apply_highlight"] = MiniTest.new_set()

T["apply_highlight"]["coalesces a run into one highlight without overdraw"] = function()
  require("codewindow.config").setup({ minimap_width = 3, show_ruler = false })
  local highlight = require("codewindow.highlight")
  highlight.setup()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { string.rep("⣿", 7) })

  highlight.apply_highlight({ { { "type" }, { "type" }, { "type" } } }, buffer, { "a", "b", "c", "d" })

  local namespace = vim.api.nvim_get_namespaces()["codewindow.highlight"]
  local marks = vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })
  local utils = require("codewindow.utils")
  MiniTest.expect.equality(#marks, 1)
  MiniTest.expect.equality(marks[1][4].hl_group, "@type")
  MiniTest.expect.equality(marks[1][3], utils.minimap_col_start_byte(1))
  MiniTest.expect.equality(marks[1][4].end_col, utils.minimap_col_end_byte(3))
end

T["apply_highlight"]["stops a run at the next color"] = function()
  require("codewindow.config").setup({ minimap_width = 3, show_ruler = false })
  local highlight = require("codewindow.highlight")
  highlight.setup()
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { string.rep("⣿", 7) })

  highlight.apply_highlight({ { { "type" }, { "type" }, { "function" } } }, buffer, { "a", "b", "c", "d" })

  local namespace = vim.api.nvim_get_namespaces()["codewindow.highlight"]
  local marks = vim.api.nvim_buf_get_extmarks(buffer, namespace, 0, -1, { details = true })
  local utils = require("codewindow.utils")
  MiniTest.expect.equality(#marks, 2)
  MiniTest.expect.equality(marks[1][4].hl_group, "@type")
  MiniTest.expect.equality(marks[1][4].end_col, utils.minimap_col_end_byte(2))
  MiniTest.expect.equality(marks[2][4].hl_group, "@function")
  MiniTest.expect.equality(marks[2][3], utils.minimap_col_start_byte(3))
end

return T
