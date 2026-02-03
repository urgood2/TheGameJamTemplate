-- test_smoke.lua
-- Minimal harness validation tests (runs without engine scene).
--
-- Phase 1 (bd-12l.9): Smoke tests to validate harness plumbing
--
-- PURPOSE: These tests should pass BEFORE any other tests run.
-- If smoke tests fail, the harness is not ready for use.
--
-- USAGE: Run this module first to verify environment is properly set up.
--   lua assets/scripts/test/run_smoke.lua
-- OR via test runner:
--   TestRunner:run({tags = {"smoke"}})
--
-- Logging prefix: [SMOKE]

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

-- Try to load capabilities for environment info
local Capabilities = nil
pcall(function() Capabilities = require("test.capabilities") end)

--------------------------------------------------------------------------------
-- Environment Logging
--------------------------------------------------------------------------------

local function log_environment()
    print("[SMOKE] ========================================")
    print("[SMOKE] Starting smoke test suite...")
    print("[SMOKE] ========================================")

    -- Lua version
    local lua_version = _VERSION or "unknown"
    print(string.format("[SMOKE] Lua version: %s", lua_version))

    -- LuaJIT detection
    if jit then
        print(string.format("[SMOKE] LuaJIT: %s (%s/%s)", jit.version, jit.os, jit.arch))
    end

    -- Platform info
    if Capabilities then
        local caps = Capabilities.detect()
        print(string.format("[SMOKE] Platform: %s", caps.environment.platform))
        print(string.format("[SMOKE] Resolution: %s @ %.1fx DPI", caps.environment.resolution, caps.environment.dpi_scale))
        print(string.format("[SMOKE] Renderer: %s", caps.environment.renderer))

        -- Gate summary
        print("[SMOKE] Go/No-Go Gates:")
        for gate, passed in pairs(caps.gates) do
            print(string.format("[SMOKE]   %s: %s", gate, passed and "PASS" or "FAIL"))
        end
    else
        print("[SMOKE] Capabilities module not available")
    end

    print("[SMOKE] ----------------------------------------")
end

-- Log environment on module load
log_environment()

--------------------------------------------------------------------------------
-- Smoke Tests
--------------------------------------------------------------------------------

-- Smoke test 1: Basic assertions work
TestRunner.register("smoke.assertion.basic", "smoke", function()
    print("[SMOKE] Checking: basic assertion...")
    test_utils.assert_eq(1 + 1, 2, "Basic math works")
    test_utils.assert_eq("hello", "hello", "String equality works")
    test_utils.assert_neq(1, 2, "Inequality works")
    test_utils.assert_true(true, "True is true")
    test_utils.assert_false(false, "False is false")
    test_utils.assert_nil(nil, "Nil is nil")
    test_utils.assert_not_nil({}, "Table is not nil")
    print("[SMOKE] Checking: basic assertion... PASS")
end, {
    tags = {"smoke", "selftest"},
    self_test = true,
    doc_ids = {},
})

-- Smoke test 2: Advanced assertions work
TestRunner.register("smoke.assertion.advanced", "smoke", function()
    print("[SMOKE] Checking: advanced assertions...")
    test_utils.assert_gt(5, 3, "Greater than works")
    test_utils.assert_gte(5, 5, "Greater than or equal works")
    test_utils.assert_lt(3, 5, "Less than works")
    test_utils.assert_lte(5, 5, "Less than or equal works")
    test_utils.assert_contains("hello world", "world", "Contains works")
    -- assert_throws and assert_error just verify the function throws
    test_utils.assert_throws(function() error("expected error") end)
    test_utils.assert_error(function() error("another error") end)
    print("[SMOKE] Checking: advanced assertions... PASS")
end, {
    tags = {"smoke", "selftest"},
    self_test = true,
    doc_ids = {},
})

-- Smoke test 3: safe_filename works
TestRunner.register("smoke.safe_filename", "smoke", function()
    print("[SMOKE] Checking: safe_filename...")
    local input = "ui.UIBox Alignment TEST"
    local safe = test_utils.safe_filename(input)
    -- Should be lowercase, special chars replaced
    test_utils.assert_true(safe:find("ui") ~= nil, "Contains 'ui'")
    test_utils.assert_true(safe:find(" ") == nil, "No spaces")
    print(string.format("[SMOKE] Checking: safe_filename... PASS (input='%s' -> '%s')", input, safe))
end, {
    tags = {"smoke", "selftest"},
    self_test = true,
    doc_ids = {},
})

