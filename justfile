# Run all tests
test:
  nvim --headless -u tests/minimal_init.lua \
    -c "lua MiniTest.run({ collect = { find_files = function() return vim.fn.globpath('tests', 'test_*.lua', true, true) end } })"

# Run a single test file
test-file FILE:
  nvim --headless -u tests/minimal_init.lua \
    -c "lua MiniTest.run_file('{{FILE}}')"

# Watch mode — reruns tests on any .lua change
watch:
  watchexec -e lua -w lua -w tests -- just test

# Format all lua files
format:
  stylua lua/ plugin/ tests/

# Check formatting without modifying
check:
  stylua --check lua/ plugin/ tests/
