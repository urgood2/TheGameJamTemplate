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
- Filter tests by name pattern
- Watch mode for auto-rerun on file changes
- Verbose mode for detailed assertion output
- Timing statistics per test and total

Usage (programmatic):
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

Configuration:
    t.set_filter("vbox")     -- Only run tests matching "vbox"
    t.set_verbose(true)      -- Show detailed output
    t.set_timing(false)      -- Hide timing info

CLI Usage:
    lua test_runner.lua [options] [directory]

    Options:
      -f, --filter PATTERN   Filter tests by name pattern
      -v, --verbose          Show detailed assertion output
      -w, --watch            Watch mode - re-run on file changes
      -h, --help             Show help

Examples:
    lua test_runner.lua --filter "vbox"
    lua test_runner.lua --verbose --watch
]]

local TestRunner = {}
local json = require("external.json")

-- State
local suites = {}           -- Registered describe blocks
local current_suite = nil   -- Current suite being defined
local function init_results()
    return {
        passed = 0,
        failed = 0,
        skipped = 0,
        errors = {},
        timings = {},
        total_time = 0,
        quarantine = {
            active = 0,
            expired = 0,
            failures = 0,
            blocking_failures = 0,
            mode = nil,
            failures_list = {},
            expired_list = {},
        },
    }
end

local results = init_results()

-- Configuration
local config = {
    filter = nil,           -- Pattern to filter tests by name
    verbose = false,        -- Show detailed assertion output
    watch = false,          -- Watch mode (re-run on file changes)
    show_timing = true,     -- Show timing statistics
    quarantine_path = "test_baselines/visual_quarantine.json",
    quarantine_mode = nil,  -- pr | nightly | verify | local (defaults inferred)
    quarantine_platform = nil,
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
    return term and term ~= "dumb"
end

if not supports_colors() then
    for k in pairs(COLORS) do COLORS[k] = "" end
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

--- Set quarantine file path
--- @param path string Path to quarantine JSON
function TestRunner.set_quarantine_path(path)
    config.quarantine_path = path
    TestRunner._quarantine_state = nil
end

--- Set quarantine mode (pr | nightly | verify | local)
--- @param mode string
function TestRunner.set_quarantine_mode(mode)
    config.quarantine_mode = mode
    TestRunner._quarantine_state = nil
end

--- Set quarantine platform override (e.g. "linux", "windows", "macos")
--- @param platform string
function TestRunner.set_quarantine_platform(platform)
    config.quarantine_platform = platform
    TestRunner._quarantine_state = nil
end

--- Configure the test runner
--- @param opts table Configuration options
function TestRunner.configure(opts)
    if opts.filter ~= nil then config.filter = opts.filter end
    if opts.verbose ~= nil then config.verbose = opts.verbose end
    if opts.watch ~= nil then config.watch = opts.watch end
    if opts.show_timing ~= nil then config.show_timing = opts.show_timing end
    if opts.quarantine_path ~= nil then config.quarantine_path = opts.quarantine_path end
    if opts.quarantine_mode ~= nil then config.quarantine_mode = opts.quarantine_mode end
    if opts.quarantine_platform ~= nil then config.quarantine_platform = opts.quarantine_platform end
    TestRunner._quarantine_state = nil
end

--------------------------------------------------------------------------------
-- Quarantine Utilities
--------------------------------------------------------------------------------

local function read_file(path)
    local handle = io.open(path, "r")
    if not handle then
        return nil
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function utc_offset_seconds()
    local now = os.time()
    local utc = os.time(os.date("!*t", now))
    return os.difftime(now, utc)
end

local function parse_iso_utc(iso)
    if type(iso) ~= "string" then
        return nil
    end
    local year, month, day, hour, min, sec = iso:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
    if not year then
        return nil
    end
    local epoch = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
        isdst = false,
    })
    if not epoch then
        return nil
    end
    return epoch - utc_offset_seconds()
end

