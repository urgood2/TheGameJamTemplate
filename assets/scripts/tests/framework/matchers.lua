-- matchers.lua
-- Optional error formatting helpers
-- TODO: Implement matcher utilities

local M = {}

--- Format a mismatch message
-- @param expected any
-- @param actual any
function M.format_mismatch(expected, actual)
  return 'Expected ' .. tostring(expected) .. ' but got ' .. tostring(actual)
end

return M
