-- assertions.lua
-- Assertion helpers for tests
-- TODO: Implement rich assertion functions

local M = {}

--- Assert that a value is truthy
-- @param value any
-- @param message string|nil
function M.truthy(value, message)
  if not value then
    error(message or 'Expected value to be truthy')
  end
end

--- Assert that two values are equal
-- @param expected any
-- @param actual any
-- @param message string|nil
function M.equals(expected, actual, message)
  if expected ~= actual then
    error(message or ('Expected ' .. tostring(expected) .. ' but got ' .. tostring(actual)))
  end
end

return M
