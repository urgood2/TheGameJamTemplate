-- assets/scripts/tests/test_runner.lua
--[[
================================================================================
TEST RUNNER: Enhanced Test Framework for Phase 1
================================================================================
A comprehensive test harness with:

CLASSIC API (BDD-style):
- describe() and it() for test structure
- expect() fluent matchers for expressive assertions
- before_each/after_each hooks

PHASE 1 API (Registration-based):
- TestRunner:register() for metadata-rich test registration
- opts.tags, opts.doc_ids, opts.requires, opts.timeout_frames, opts.perf_budget_ms
- Deterministic ordering (category → test_id)
- Sharding support (shard_count/shard_index)
- Reporter pipeline (Markdown, JSON, JUnit)

OUTPUTS:
- test_output/report.md (stable section markers)
- test_output/status.json (summary)
- test_output/results.json (detailed)
- test_output/junit.xml (CI integration)

Usage (BDD-style):
    local t = require("tests.test_runner")

    t.describe("MyModule", function()
        t.it("should do something", function()
            t.expect(1).to_be(1)
        end)
    end)

    t.run()

Usage (Registration-based):
    local t = require("tests.test_runner")

    t.TestRunner:register("my_test", "unit", function()
        t.expect(1).to_be(1)
    end, {
        tags = {"fast", "core"},
        doc_ids = {"doc-123"},
        timeout_frames = 300,
        perf_budget_ms = 100,
    })

    t.TestRunner:run({ shard_count = 2, shard_index = 0 })
]]

local TestRunner = {}

-- Schema version for output files
local SCHEMA_VERSION = "1.0"

-- State
local suites = {}           -- Registered describe blocks
local registered_tests = {} -- Phase 1 registered tests
local current_suite = nil   -- Current suite being defined
local results = { passed = 0, failed = 0, skipped = 0, errors = {}, timings = {}, total_time = 0 }
local run_model = nil       -- Canonical run model for reporters

-- Capabilities (detected at runtime)
local capabilities = {
    screenshot = false,
    log_capture = false,
    reset_world = false,
    deterministic_rng = false,
}

-- Configuration
local config = {
    filter = nil,           -- Pattern to filter tests by name
    verbose = false,        -- Show detailed assertion output
    watch = false,          -- Watch mode (re-run on file changes)
    show_timing = true,     -- Show timing statistics
    output_dir = "test_output",
    shard_count = 1,        -- Total number of shards
    shard_index = 0,        -- This shard's index (0-based)
    default_timeout_frames = 600,
    rng_seed = 12345,       -- Fixed RNG seed for determinism
    enable_reporters = true, -- Generate output files
}

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
    local no_color = os.getenv("NO_COLOR")
    if no_color then return false end
    return term and term ~= "dumb"
end

if not supports_colors() then
    for k in pairs(COLORS) do COLORS[k] = "" end
end

--------------------------------------------------------------------------------
-- Logging with Stable Prefixes
--------------------------------------------------------------------------------

--- Log with consistent prefix for tooling
--- @param prefix string Log category prefix
--- @param msg string Message to log
local function log(prefix, msg)
    print(string.format("[%s] %s", prefix, msg))
end

--------------------------------------------------------------------------------
-- Timing Utilities
--------------------------------------------------------------------------------

--- High-precision timer using os.clock()
local function get_time()
    return os.clock()
end

--- Format duration in human-readable format
local function format_duration(seconds)
    if seconds < 0.001 then
        return string.format("%.2fμs", seconds * 1000000)
    elseif seconds < 1 then
        return string.format("%.2fms", seconds * 1000)
    else
        return string.format("%.2fs", seconds)
    end
end

--- Get current ISO8601 timestamp
local function get_iso8601()
    local now = os.date("!*t")
    return string.format(
        "%04d-%02d-%02dT%02d:%02d:%02dZ",
        now.year, now.month, now.day,
        now.hour, now.min, now.sec
    )
end

--------------------------------------------------------------------------------
-- Safe Filename Generation
--------------------------------------------------------------------------------

--- Convert test_id to safe filename
--- @param test_id string Test identifier
--- @return string safe filename (lowercase, non-alphanumeric replaced with _)
function TestRunner.safe_filename(test_id)
    if not test_id then return "unknown" end
    local safe = test_id:lower()
    safe = safe:gsub("[^a-z0-9._%-]", "_")
    safe = safe:gsub("_+", "_") -- Collapse multiple underscores
    safe = safe:gsub("^_", ""):gsub("_$", "") -- Trim leading/trailing
    return safe
end

--------------------------------------------------------------------------------
-- Stack Trace Formatting
--------------------------------------------------------------------------------

