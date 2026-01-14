-- assets/scripts/tests/test_runner.lua
--[[
================================================================================
TEST RUNNER: describe/it Test Framework
================================================================================
A lightweight BDD-style test runner with:
- describe() and it() for test structure
- expect() fluent matchers for expressive assertions
- Clear pass/fail output with colors
- Stack traces for failed assertions
- Directory-based test discovery
- Exit codes (0 = pass, 1 = fail)

Usage:
    local t = require("tests.test_runner")

    t.describe("MyModule", function()
        t.it("should do something", function()
            t.expect(1).to_be(1)
            t.expect({a = 1}).to_equal({a = 1})
            t.expect("hello world").to_contain("world")
            t.expect(true).to_be_truthy()
            t.expect(nil).to_be_falsy()
            t.expect(function() error("oops") end).to_throw("oops")
        end)

        t.it("supports negation with .never()", function()
            t.expect(1).never().to_be(2)
        end)
    end)

    t.run()  -- Returns true if all pass, exits with code 1 on failure

Run all tests in directory:
    lua assets/scripts/tests/test_runner.lua [directory]
]]

local TestRunner = {}

-- State
local suites = {}           -- Registered describe blocks
local current_suite = nil   -- Current suite being defined
local results = { passed = 0, failed = 0, skipped = 0, errors = {} }

-- ANSI colors (disable if not supported)
local COLORS = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    cyan = "\27[36m",
    dim = "\27[2m",
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
-- Stack Trace Formatting
--------------------------------------------------------------------------------

--- Extract meaningful stack trace from error, filtering test runner internals
local function format_stack_trace(err)
    local trace = debug.traceback(err, 3)
    local lines = {}
    local skip_internal = true

    for line in trace:gmatch("[^\n]+") do
        -- Skip test_runner.lua internal frames
        if line:find("test_runner%.lua") then
            skip_internal = true
        elseif line:find("^%s*%[C%]") then
            -- Skip C frames
        elseif line:find("^stack traceback:") then
            table.insert(lines, line)
        else
            -- Include user test code
            if line:find("%.lua:%d+") then
                table.insert(lines, "    " .. line:match("^%s*(.*)$"))
            end
        end
    end

    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Describe / It API
--------------------------------------------------------------------------------

--- Define a test suite (describe block)
--- @param name string Suite name
--- @param fn function Suite definition containing it() calls
function TestRunner.describe(name, fn)
    local suite = {
        name = name,
        tests = {},
        before_each = nil,
        after_each = nil,
    }

    -- Push suite context
    local parent = current_suite
    current_suite = suite

    -- Execute suite definition to collect tests
    local ok, err = pcall(fn)
    if not ok then
        print(COLORS.red .. "[ERROR] Failed to define suite '" .. name .. "': " .. tostring(err) .. COLORS.reset)
    end

    -- Restore parent context
    current_suite = parent

    -- Register suite
    if parent then
        -- Nested suite - add as a test that runs the suite
        table.insert(parent.tests, {
            name = name,
            fn = function() TestRunner._run_suite(suite) end,
            is_suite = true,
        })
    else
        table.insert(suites, suite)
    end
end

--- Define a test case within a describe block
--- @param name string Test description
--- @param fn function Test implementation
function TestRunner.it(name, fn)
    if not current_suite then
        error("it() must be called inside a describe() block")
    end
    table.insert(current_suite.tests, { name = name, fn = fn })
end

--- Define setup to run before each test
--- @param fn function Setup function
function TestRunner.before_each(fn)
    if not current_suite then
        error("before_each() must be called inside a describe() block")
    end
    current_suite.before_each = fn
end

--- Define teardown to run after each test
--- @param fn function Teardown function
function TestRunner.after_each(fn)
    if not current_suite then
        error("after_each() must be called inside a describe() block")
    end
    current_suite.after_each = fn
end

