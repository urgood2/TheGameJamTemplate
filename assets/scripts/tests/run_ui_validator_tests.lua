--[[
================================================================================
UI VALIDATOR TESTS - IN-GAME TEST RUNNER
================================================================================
Runs all UIValidator-related tests.

Run in-game by calling:
    require("tests.run_ui_validator_tests").run()

Or set RUN_UI_VALIDATOR_TESTS=1 environment variable.
]]

local test = {}

local TestRunner = require("tests.test_runner")

function test.run()
    print("\n================================================================================")
    print("UI VALIDATOR TESTS")
    print("================================================================================\n")

    -- Reset test runner state
    TestRunner.reset()

    -- Load and register all UIValidator tests
    print("Loading test_ui_validator.lua...")
    local ok1, err1 = pcall(require, "tests.test_ui_validator")
    if not ok1 then
        print("[ERROR] Failed to load test_ui_validator: " .. tostring(err1))
    end

    print("Loading test_inventory_validation.lua...")
    local ok2, err2 = pcall(require, "tests.test_inventory_validation")
    if not ok2 then
        print("[ERROR] Failed to load test_inventory_validation: " .. tostring(err2))
    end

    -- Run all registered tests
    print("\nRunning tests...\n")
    local success = TestRunner.run_all()

    print("\n================================================================================")
    if success then
        print("ALL TESTS PASSED!")
    else
        print("SOME TESTS FAILED - see output above")
    end
    print("================================================================================\n")

    return success
end

return test
