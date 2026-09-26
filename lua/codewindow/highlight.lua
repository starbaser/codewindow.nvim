local M = {}

local config = require("codewindow.config").get()
local utils = require("codewindow.utils")
local highlighter

local hl_namespace
local screenbounds_namespace
local diagnostic_namespace
local cursor_namespace

local api = vim.api
local highlight_range = vim.highlight.range

function M.setup()
  hl_namespace = api.nvim_create_namespace("codewindow.highlight")
  screenbounds_namespace = api.nvim_create_namespace("codewindow.screenbounds")
  diagnostic_namespace = api.nvim_create_namespace("codewindow.diagnostic")
  cursor_namespace = api.nvim_create_namespace("codewindow.cursor")

  api.nvim_set_hl(0, "CodewindowBackground", { link = "Normal", default = true })
  api.nvim_set_hl(0, "CodewindowBorder", { fg = "#ffffff", default = true })
  api.nvim_set_hl(0, "CodewindowWarn", { link = "DiagnosticSignWarn", default = true })
  api.nvim_set_hl(0, "CodewindowError", { link = "DiagnosticSignError", default = true })
  api.nvim_set_hl(0, "CodewindowAddition", { fg = "#aadb56", default = true })
  api.nvim_set_hl(0, "CodewindowDeletion", { fg = "#fc4c4c", default = true })
  api.nvim_set_hl(0, "CodewindowRuler", { link = "LineNr", default = true })
  api.nvim_set_hl(0, "CodewindowUnderline", { underline = true, sp = "#ffffff", default = true })
  api.nvim_set_hl(0, "CodewindowBoundsBackground", { link = "CursorLine", default = true })

  if config.use_heatmap then
    require("codewindow.heatmap").setup()
  end
end

local function create_hl_namespaces(buffer)
  api.nvim_buf_clear_namespace(buffer, hl_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, screenbounds_namespace, 0, -1)
  api.nvim_buf_clear_namespace(buffer, diagnostic_namespace, 0, -1)
end

local function best_group(votes, weight)
  -- A glyph can use only one color; later query patterns break equal-coverage ties.
  local best, best_count, best_pattern = nil, 0, -1
  for group, score in pairs(votes or {}) do
    local count = score[weight]
    if
      count > best_count
      or (count == best_count and score.pattern > best_pattern)
      or (count == best_count and score.pattern == best_pattern and (best == nil or group < best))
    then
      best, best_count, best_pattern = group, count, score.pattern
    end
  end
  return best, best_pattern
end

