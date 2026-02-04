-- assets/scripts/tests/run_bargain_tests.lua
--[[
================================================================================
BARGAIN HEADLESS TEST RUNNER
================================================================================
Entry point for running Bargain MVP tests in headless mode (no window/graphics).

Contract:
- Exit code 0 on success (set via BARGAIN_EXIT_CODE = 0)
- Exit code 1 on failure (set via BARGAIN_EXIT_CODE = 1)
- On failure: prints exactly ONE JSON repro line to stdout
- No other JSON-shaped output

Usage:
  RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template
]]

--------------------------------------------------------------------------------
-- Package path setup (safe for standalone execution)
--------------------------------------------------------------------------------

local function append_path(path)
    if not package.path:find(path, 1, true) then
        package.path = package.path .. ";" .. path
    end
end

append_path("./assets/scripts/?.lua")
append_path("./assets/scripts/?/init.lua")
append_path("./assets/scripts/tests/?.lua")
append_path("./assets/scripts/tests/?/init.lua")

--------------------------------------------------------------------------------
-- Headless markers (standalone convenience)
--------------------------------------------------------------------------------

if _G.HEADLESS_MODE == nil then
    _G.HEADLESS_MODE = true
end

if _G.BARGAIN_TEST_MODE == nil then
    _G.BARGAIN_TEST_MODE = true
end

--------------------------------------------------------------------------------
-- Repro helpers
--------------------------------------------------------------------------------

local repro = require("tests.bargain.repro_util")
local repro_state = repro.default_state()
local repro_emitted = false

local function emit_repro_once(overrides)
    if repro_emitted then
        return
    end
    repro_emitted = true
    repro.emit_repro(repro_state, overrides)
end

--------------------------------------------------------------------------------
-- Test suites to run
--------------------------------------------------------------------------------

local SUITES = {
    "tests.bargain.contracts_spec",
    "tests.bargain.sim_smoke_spec",
    "tests.bargain.repro_schema_spec",
    "tests.bargain.deals_loader_spec",
    "tests.bargain.deals_downside_spec",
    "tests.bargain.ai_spec",
    "tests.bargain.victory_death_spec",
    "tests.bargain.run_scripts_spec",
    "tests.bargain.digest_spec",
    "tests.bargain.determinism_static_spec",
    "tests.bargain.floors_spec",
    "tests.bargain.fov_spec",
}

--------------------------------------------------------------------------------
-- Main execution
--------------------------------------------------------------------------------

local t = require("tests.test_runner")
t.reset()

local load_errors = {}
for _, suite_name in ipairs(SUITES) do
    local ok, err = pcall(require, suite_name)
    if not ok then
        load_errors[#load_errors + 1] = { name = suite_name, error = tostring(err) }
        io.write(string.format("[ERROR] Failed to load %s: %s\n", suite_name, err))
    end
end

if #load_errors > 0 then
    _G.BARGAIN_TESTS_PASSED = false
    _G.BARGAIN_EXIT_CODE = 1
    emit_repro_once({ run_state = "death", phase = "INIT" })
    return
end

local all_passed = t.run()

_G.BARGAIN_TESTS_PASSED = all_passed
_G.BARGAIN_EXIT_CODE = all_passed and 0 or 1

if not all_passed then
    emit_repro_once({ run_state = "death" })
end

function run_bargain_tests()
    return _G.BARGAIN_EXIT_CODE or 1
end

return {
    emit_repro = emit_repro_once,
    passed = all_passed,
    exit_code = _G.BARGAIN_EXIT_CODE,
}
