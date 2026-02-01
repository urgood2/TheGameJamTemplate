-- assets/scripts/tests/run_descent_tests.lua
--[[
================================================================================
DESCENT TEST RUNNER
================================================================================
In-engine test runner for Descent (roguelike) mode tests.
Designed to run with the game engine (not standalone Lua).

Usage (from game engine):
    RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template

Requirements per PLAN.md A2:
    - TestRunner.reset() before loading tests
    - TestRunner.run_all() returns pass/fail
    - Prints seed, test name, summary
    - 15s watchdog timeout
    - Exit 0 on pass, 1 on fail/timeout/module-load-error
    - Works without ENABLE_DESCENT=1

Exit codes:
    0 = All tests passed
    1 = Tests failed, timeout, or module load error
]]

local DescentTestRunner = {}

-- Import the base test runner
local TestRunner = require("tests.test_runner")

-- Configuration
local CONFIG = {
    WATCHDOG_TIMEOUT = 15,  -- seconds (per PLAN.md §5.2)
    TEST_FILE_PATTERN = "test_descent_",
}

-- State
local current_test = nil
local current_module = nil
local start_time = nil
local descent_seed = nil
local watchdog_triggered = false
local module_load_errors = {}

-- ANSI colors (matching test_runner.lua)
local COLORS = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    cyan = "\27[36m",
    dim = "\27[2m",
    bold = "\27[1m",
}

-- Detect if colors are supported
local function supports_colors()
    local term = os.getenv("TERM")
    return term and term ~= "dumb"
end

if not supports_colors() then
    for k in pairs(COLORS) do COLORS[k] = "" end
end

--------------------------------------------------------------------------------
-- Seed Management
--------------------------------------------------------------------------------

--- Get or generate the Descent seed
--- @return number The seed value
local function get_seed()
    if descent_seed then return descent_seed end

    local env_seed = os.getenv("DESCENT_SEED")
    if env_seed then
        local parsed = tonumber(env_seed)
        if parsed and parsed == math.floor(parsed) then
            descent_seed = parsed
        else
            print(COLORS.yellow .. "[DESCENT_TESTS] Warning: Invalid DESCENT_SEED '" ..
                  tostring(env_seed) .. "', generating random seed" .. COLORS.reset)
            descent_seed = os.time()
        end
    else
        descent_seed = os.time()
    end

    return descent_seed
end

--------------------------------------------------------------------------------
-- Watchdog Timer
--------------------------------------------------------------------------------

--- Check if watchdog timeout has been exceeded
--- @return boolean True if timeout exceeded
local function check_watchdog()
    if not start_time then return false end

    local elapsed = os.clock() - start_time
    if elapsed > CONFIG.WATCHDOG_TIMEOUT then
        watchdog_triggered = true
        return true
    end
    return false
end

