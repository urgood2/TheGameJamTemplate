-- test_stubs.lua
-- Verify all stub modules load without error

local function test_require(path)
  local ok, err = pcall(require, path)
  if not ok then
    error('Failed to require ' .. path .. ': ' .. tostring(err))
  end
  print('OK: ' .. path)
end

test_require('tests.framework.bootstrap')
test_require('tests.framework.test_runner')
test_require('tests.framework.discovery')
test_require('tests.framework.assertions')
test_require('tests.framework.matchers')
test_require('tests.framework.actions')
test_require('tests.framework.reporters.json')
test_require('tests.framework.reporters.junit')
test_require('tests.framework.reporters.tap')

print('All stub modules load successfully')

return true