--- Skip a test (marks as skipped in output)
--- @param name string Test description
--- @param fn function Test implementation (not run)
function TestRunner.xit(name, fn)
    if not current_suite then
        error("xit() must be called inside a describe() block")
    end
    table.insert(current_suite.tests, { name = name, fn = fn, skip = true })
end

--------------------------------------------------------------------------------
-- Expect Matchers (Fluent API)
--------------------------------------------------------------------------------

--- Create an expectation object for fluent assertions
--- Usage: expect(value).to_be(expected), expect(fn).to_throw("pattern")
--- @param value any The value to test
--- @return table Expectation object with matcher methods
function TestRunner.expect(value)
    local _value = value
    local _negated = false

    local expectation = {}

    --- Negate the next matcher
    --- @return table Self for chaining
    function expectation.never()
        _negated = true
        return expectation
    end

    --- Check for strict equality (===)
    --- @param expected any Expected value
    function expectation.to_be(expected)
        local passes = _value == expected
        if _negated then passes = not passes end

        if not passes then
            local msg = _negated
                and string.format("expected %s NOT to be %s", tostring(_value), tostring(expected))
                or string.format("expected %s to be %s\n    expected: %s\n    actual:   %s",
                    tostring(_value), tostring(expected),
                    tostring(expected), tostring(_value))
            error(msg, 2)
        end
    end

    --- Check for deep equality (tables)
    --- @param expected any Expected value (recursively compared)
    function expectation.to_equal(expected)
        local function deep_eq(a, b, path)
            path = path or ""
            if type(a) ~= type(b) then
                return false, path .. " type mismatch: " .. type(a) .. " vs " .. type(b)
            end
            if type(a) ~= "table" then
                if a ~= b then
                    return false, path .. " value mismatch: " .. tostring(a) .. " vs " .. tostring(b)
                end
                return true
            end
            for k, v in pairs(a) do
                local ok, diff = deep_eq(v, b[k], path .. "." .. tostring(k))
                if not ok then return false, diff end
            end
            for k, v in pairs(b) do
                if a[k] == nil then
                    return false, path .. "." .. tostring(k) .. " unexpected key"
                end
            end
            return true
        end

        local is_equal, diff = deep_eq(expected, _value)
        local passes = is_equal
        if _negated then passes = not passes end

        if not passes then
            local msg
            if _negated then
                msg = "expected tables NOT to be deeply equal"
            else
                msg = "expected tables to be deeply equal\n    difference: " .. (diff or "unknown")
            end
            error(msg, 2)
        end
    end

    --- Check if value contains substring or table element
    --- @param needle any For strings: substring. For tables: value to find
    function expectation.to_contain(needle)
        local passes = false
        local val_type = type(_value)

        if val_type == "string" then
            passes = _value:find(needle, 1, true) ~= nil
        elseif val_type == "table" then
            -- Check array elements first
            for _, v in ipairs(_value) do
                if v == needle then
                    passes = true
                    break
                end
            end
            -- Also check keys (for key existence)
            if not passes and _value[needle] ~= nil then
                passes = true
            end
        else
            error("to_contain() requires string or table, got " .. val_type, 2)
        end

        if _negated then passes = not passes end

        if not passes then
            local msg = _negated
                and string.format("expected %s NOT to contain %s", tostring(_value), tostring(needle))
                or string.format("expected %s to contain %s\n    actual:   %s\n    needle:   %s",
                    val_type, tostring(needle), tostring(_value), tostring(needle))
            error(msg, 2)
        end
    end

    --- Check if value is truthy (not nil and not false)
    function expectation.to_be_truthy()
        local passes = _value ~= nil and _value ~= false
        if _negated then passes = not passes end

        if not passes then
            local msg = _negated
                and string.format("expected %s NOT to be truthy", tostring(_value))
                or string.format("expected truthy value\n    actual: %s", tostring(_value))
            error(msg, 2)
        end
    end

    --- Check if value is falsy (nil or false)
    function expectation.to_be_falsy()
        local passes = _value == nil or _value == false
        if _negated then passes = not passes end

        if not passes then
            local msg = _negated
                and string.format("expected %s NOT to be falsy", tostring(_value))
                or string.format("expected falsy value\n    actual: %s", tostring(_value))
            error(msg, 2)
        end
    end

    --- Check if function throws an error
    --- @param pattern string? Optional pattern to match against error message
    function expectation.to_throw(pattern)
        if type(_value) ~= "function" then
            error("to_throw() requires a function, got " .. type(_value), 2)
        end

        local ok, err = pcall(_value)
        local threw = not ok
        local pattern_matches = true

        if threw and pattern then
            pattern_matches = tostring(err):find(pattern) ~= nil
        end

        local passes = threw and pattern_matches
        if _negated then passes = not passes end

        if not passes then
            local msg
            if _negated then
                msg = "expected function NOT to throw"
                if threw then
                    msg = msg .. "\n    thrown: " .. tostring(err)
                end
            else
                if not threw then
                    msg = "expected function to throw\n    actual: function did not throw"
                else
                    msg = string.format("expected error to match pattern: %s\n    actual: %s",
                        tostring(pattern), tostring(err))
                end
            end
            error(msg, 2)
        end
    end

    --- Check if value is nil
    function expectation.to_be_nil()
        local passes = _value == nil
        if _negated then passes = not passes end

        if not passes then
            local msg = _negated
                and "expected value NOT to be nil"
                or string.format("expected nil\n    actual: %s", tostring(_value))
            error(msg, 2)
        end
    end

    --- Check if value is of specific type
    --- @param expected_type string Expected type name
    function expectation.to_be_type(expected_type)
        local actual_type = type(_value)
        local passes = actual_type == expected_type
        if _negated then passes = not passes end

        if not passes then
            local msg = _negated
                and string.format("expected type NOT to be %s", expected_type)
                or string.format("expected type %s\n    actual type: %s", expected_type, actual_type)
            error(msg, 2)
        end
    end

    return expectation
