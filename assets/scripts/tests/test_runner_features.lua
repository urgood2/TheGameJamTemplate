-- assets/scripts/tests/test_runner_features.lua
--[[
Tests for test runner advanced features:
- Filtering by name pattern
- Verbose mode
- Timing statistics
- Summary counts
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Test Filtering
--------------------------------------------------------------------------------

t.describe("Test Runner Filtering", function()
    t.it("should have set_filter method", function()
        t.expect(t.set_filter).to_be_type("function")
    end)

    t.it("should have get_filter method", function()
        t.expect(t.get_filter).to_be_type("function")
    end)

    t.it("should allow setting and getting filter", function()
        t.set_filter("example")
        t.expect(t.get_filter()).to_be("example")
        t.set_filter(nil) -- Clear filter
        t.expect(t.get_filter()).to_be_nil()
    end)

    t.it("should have configure method", function()
        t.expect(t.configure).to_be_type("function")
    end)

    t.it("should allow configuring multiple options at once", function()
        t.configure({ filter = "test", verbose = true })
        t.expect(t.get_filter()).to_be("test")
        t.expect(t.is_verbose()).to_be(true)
        -- Reset
        t.configure({ filter = nil, verbose = false })
    end)
end)

--------------------------------------------------------------------------------
-- Verbose Mode
--------------------------------------------------------------------------------

t.describe("Test Runner Verbose Mode", function()
    t.it("should have set_verbose method", function()
        t.expect(t.set_verbose).to_be_type("function")
    end)

    t.it("should have is_verbose method", function()
        t.expect(t.is_verbose).to_be_type("function")
    end)

    t.it("should toggle verbose mode", function()
        t.set_verbose(true)
        t.expect(t.is_verbose()).to_be(true)
        t.set_verbose(false)
        t.expect(t.is_verbose()).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Timing Statistics
--------------------------------------------------------------------------------

t.describe("Test Runner Timing", function()
    t.it("should have set_timing method", function()
        t.expect(t.set_timing).to_be_type("function")
    end)

    t.it("should have get_results method", function()
        t.expect(t.get_results).to_be_type("function")
    end)

    t.it("should have get_timings method", function()
        t.expect(t.get_timings).to_be_type("function")
    end)

    t.it("should return results with timing fields", function()
        local results = t.get_results()
        t.expect(results).to_be_type("table")
        t.expect(results.timings).to_be_type("table")
        t.expect(results.total_time).to_be_type("number")
    end)
end)

--------------------------------------------------------------------------------
-- Summary Counts
--------------------------------------------------------------------------------

t.describe("Test Runner Summary Counts", function()
    t.it("should track passed count", function()
        local results = t.get_results()
        t.expect(results.passed).to_be_type("number")
    end)

    t.it("should track failed count", function()
        local results = t.get_results()
        t.expect(results.failed).to_be_type("number")
    end)

    t.it("should track skipped count", function()
        local results = t.get_results()
        t.expect(results.skipped).to_be_type("number")
    end)

    t.it("should track errors array", function()
        local results = t.get_results()
        t.expect(results.errors).to_be_type("table")
    end)
end)

--------------------------------------------------------------------------------
-- Watch Mode
--------------------------------------------------------------------------------

t.describe("Test Runner Watch Mode", function()
    t.it("should have watch method", function()
        t.expect(t.watch).to_be_type("function")
    end)
end)

--------------------------------------------------------------------------------
-- Reset Functionality
--------------------------------------------------------------------------------

t.describe("Test Runner Reset", function()
    t.it("should have reset method", function()
        t.expect(t.reset).to_be_type("function")
    end)

    t.it("should clear filter and verbose on reset", function()
        t.set_filter("something")
        t.set_verbose(true)
        t.reset()
        t.expect(t.get_filter()).to_be_nil()
        t.expect(t.is_verbose()).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