local function iso_date(iso)
    if type(iso) ~= "string" then
        return "unknown"
    end
    return iso:match("^(%d%d%d%d%-%d%d%-%d%d)") or iso
end

local function normalize_platform(value)
    if not value then
        return nil
    end
    return tostring(value):lower()
end

local function detect_platform()
    local override = normalize_platform(config.quarantine_platform)
    if override and override ~= "" then
        return override
    end
    local env = normalize_platform(os.getenv("TEST_PLATFORM") or os.getenv("RUNNER_OS"))
    if env and env ~= "" then
        return env
    end
    if jit and jit.os then
        return normalize_platform(jit.os)
    end
    if package.config:sub(1, 1) == "\\" then
        return "windows"
    end
    return "linux"
end

local function platform_matches(platforms, current_platform)
    if type(platforms) == "string" then
        platforms = { platforms }
    end
    if not platforms or #platforms == 0 then
        return true
    end
    for _, entry in ipairs(platforms) do
        local value = normalize_platform(entry)
        if value == "*" then
            return true
        end
        if value == current_platform then
            return true
        end
        if value and current_platform and current_platform:find(value, 1, true) then
            return true
        end
    end
    return false
end

local function detect_quarantine_mode()
    local mode = normalize_platform(config.quarantine_mode)
        or normalize_platform(os.getenv("TEST_QUARANTINE_MODE"))
        or normalize_platform(os.getenv("QUARANTINE_MODE"))
    if mode and mode ~= "" then
        return mode
    end
    if os.getenv("CI") then
        return "pr"
    end
    return "local"
end

local function quarantine_mode_blocks(mode)
    return mode == "nightly" or mode == "verify" or mode == "full"
end

function TestRunner.load_quarantine(path)
    local quarantine_path = path or config.quarantine_path
    local content = read_file(quarantine_path)
    if not content then
        return {
            schema_version = "1.0",
            updated_at = nil,
            default_expiry_days = 14,
            quarantined_tests = {},
            _missing = true,
        }, quarantine_path
    end

    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" then
        return {
            schema_version = "1.0",
            updated_at = nil,
            default_expiry_days = 14,
            quarantined_tests = {},
            _invalid = true,
        }, quarantine_path
    end

    data.schema_version = data.schema_version or "1.0"
    data.default_expiry_days = data.default_expiry_days or 14
    data.quarantined_tests = data.quarantined_tests or {}
    return data, quarantine_path
end

local function build_quarantine_state()
    local data, path = TestRunner.load_quarantine()
    local now = os.time()
    local platform = detect_platform()
    local mode = detect_quarantine_mode()
    return {
        data = data,
        path = path,
        now = now,
        platform = platform,
        mode = mode,
    }
end

local function get_quarantine_state()
    if not TestRunner._quarantine_state then
        TestRunner._quarantine_state = build_quarantine_state()
    end
    return TestRunner._quarantine_state
end

local function compute_expired(entry, now_epoch)
    if not entry.expires_at then
        return true
    end
    local expiry_epoch = parse_iso_utc(entry.expires_at)
    if not expiry_epoch then
        return true
    end
    return now_epoch >= expiry_epoch
end

local function summarize_quarantine_entries(state)
    local active = {}
    local expired = {}

    for _, entry in ipairs(state.data.quarantined_tests or {}) do
        if entry.test_id and platform_matches(entry.platforms or { "*" }, state.platform) then
            local is_expired = compute_expired(entry, state.now)
            if is_expired then
                table.insert(expired, entry)
            else
                table.insert(active, entry)
            end
        end
    end

    return active, expired
end

function TestRunner.check_quarantine(test_id)
    if not test_id then
        return { quarantined = false }
    end
    local state = get_quarantine_state()
    for _, entry in ipairs(state.data.quarantined_tests or {}) do
        if entry.test_id == test_id and platform_matches(entry.platforms or { "*" }, state.platform) then
            return {
                quarantined = true,
                expired = compute_expired(entry, state.now),
                reason = entry.reason,
                owner = entry.owner,
                issue_link = entry.issue_link,
                expires_at = entry.expires_at,
                entry = entry,
            }
        end
    end
    return { quarantined = false }
