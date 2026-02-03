-- assets/scripts/core/test/test_runner.lua
--[[
================================================================================
CORE TEST RUNNER WRAPPER
================================================================================
Provides a minimal register() API on top of the existing tests.test_runner
BDD framework so new tests can attach metadata like doc_ids/tags.
]]

local BaseRunner = require("tests.test_runner")

local TestRunner = {
    _registry = {},
}

--- Register a test with metadata and map it onto the base runner.
--- @param test_id string
--- @param category string
--- @param fn function
--- @param meta table|nil
function TestRunner.register(test_id, category, fn, meta)
    table.insert(TestRunner._registry, {
        id = test_id,
        category = category,
        meta = meta or {},
    })

    BaseRunner.describe(category, function()
        BaseRunner.it(test_id, fn)
    end)
end

function TestRunner.get_registry()
    return TestRunner._registry
end

function TestRunner.reset()
    TestRunner._registry = {}
    BaseRunner.reset()
end

function TestRunner.run()
    return BaseRunner.run()
end

function TestRunner.run_all()
    return BaseRunner.run()
end

return TestRunner