end

--------------------------------------------------------------------------------
-- Legacy Assertions (for backwards compatibility)
--------------------------------------------------------------------------------

--- Assert two values are equal
function TestRunner.assert_equals(expected, actual, msg)
    if expected ~= actual then
        error((msg or "Assertion failed") .. "\n    expected: " .. tostring(expected) .. "\n    actual:   " .. tostring(actual), 2)
    end
end

--- Assert value is truthy
function TestRunner.assert_true(value, msg)
    if not value then
        error((msg or "Assertion failed") .. ": expected truthy, got " .. tostring(value), 2)
    end
end

--- Assert value is falsy
function TestRunner.assert_false(value, msg)
    if value then
        error((msg or "Assertion failed") .. ": expected falsy, got " .. tostring(value), 2)
    end
end

--- Assert value is nil
function TestRunner.assert_nil(value, msg)
    if value ~= nil then
        error((msg or "Assertion failed") .. ": expected nil, got " .. tostring(value), 2)
    end
end

--- Assert value is not nil
function TestRunner.assert_not_nil(value, msg)
    if value == nil then
        error((msg or "Assertion failed") .. ": expected non-nil value", 2)
    end
end

--- Assert table contains key
function TestRunner.assert_table_contains(tbl, key, msg)
    if type(tbl) ~= "table" then
        error((msg or "Assertion failed") .. ": expected table, got " .. type(tbl), 2)
    end
    if tbl[key] == nil then
        error((msg or "Assertion failed") .. ": table missing key '" .. tostring(key) .. "'", 2)
    end
end

