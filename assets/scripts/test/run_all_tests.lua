-- assets/scripts/test/run_all_tests.lua
-- Canonical test runner entrypoint for the test suite.
--
-- Usage:
--   dofile("assets/scripts/test/run_all_tests.lua")
--
-- With filtering:
--   _G.TEST_FILTER = { category = "selftest" }
--   dofile("assets/scripts/test/run_all_tests.lua")
--
-- With sharding:
--   _G.TEST_SHARD = { index = 0, total = 4 }
--   dofile("assets/scripts/test/run_all_tests.lua")
--
-- Exit codes (via _G.TEST_EXIT_CODE):
--   0 = All tests passed
--   1 = Some tests failed
--   2 = Test harness error
--
-- Logging prefix: [RUN-ALL]

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local TEST_ROOT = "test"
local REPORT_DIR = "test_output"
local LOG_PREFIX = "[RUN-ALL]"

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function log(msg)
    print(LOG_PREFIX .. " " .. tostring(msg))
end

local function parse_env_filter()
    -- Check for environment-provided filter
    if _G.TEST_FILTER then
        return _G.TEST_FILTER
    end
    return nil
end

local function parse_env_shard()
    -- Check for environment-provided sharding
    if _G.TEST_SHARD then
        local shard = _G.TEST_SHARD
        if shard.index and shard.total and shard.total > 1 then
            return {
                index = shard.index,
                total = shard.total,
            }
        end
    end
    return nil
end

local function ensure_output_dir()
    -- Create output directory if it doesn't exist
    os.execute('mkdir -p "' .. REPORT_DIR .. '" 2>/dev/null')
    os.execute('mkdir "' .. REPORT_DIR .. '" 2>NUL')
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

local function main()
    log("=== Starting Test Suite ===")

    -- Ensure output directory
    ensure_output_dir()

    -- Load test runner
    local ok, TestRunner = pcall(require, TEST_ROOT .. ".test_runner")
    if not ok then
        log("ERROR: Failed to load test_runner: " .. tostring(TestRunner))
        _G.TEST_EXIT_CODE = 2
        return false
    end

    -- Load test modules list
    local modules_ok, modules = pcall(require, TEST_ROOT .. ".test_modules")
    if not modules_ok then
        log("ERROR: Failed to load test_modules: " .. tostring(modules))
        _G.TEST_EXIT_CODE = 2
        return false
    end

    log("Loading " .. #modules .. " test modules...")

    -- Load each test module
    local load_errors = 0
    for i, moduleName in ipairs(modules) do
        local load_ok, load_err = pcall(require, moduleName)
        if load_ok then
            log("  [" .. i .. "/" .. #modules .. "] Loaded: " .. moduleName)
        else
            log("  [" .. i .. "/" .. #modules .. "] FAILED: " .. moduleName .. " - " .. tostring(load_err))
            load_errors = load_errors + 1
        end
    end

    if load_errors > 0 then
        log("WARNING: " .. load_errors .. " module(s) failed to load")
    end

    -- Parse filter and shard
    local filter = parse_env_filter()
    local shard = parse_env_shard()

    if filter then
        log("Filter: " .. (filter.category or "all categories"))
        if filter.tags then
            log("  Tags: " .. table.concat(filter.tags, ", "))
        end
    end

    if shard then
        log("Sharding: shard " .. shard.index .. " of " .. shard.total)
    end

    -- Build run options
    local run_options = {}
    if filter then
        run_options.filter = filter
    end
    if shard then
        run_options.shard_index = shard.index
        run_options.shard_total = shard.total
    end

    -- Run tests
    log("Running tests...")
    local passed, failed, skipped = TestRunner:run(run_options)

    -- Generate reports
    log("Generating reports...")
    local report_path = REPORT_DIR .. "/report.md"
    local manifest_path = REPORT_DIR .. "/test_manifest.json"

    if TestRunner.write_report then
        local report_ok = pcall(TestRunner.write_report, TestRunner, report_path)
        if report_ok then
            log("  Report written to: " .. report_path)
        else
            log("  WARNING: Failed to write report")
        end
    end

    if TestRunner.write_manifest then
        local manifest_ok = pcall(TestRunner.write_manifest, TestRunner, manifest_path)
        if manifest_ok then
            log("  Manifest written to: " .. manifest_path)
        else
            log("  WARNING: Failed to write manifest")
        end
    end

    local coverage_ok, CoverageReport = pcall(require, TEST_ROOT .. ".test_coverage_report")
    if coverage_ok and CoverageReport and CoverageReport.generate then
        local coverage_path = REPORT_DIR .. "/coverage_report.md"
        local report_ok = CoverageReport.generate(REPORT_DIR .. "/results.json", coverage_path)
        if report_ok then
            log("  Coverage report written to: " .. coverage_path)
        else
            log("  WARNING: Failed to write coverage report")
        end
    else
        log("  WARNING: Failed to load coverage report generator")
    end

    -- Summary
    local total = (passed or 0) + (failed or 0) + (skipped or 0)
    log("=== Test Suite Complete ===")
    log("  Total:   " .. total)
    log("  Passed:  " .. (passed or 0))
    log("  Failed:  " .. (failed or 0))
    log("  Skipped: " .. (skipped or 0))

    -- Set exit code
    if (failed or 0) > 0 then
        _G.TEST_EXIT_CODE = 1
        log("RESULT: FAIL")
        return false
    else
        _G.TEST_EXIT_CODE = 0
        log("RESULT: PASS")
        return true
    end
end

-- Run main and capture any errors
local run_ok, run_result = pcall(main)
if not run_ok then
    log("FATAL: " .. tostring(run_result))
    _G.TEST_EXIT_CODE = 2
end

return _G.TEST_EXIT_CODE == 0
