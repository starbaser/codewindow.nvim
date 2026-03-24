# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

codewindow.nvim is a Neovim minimap plugin that renders buffer content as braille characters in a floating window, with treesitter syntax highlighting, LSP diagnostic indicators, and git diff markers.

## Development

- **Language**: Lua (Neovim plugin, no build step)
- **Formatter**: StyLua (config in `.stylua.toml` — indent: tabs, width: 120, collapse simple statements: never)
- **No tests or CI** — manual testing in Neovim
- **Linting**: `stylua --check lua/` to verify formatting; `stylua lua/` to fix

## Architecture

Single minimap instance managed via module-level state in `window.lua`. One floating window anchored to the right of the active window.

### Module Dependency Graph

```
codewindow.lua            public API / entry point
    │
    ├── window.lua         floating window lifecycle, autocmds, scroll sync
    ├── text.lua           orchestrates minimap updates (the main pipeline)
    └── highlight.lua      treesitter highlight extraction + all namespace management
         │
         ├── errors.lua    LSP diagnostics → braille bit-flags
         ├── git.lua       git diff → braille bit-flags
         └── utils.lua     braille char table, coordinate math, scroll helpers

config.lua                 singleton config table (no deps, imported by all)
stopwatch.lua              dev-only perf utility (unused in production)
```

### Minimap Update Pipeline

`text.update_minimap()` is the core render path, triggered by autocmds:

1. `compress_text(lines)` — buffer text → braille chars (2 cols × 4 rows per braille cell)
2. `errors.get_lsp_errors()` — diagnostics → 2-char braille column (error + warn)
3. `git.parse_git_diff()` — `git diff -U0` output → 2-char braille column (adds + deletes)
4. Assemble rows: `[err|warn] [minimap_width braille chars] [add|del]`
5. Write to minimap buffer
6. `highlight.extract_highlighting()` → `highlight.apply_highlight()` — treesitter captures to highlight namespaces
7. `highlight.display_cursor()` + `highlight.display_screen_bounds()` — viewport indicators

### Braille Encoding

Each braille Unicode character encodes a 2×4 grid of dots. The 256-character lookup table in `utils.lua` maps an 8-bit flag to the corresponding braille character. `coord_to_flag(x, y)` computes the bit: `2^(y%4)` for even columns, `2^(y%4) * 16` for odd columns.

### Minimap Row Layout

```
[err][warn][...minimap_width braille chars...][add][del]
 3B   3B        minimap_width × 3 bytes        3B   3B
```

Floating window width = `minimap_width + 4` chars (2 diagnostic + 2 git side columns).

### Key Design Details

- `window.lua` holds a single module-level `window` table — only one minimap exists at a time
- Treesitter integration is resolved at module load time: real `extract_highlighting` or no-op depending on `config.use_treesitter`
- `config.get()` returns the table by reference — modules cache the reference at load time
- Highlight groups: `CodewindowBorder`, `CodewindowBackground`, `CodewindowWarn`, `CodewindowError`, `CodewindowAddition`, `CodewindowDeletion`, `CodewindowUnderline`, `CodewindowBoundsBackground`
- Four namespaces created in `highlight.setup()`: `codewindow.highlight`, `codewindow.screenbounds`, `codewindow.diagnostic`, `codewindow.cursor`
