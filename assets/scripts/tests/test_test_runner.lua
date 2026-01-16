--[[
================================================================================
TEST: tests/test_runner.lua
================================================================================
Self-test for the test runner framework.

Run standalone: lua assets/scripts/tests/test_test_runner.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

-- Reset to clear any previous state
t.reset()

--------------------------------------------------------------------------------
-- Test Suite: describe/it Structure
--------------------------------------------------------------------------------

t.describe("describe/it Structure", function()
    t.it("should register tests inside describe blocks", function()
        -- This test existing proves it works
        t.assert_true(true)
    end)

    t.it("should pass with successful assertions", function()
        t.assert_equals(1, 1)
        t.assert_true(true)
        t.assert_false(false)
        t.assert_nil(nil)
        t.assert_not_nil("value")
    end)
end)

--------------------------------------------------------------------------------
-- Test Suite: Assertions
--------------------------------------------------------------------------------

t.describe("Assertions", function()
    t.it("assert_equals compares values correctly", function()
        t.assert_equals(42, 42)
        t.assert_equals("hello", "hello")
        t.assert_equals(nil, nil)
    end)

    t.it("assert_true checks truthy values", function()
        t.assert_true(true)
        t.assert_true(1)
        t.assert_true("string")
        t.assert_true({})
    end)

    t.it("assert_false checks falsy values", function()
        t.assert_false(false)
        t.assert_false(nil)
    end)

    t.it("assert_nil checks nil values", function()
        t.assert_nil(nil)
        local x
        t.assert_nil(x)
    end)

    t.it("assert_not_nil checks non-nil values", function()
        t.assert_not_nil(1)
        t.assert_not_nil("")
        t.assert_not_nil(false)  -- false is not nil
    end)

    t.it("assert_table_contains checks table keys", function()
        local tbl = { foo = 1, bar = "baz" }
        t.assert_table_contains(tbl, "foo")
        t.assert_table_contains(tbl, "bar")
    end)

    t.it("assert_throws catches expected errors", function()
        t.assert_throws(function()
            error("expected error")
        end)

        t.assert_throws(function()
            error("specific message")
        end, "specific")
    end)

    t.it("assert_deep_equals compares tables recursively", function()
        t.assert_deep_equals({ a = 1 }, { a = 1 })
        t.assert_deep_equals({ nested = { x = 10 } }, { nested = { x = 10 } })
        t.assert_deep_equals({}, {})
    end)
end)

--------------------------------------------------------------------------------
-- Test Suite: before_each / after_each
--------------------------------------------------------------------------------

t.describe("Setup/Teardown Hooks", function()
    local counter = 0

    t.before_each(function()
        counter = counter + 1
    end)

    t.after_each(function()
        -- Just verify it doesn't crash
    end)

    t.it("runs before_each before first test", function()
        t.assert_equals(1, counter)
    end)

    t.it("runs before_each before second test", function()
        t.assert_equals(2, counter)
    end)

    t.it("runs before_each before third test", function()
        t.assert_equals(3, counter)
    end)
end)

--------------------------------------------------------------------------------
-- Test Suite: Skip tests
--------------------------------------------------------------------------------

t.describe("Skipped Tests", function()
    t.it("normal test runs", function()
        t.assert_true(true)
    end)

    t.xit("skipped test is not executed", function()
        -- This would fail if run
        error("This should not run!")
    end)

    t.it("tests after skipped test still run", function()
        t.assert_true(true)
    end)
end)

--------------------------------------------------------------------------------
-- Test Suite: Nested describe blocks
--------------------------------------------------------------------------------

t.describe("Nested Describe Blocks", function()
    t.describe("Inner Suite A", function()
        t.it("can define tests in nested blocks", function()
            t.assert_true(true)
        end)
    end)

    t.describe("Inner Suite B", function()
        t.it("multiple nested suites work", function()
            t.assert_equals(1 + 1, 2)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Test Suite: Error Messages
--------------------------------------------------------------------------------

t.describe("Error Message Quality", function()
    t.it("assert_equals shows expected and actual values", function()
        local ok, err = pcall(function()
            t.assert_equals(1, 2, "Custom message")
        end)
        t.assert_false(ok, "Should have failed")
        t.assert_true(tostring(err):find("expected"), "Should include 'expected'")
        t.assert_true(tostring(err):find("actual"), "Should include 'actual'")
        t.assert_true(tostring(err):find("Custom message"), "Should include custom message")
    end)

    t.it("assert_throws shows pattern when not matched", function()
        local ok, err = pcall(function()
            t.assert_throws(function()
                error("wrong error")
            end, "specific pattern")
        end)
        t.assert_false(ok, "Should have failed")
        t.assert_true(tostring(err):find("did not match pattern"), "Should explain pattern mismatch")
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Always run - this file is designed to be run directly
local success = t.run()
os.exit(success and 0 or 1)
