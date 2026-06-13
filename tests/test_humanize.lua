---@diagnostic disable: undefined-global

local T = MiniTest.new_set()

local function fresh_humanize()
  package.loaded["codewindow.humanize"] = nil
  return require("codewindow.humanize")
end

T["line_number_labels"] = MiniTest.new_set()

T["line_number_labels"]["keeps exact thousands compact"] = function()
  local labels, width = fresh_humanize().line_number_labels({ 1, 1000 }, 3)

  MiniTest.expect.equality(width, 3)
  MiniTest.expect.equality(labels, { "  1", " 1k" })
end

T["line_number_labels"]["uses decimals for non-exact thousands"] = function()
  local labels, width = fresh_humanize().line_number_labels({ 2100 }, 3)

  MiniTest.expect.equality(width, 4)
  MiniTest.expect.equality(labels, { "2.1k" })
end

T["line_number_labels"]["adds enough decimal precision to stay unique"] = function()
  local labels, width = fresh_humanize().line_number_labels({ 2016, 2048, 2080 }, 3)

  MiniTest.expect.equality(width, 5)
  MiniTest.expect.equality(labels, { "2.02k", "2.05k", "2.08k" })
end

T["line_number_labels"]["supports wider decimal labels"] = function()
  local labels, width = fresh_humanize().line_number_labels({ 22310, 22320 }, 3)

  MiniTest.expect.equality(width, 6)
  MiniTest.expect.equality(labels, { "22.31k", "22.32k" })
end

return T