local function vote_capture(dot_votes, lines, selected, group, max_col)
  local start_row, start_col, end_row, end_col = unpack(selected.range)
  local width_multiplier = config.width_multiplier

  for row = start_row, math.min(end_row, #lines - 1) do
    local line = lines[row + 1]
    -- Tree-sitter ranges are half-open, with partial columns only on the edge rows.
    local first = row == start_row and start_col or 0
    local last = row == end_row and end_col or #line
    last = math.min(last, #line, max_col)

    for col = first, last - 1 do
      local chr = line:sub(col + 1, col + 1)
      if chr ~= " " and chr ~= "\t" then
        local minimap_x, minimap_y = utils.buf_to_minimap(col + 1, row + 1)
        local dot_index = (row % 4) * 2 + (math.floor(col / width_multiplier) % 2) + 1
        dot_votes[minimap_y] = dot_votes[minimap_y] or {}
        local cells = dot_votes[minimap_y]
        cells[minimap_x] = cells[minimap_x] or {}
        local dots = cells[minimap_x]
        dots[dot_index] = dots[dot_index] or {}
        local dot = dots[dot_index]
        local score = dot[group]
        if score then
          score.bytes = score.bytes + 1
          score.pattern = math.max(score.pattern, selected.pattern)
        else
          dot[group] = { bytes = 1, pattern = selected.pattern }
        end
      end
    end
  end
end

local function extract_highlighting(buffer, lines)
  if not api.nvim_buf_is_valid(buffer) then
    return
  end

  local buf_highlighter = highlighter.active[buffer]

  if buf_highlighter == nil then
    return
  end

  local line_count = #lines
  local minimap_width = config.minimap_width
  local minimap_height = math.ceil(line_count / 4)
  local width_multiplier = config.width_multiplier
  local minimap_char_width = minimap_width * width_multiplier * 2

  -- Score the ink represented by each braille dot, not every byte as a full glyph vote.
  local dot_votes = {}

  buf_highlighter.tree:for_each_tree(function(tstree, tree)
    if not tstree then
      return
    end

    local root = tstree:root()

    local query = buf_highlighter:get_query(tree:lang())

    if not query:query() then
      return
    end

    -- iter_matches also returns fallback captures on nodes with a later, more specific pattern.
    local captures_by_node = {}
    local iter = query:query():iter_matches(root, buf_highlighter.bufnr, 0, line_count + 1)

    for pattern, match in iter do
      for capture, nodes in pairs(match) do
        if query.hl_cache[capture] then
          for _, node in ipairs(nodes) do
            local start_row, start_col, end_row, end_col = vim.treesitter.get_node_range(node)
            local key = table.concat({ start_row, start_col, end_row, end_col }, ":")
            local selected = captures_by_node[key]

            if selected == nil or pattern > selected.pattern then
              selected = {
                pattern = pattern,
                captures = {},
                range = { start_row, start_col, end_row, end_col },
              }
              captures_by_node[key] = selected
            end

            if pattern == selected.pattern then
              selected.captures[capture] = true
            end
          end
        end
      end
    end

    for _, selected in pairs(captures_by_node) do
      for capture in pairs(selected.captures) do
        local group = query._query.captures[capture]
        if group ~= nil then
          vote_capture(dot_votes, lines, selected, group, minimap_char_width)
        end
      end
    end
  end, true)

  local highlights = {}
  for y = 1, minimap_height do
    local row = {}
    for x = 1, minimap_width do
      local groups = {}
      local dots = dot_votes[y] and dot_votes[y][x]
      for _, dot in pairs(dots or {}) do
        local group, pattern = best_group(dot, "bytes")
        if group then
          local score = groups[group]
          if score then
            score.dots = score.dots + 1
            score.pattern = math.max(score.pattern, pattern)
          else
            groups[group] = { dots = 1, pattern = pattern }
          end
        end
      end
      local group = best_group(groups, "dots")
      row[x] = group and { group } or {}
    end
    highlights[y] = row
  end

  return highlights
end

if config.use_treesitter then
  highlighter = require("vim.treesitter.highlighter")
  M.extract_highlighting = extract_highlighting
else
  M.extract_highlighting = function() end
end

function M.apply_highlight(highlights, buffer, lines)
  local minimap_height = math.ceil(#lines / 4)
  local minimap_width = config.minimap_width

  create_hl_namespaces(buffer)

  if config.use_heatmap then
    local heatmap = require("codewindow.heatmap")
    local density = heatmap.compute(lines)
    if density then
      for y = 1, minimap_height do
        for x = 1, minimap_width do
          local level = density[y][x] or 0
          if level > 0 then
            local col_start = utils.minimap_col_start_byte(x)
            api.nvim_buf_add_highlight(
              buffer,
              hl_namespace,
              "CodewindowHeatmap" .. level,
              y - 1,
              col_start,
              col_start + 3
            )
          end
        end
      end
    end
  elseif highlights ~= nil then
    for y = 1, minimap_height do
      local x = 1
      while x <= minimap_width do
        local group = highlights[y][x][1]
        if group and group ~= "" then
          local end_x = x
          while end_x < minimap_width and highlights[y][end_x + 1][1] == group do
            end_x = end_x + 1
          end
          api.nvim_buf_add_highlight(
            buffer,
            hl_namespace,
            "@" .. group,
            y - 1,
            utils.minimap_col_start_byte(x),
            utils.minimap_col_end_byte(end_x)
          )
          x = end_x + 1
        else
          x = x + 1
        end
      end
    end
  end

  for y = 1, minimap_height do
    api.nvim_buf_add_highlight(buffer, diagnostic_namespace, "CodewindowError", y - 1, 0, 3)
    api.nvim_buf_add_highlight(buffer, diagnostic_namespace, "CodewindowWarn", y - 1, 3, 6)

    local ruler_start = utils.ruler_start_byte()
    local ruler_end = utils.ruler_end_byte()
    if ruler_start and ruler_end then
      api.nvim_buf_add_highlight(buffer, diagnostic_namespace, "CodewindowRuler", y - 1, ruler_start, ruler_end)
    end

    local git_start = utils.git_start_byte()
    highlight_range(
      buffer,
      diagnostic_namespace,
      "CodewindowAddition",
      { y - 1, git_start },
      { y - 1, git_start + 3 },
      {}
    )
    highlight_range(
      buffer,
      diagnostic_namespace,
      "CodewindowDeletion",
      { y - 1, git_start + 3 },
      { y - 1, git_start + 6 },
      {}
    )
  end
end

function M.display_screen_bounds(window)
  if screenbounds_namespace == nil then
    return
  end
  api.nvim_buf_clear_namespace(window.buffer, screenbounds_namespace, 0, -1)

  local topline = utils.get_top_line(window.parent_win)
  local botline = utils.get_bot_line(window.parent_win)

  local difference = math.ceil((botline - topline) / 4) + 1

  local top_y = math.floor(topline / 4)

  if top_y > 0 and config.screen_bounds == "lines" then
    api.nvim_buf_add_highlight(
      window.buffer,
      screenbounds_namespace,
      "CodewindowUnderline",
      top_y - 1,
      utils.content_start_byte(),
      utils.content_end_byte()
    )
  end

  local bot_y = top_y + difference - 1
  local buf_height = api.nvim_buf_line_count(window.buffer)

  if bot_y > buf_height - 1 then
    bot_y = buf_height - 1
  end

  if bot_y < 0 then
    return
  end

  if config.screen_bounds == "lines" then
    api.nvim_buf_add_highlight(
      window.buffer,
      screenbounds_namespace,
      "CodewindowUnderline",
      bot_y,
      utils.content_start_byte(),
      utils.content_end_byte()
    )
  end

  if config.screen_bounds == "background" then
    for y = top_y, bot_y do
      api.nvim_buf_add_highlight(
        window.buffer,
        screenbounds_namespace,
        "CodewindowBoundsBackground",
        y,
        utils.content_start_byte(),
        utils.content_end_byte()
      )
    end
  end

  local center = math.floor((top_y + bot_y) / 2) + 1
  if api.nvim_win_is_valid(window.window) then
    api.nvim_win_set_cursor(window.window, { center, 0 })
  end
end

function M.display_cursor(window)
  if not config.show_cursor then
    return
  end

  if api.nvim_buf_is_valid(window.buffer) then
    api.nvim_buf_clear_namespace(window.buffer, cursor_namespace, 0, -1)
  end
  if not api.nvim_win_is_valid(window.parent_win) then
    return
  end
  local cursor = api.nvim_win_get_cursor(window.parent_win)

  local minimap_x, minimap_y = utils.buf_to_minimap(cursor[2] + 1, cursor[1])

  minimap_y = minimap_y - 1

  if api.nvim_buf_is_valid(window.buffer) then
    api.nvim_buf_add_highlight(
      window.buffer,
      cursor_namespace,
      "Cursor",
      minimap_y,
      utils.minimap_col_start_byte(minimap_x),
      utils.minimap_col_end_byte(minimap_x)
    )
  end
end

return M
