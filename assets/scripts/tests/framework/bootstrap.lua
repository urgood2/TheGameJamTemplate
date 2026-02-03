-- bootstrap.lua - Entry point for test mode
-- This file is loaded by the engine when --test-mode is set

local test_runner = require('tests.framework.test_runner')
local discovery = require('tests.framework.discovery')
local assertions = require('tests.framework.assertions')
local reporters = {
  json = require('tests.framework.reporters.json'),
  junit = require('tests.framework.reporters.junit'),
  tap = require('tests.framework.reporters.tap'),
}

-- Make assertions global for tests
_G.assert = setmetatable(assertions, { __index = _G.assert })

-- TODO: Initialize test harness from C++ bindings
-- TODO: Discover and load tests
-- TODO: Run tests
-- TODO: Generate reports

print('TODO: Implement test bootstrap')

return {
  test_runner = test_runner,
  discovery = discovery,
  assertions = assertions,
  reporters = reporters,
}
