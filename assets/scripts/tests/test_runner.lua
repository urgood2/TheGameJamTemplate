-- assets/scripts/tests/test_runner.lua
local TestRunner = {}

local tests = {}
local results = { passed = 0, failed = 0, errors = {} }

function TestRunner.describe(name, fn)
    tests[name] = fn
end

function TestRunner.it(name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.passed = results.passed + 1
        print("[PASS] " .. name)
    else
        results.failed = results.failed + 1
        table.insert(results.errors, { name = name, error = err })
        print("[FAIL] " .. name .. ": " .. tostring(err))
    end
end

function TestRunner.assert_equals(expected, actual, msg)
    if expected ~= actual then
        error((msg or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

function TestRunner.assert_true(value, msg)
    if not value then
        error((msg or "Assertion failed") .. ": expected true, got " .. tostring(value))
    end
end

function TestRunner.assert_nil(value, msg)
    if value ~= nil then
        error((msg or "Assertion failed") .. ": expected nil, got " .. tostring(value))
    end
end

function TestRunner.assert_not_nil(value, msg)
    if value == nil then
        error((msg or "Assertion failed") .. ": expected non-nil value")
    end
end

function TestRunner.assert_table_contains(tbl, key, msg)
    if tbl[key] == nil then
        error((msg or "Assertion failed") .. ": table missing key " .. tostring(key))
    end
end

function TestRunner.run_all()
    results = { passed = 0, failed = 0, errors = {} }
    for name, fn in pairs(tests) do
        print("\n=== " .. name .. " ===")
        fn()
    end
    print("\n=== RESULTS ===")
    print("Passed: " .. results.passed)
    print("Failed: " .. results.failed)
    if #results.errors > 0 then
        print("\nFailures:")
        for _, e in ipairs(results.errors) do
            print("  - " .. e.name .. ": " .. e.error)
        end
    end
    return results.failed == 0
end

function TestRunner.reset()
    tests = {}
    results = { passed = 0, failed = 0, errors = {} }
end

return TestRunner
