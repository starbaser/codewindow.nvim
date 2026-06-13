---@diagnostic disable: undefined-global

local T = MiniTest.new_set()

local function fresh_ruler(config)
  package.loaded["codewindow.config"] = nil
  package.loaded["codewindow.utils"] = nil
  package.loaded["codewindow.ruler"] = nil
  package.loaded["codewindow.config"] = {
    get = function()
      return config
    end,
  }
  return require("codewindow.ruler")
end

local function source_lines(count)
  local lines = {}
  for i = 1, count do
    lines[i] = "line " .. i
  end
  return lines
end

T["render"] = MiniTest.new_set()

T["render"]["labels first line and configured intervals"] = function()
  local ruler = fresh_ruler({
    show_ruler = true,
    ruler_width = 3,
    ruler_interval = 10,
    width_multiplier = 4,
    minimap_width = 20,
  })

  local result = ruler.render(source_lines(25))

  MiniTest.expect.equality(#result, 7)
  MiniTest.expect.equality(result[1], "  1")
  MiniTest.expect.equality(result[2], "  .")
  MiniTest.expect.equality(result[3], " 10")
  MiniTest.expect.equality(result[4], "  .")
  MiniTest.expect.equality(result[5], " 20")
end

T["render"]["automatic intervals leave a centered midpoint row"] = function()
  local old_lines = vim.o.lines
  vim.o.lines = 24
  local ruler = fresh_ruler({
    show_ruler = true,
    ruler_width = 3,
    ruler_interval = nil,
    width_multiplier = 4,
    minimap_width = 20,
  })

  local result = ruler.render(source_lines(70))
  vim.o.lines = old_lines

  MiniTest.expect.equality(result[4], "  .")
  MiniTest.expect.equality(result[8], " 32")
  MiniTest.expect.equality(result[12], "  .")
  MiniTest.expect.equality(result[16], " 64")
end

T["render"]["returns no gutter text when disabled"] = function()
  local ruler = fresh_ruler({
    show_ruler = false,
    ruler_width = 4,
    ruler_interval = 10,
    width_multiplier = 4,
    minimap_width = 20,
  })

  MiniTest.expect.equality(ruler.render(source_lines(25)), {})
end

T["render"]["compacts large line numbers inside the gutter"] = function()
  local ruler = fresh_ruler({
    show_ruler = true,
    ruler_width = 3,
    ruler_interval = 1000,
    width_multiplier = 4,
    minimap_width = 20,
  })

  local result = ruler.render(source_lines(1000))

  MiniTest.expect.equality(result[250], " 1k")
end

T["render"]["keeps shortened large labels unique"] = function()
  local ruler = fresh_ruler({
    show_ruler = true,
    ruler_width = 3,
    ruler_interval = 32,
    width_multiplier = 4,
    minimap_width = 20,
  })

  local result = ruler.render(source_lines(2100))

  MiniTest.expect.equality(result[504], "2.02k")
  MiniTest.expect.equality(result[512], "2.05k")
  MiniTest.expect.equality(result[520], "2.08k")
end

T["render"]["uses configured tick intervals"] = function()
  local ruler = fresh_ruler({
    show_ruler = true,
    ruler_width = 3,
    ruler_interval = 30,
    ruler_tick_interval = 10,
    width_multiplier = 4,
    minimap_width = 20,
  })

  local result = ruler.render(source_lines(40))

  MiniTest.expect.equality(result[3], "  .")
  MiniTest.expect.equality(result[5], "  .")
  MiniTest.expect.equality(result[8], " 30")
end

return T
