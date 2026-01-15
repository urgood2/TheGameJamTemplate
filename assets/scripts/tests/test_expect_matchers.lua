-- assets/scripts/tests/test_expect_matchers.lua
--[[
Tests for the expect() fluent matcher API.

Run standalone: lua assets/scripts/tests/test_expect_matchers.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

-- Reset to clear any previous state
t.reset()

--------------------------------------------------------------------------------
-- to_be() - Strict Equality
--------------------------------------------------------------------------------

t.describe("expect().to_be()", function()
    t.it("passes when values are equal", function()
        t.expect(1).to_be(1)
        t.expect("hello").to_be("hello")
        t.expect(true).to_be(true)
        t.expect(nil).to_be(nil)
    end)

    t.it("fails when values are not equal", function()
        t.expect(function()
            t.expect(1).to_be(2)
        end).to_throw("expected")
    end)

    t.it("shows expected vs actual in error message", function()
        local ok, err = pcall(function()
            t.expect(42).to_be(100)
        end)
        t.expect(ok).to_be(false)
        t.expect(tostring(err)).to_contain("expected")
        t.expect(tostring(err)).to_contain("actual")
        t.expect(tostring(err)).to_contain("100")
        t.expect(tostring(err)).to_contain("42")
    end)

    t.it("supports negation with .never()", function()
        t.expect(1).never().to_be(2)
        t.expect("a").never().to_be("b")
    end)
end)

--------------------------------------------------------------------------------
-- to_equal() - Deep Table Equality
--------------------------------------------------------------------------------

t.describe("expect().to_equal()", function()
    t.it("passes for identical tables", function()
        t.expect({a = 1, b = 2}).to_equal({a = 1, b = 2})
        t.expect({1, 2, 3}).to_equal({1, 2, 3})
        t.expect({nested = {deep = true}}).to_equal({nested = {deep = true}})
    end)

    t.it("fails when tables differ", function()
        t.expect(function()
            t.expect({a = 1}).to_equal({a = 2})
        end).to_throw("deeply equal")
    end)

    t.it("fails when keys are missing", function()
        t.expect(function()
            t.expect({a = 1}).to_equal({a = 1, b = 2})
        end).to_throw("deeply equal")  -- Reports type mismatch (number vs nil) for missing key
    end)

    t.it("fails on type mismatch", function()
        t.expect(function()
            t.expect({a = "1"}).to_equal({a = 1})
        end).to_throw("type mismatch")
    end)

    t.it("supports negation", function()
        t.expect({a = 1}).never().to_equal({a = 2})
    end)
end)

--------------------------------------------------------------------------------
-- to_contain() - String/Table Containment
--------------------------------------------------------------------------------

t.describe("expect().to_contain()", function()
    t.describe("strings", function()
        t.it("passes when substring exists", function()
            t.expect("hello world").to_contain("world")
            t.expect("abc").to_contain("b")
        end)

        t.it("fails when substring is missing", function()
            t.expect(function()
                t.expect("hello").to_contain("xyz")
            end).to_throw("contain")
        end)

        t.it("supports negation", function()
            t.expect("hello").never().to_contain("xyz")
        end)
    end)

    t.describe("tables (arrays)", function()
        t.it("passes when element exists", function()
            t.expect({1, 2, 3}).to_contain(2)
            t.expect({"a", "b", "c"}).to_contain("b")
        end)

        t.it("fails when element is missing", function()
            t.expect(function()
                t.expect({1, 2, 3}).to_contain(5)
            end).to_throw("contain")
        end)
    end)

    t.describe("tables (keys)", function()
        t.it("passes when key exists", function()
            t.expect({foo = "bar"}).to_contain("foo")
        end)

        t.it("fails when key is missing", function()
            t.expect(function()
                t.expect({foo = "bar"}).to_contain("baz")
            end).to_throw("contain")
        end)
    end)
end)

--------------------------------------------------------------------------------
-- to_be_truthy() / to_be_falsy()
--------------------------------------------------------------------------------

t.describe("expect().to_be_truthy()", function()
    t.it("passes for truthy values", function()
        t.expect(true).to_be_truthy()
        t.expect(1).to_be_truthy()
        t.expect("string").to_be_truthy()
        t.expect({}).to_be_truthy()
        t.expect(0).to_be_truthy()  -- 0 is truthy in Lua!
    end)

    t.it("fails for falsy values", function()
        t.expect(function()
            t.expect(nil).to_be_truthy()
        end).to_throw("truthy")

        t.expect(function()
            t.expect(false).to_be_truthy()
        end).to_throw("truthy")
    end)

    t.it("supports negation", function()
        t.expect(nil).never().to_be_truthy()
        t.expect(false).never().to_be_truthy()
    end)
end)

t.describe("expect().to_be_falsy()", function()
    t.it("passes for falsy values", function()
        t.expect(nil).to_be_falsy()
        t.expect(false).to_be_falsy()
    end)

    t.it("fails for truthy values", function()
        t.expect(function()
            t.expect(true).to_be_falsy()
        end).to_throw("falsy")

        t.expect(function()
            t.expect(1).to_be_falsy()
        end).to_throw("falsy")
    end)

    t.it("supports negation", function()
        t.expect(true).never().to_be_falsy()
        t.expect(1).never().to_be_falsy()
    end)
end)

--------------------------------------------------------------------------------
-- to_throw() - Error Checking
--------------------------------------------------------------------------------

t.describe("expect().to_throw()", function()
    t.it("passes when function throws", function()
        t.expect(function()
            error("something went wrong")
        end).to_throw()
    end)

    t.it("passes when error matches pattern", function()
        t.expect(function()
            error("validation error: invalid email")
        end).to_throw("validation")

        t.expect(function()
            error("validation error: invalid email")
        end).to_throw("invalid email")
    end)

    t.it("fails when function does not throw", function()
        t.expect(function()
            t.expect(function() return 1 end).to_throw()
        end).to_throw("did not throw")
    end)

    t.it("fails when error does not match pattern", function()
        t.expect(function()
            t.expect(function()
                error("wrong error")
            end).to_throw("expected pattern")
        end).to_throw("match pattern")
    end)

    t.it("requires a function argument", function()
        t.expect(function()
            t.expect("not a function").to_throw()
        end).to_throw("requires a function")
    end)

    t.it("supports negation", function()
        t.expect(function() return 1 end).never().to_throw()
    end)
end)

--------------------------------------------------------------------------------
-- Bonus: to_be_nil() and to_be_type()
--------------------------------------------------------------------------------

t.describe("expect().to_be_nil()", function()
    t.it("passes for nil", function()
        t.expect(nil).to_be_nil()
    end)

    t.it("fails for non-nil", function()
        t.expect(function()
            t.expect(1).to_be_nil()
        end).to_throw("expected nil")
    end)

    t.it("supports negation", function()
        t.expect(1).never().to_be_nil()
    end)
end)

t.describe("expect().to_be_type()", function()
    t.it("passes for correct type", function()
        t.expect(1).to_be_type("number")
        t.expect("hello").to_be_type("string")
        t.expect({}).to_be_type("table")
        t.expect(function() end).to_be_type("function")
        t.expect(nil).to_be_type("nil")
    end)

    t.it("fails for wrong type", function()
        t.expect(function()
            t.expect(1).to_be_type("string")
        end).to_throw("expected type string")
    end)

    t.it("supports negation", function()
        t.expect(1).never().to_be_type("string")
    end)
end)

--------------------------------------------------------------------------------
-- Error Message Quality
--------------------------------------------------------------------------------

t.describe("Error messages", function()
    t.it("include 'expected' and 'actual' labels", function()
        local ok, err = pcall(function()
            t.expect(5).to_be(10)
        end)
        t.expect(ok).to_be(false)
        local msg = tostring(err)
        t.expect(msg).to_contain("expected")
        t.expect(msg).to_contain("actual")
    end)

    t.it("show the actual value in to_be_truthy failure", function()
        local ok, err = pcall(function()
            t.expect(nil).to_be_truthy()
        end)
        t.expect(ok).to_be(false)
        t.expect(tostring(err)).to_contain("nil")
    end)

    t.it("show pattern vs actual in to_throw mismatch", function()
        local ok, err = pcall(function()
            t.expect(function()
                error("actual error text")
            end).to_throw("expected pattern")
        end)
        t.expect(ok).to_be(false)
        local msg = tostring(err)
        t.expect(msg).to_contain("expected pattern")
        t.expect(msg).to_contain("actual error text")
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
t.reset()
os.exit(success and 0 or 1)
