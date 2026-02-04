-- assets/scripts/tests/run_bargain_headless.lua
--[[
================================================================================
BARGAIN HEADLESS TEST RUNNER
================================================================================
Entry point for running Bargain MVP tests in headless mode (no window/graphics).

Contract:
- Exit code 0 on success
- Exit code 1 on failure
- On failure: prints exactly ONE JSON repro line to stdout
- No other JSON-shaped output
================================================================================
]]

-- Ensure package.path includes assets/scripts and tests directories
if not package.path:find("assets/scripts") then
    package.path = package.path ..
        ";./assets/scripts/?.lua" ..
        ";./assets/scripts/?/init.lua" ..
        ";./assets/scripts/tests/?.lua" ..
        ";./assets/scripts/tests/?/init.lua"
end

-- JSON encoder for repro output (minimal, no dependencies)
local function json_encode(val)
    local t = type(val)
    if t == "nil" then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then return tostring(val)
    elseif t == "string" then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif t == "table" then
        if next(val) == nil then
            return "{}"
        end
        -- Check if array
        local is_array = true
        local max_idx = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                is_array = false
                break
            end
            max_idx = math.max(max_idx, k)
        end
        if is_array and max_idx == #val then
            local parts = {}
            for i = 1, #val do
                parts[i] = json_encode(val[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            -- Sort keys for determinism
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                parts[#parts + 1] = json_encode(tostring(k)) .. ":" .. json_encode(val[k])
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return '"[' .. t .. ']"'
    end
end

-- Repro bundle state (required fields for deterministic replay)
local repro_state = {
    seed = 0,
    script_id = "HARNESS",
    floor_num = 0,
    turn = 0,
    phase = "INIT",
    run_state = "running",
    last_input = nil,
    pending_offer = nil,
    last_events = {},
    digest = "",
    digest_version = "bargain.v1",
    caps_hit = false,
    world_snapshot_path = nil,
    error_message = nil,
}

-- Emit repro JSON (exactly one line)
local function emit_repro(extra)
    local bundle = {}
    for k, v in pairs(repro_state) do
        bundle[k] = v
    end
    if extra then
        for k, v in pairs(extra) do
            bundle[k] = v
        end
    end
    print(json_encode(bundle))
end

--------------------------------------------------------------------------------
-- Test Framework (minimal, self-contained)
--------------------------------------------------------------------------------

local tests = {}
local current_suite = nil
local results = { passed = 0, failed = 0, errors = {} }

local function describe(name, fn)
    current_suite = { name = name, tests = {} }
    tests[#tests + 1] = current_suite
    fn()
    current_suite = nil
end

local function it(name, fn)
    if not current_suite then
        error("it() called outside of describe()")
    end
    current_suite.tests[#current_suite.tests + 1] = { name = name, fn = fn }
end

-- Minimal expect implementation
local function expect(actual)
    local negated = false
    local exp = {}

    function exp.never()
        negated = true
        return exp
    end

    local function check(condition, msg)
        local pass = condition
        if negated then pass = not pass end
        if not pass then
            error(msg, 3)
        end
    end

    function exp.to_be(expected)
        check(actual == expected,
            string.format("Expected %s to%s be %s",
                tostring(actual), negated and " not" or "", tostring(expected)))
    end

    function exp.to_equal(expected)
        local function deep_equal(a, b)
            if type(a) ~= type(b) then return false end
            if type(a) ~= "table" then return a == b end
            for k, v in pairs(a) do
                if not deep_equal(v, b[k]) then return false end
            end
            for k in pairs(b) do
                if a[k] == nil then return false end
            end
            return true
        end
        check(deep_equal(actual, expected),
            string.format("Expected tables to%s be equal", negated and " not" or ""))
    end

    function exp.to_be_truthy()
        check(actual, string.format("Expected %s to%s be truthy",
            tostring(actual), negated and " not" or ""))
    end

    function exp.to_be_falsy()
        check(not actual, string.format("Expected %s to%s be falsy",
            tostring(actual), negated and " not" or ""))
    end

    function exp.to_be_nil()
        check(actual == nil, string.format("Expected %s to%s be nil",
            tostring(actual), negated and " not" or ""))
    end

    function exp.to_be_type(expected_type)
        check(type(actual) == expected_type,
            string.format("Expected type %s but got %s", expected_type, type(actual)))
    end

    function exp.to_throw(pattern)
        local ok, err = pcall(actual)
        local threw = not ok
        local matches = threw and (not pattern or tostring(err):match(pattern))
        check(threw and matches,
            string.format("Expected function to%s throw%s",
                negated and " not" or "",
                pattern and (" matching '" .. pattern .. "'") or ""))
    end

    function exp.to_contain(substring)
        local matches = type(actual) == "string" and actual:find(substring, 1, true) ~= nil
        check(matches, string.format("Expected %q to%s contain %q",
            tostring(actual), negated and " not" or "", tostring(substring)))
    end

    return exp
end

-- Run all tests
local function run_tests()
    io.write("\n=== Bargain Test Suite ===\n\n")

    for _, suite in ipairs(tests) do
        io.write(string.format("  %s\n", suite.name))

        for _, test in ipairs(suite.tests) do
            local ok, err = xpcall(test.fn, debug.traceback)
            if ok then
                results.passed = results.passed + 1
                io.write(string.format("    [PASS] %s\n", test.name))
            else
                results.failed = results.failed + 1
                results.errors[#results.errors + 1] = {
                    suite = suite.name,
                    test = test.name,
                    error = err
                }
                io.write(string.format("    [FAIL] %s\n", test.name))
                io.write(string.format("           %s\n", tostring(err):match("^[^\n]*")))
            end
        end
        io.write("\n")
    end

    -- Summary
    local total = results.passed + results.failed
    io.write(string.format("Results: %d/%d passed", results.passed, total))
    if results.failed > 0 then
        io.write(string.format(" (%d failed)", results.failed))
    end
    io.write("\n\n")

    return results.failed == 0
end

--------------------------------------------------------------------------------
-- Export test API
--------------------------------------------------------------------------------

local M = {
    describe = describe,
    it = it,
    expect = expect,
    run = run_tests,
    emit_repro = emit_repro,
    repro_state = repro_state,
    json_encode = json_encode,
    results = results,
}

--------------------------------------------------------------------------------
-- Load and run test suites
--------------------------------------------------------------------------------

local SUITES = {
    "tests.bargain.contracts_spec",
    "tests.bargain.determinism_static_spec",
    -- Future suites:
    -- "tests.bargain.repro_schema_spec",
    -- "tests.bargain.sim_smoke_spec",
}

local function load_suites()
    _G.bargain_test = M
    local load_errors = {}
    for _, suite_name in ipairs(SUITES) do
        local ok, err = pcall(require, suite_name)
        if not ok then
            load_errors[#load_errors + 1] = { suite = suite_name, error = err }
        end
    end
    return load_errors
end

local function run_all()
    results.passed = 0
    results.failed = 0
    results.errors = {}

    local load_errors = load_suites()
    local all_passed = run_tests()
    local success = all_passed and #load_errors == 0

    if not success then
        if #load_errors > 0 then
            local names = {}
            for _, entry in ipairs(load_errors) do
                names[#names + 1] = entry.suite
            end
            repro_state.error_message = "Failed to load: " .. table.concat(names, ", ")
        elseif #results.errors > 0 then
            local first_err = results.errors[1]
            repro_state.error_message = string.format("%s::%s: %s",
                first_err.suite, first_err.test,
                tostring(first_err.error):match("^[^\n]*"))
        else
            repro_state.error_message = "Test failure"
        end
        emit_repro()
    end

    return success
end

-- Expose global entry point for C++ harness
_G.run_bargain_tests = function()
    return run_all()
end

-- Standalone execution (avoid auto-run in C++ harness)
if not rawget(_G, "BARGAIN_TEST_MODE") then
    if arg and arg[0] and arg[0]:match("run_bargain_headless%.lua$") then
        local passed = run_all()
        os.exit(passed and 0 or 1)
    end
end

return M