end

local function log_quarantine_status(state)
    local active, expired = summarize_quarantine_entries(state)
    results.quarantine.active = #active
    results.quarantine.expired = #expired
    results.quarantine.mode = state.mode
    results.quarantine.expired_list = expired

    print("[QUARANTINE] === Quarantine Status ===")
    print(string.format("[QUARANTINE] Active quarantines: %d", #active))
    for _, entry in ipairs(active) do
        print(string.format("[QUARANTINE]   - %s (expires: %s)", entry.test_id, iso_date(entry.expires_at)))
    end
    for _, entry in ipairs(expired) do
        print(string.format("[QUARANTINE]   - %s (expires: %s, EXPIRED!)", entry.test_id, iso_date(entry.expires_at)))
    end
    print("")
end

local function log_quarantine_test(entry, status, mode, blocking)
    print(string.format("[QUARANTINE] Test: %s", entry.test_id))
    print(string.format("[QUARANTINE]   Status: %s", status))
    if entry.reason then
        print(string.format("[QUARANTINE]   Reason: %s", entry.reason))
    end
    if entry.owner then
        print(string.format("[QUARANTINE]   Owner: %s", entry.owner))
    end
    if entry.issue_link then
        print(string.format("[QUARANTINE]   Issue: %s", entry.issue_link))
    end
    if entry.expires_at then
        print(string.format("[QUARANTINE]   Expires: %s", iso_date(entry.expires_at)))
    end
    if blocking then
        print(string.format("[QUARANTINE]   Action: Error (%s)", mode))
    else
        print("[QUARANTINE]   Action: Warning only (PR CI)")
    end
    print("")
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
--- @param opts_or_fn table|function Options or test function
--- @param maybe_fn function? Test implementation if opts provided
function TestRunner.it(name, opts_or_fn, maybe_fn)
    if not current_suite then
        error("it() must be called inside a describe() block")
    end
    local opts = {}
    local fn = maybe_fn
    if type(opts_or_fn) == "function" then
        fn = opts_or_fn
    elseif type(opts_or_fn) == "table" then
        opts = opts_or_fn
    end
    if not fn then
        error("it() requires a test function")
    end
    table.insert(current_suite.tests, {
        name = name,
        fn = fn,
        test_id = opts.test_id,
        has_visual = opts.has_visual or opts.visual,
    })
end

--- Define a visual test case with quarantine metadata
--- @param name string Test description
--- @param test_id string Unique test identifier
--- @param fn function Test implementation
--- @param opts table? Additional metadata
function TestRunner.it_visual(name, test_id, fn, opts)
    opts = opts or {}
    opts.test_id = test_id
    opts.has_visual = true
    TestRunner.it(name, opts, fn)
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

--- Check if a test matches the current filter
--- @param suite_name string Suite name
--- @param test_name string Test name
--- @return boolean True if test matches filter or no filter set
local function matches_filter(suite_name, test_name)
    if not config.filter then return true end
    local full_name = suite_name .. " " .. test_name
    return full_name:lower():find(config.filter:lower()) ~= nil
end

--- Run a single test suite
function TestRunner._run_suite(suite, indent)
    indent = indent or ""
    local suite_start = get_time()
    local suite_has_matching_tests = false
    local quarantine_state = get_quarantine_state()

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
            -- (filtered tests are simply not run, not counted as skipped)
        elseif test.skip then
            -- Skipped test
            results.skipped = results.skipped + 1
            print(indent .. "  " .. COLORS.yellow .. "○ " .. test.name .. " (skipped)" .. COLORS.reset)
        else
            local test_start = get_time()

            -- Run before_each
            if suite.before_each then
                local ok, err = pcall(suite.before_each)
                if not ok then
                    local test_duration = get_time() - test_start
                    print(indent .. "  " .. COLORS.red .. "✗ " .. test.name .. " (before_each failed)" .. COLORS.reset)
                    print(indent .. "    " .. COLORS.dim .. tostring(err) .. COLORS.reset)
                    results.failed = results.failed + 1
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

            local test_id = test.test_id
            local quarantine_status = nil
            if test.has_visual then
                test_id = test_id or (suite.name .. "::" .. test.name)
                quarantine_status = TestRunner.check_quarantine(test_id)
                if quarantine_status.quarantined then
                    quarantine_status.entry.test_id = test_id
                end
            end

            -- Run test
            local ok, err = pcall(test.fn)
            local test_duration = get_time() - test_start

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

                -- Verbose mode: show that assertions passed
                if config.verbose then
                    print(indent .. "    " .. COLORS.dim .. "(all assertions passed)" .. COLORS.reset)
                end
            else
                local trace = format_stack_trace(err)
                local timing_str = config.show_timing and (" " .. COLORS.dim .. "(" .. format_duration(test_duration) .. ")" .. COLORS.reset) or ""

                if quarantine_status and quarantine_status.quarantined and test.has_visual then
                    local status = quarantine_status.expired and "quarantine_expired" or "quarantine_fail"
                    local blocking = quarantine_status.expired or quarantine_mode_blocks(quarantine_state.mode)

                    results.quarantine.failures = results.quarantine.failures + 1
                    table.insert(results.quarantine.failures_list, {
                        test_id = test_id,
                        status = status,
                        reason = quarantine_status.reason,
                        owner = quarantine_status.owner,
                        issue_link = quarantine_status.issue_link,
                        expires_at = quarantine_status.expires_at,
                        blocking = blocking,
                    })

                    if blocking then
                        results.failed = results.failed + 1
                        results.quarantine.blocking_failures = results.quarantine.blocking_failures + 1
                        table.insert(results.errors, {
                            suite = suite.name,
                            name = test.name .. " (" .. status .. ")",
                            error = err,
                            trace = trace,
                        })
                        print(indent .. "  " .. COLORS.red .. "✗ " .. test.name .. " (quarantined)" .. COLORS.reset .. timing_str)
                    else
                        print(indent .. "  " .. COLORS.yellow .. "⚠ " .. test.name .. " (quarantined)" .. COLORS.reset .. timing_str)
                    end

                    local entry = quarantine_status.entry or { test_id = test_id }
                    log_quarantine_test(entry, status, quarantine_state.mode, blocking)
                else
                    results.failed = results.failed + 1
                    table.insert(results.errors, {
                        suite = suite.name,
                        name = test.name,
                        error = err,
                        trace = trace,
                    })
                    print(indent .. "  " .. COLORS.red .. "✗ " .. test.name .. COLORS.reset .. timing_str)

                    -- Show inline error (always shown, but more detail in verbose mode)
                    if config.verbose then
                        print(indent .. "    " .. COLORS.dim .. tostring(err) .. COLORS.reset)
                        if trace and trace ~= "" then
                            for line in trace:gmatch("[^\n]+") do
                                print(indent .. "    " .. COLORS.dim .. line .. COLORS.reset)
                            end
                        end
                    else
                        -- Show just first line of error
                        local err_line = tostring(err):match("^[^\n]+") or tostring(err)
                        print(indent .. "    " .. COLORS.dim .. err_line .. COLORS.reset)
                    end
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

--- Run all registered test suites
--- @return boolean True if all tests passed
function TestRunner.run()
    results = init_results()
    local run_start = get_time()

    print("\n" .. COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)
    print(COLORS.cyan .. "                         TEST RESULTS" .. COLORS.reset)
    print(COLORS.cyan .. "═══════════════════════════════════════════════════════════════" .. COLORS.reset)

    -- Show active filter if set
    if config.filter then
        print(COLORS.yellow .. "  Filter: " .. config.filter .. COLORS.reset)
    end
    if config.verbose then
        print(COLORS.yellow .. "  Mode: verbose" .. COLORS.reset)
    end
    print("")

    TestRunner._quarantine_state = build_quarantine_state()
    log_quarantine_status(TestRunner._quarantine_state)

    for _, suite in ipairs(suites) do
        TestRunner._run_suite(suite)
        print("")
    end

    results.total_time = get_time() - run_start

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

        -- In verbose mode, show slowest tests
        if config.verbose and #results.timings > 0 then
            -- Sort by duration descending
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

    -- Quarantine summary
    print("\n[QUARANTINE] Summary:")
    local total_quarantined = results.quarantine.active + results.quarantine.expired
    print(string.format("[QUARANTINE]   Quarantined tests: %d", total_quarantined))
    print(string.format("[QUARANTINE]   Quarantine failures: %d", results.quarantine.failures))
    if results.quarantine.expired > 0 then
        print(string.format("[QUARANTINE]   Expired quarantines: %d (blocking!)", results.quarantine.expired))
    else
        print("[QUARANTINE]   Expired quarantines: 0")
    end

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

    local success = results.failed == 0 and results.quarantine.expired == 0
    local final_message
    if success then
        final_message = COLORS.green .. "✓ All tests passed!"
    elseif results.failed > 0 then
        final_message = COLORS.red .. "✗ Some tests failed"
    else
        final_message = COLORS.red .. "✗ Quarantine expired"
    end
    print("\n" .. final_message .. COLORS.reset .. "\n")

    return success
end

--- Alias for backwards compatibility
TestRunner.run_all = TestRunner.run

--- Reset all registered suites and results
function TestRunner.reset()
    suites = {}
    current_suite = nil
    results = init_results()
    -- Also reset config to defaults
    config.filter = nil
    config.verbose = false
    config.quarantine_path = "test_baselines/visual_quarantine.json"
    config.quarantine_mode = nil
    config.quarantine_platform = nil
    TestRunner._quarantine_state = nil
end

--- Get the results of the last test run
--- @return table Results with passed, failed, skipped, errors, timings, total_time
function TestRunner.get_results()
    return results
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
            -- Use os.execute with stat to get mtime (portable)
            local cmd
            if package.config:sub(1, 1) == "\\" then
                -- Windows - use forfiles
                cmd = 'forfiles /P "' .. filepath:match("(.+)[\\/]") .. '" /M "' .. filepath:match("[\\/]([^\\/]+)$") .. '" /C "cmd /c echo @fdate @ftime" 2>nul'
            else
                -- Unix - use stat
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
        -- Sleep for interval
        os.execute("sleep " .. interval)

        -- Check for changes
        local current_mtimes = get_file_mtimes(dir)
        local changed = false

        for filepath, mtime in pairs(current_mtimes) do
            if last_mtimes[filepath] ~= mtime then
                changed = true
                print("\n" .. COLORS.yellow .. "File changed: " .. filepath .. COLORS.reset)
                break
            end
        end

        -- Check for new files
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
--- @return table Parsed options with dir, filter, verbose, watch flags
local function parse_args(args)
    local opts = {
        dir = "./assets/scripts/tests",
        filter = nil,
        verbose = false,
        watch = false,
        help = false,
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
  -h, --help             Show this help message

Examples:
  lua test_runner.lua                          # Run all tests in default directory
  lua test_runner.lua ./my_tests               # Run tests in specific directory
  lua test_runner.lua --filter "vbox"          # Run only tests matching "vbox"
  lua test_runner.lua --verbose --filter text  # Verbose output for "text" tests
  lua test_runner.lua --watch                  # Watch mode with auto-rerun
]])
end

-- Check if running as main script (not test_test_runner.lua or similar)
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
    print("")

    if opts.watch then
        TestRunner.watch(opts.dir)
    else
        local success = TestRunner.run_directory(opts.dir)
        os.exit(success and 0 or 1)
    end
end

return TestRunner