--- Assert function throws an error
function TestRunner.assert_throws(fn, pattern, msg)
    local ok, err = pcall(fn)
    if ok then
        error((msg or "Assertion failed") .. ": expected function to throw", 2)
    end
    if pattern and not tostring(err):find(pattern) then
        error((msg or "Assertion failed") .. ": error did not match pattern '" .. pattern .. "'\n    actual error: " .. tostring(err), 2)
    end
end

--- Assert two tables are deeply equal
function TestRunner.assert_deep_equals(expected, actual, msg)
    local function deep_eq(a, b, path)
        path = path or ""
        if type(a) ~= type(b) then
            return false, path .. " type mismatch: " .. type(a) .. " vs " .. type(b)
        end
        if type(a) ~= "table" then
            if a ~= b then
                return false, path .. " value mismatch: " .. tostring(a) .. " vs " .. tostring(b)
            end
            return true
        end
        for k, v in pairs(a) do
            local ok, diff = deep_eq(v, b[k], path .. "." .. tostring(k))
            if not ok then return false, diff end
        end
        for k, v in pairs(b) do
            if a[k] == nil then
                return false, path .. "." .. tostring(k) .. " unexpected key"
            end
        end
        return true
    end

    local ok, diff = deep_eq(expected, actual)
    if not ok then
        error((msg or "Deep equality failed") .. ":\n    " .. diff, 2)
    end
end

--------------------------------------------------------------------------------
-- Test Execution
--------------------------------------------------------------------------------

--- Run a single test suite
function TestRunner._run_suite(suite, indent)
    indent = indent or ""
    print(indent .. COLORS.cyan .. "● " .. suite.name .. COLORS.reset)

    for _, test in ipairs(suite.tests) do
        if test.is_suite then
            -- Nested suite
            test.fn()
        elseif test.skip then
            -- Skipped test
            results.skipped = results.skipped + 1
            print(indent .. "  " .. COLORS.yellow .. "○ " .. test.name .. " (skipped)" .. COLORS.reset)
        else
            -- Run before_each
            if suite.before_each then
                local ok, err = pcall(suite.before_each)
                if not ok then
                    print(indent .. "  " .. COLORS.red .. "✗ " .. test.name .. " (before_each failed)" .. COLORS.reset)
                    print(indent .. "    " .. COLORS.dim .. tostring(err) .. COLORS.reset)
                    results.failed = results.failed + 1
                    table.insert(results.errors, {
                        suite = suite.name,
                        name = test.name .. " (before_each)",
                        error = err,
                        trace = format_stack_trace(err),
                    })
                    goto continue
                end
            end

            -- Run test
            local ok, err = pcall(test.fn)

            if ok then
                results.passed = results.passed + 1
                print(indent .. "  " .. COLORS.green .. "✓ " .. test.name .. COLORS.reset)
            else
                results.failed = results.failed + 1
                local trace = format_stack_trace(err)
                table.insert(results.errors, {
                    suite = suite.name,
                    name = test.name,
                    error = err,
                    trace = trace,
                })
                print(indent .. "  " .. COLORS.red .. "✗ " .. test.name .. COLORS.reset)
                -- Show inline error summary
                local err_line = tostring(err):match("^[^\n]+") or tostring(err)
                print(indent .. "    " .. COLORS.dim .. err_line .. COLORS.reset)
            end

            -- Run after_each
            if suite.after_each then
                pcall(suite.after_each)
            end

            ::continue::
        end
    end
end

