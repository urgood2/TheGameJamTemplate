-- assets/scripts/tests/test_descent_smoke.lua
--[[
================================================================================
DESCENT SMOKE TESTS
================================================================================
Basic sanity tests for the Descent test framework itself.
These tests verify that the test runner and basic infrastructure work correctly.

These tests should pass even before any Descent gameplay code exists.
]]

local t = require("tests.test_runner")

t.describe("Descent Smoke Tests", function()
    t.describe("Test Runner Infrastructure", function()
        t.it("should load the test runner module", function()
            local runner = require("tests.run_descent_tests")
            t.expect(runner).to_be_truthy()
            t.expect(type(runner.reset)).to_be("function")
            t.expect(type(runner.run_all)).to_be("function")
        end)

        t.it("should have a valid seed", function()
            local runner = require("tests.run_descent_tests")
            local seed = runner.get_seed()
            t.expect(seed).to_be_truthy()
            t.expect(type(seed)).to_be("number")
            t.expect(seed).to_be(math.floor(seed))  -- Must be integer
        end)
    end)

    t.describe("Environment Variables", function()
        t.it("should detect RUN_DESCENT_TESTS environment variable", function()
            local run_tests = os.getenv("RUN_DESCENT_TESTS")
            -- This test only runs when RUN_DESCENT_TESTS=1, so it should be "1"
            t.expect(run_tests).to_be("1")
        end)

        t.it("should read DESCENT_SEED if provided", function()
            local seed_env = os.getenv("DESCENT_SEED")
            -- DESCENT_SEED is optional, so just verify we can read it
            if seed_env then
                local parsed = tonumber(seed_env)
                t.expect(parsed).to_be_truthy()
            end
            -- No assertion if not set - that's valid
        end)
    end)

    t.describe("Basic Lua Environment", function()
        t.it("should have os.clock for timing", function()
            t.expect(type(os.clock)).to_be("function")
            local start = os.clock()
            t.expect(type(start)).to_be("number")
        end)

        t.it("should have os.getenv for environment access", function()
            t.expect(type(os.getenv)).to_be("function")
        end)

        t.it("should have pcall for error handling", function()
            t.expect(type(pcall)).to_be("function")

            -- Test pcall works correctly
            local ok, err = pcall(function()
                error("test error")
            end)
            t.expect(ok).to_be(false)
            t.expect(tostring(err)).to_contain("test error")
        end)
    end)

    t.describe("Math Functions", function()
        t.it("should have math.floor", function()
            t.expect(math.floor(3.7)).to_be(3)
            t.expect(math.floor(-1.2)).to_be(-2)
        end)

        t.it("should have math.random (for seed verification)", function()
            -- Note: Descent code should NOT use math.random directly
            -- This just verifies the function exists for the test framework
            t.expect(type(math.random)).to_be("function")
        end)
    end)
end)
