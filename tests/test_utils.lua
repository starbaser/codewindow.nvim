---@diagnostic disable: undefined-global

local T = MiniTest.new_set()

local function fresh_utils(overrides)
  package.loaded["codewindow.config"] = nil
  package.loaded["codewindow.utils"] = nil
  local config = {
    width_multiplier = 4,
    minimap_width = 20,
    show_ruler = true,
    ruler_side = "right",
    ruler_width = 3,
    ruler_gap = 1,
  }
  for key, value in pairs(overrides or {}) do
    config[key] = value
  end
  package.loaded["codewindow.config"] = {
    get = function()
      return config
    end,
  }
  return require("codewindow.utils")
end

local utils = fresh_utils()

T["flag_to_char"] = MiniTest.new_set()

T["flag_to_char"]["flag 0 is blank braille"] = function()
  local ch = utils.flag_to_char(0)
  MiniTest.expect.equality(#ch, 3)
  MiniTest.expect.equality(ch, "\xe2\xa0\x80")
end

T["flag_to_char"]["flag 255 is full braille"] = function()
  MiniTest.expect.equality(utils.flag_to_char(255), "\xe2\xa3\xbf")
end

T["flag_to_char"]["flag 1 maps to dot 1"] = function()
  MiniTest.expect.equality(utils.flag_to_char(1), "\xe2\xa0\x81")
end

T["flag_to_char"]["all flags produce 3-byte chars"] = function()
  for i = 0, 255 do
    MiniTest.expect.equality(#utils.flag_to_char(i), 3)
  end
end

T["buf_to_minimap"] = MiniTest.new_set()

T["buf_to_minimap"]["col 1 row 1 maps to (1,1)"] = function()
  local mx, my = utils.buf_to_minimap(1, 1)
  MiniTest.expect.equality(mx, 1)
  MiniTest.expect.equality(my, 1)
end

T["buf_to_minimap"]["4 rows collapse to minimap row 1"] = function()
  local _, my1 = utils.buf_to_minimap(1, 1)
  local _, my4 = utils.buf_to_minimap(1, 4)
  MiniTest.expect.equality(my1, my4)
end

T["buf_to_minimap"]["row 5 maps to minimap row 2"] = function()
  local _, my = utils.buf_to_minimap(1, 5)
  MiniTest.expect.equality(my, 2)
end

T["buf_to_minimap"]["8 source cols collapse to 1 minimap col"] = function()
  local mx1, _ = utils.buf_to_minimap(1, 1)
  local mx8, _ = utils.buf_to_minimap(8, 1)
  MiniTest.expect.equality(mx1, mx8)
end

T["buf_to_minimap"]["col 9 maps to minimap col 2"] = function()
  local mx, _ = utils.buf_to_minimap(9, 1)
  MiniTest.expect.equality(mx, 2)
end

T["layout"] = MiniTest.new_set()

T["layout"]["window width includes ruler width"] = function()
  local current_utils = fresh_utils()
  MiniTest.expect.equality(current_utils.window_width(), 28)
end

T["layout"]["ruler can be disabled"] = function()
  local current_utils = fresh_utils({ show_ruler = false })
  MiniTest.expect.equality(current_utils.ruler_width(), 0)
  MiniTest.expect.equality(current_utils.window_width(), 24)
end

T["layout"]["content starts after diagnostics and ruler"] = function()
  local current_utils = fresh_utils({ ruler_side = "left", ruler_width = 3, ruler_gap = 1 })
  MiniTest.expect.equality(current_utils.content_start_byte(), 10)
  MiniTest.expect.equality(current_utils.minimap_col_start_byte(2), 13)
  MiniTest.expect.equality(current_utils.git_start_byte(), 70)
  MiniTest.expect.equality(current_utils.ruler_start_byte(), 6)
end

T["layout"]["right ruler does not shift minimap content"] = function()
  local current_utils = fresh_utils({ ruler_width = 3, ruler_gap = 1 })
  MiniTest.expect.equality(current_utils.content_start_byte(), 6)
  MiniTest.expect.equality(current_utils.minimap_col_start_byte(2), 9)
  MiniTest.expect.equality(current_utils.git_start_byte(), 66)
  MiniTest.expect.equality(current_utils.ruler_start_byte(), 73)
end

return T