--- Extract meaningful stack trace from error, filtering test runner internals
local function format_stack_trace(err)
    local trace = debug.traceback(err, 3)
    local lines = {}

    for line in trace:gmatch("[^\n]+") do
        -- Skip test_runner.lua internal frames
        if line:find("test_runner%.lua") then
            -- skip
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
-- Configuration API
--------------------------------------------------------------------------------

--- Set test filter pattern
--- @param pattern string? Lua pattern to match test names (nil to clear)
function TestRunner.set_filter(pattern)
    config.filter = pattern
end

--- Get current filter pattern
--- @return string? Current filter pattern
function TestRunner.get_filter()
    return config.filter
end

--- Enable/disable verbose mode
--- @param enabled boolean Whether to show detailed assertion output
function TestRunner.set_verbose(enabled)
    config.verbose = enabled
end

--- Check if verbose mode is enabled
--- @return boolean Whether verbose mode is enabled
function TestRunner.is_verbose()
    return config.verbose
end

--- Enable/disable timing display
--- @param enabled boolean Whether to show timing statistics
function TestRunner.set_timing(enabled)
    config.show_timing = enabled
end

--- Configure the test runner
--- @param opts table Configuration options
function TestRunner.configure(opts)
    if opts.filter ~= nil then config.filter = opts.filter end
    if opts.verbose ~= nil then config.verbose = opts.verbose end
    if opts.watch ~= nil then config.watch = opts.watch end
    if opts.show_timing ~= nil then config.show_timing = opts.show_timing end
    if opts.output_dir ~= nil then config.output_dir = opts.output_dir end
    if opts.shard_count ~= nil then config.shard_count = opts.shard_count end
    if opts.shard_index ~= nil then config.shard_index = opts.shard_index end
    if opts.default_timeout_frames ~= nil then config.default_timeout_frames = opts.default_timeout_frames end
    if opts.rng_seed ~= nil then config.rng_seed = opts.rng_seed end
    if opts.enable_reporters ~= nil then config.enable_reporters = opts.enable_reporters end
end

--------------------------------------------------------------------------------
-- Phase 1: Registration API
--------------------------------------------------------------------------------

--- Register a test with the Phase 1 API
--- @param name string Test name (unique identifier)
--- @param category string Test category for grouping
--- @param testFn function Test implementation
--- @param opts table? Optional settings: tags, doc_ids, requires, timeout_frames, perf_budget_ms, source_ref
function TestRunner.register(self, name, category, testFn, opts)
    opts = opts or {}

    local test = {
        name = name,
        category = category or "default",
        fn = testFn,
        tags = opts.tags or {},
        doc_ids = opts.doc_ids or {},
        requires = opts.requires or {},
        timeout_frames = opts.timeout_frames or config.default_timeout_frames,
        perf_budget_ms = opts.perf_budget_ms,
        source_ref = opts.source_ref,
        -- Computed test_id for deterministic ordering
        test_id = (category or "default") .. "::" .. name,
    }

    table.insert(registered_tests, test)

    if config.verbose then
        log("REGISTER", test.test_id .. " (tags: " .. table.concat(test.tags, ", ") .. ")")
    end
end

--------------------------------------------------------------------------------
-- Capability Detection
--------------------------------------------------------------------------------

--- Detect available capabilities
function TestRunner.detect_capabilities()
    -- Check screenshot API
    if _G.screenshot and type(_G.screenshot.capture) == "function" then
        capabilities.screenshot = true
    elseif _G.globals and _G.globals.screenshot then
        capabilities.screenshot = true
    end

    -- Check log capture
    if _G.log_capture or (_G.globals and _G.globals.log_capture) then
        capabilities.log_capture = true
    end

    -- Check reset_world
    if _G.reset_world and type(_G.reset_world) == "function" then
        capabilities.reset_world = true
    end

    -- Check RNG seeding
    capabilities.deterministic_rng = true -- Lua always supports math.randomseed

    log("CAPS", string.format(
        "screenshot=%s, log_capture=%s, reset_world=%s, deterministic_rng=%s",
        capabilities.screenshot and "yes" or "no",
        capabilities.log_capture and "yes" or "no",
        capabilities.reset_world and "yes" or "no",
        capabilities.deterministic_rng and "yes" or "no"
    ))

    return capabilities
end

--- Get detected capabilities
--- @return table capabilities
function TestRunner.get_capabilities()
    return capabilities
end

--------------------------------------------------------------------------------
-- Describe / It API (BDD-style)
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
-- Sharding
--------------------------------------------------------------------------------

--- Compute deterministic shard assignment for a test
--- @param test_id string Test identifier
--- @param shard_count number Total shards
--- @return number shard_index (0-based)
local function compute_shard(test_id, shard_count)
    if shard_count <= 1 then return 0 end

    -- Simple hash-based distribution
    local hash = 0
    for i = 1, #test_id do
        hash = (hash * 31 + string.byte(test_id, i)) % 2147483647
    end

    return hash % shard_count