--- Run all registered test suites
--- @return boolean True if all tests passed
function TestRunner.run()
    results = { passed = 0, failed = 0, skipped = 0, errors = {} }

    print("\n" .. COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. "                         TEST RESULTS" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset .. "\n")

    for _, suite in ipairs(suites) do
        TestRunner._run_suite(suite)
        print("")
    end

    -- Summary
    print(COLORS.cyan .. "───────────────────────────────────────────────────────────────" .. COLORS.reset)
    local total = results.passed + results.failed + results.skipped
    print(string.format("  Total:   %d tests", total))
    print(string.format("  " .. COLORS.green .. "Passed:  %d" .. COLORS.reset, results.passed))
    if results.failed > 0 then
        print(string.format("  " .. COLORS.red .. "Failed:  %d" .. COLORS.reset, results.failed))
    end
    if results.skipped > 0 then
        print(string.format("  " .. COLORS.yellow .. "Skipped: %d" .. COLORS.reset, results.skipped))
    end
    print(COLORS.cyan .. "───────────────────────────────────────────────────────────────" .. COLORS.reset)

    -- Detailed failures
    if #results.errors > 0 then
        print("\n" .. COLORS.red .. "FAILURES:" .. COLORS.reset)
        for i, e in ipairs(results.errors) do
            print("\n" .. COLORS.red .. i .. ") " .. e.suite .. " › " .. e.name .. COLORS.reset)
            print(COLORS.dim .. tostring(e.error) .. COLORS.reset)
            if e.trace and e.trace ~= "" then
                print(COLORS.dim .. e.trace .. COLORS.reset)
            end
        end
    end

    local success = results.failed == 0
    print("\n" .. (success and COLORS.green .. "✓ All tests passed!" or COLORS.red .. "✗ Some tests failed") .. COLORS.reset .. "\n")

    return success
end

--- Alias for backwards compatibility
TestRunner.run_all = TestRunner.run

--- Reset all registered suites and results
function TestRunner.reset()
    suites = {}
    current_suite = nil
    results = { passed = 0, failed = 0, skipped = 0, errors = {} }
end

--------------------------------------------------------------------------------
-- Directory-Based Test Discovery
--------------------------------------------------------------------------------

--- List files in directory matching pattern (portable implementation)
local function list_test_files(dir)
    local files = {}

    -- Try using 'find' command (Unix) or 'dir' (Windows)
    local cmd
    if package.config:sub(1, 1) == "\\" then
        -- Windows
        cmd = 'dir /b /s "' .. dir .. '\\test_*.lua" 2>nul'
    else
        -- Unix
        cmd = 'find "' .. dir .. '" -name "test_*.lua" -type f 2>/dev/null | sort'
    end

    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            if line:match("test_.*%.lua$") then
                table.insert(files, line)
            end
        end
        handle:close()
    end

    return files
end

--- Run all test files in a directory
--- @param dir string Directory path
--- @return boolean True if all tests passed
function TestRunner.run_directory(dir)
    dir = dir or "."
    local files = list_test_files(dir)

    if #files == 0 then
        print(COLORS.yellow .. "No test files found in: " .. dir .. COLORS.reset)
        return true
    end

    print(COLORS.cyan .. "Found " .. #files .. " test file(s)" .. COLORS.reset)

    local all_passed = true

    for _, filepath in ipairs(files) do
        -- Skip this file if it's the test runner itself
        if filepath:find("test_runner%.lua$") then
            goto continue
        end

        print("\n" .. COLORS.cyan .. "Running: " .. filepath .. COLORS.reset)

        -- Execute test file as a separate Lua process
        local cmd = 'lua "' .. filepath .. '"'
        local exit_code = os.execute(cmd)

        -- os.execute returns different values in different Lua versions
        local success
        if type(exit_code) == "boolean" then
            success = exit_code
        elseif type(exit_code) == "number" then
            success = exit_code == 0
        else
            success = exit_code == true
        end

        if not success then
            all_passed = false
        end

        ::continue::
    end

    return all_passed
end

--------------------------------------------------------------------------------
-- CLI Entry Point
--------------------------------------------------------------------------------

-- Check if running as main script
if arg and arg[0] and arg[0]:find("test_runner%.lua$") then
    local dir = arg[1] or "./assets/scripts/tests"

    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. "                     TEST RUNNER" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print("Directory: " .. dir .. "\n")

    local success = TestRunner.run_directory(dir)
    os.exit(success and 0 or 1)
end

return TestRunner