-- Smoke test 4: Screenshot capture (with or without engine)
TestRunner.register("smoke.screenshot.placeholder", "smoke", function()
    print("[SMOKE] Checking: screenshot capture...")
    local path = test_utils.capture_screenshot("smoke_test_screenshot")
    local handle = io.open(path, "rb")
    test_utils.assert_not_nil(handle, "Screenshot file should exist")
    if handle then
        local size = handle:seek("end")
        handle:close()
        print(string.format("[SMOKE] Checking: screenshot capture... PASS (wrote %s, %d bytes)", path, size))
    end
end, {
    tags = {"smoke", "selftest", "visual"},
    self_test = true,
    doc_ids = {},
})

-- Smoke test 5: World reset works
TestRunner.register("smoke.reset.world", "smoke", function()
    print("[SMOKE] Checking: world reset...")
    -- This should not error
    test_utils.reset_world()
    -- Verify RNG was seeded (should give deterministic result)
    math.randomseed(test_utils.DEFAULT_SEED)
    local first = math.random()
    math.randomseed(test_utils.DEFAULT_SEED)
    local second = math.random()
    test_utils.assert_eq(first, second, "RNG seeding is deterministic")
    print("[SMOKE] Checking: world reset... PASS")
end, {
    tags = {"smoke", "selftest"},
    self_test = true,
    doc_ids = {},
})

-- Smoke test 6: Test output directory is writable
TestRunner.register("smoke.output.writable", "smoke", function()
    print("[SMOKE] Checking: output directory writable...")
    test_utils.ensure_output_dirs()
    local test_file = "test_output/smoke_write_test.txt"
    -- write_file throws on error, so if this succeeds, we're good
    test_utils.write_file(test_file, "smoke test")
    -- Verify the file exists
    local handle = io.open(test_file, "r")
    test_utils.assert_not_nil(handle, "Should be able to read written file")
    if handle then
        handle:close()
    end
    -- Clean up
    os.remove(test_file)
    print("[SMOKE] Checking: output directory writable... PASS")
end, {
    tags = {"smoke", "selftest"},
    self_test = true,
    doc_ids = {},
})

-- Smoke test 7: Test registry works
TestRunner.register("smoke.registry.basic", "smoke", function()
    print("[SMOKE] Checking: test registry...")
    local TestRegistry = require("test.test_registry_runtime")
    -- Registry should be loadable and have basic methods
    test_utils.assert_not_nil(TestRegistry.register, "Registry has register method")
    test_utils.assert_not_nil(TestRegistry.all, "Registry has all method")
    test_utils.assert_not_nil(TestRegistry.doc_index, "Registry has doc_index method")
    test_utils.assert_not_nil(TestRegistry.coverage_summary, "Registry has coverage_summary method")
    print("[SMOKE] Checking: test registry... PASS")
end, {
    tags = {"smoke", "selftest"},
    self_test = true,
    doc_ids = {},
})

-- Smoke test 8: Capabilities detection works
TestRunner.register("smoke.capabilities.detect", "smoke", function()
    print("[SMOKE] Checking: capabilities detection...")
    if not Capabilities then
        print("[SMOKE] Capabilities module not available, skipping")
        return
    end
    local caps = Capabilities.detect()
    test_utils.assert_not_nil(caps.schema_version, "Has schema_version")
    test_utils.assert_not_nil(caps.gates, "Has gates")
    test_utils.assert_not_nil(caps.capabilities, "Has capabilities")
    test_utils.assert_not_nil(caps.environment, "Has environment")
    print("[SMOKE] Checking: capabilities detection... PASS")
end, {
    tags = {"smoke", "selftest"},
    self_test = true,
    doc_ids = {},
})

--------------------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------------------

print("[SMOKE] Smoke tests registered. Run with tags={'smoke'} to execute.")
print("[SMOKE] ========================================")

return true