end

--- Filter tests by shard assignment
--- @param tests table Array of tests
--- @param shard_count number Total shards
--- @param shard_index number This shard (0-based)
--- @return table Filtered tests for this shard
local function filter_by_shard(tests, shard_count, shard_index)
    if shard_count <= 1 then return tests end

    local filtered = {}
    for _, test in ipairs(tests) do
        local test_shard = compute_shard(test.test_id or test.name, shard_count)
        if test_shard == shard_index then
            table.insert(filtered, test)
        end
    end

    log("SHARD", string.format(
        "Running shard %d/%d (%d tests)",
        shard_index + 1, shard_count, #filtered
    ))

    return filtered
end

--------------------------------------------------------------------------------
-- Run State Integration
--------------------------------------------------------------------------------

local RunState = nil

--- Load run_state module if available
local function load_run_state()
    local ok, mod = pcall(require, "test.run_state")
    if ok then
        RunState = mod
        return true
    end
    return false
end

--------------------------------------------------------------------------------
-- Test Execution
--------------------------------------------------------------------------------

--- Check if a test matches the current filter
--- @param suite_name string Suite name
--- @param test_name string Test name
--- @return boolean True if test matches filter or no filter set
local function matches_filter(suite_name, test_name)
    if not config.filter then return true end
    local full_name = (suite_name or "") .. " " .. (test_name or "")
    return full_name:lower():find(config.filter:lower()) ~= nil
end

--- Check if test has required capabilities
--- @param test table Test with requires field
--- @return boolean, string? has_caps, missing_cap_name
local function check_capabilities(test)
    if not test.requires or #test.requires == 0 then
        return true, nil
    end

    for _, cap in ipairs(test.requires) do
        if not capabilities[cap] then
            return false, cap
        end
    end

    return true, nil
end

--- Run a single test suite (BDD-style)
function TestRunner._run_suite(suite, indent)
    indent = indent or ""
    local suite_start = get_time()
    local suite_has_matching_tests = false

    -- Pre-check if any tests match the filter
    if config.filter then
        for _, test in ipairs(suite.tests) do
            if test.is_suite or matches_filter(suite.name, test.name) then
                suite_has_matching_tests = true
                break
            end
        end
        if not suite_has_matching_tests then
            return -- Skip entire suite if no tests match
        end
    end

    print(indent .. COLORS.cyan .. "● " .. suite.name .. COLORS.reset)

    for _, test in ipairs(suite.tests) do
        if test.is_suite then
            -- Nested suite
            test.fn()
        elseif not matches_filter(suite.name, test.name) then
            -- Filtered out - don't count or display
        elseif test.skip then
            -- Skipped test
            results.skipped = results.skipped + 1
            local test_id = suite.name .. "::" .. test.name
            log("SKIP", test_id .. ": explicitly skipped")
            print(indent .. "  " .. COLORS.yellow .. "○ " .. test.name .. " (skipped)" .. COLORS.reset)
        else
            local test_id = suite.name .. "::" .. test.name
            local test_start = get_time()

            -- Log test start
            log("TEST START", test_id .. " (category: " .. suite.name .. ")")

            -- Update run state sentinel
            if RunState then
                RunState.test_start(test_id)
            end

            -- Run before_each
            if suite.before_each then
                local ok, err = pcall(suite.before_each)
                if not ok then
                    local test_duration = get_time() - test_start
                    print(indent .. "  " .. COLORS.red .. "✗ " .. test.name .. " (before_each failed)" .. COLORS.reset)
                    print(indent .. "    " .. COLORS.dim .. tostring(err) .. COLORS.reset)
                    results.failed = results.failed + 1
                    log("TEST END", test_id .. " [FAIL] (" .. string.format("%.2fms", test_duration * 1000) .. ")")
                    log("FAIL DETAIL", test_id .. ": " .. tostring(err))
                    if RunState then
                        RunState.test_end(test_id, "failed")
                    end
                    table.insert(results.errors, {
                        suite = suite.name,
                        name = test.name .. " (before_each)",
                        error = err,
                        trace = format_stack_trace(err),
                    })
                    table.insert(results.timings, {
                        suite = suite.name,
                        name = test.name,
                        duration = test_duration,
                        passed = false,
                    })
                    goto continue
                end
            end

            -- Seed RNG for determinism
            math.randomseed(config.rng_seed)

            -- Run test
            local ok, err = pcall(test.fn)
            local test_duration = get_time() - test_start
            local duration_ms = test_duration * 1000

            -- Record timing
            table.insert(results.timings, {
                suite = suite.name,
                name = test.name,
                duration = test_duration,
                passed = ok,
            })

            if ok then
                results.passed = results.passed + 1
                local timing_str = config.show_timing and (" " .. COLORS.dim .. "(" .. format_duration(test_duration) .. ")" .. COLORS.reset) or ""
                print(indent .. "  " .. COLORS.green .. "✓ " .. test.name .. COLORS.reset .. timing_str)
                log("TEST END", test_id .. " [PASS] (" .. string.format("%.2fms", duration_ms) .. ")")

                if RunState then
                    RunState.test_end(test_id, "passed")
                end

                if config.verbose then
                    print(indent .. "    " .. COLORS.dim .. "(all assertions passed)" .. COLORS.reset)
                end
            else
                results.failed = results.failed + 1
                local trace = format_stack_trace(err)
                table.insert(results.errors, {
                    suite = suite.name,
                    name = test.name,
                    error = err,
                    trace = trace,
                })
                local timing_str = config.show_timing and (" " .. COLORS.dim .. "(" .. format_duration(test_duration) .. ")" .. COLORS.reset) or ""
                print(indent .. "  " .. COLORS.red .. "✗ " .. test.name .. COLORS.reset .. timing_str)
                log("TEST END", test_id .. " [FAIL] (" .. string.format("%.2fms", duration_ms) .. ")")
                log("FAIL DETAIL", test_id .. ": " .. tostring(err) .. "\n" .. (trace or ""))

                if RunState then
                    RunState.test_end(test_id, "failed")
                end

                if config.verbose then
                    print(indent .. "    " .. COLORS.dim .. tostring(err) .. COLORS.reset)
                    if trace and trace ~= "" then
                        for line in trace:gmatch("[^\n]+") do
                            print(indent .. "    " .. COLORS.dim .. line .. COLORS.reset)
                        end
                    end
                else
                    local err_line = tostring(err):match("^[^\n]+") or tostring(err)
                    print(indent .. "    " .. COLORS.dim .. err_line .. COLORS.reset)
                end
            end

            -- Run after_each
            if suite.after_each then
                pcall(suite.after_each)
            end

            ::continue::
        end
    end

    -- Show suite timing in verbose mode
    if config.verbose and config.show_timing then
        local suite_duration = get_time() - suite_start
        print(indent .. COLORS.dim .. "  Suite completed in " .. format_duration(suite_duration) .. COLORS.reset)
    end