--- Print watchdog timeout message and prepare for exit
local function handle_watchdog_timeout()
    print("")
    print(COLORS.red .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.red .. COLORS.bold .. "              WATCHDOG TIMEOUT (" .. CONFIG.WATCHDOG_TIMEOUT .. "s)" .. COLORS.reset)
    print(COLORS.red .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print("")
    print(COLORS.yellow .. "  Seed:         " .. COLORS.reset .. tostring(get_seed()))

    if current_module then
        print(COLORS.yellow .. "  Loading:      " .. COLORS.reset .. current_module)
    elseif current_test then
        print(COLORS.yellow .. "  Current test: " .. COLORS.reset .. current_test)
    else
        print(COLORS.yellow .. "  Phase:        " .. COLORS.reset .. "Unknown")
    end

    local elapsed = os.clock() - start_time
    print(COLORS.yellow .. "  Elapsed:      " .. COLORS.reset .. string.format("%.2fs", elapsed))
    print("")
    print(COLORS.red .. "Tests aborted due to timeout" .. COLORS.reset)
    print("")
end

--------------------------------------------------------------------------------
-- Test File Discovery
--------------------------------------------------------------------------------

--- Discover Descent test files
--- @return table Array of test file paths (module names)
local function discover_test_files()
    local test_files = {}

    -- For in-engine use, we manually list test files
    -- This can be expanded to use io.popen with find command if needed
    local known_tests = {
        "tests.test_descent_smoke",
        "tests.test_descent_map",
        "tests.test_descent_combat",
        "tests.test_descent_pathfinding",
        "tests.test_descent_procgen_validation",
        "tests.test_descent_enemy_ai",
        "tests.test_descent_spells",
        "tests.test_descent_rng",
        "tests.test_descent_player",
        "tests.test_descent_endings",
        -- Add more test_descent_*.lua files as they are created
    }

    for _, module_name in ipairs(known_tests) do
        table.insert(test_files, module_name)
    end

    return test_files
end

--------------------------------------------------------------------------------
-- Test Execution
--------------------------------------------------------------------------------

--- Load a test module safely
--- @param module_name string The module to load
--- @return boolean Success
--- @return string|nil Error message if failed
local function safe_require(module_name)
    current_module = module_name

    -- Check watchdog before loading
    if check_watchdog() then
        return false, "Watchdog timeout during module load"
    end

    local ok, result = pcall(require, module_name)
    current_module = nil

    if not ok then
        return false, tostring(result)
    end

    return true, nil
end

--- Reset the test runner state
function DescentTestRunner.reset()
    TestRunner.reset()
    current_test = nil
    current_module = nil
    start_time = nil
    descent_seed = nil
    watchdog_triggered = false
    module_load_errors = {}
end

--- Run all Descent tests
--- @return boolean True if all tests passed
function DescentTestRunner.run_all()
    start_time = os.clock()
    local seed = get_seed()

    -- Print header
    print("")
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. COLORS.bold .. "                    DESCENT TEST RUNNER" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print("")
    print(COLORS.yellow .. "  Seed:    " .. COLORS.reset .. tostring(seed))
    print(COLORS.yellow .. "  Timeout: " .. COLORS.reset .. CONFIG.WATCHDOG_TIMEOUT .. "s")
    print("")

    -- Discover test files
    local test_files = discover_test_files()
    print(COLORS.cyan .. "  Found " .. #test_files .. " test file(s)" .. COLORS.reset)
    print("")

    -- Load all test files
    for _, module_name in ipairs(test_files) do
        print(COLORS.dim .. "  Loading: " .. module_name .. COLORS.reset)

        local ok, err = safe_require(module_name)
        if not ok then
            print(COLORS.red .. "  FAILED to load: " .. module_name .. COLORS.reset)
            print(COLORS.red .. "    Error: " .. tostring(err) .. COLORS.reset)
            table.insert(module_load_errors, {
                module = module_name,
                error = err,
            })
        end

        -- Check watchdog after each module load
        if check_watchdog() then
            handle_watchdog_timeout()
            return false
        end
    end

    -- If any module failed to load, report and fail
    if #module_load_errors > 0 then
        print("")
        print(COLORS.red .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
        print(COLORS.red .. "                    MODULE LOAD FAILURES" .. COLORS.reset)
        print(COLORS.red .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
        for i, err_info in ipairs(module_load_errors) do
            print("")
            print(COLORS.red .. i .. ") " .. err_info.module .. COLORS.reset)
            print(COLORS.dim .. "   " .. tostring(err_info.error) .. COLORS.reset)
        end
        print("")
        print(COLORS.red .. "Tests aborted due to module load failures" .. COLORS.reset)
        print(COLORS.yellow .. "  Seed: " .. COLORS.reset .. tostring(seed))
        return false
    end

    print("")

    -- Run all loaded tests
    local success = TestRunner.run()

    -- Check watchdog one more time
    if check_watchdog() then
        handle_watchdog_timeout()
        return false
    end

    -- Print final summary with seed
    local elapsed = os.clock() - start_time
    local results = TestRunner.get_results()

    print("")
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. "                    DESCENT TEST SUMMARY" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print("")
    print(COLORS.yellow .. "  Seed:    " .. COLORS.reset .. tostring(seed))
    print(COLORS.yellow .. "  Passed:  " .. COLORS.reset .. COLORS.green .. results.passed .. COLORS.reset)
    print(COLORS.yellow .. "  Failed:  " .. COLORS.reset .. (results.failed > 0 and COLORS.red or "") .. results.failed .. COLORS.reset)
    print(COLORS.yellow .. "  Skipped: " .. COLORS.reset .. results.skipped)
    print(COLORS.yellow .. "  Time:    " .. COLORS.reset .. string.format("%.2fs", elapsed))
    print("")

    if success then
        print(COLORS.green .. COLORS.bold .. "✓ All Descent tests passed!" .. COLORS.reset)
    else
        print(COLORS.red .. COLORS.bold .. "✗ Some Descent tests failed" .. COLORS.reset)
    end
    print("")

    return success
end

--- Get the current seed
--- @return number The active seed
function DescentTestRunner.get_seed()
    return get_seed()
end

--- Check if watchdog was triggered
--- @return boolean True if watchdog timeout occurred
function DescentTestRunner.watchdog_triggered()
    return watchdog_triggered
end

--- Manually set current test name (called by test runner hooks)
--- @param name string Test name
function DescentTestRunner.set_current_test(name)
    current_test = name
end

return DescentTestRunner
