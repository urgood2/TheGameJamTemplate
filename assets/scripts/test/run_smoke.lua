#!/usr/bin/env lua
-- assets/scripts/test/run_smoke.lua
-- Standalone smoke test runner for harness validation.
--
-- Phase 1 (bd-12l.9): Smoke test entry point
--
-- Usage:
--   lua5.4 assets/scripts/test/run_smoke.lua
--   # OR from project root with package path:
--   cd /path/to/project && lua5.4 -e "package.path='assets/scripts/?.lua;'..package.path" assets/scripts/test/run_smoke.lua
--
-- Exit codes:
--   0 = All smoke tests passed
--   1 = One or more smoke tests failed

-- Setup package path
package.path = "assets/scripts/?.lua;assets/scripts/?/init.lua;" .. package.path

print("========================================")
print("SMOKE TEST RUNNER")
print("========================================")
print()

-- Load the test runner
local ok, TestRunner = pcall(require, "test.test_runner")
if not ok then
    print("[SMOKE] CRITICAL: Failed to load test_runner.lua")
    print("[SMOKE] Error: " .. tostring(TestRunner))
    os.exit(1)
end

-- Load self-tests if available
pcall(dofile, "assets/scripts/test/test_selftest.lua")

-- Load smoke tests (this registers them)
local smoke_ok, smoke_err = pcall(dofile, "assets/scripts/test/test_smoke.lua")
if not smoke_ok then
    print("[SMOKE] CRITICAL: Failed to load test_smoke.lua")
    print("[SMOKE] Error: " .. tostring(smoke_err))
    os.exit(1)
end

-- Run tests
print()
print("[SMOKE] Running smoke tests...")
print()

local success = TestRunner.run({
    tags = {"smoke"},
    output_dir = "test_output",
    verbose = true,
})

local function load_status()
    local ok, json = pcall(require, "external.json")
    if not ok or not json or not json.decode then
        return nil
    end
    local file = io.open("test_output/status.json", "r")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()
    local parsed_ok, data = pcall(json.decode, content)
    if not parsed_ok then
        return nil
    end
    return data
end

local status = load_status()
local results = {
    passed = status and status.passed_count or (success and 1 or 0),
    failed = status and status.failed or (success and 0 or 1),
    skipped = status and status.skipped or 0,
}

-- Report results
print()
print("========================================")
if results.failed == 0 then
    print("[SMOKE] All smoke tests passed. Harness ready for use.")
    print(string.format("[SMOKE] Passed: %d, Failed: %d, Skipped: %d",
        results.passed or 0, results.failed or 0, results.skipped or 0))
    print("========================================")
    os.exit(0)
else
    print("[SMOKE] CRITICAL: Smoke tests failed!")
    print(string.format("[SMOKE] Passed: %d, Failed: %d, Skipped: %d",
        results.passed or 0, results.failed or 0, results.skipped or 0))
    print("[SMOKE] Harness is NOT ready. Fix environment before proceeding.")
    print("========================================")
    os.exit(1)
end