end

--- Build canonical run model for reporters
--- @return table run_model
local function build_run_model()
    local model = {
        schema_version = SCHEMA_VERSION,
        generated_at = get_iso8601(),
        config = {
            shard_count = config.shard_count,
            shard_index = config.shard_index,
            filter = config.filter,
            rng_seed = config.rng_seed,
        },
        capabilities = capabilities,
        summary = {
            total = results.passed + results.failed + results.skipped,
            passed = results.passed,
            failed = results.failed,
            skipped = results.skipped,
            duration_ms = results.total_time * 1000,
        },
        tests = {},
        failures = {},
        skipped = {},
    }

    -- Build test results
    for _, timing in ipairs(results.timings) do
        local test_id = timing.suite .. "::" .. timing.name
        table.insert(model.tests, {
            test_id = test_id,
            category = timing.suite,
            name = timing.name,
            status = timing.passed and "PASS" or "FAIL",
            duration_ms = timing.duration * 1000,
        })
    end

    -- Build failure details
    for _, err in ipairs(results.errors) do
        local test_id = err.suite .. "::" .. err.name
        table.insert(model.failures, {
            test_id = test_id,
            error = tostring(err.error),
            stack_trace = err.trace,
        })
    end

    return model
end

--------------------------------------------------------------------------------
-- Reporter Pipeline
--------------------------------------------------------------------------------

--- Ensure output directory exists
local function ensure_output_dir()
    os.execute("mkdir -p " .. config.output_dir .. " 2>/dev/null")
    os.execute("mkdir -p " .. config.output_dir .. "/screenshots 2>/dev/null")
    os.execute("mkdir -p " .. config.output_dir .. "/artifacts 2>/dev/null")
end

--- Simple JSON encoder (no external deps)
local function encode_json(value, indent_level)
    indent_level = indent_level or 0
    local indent = string.rep("  ", indent_level)
    local next_indent = string.rep("  ", indent_level + 1)

    if value == nil then
        return "null"
    elseif type(value) == "boolean" then
        return value and "true" or "false"
    elseif type(value) == "number" then
        if value ~= value then return "null" end -- NaN
        if value == math.huge or value == -math.huge then return "null" end
        return tostring(value)
    elseif type(value) == "string" then
        return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif type(value) == "table" then
        -- Check if array
        local is_array = #value > 0 or next(value) == nil
        if is_array then
            local parts = {}
            for _, v in ipairs(value) do
                table.insert(parts, next_indent .. encode_json(v, indent_level + 1))
            end
            if #parts == 0 then return "[]" end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
        else
            local parts = {}
            -- Sort keys for determinism
            local keys = {}
            for k in pairs(value) do table.insert(keys, k) end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)

            for _, k in ipairs(keys) do
                local v = value[k]
                table.insert(parts, next_indent .. '"' .. tostring(k) .. '": ' .. encode_json(v, indent_level + 1))
            end
            if #parts == 0 then return "{}" end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        end
    end
    return "null"
end

--- Write Markdown report
--- @param model table Run model
local function write_markdown_report(model)
    local path = config.output_dir .. "/report.md"
    log("REPORT", "Writing " .. path .. "...")

    local lines = {
        "# Test Report",
        "",
        "Generated: " .. model.generated_at,
        "",
        "## Summary",
        "",
        string.format("- **Total:** %d tests", model.summary.total),
        string.format("- **Passed:** %d", model.summary.passed),
        string.format("- **Failed:** %d", model.summary.failed),
        string.format("- **Skipped:** %d", model.summary.skipped),
        string.format("- **Duration:** %.2fms", model.summary.duration_ms),
        "",
        "## Results",
        "",
    }

    -- Test results (deterministic order)
    for _, test in ipairs(model.tests) do
        local status = test.status == "PASS" and "PASS" or "FAIL"
        local line = string.format("%s %s", status, test.test_id)
        table.insert(lines, line)
    end

    table.insert(lines, "")
    table.insert(lines, "## Failures")
    table.insert(lines, "")

    if #model.failures == 0 then
        table.insert(lines, "_No failures_")
    else
        for _, failure in ipairs(model.failures) do
            table.insert(lines, string.format("### FAIL %s", failure.test_id))
            table.insert(lines, "")
            table.insert(lines, "**Error:** " .. (failure.error or "unknown"))
            if failure.stack_trace and failure.stack_trace ~= "" then
                table.insert(lines, "")
                table.insert(lines, "```")
                table.insert(lines, failure.stack_trace)
                table.insert(lines, "```")
            end
            table.insert(lines, "")
        end
    end

    table.insert(lines, "## Skipped")
    table.insert(lines, "")

    if #model.skipped == 0 then
        table.insert(lines, "_No skipped tests_")
    else
        for _, skip in ipairs(model.skipped) do
            local reason = skip.reason or "unknown"
            table.insert(lines, string.format("SKIP %s - %s", skip.test_id, reason))
        end
    end

    table.insert(lines, "")
    table.insert(lines, "## Screenshots")
    table.insert(lines, "")
    table.insert(lines, "_Screenshots available in test_output/screenshots/_")

    local file = io.open(path, "w")
    if file then
        file:write(table.concat(lines, "\n"))
        file:close()
        local size = #table.concat(lines, "\n")
        log("REPORT", path .. " written (" .. size .. " bytes)")
    else
        log("REPORT", "ERROR: Could not write " .. path)
    end
end

--- Write JSON status report (summary)
--- @param model table Run model
local function write_status_json(model)
    local path = config.output_dir .. "/status.json"
    log("REPORT", "Writing " .. path .. "...")

    local status = {
        schema_version = model.schema_version,
        generated_at = model.generated_at,
        passed = model.summary.failed == 0,
        summary = model.summary,
    }

    local file = io.open(path, "w")
    if file then
        local content = encode_json(status)
        file:write(content)
        file:close()
        log("REPORT", path .. " written (" .. #content .. " bytes)")
    end
end

--- Write JSON results report (detailed)
--- @param model table Run model
local function write_results_json(model)
    local path = config.output_dir .. "/results.json"
    log("REPORT", "Writing " .. path .. "...")

    local file = io.open(path, "w")
    if file then
        local content = encode_json(model)
        file:write(content)
        file:close()
        log("REPORT", path .. " written (" .. #content .. " bytes)")
    end
end

--- Write JUnit XML report
--- @param model table Run model
local function write_junit_xml(model)
    local path = config.output_dir .. "/junit.xml"
    log("REPORT", "Writing " .. path .. "...")

    local function escape_xml(s)
        if not s then return "" end
        return tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
    end

    local lines = {
        '<?xml version="1.0" encoding="UTF-8"?>',
        string.format('<testsuite name="TestRunner" tests="%d" failures="%d" skipped="%d" time="%.3f" timestamp="%s">',
            model.summary.total,
            model.summary.failed,
            model.summary.skipped,
            model.summary.duration_ms / 1000,
            model.generated_at),
    }

    -- Group tests by category
    local by_category = {}
    for _, test in ipairs(model.tests) do
        by_category[test.category] = by_category[test.category] or {}
        table.insert(by_category[test.category], test)
    end

    -- Build failure lookup
    local failure_lookup = {}
    for _, f in ipairs(model.failures) do
        failure_lookup[f.test_id] = f
    end

    -- Output test cases
    for category, tests in pairs(by_category) do
        table.insert(lines, string.format('  <testsuite name="%s" tests="%d">', escape_xml(category), #tests))

        for _, test in ipairs(tests) do
            local time_sec = test.duration_ms / 1000
            table.insert(lines, string.format('    <testcase classname="%s" name="%s" time="%.3f">',
                escape_xml(category), escape_xml(test.name), time_sec))

            if test.status == "FAIL" then
                local failure = failure_lookup[test.test_id]
                if failure then
                    table.insert(lines, string.format('      <failure message="%s">%s</failure>',
                        escape_xml(failure.error),
                        escape_xml(failure.stack_trace or "")))
                else
                    table.insert(lines, '      <failure message="Unknown error"/>')
                end
            elseif test.status == "SKIP" then
                table.insert(lines, '      <skipped/>')
            end

            table.insert(lines, '    </testcase>')
        end

        table.insert(lines, '  </testsuite>')
    end

    table.insert(lines, '</testsuite>')

    local file = io.open(path, "w")
    if file then
        local content = table.concat(lines, "\n")
        file:write(content)
        file:close()
        log("REPORT", path .. " written (" .. #content .. " bytes)")
    end
end

--- Write all reports
--- @param model table Run model
local function write_reports(model)
    if not config.enable_reporters then return end

    ensure_output_dir()
    write_markdown_report(model)
    write_status_json(model)
    write_results_json(model)
    write_junit_xml(model)
end

--------------------------------------------------------------------------------
-- Main Run API
--------------------------------------------------------------------------------

--- Run all registered test suites
--- @param filter_opts table? Filter options: category, name_substr, tags_any, tags_all, shard_count, shard_index
--- @return boolean True if all tests passed
function TestRunner.run(filter_opts)
    filter_opts = filter_opts or {}

    -- Apply filter options to config
    if filter_opts.shard_count then config.shard_count = filter_opts.shard_count end
    if filter_opts.shard_index then config.shard_index = filter_opts.shard_index end
    if filter_opts.filter then config.filter = filter_opts.filter end

    -- Initialize
    results = { passed = 0, failed = 0, skipped = 0, errors = {}, timings = {}, total_time = 0 }
    local run_start = get_time()

    -- Load run state sentinel
    load_run_state()
    if RunState then
        RunState.init()
    end

    -- Detect capabilities
    TestRunner.detect_capabilities()

    print("\n" .. COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. "                         TEST RESULTS" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)

    -- Show config
    if config.filter then
        print(COLORS.yellow .. "  Filter: " .. config.filter .. COLORS.reset)
    end
    if config.shard_count > 1 then
        print(COLORS.yellow .. "  Shard: " .. (config.shard_index + 1) .. "/" .. config.shard_count .. COLORS.reset)
    end
    if config.verbose then
        print(COLORS.yellow .. "  Mode: verbose" .. COLORS.reset)
    end
    print("")

    -- Run BDD-style suites (apply sharding by suite name)
    for _, suite in ipairs(suites) do
        -- Simple shard assignment for suites
        if config.shard_count > 1 then
            local shard = compute_shard(suite.name, config.shard_count)
            if shard ~= config.shard_index then
                goto continue_suite
            end
        end

        TestRunner._run_suite(suite)
        print("")

        ::continue_suite::
    end

    -- Run Phase 1 registered tests
    if #registered_tests > 0 then
        -- Sort by category, then test_id for determinism
        table.sort(registered_tests, function(a, b)
            if a.category ~= b.category then
                return a.category < b.category
            end
            return a.test_id < b.test_id
        end)

        -- Apply sharding
        local tests_to_run = filter_by_shard(registered_tests, config.shard_count, config.shard_index)

        for _, test in ipairs(tests_to_run) do
            -- Check filter
            if config.filter and not test.test_id:lower():find(config.filter:lower()) then
                goto continue_test
            end

            -- Check capabilities
            local has_caps, missing_cap = check_capabilities(test)
            if not has_caps then
                results.skipped = results.skipped + 1
                log("SKIP", test.test_id .. ": missing capability " .. (missing_cap or "unknown"))
                print(COLORS.yellow .. "○ " .. test.test_id .. " (missing: " .. (missing_cap or "?") .. ")" .. COLORS.reset)
                goto continue_test
            end

            local test_start = get_time()
            log("TEST START", test.test_id .. " (category: " .. test.category .. ")")

            if RunState then
                RunState.test_start(test.test_id)
            end

            -- Seed RNG
            math.randomseed(config.rng_seed)

            -- Run test
            local ok, err = pcall(test.fn)
            local test_duration = get_time() - test_start
            local duration_ms = test_duration * 1000

            table.insert(results.timings, {
                suite = test.category,
                name = test.name,
                duration = test_duration,
                passed = ok,
            })

            if ok then
                results.passed = results.passed + 1
                local timing_str = config.show_timing and (" " .. COLORS.dim .. "(" .. format_duration(test_duration) .. ")" .. COLORS.reset) or ""
                print(COLORS.green .. "✓ " .. test.test_id .. COLORS.reset .. timing_str)
                log("TEST END", test.test_id .. " [PASS] (" .. string.format("%.2fms", duration_ms) .. ")")

                if RunState then
                    RunState.test_end(test.test_id, "passed")
                end

                -- Check perf budget
                if test.perf_budget_ms and duration_ms > test.perf_budget_ms then
                    print(COLORS.yellow .. "  WARNING: exceeded perf budget " .. test.perf_budget_ms .. "ms" .. COLORS.reset)
                end
            else
                results.failed = results.failed + 1
                local trace = format_stack_trace(err)
                table.insert(results.errors, {
                    suite = test.category,
                    name = test.name,
                    error = err,
                    trace = trace,
                })
                print(COLORS.red .. "✗ " .. test.test_id .. COLORS.reset)
                log("TEST END", test.test_id .. " [FAIL] (" .. string.format("%.2fms", duration_ms) .. ")")
                log("FAIL DETAIL", test.test_id .. ": " .. tostring(err) .. "\n" .. (trace or ""))

                if RunState then
                    RunState.test_end(test.test_id, "failed")
                end

                if config.verbose then
                    print("    " .. COLORS.dim .. tostring(err) .. COLORS.reset)
                end
            end

            ::continue_test::
        end
    end

    results.total_time = get_time() - run_start

    -- Build run model and write reports
    run_model = build_run_model()
    write_reports(run_model)

    -- Complete run state
    if RunState then
        RunState.complete(results.failed == 0)
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

    -- Timing summary
    if config.show_timing then
        print(string.format("  " .. COLORS.dim .. "Time:    %s" .. COLORS.reset, format_duration(results.total_time)))

        -- Show slowest tests in verbose mode
        if config.verbose and #results.timings > 0 then
            local sorted_timings = {}
            for _, t in ipairs(results.timings) do
                table.insert(sorted_timings, t)
            end
            table.sort(sorted_timings, function(a, b) return a.duration > b.duration end)

            print("")
            print(COLORS.dim .. "  Slowest tests:" .. COLORS.reset)
            for i = 1, math.min(5, #sorted_timings) do
                local t = sorted_timings[i]
                local status = t.passed and COLORS.green or COLORS.red
                print(string.format("    %s%s%s %s › %s",
                    status, format_duration(t.duration), COLORS.reset,
                    t.suite, t.name))
            end
        end
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
    registered_tests = {}
    current_suite = nil
    results = { passed = 0, failed = 0, skipped = 0, errors = {}, timings = {}, total_time = 0 }
    run_model = nil
    -- Also reset config to defaults
    config.filter = nil
    config.verbose = false
    config.shard_count = 1
    config.shard_index = 0
end

--- Get the results of the last test run
--- @return table Results with passed, failed, skipped, errors, timings, total_time
function TestRunner.get_results()
    return results
end

--- Get the canonical run model from the last run
--- @return table? Run model or nil if no run completed
function TestRunner.get_run_model()
    return run_model
end

--- Get timing information for all tests
--- @return table Array of {suite, name, duration, passed}
function TestRunner.get_timings()
    return results.timings
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

    -- Build extra args for subprocess
    local extra_args = ""
    if config.filter then
        extra_args = extra_args .. ' --filter "' .. config.filter .. '"'
    end
    if config.verbose then
        extra_args = extra_args .. " --verbose"
    end

    local all_passed = true

    for _, filepath in ipairs(files) do
        -- Skip this file if it's the test runner itself
        if filepath:find("test_runner%.lua$") then
            goto continue
        end

        print("\n" .. COLORS.cyan .. "Running: " .. filepath .. COLORS.reset)

        -- Execute test file as a separate Lua process
        local cmd = 'lua "' .. filepath .. '"' .. extra_args
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
-- Watch Mode
--------------------------------------------------------------------------------

--- Get modification times for all test files
--- @param dir string Directory to scan
--- @return table Map of filepath -> modification time
local function get_file_mtimes(dir)
    local mtimes = {}
    local files = list_test_files(dir)

    for _, filepath in ipairs(files) do
        local f = io.open(filepath, "r")
        if f then
            f:close()
            local cmd
            if package.config:sub(1, 1) == "\\" then
                cmd = 'forfiles /P "' .. filepath:match("(.+)[\\/]") .. '" /M "' .. filepath:match("[\\/]([^\\/]+)$") .. '" /C "cmd /c echo @fdate @ftime" 2>nul'
            else
                cmd = 'stat -f "%m" "' .. filepath .. '" 2>/dev/null || stat -c "%Y" "' .. filepath .. '" 2>/dev/null'
            end
            local handle = io.popen(cmd)
            if handle then
                local mtime = handle:read("*l")
                handle:close()
                mtimes[filepath] = mtime
            end
        end
    end

    return mtimes
end

--- Run tests in watch mode (re-run on file changes)
--- @param dir string Directory to watch
--- @param interval number Polling interval in seconds (default 1)
function TestRunner.watch(dir, interval)
    dir = dir or "./assets/scripts/tests"
    interval = interval or 1

    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. "                     WATCH MODE" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print("Watching: " .. dir)
    print("Press Ctrl+C to exit\n")

    local last_mtimes = get_file_mtimes(dir)

    -- Initial run
    TestRunner.run_directory(dir)

    while true do
        os.execute("sleep " .. interval)

        local current_mtimes = get_file_mtimes(dir)
        local changed = false

        for filepath, mtime in pairs(current_mtimes) do
            if last_mtimes[filepath] ~= mtime then
                changed = true
                print("\n" .. COLORS.yellow .. "File changed: " .. filepath .. COLORS.reset)
                break
            end
        end

        if not changed then
            for filepath, _ in pairs(current_mtimes) do
                if not last_mtimes[filepath] then
                    changed = true
                    print("\n" .. COLORS.yellow .. "New file: " .. filepath .. COLORS.reset)
                    break
                end
            end
        end

        if changed then
            print(COLORS.cyan .. "\n--- Re-running tests ---\n" .. COLORS.reset)
            last_mtimes = current_mtimes
            TestRunner.run_directory(dir)
        end
    end
end

--------------------------------------------------------------------------------
-- CLI Entry Point
--------------------------------------------------------------------------------

--- Parse command-line arguments
--- @param args table Argument array (e.g., arg)
--- @return table Parsed options
local function parse_args(args)
    local opts = {
        dir = "./assets/scripts/tests",
        filter = nil,
        verbose = false,
        watch = false,
        help = false,
        shard_count = 1,
        shard_index = 0,
    }

    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "--filter" or a == "-f" then
            i = i + 1
            opts.filter = args[i]
        elseif a == "--verbose" or a == "-v" then
            opts.verbose = true
        elseif a == "--watch" or a == "-w" then
            opts.watch = true
        elseif a == "--help" or a == "-h" then
            opts.help = true
        elseif a == "--shard-count" then
            i = i + 1
            opts.shard_count = tonumber(args[i]) or 1
        elseif a == "--shard-index" then
            i = i + 1
            opts.shard_index = tonumber(args[i]) or 0
        elseif not a:match("^%-") then
            -- Positional argument = directory
            opts.dir = a
        end
        i = i + 1
    end

    return opts
end

--- Print CLI usage help
local function print_help()
    print([[
Usage: lua test_runner.lua [options] [directory]

Options:
  -f, --filter PATTERN   Filter tests by name pattern (case-insensitive)
  -v, --verbose          Show detailed assertion output and timing
  -w, --watch            Watch mode - re-run tests on file changes
  --shard-count N        Total number of shards for parallel CI
  --shard-index N        This shard's index (0-based)
  -h, --help             Show this help message

Examples:
  lua test_runner.lua                           # Run all tests in default directory
  lua test_runner.lua ./my_tests                # Run tests in specific directory
  lua test_runner.lua --filter "vbox"           # Run only tests matching "vbox"
  lua test_runner.lua --verbose --filter text   # Verbose output for "text" tests
  lua test_runner.lua --watch                   # Watch mode with auto-rerun
  lua test_runner.lua --shard-count 4 --shard-index 0  # Run first of 4 shards

Outputs (in test_output/):
  report.md      Markdown report with stable section markers
  status.json    Summary status (passed/failed counts)
  results.json   Detailed results with timings
  junit.xml      JUnit format for CI integration
]])
end

-- Check if running as main script
if arg and arg[0] and arg[0]:match("[/\\]?test_runner%.lua$") and not arg[0]:find("test_test_runner") then
    local opts = parse_args(arg)

    if opts.help then
        print_help()
        os.exit(0)
    end

    -- Apply configuration
    TestRunner.configure({
        filter = opts.filter,
        verbose = opts.verbose,
        shard_count = opts.shard_count,
        shard_index = opts.shard_index,
    })

    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. "                     TEST RUNNER" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print("Directory: " .. opts.dir)
    if opts.filter then
        print("Filter:    " .. opts.filter)
    end
    if opts.verbose then
        print("Mode:      verbose")
    end
    if opts.watch then
        print("Mode:      watch")
    end
    if opts.shard_count > 1 then
        print("Shard:     " .. (opts.shard_index + 1) .. "/" .. opts.shard_count)
    end
    print("")

    if opts.watch then
        TestRunner.watch(opts.dir)
    else
        local success = TestRunner.run_directory(opts.dir)
        os.exit(success and 0 or 1)
    end
end

return TestRunner
