#!/usr/bin/env lua
-- assets/scripts/tests/run_standalone.lua
--[[
================================================================================
STANDALONE TEST RUNNER
================================================================================
Runs tests using a standalone Lua interpreter WITHOUT the game engine.
Designed for CI environments (GitHub Actions) and fast local iteration.

Usage:
    lua assets/scripts/tests/run_standalone.lua [options]

Options:
    -f, --filter PATTERN   Filter tests by name pattern
    -v, --verbose          Show detailed assertion output
    -l, --list             List available standalone test files
    -h, --help             Show help

Examples:
    lua assets/scripts/tests/run_standalone.lua
    lua assets/scripts/tests/run_standalone.lua --filter "schema"
    lua assets/scripts/tests/run_standalone.lua --verbose

Requirements:
    - Lua 5.3+ or LuaJIT
    - Run from repository root directory
    - No game engine dependencies

Exit codes:
    0 = All tests passed
    1 = Some tests failed
    2 = Configuration error
]]

-- Set up package path for module loading
package.path = package.path .. ";./assets/scripts/?.lua"
package.path = package.path .. ";./assets/scripts/?/init.lua"

-- ANSI colors
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
    local no_color = os.getenv("NO_COLOR")
    if no_color then return false end
    return term and term ~= "dumb"
end

if not supports_colors() then
    for k in pairs(COLORS) do COLORS[k] = "" end
end

--------------------------------------------------------------------------------
-- Standalone Test Files
--------------------------------------------------------------------------------

-- Tests that are known to work in standalone mode (no game engine required)
local STANDALONE_TESTS = {
    -- Core framework tests
    "assets/scripts/tests/test_test_runner.lua",
    "assets/scripts/tests/test_expect_matchers.lua",
    "assets/scripts/tests/test_runner_features.lua",

    -- Schema & Validation
    "assets/scripts/tests/test_schema.lua",
    "assets/scripts/tests/test_dsl_strict.lua",
    "assets/scripts/tests/test_dsl_strict_primitives.lua",
    "assets/scripts/tests/test_dsl_strict_layouts.lua",
    "assets/scripts/tests/test_dsl_strict_interactive.lua",

    -- Showcase/Docs acceptance
    "assets/scripts/tests/test_primitive_showcases.lua",
    "assets/scripts/tests/test_layout_showcases.lua",
    "assets/scripts/tests/test_pattern_showcases.lua",
    "assets/scripts/tests/test_showcase_gallery.lua",

    -- Standalone detection (game-only feature errors)
    "assets/scripts/tests/test_standalone_detection.lua",
}

-- Tests that require the game engine (skip in standalone mode)
local GAME_ONLY_TESTS = {
    "test_avatar_system.lua",
    "test_behavior_registry.lua",
    "test_constants.lua",
    "test_content_loading.lua",
    "test_enemy_behaviors.lua",
    "test_enemy_projectiles.lua",
    "test_grid_transfer.lua",
    "test_imports_bundles.lua",
    "test_inventory_grid.lua",
    "test_jokers.lua",
    "test_lighting_state_gating.lua",
    "test_lua_api_improvements.lua",
    "test_modal.lua",
    "test_noita_spell_features.lua",
    "test_particle_builder.lua",
    "test_render_groups.lua",
    "test_render_groups_visual.lua",
    "test_shop_stat_systems.lua",
    "test_spawn.lua",
    "test_spell_types.lua",
    "test_sprite_ui.lua",
    "test_status_engine.lua",
    "test_tab_ui.lua",
    "test_text_builder.lua",
    "test_timer_scope.lua",
    "test_ui_pack.lua",
}

--------------------------------------------------------------------------------
-- Command Line Parsing
--------------------------------------------------------------------------------

local function parse_args(args)
    local opts = {
        filter = nil,
        verbose = false,
        list = false,
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
        elseif a == "--list" or a == "-l" then
            opts.list = true
        elseif a == "--help" or a == "-h" then
            opts.help = true
        end
        i = i + 1
    end

    return opts
end

local function print_help()
    print([[
Standalone Test Runner for CI and Local Development

Usage: lua assets/scripts/tests/run_standalone.lua [options]

Options:
  -f, --filter PATTERN   Filter tests by name pattern (case-insensitive)
  -v, --verbose          Show detailed assertion output
  -l, --list             List available standalone test files
  -h, --help             Show this help message

Examples:
  lua assets/scripts/tests/run_standalone.lua                 # Run all standalone tests
  lua assets/scripts/tests/run_standalone.lua --filter schema # Run only schema tests
  lua assets/scripts/tests/run_standalone.lua --verbose       # Detailed output

Exit Codes:
  0 = All tests passed
  1 = Some tests failed
  2 = Configuration error (e.g., Lua not found, wrong directory)

Notes:
  - Run from repository root directory
  - Tests requiring game engine are automatically skipped
  - CI-friendly: no graphics, no audio, no window
]])
end

local function list_tests()
    print(COLORS.cyan .. "Standalone Tests (will run):" .. COLORS.reset)
    for _, path in ipairs(STANDALONE_TESTS) do
        print("  " .. COLORS.green .. "+" .. COLORS.reset .. " " .. path)
    end

    print("")
    print(COLORS.yellow .. "Game-Only Tests (skipped in standalone mode):" .. COLORS.reset)
    for _, name in ipairs(GAME_ONLY_TESTS) do
        print("  " .. COLORS.dim .. "-" .. COLORS.reset .. " " .. name)
    end
end

--------------------------------------------------------------------------------
-- Test Execution
--------------------------------------------------------------------------------

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function run_test_file(filepath, opts)
    if not file_exists(filepath) then
        print(COLORS.yellow .. "  SKIP: " .. filepath .. " (file not found)" .. COLORS.reset)
        return true, 0  -- Not an error, just skip
    end

    -- Build command with options
    local cmd = 'lua "' .. filepath .. '"'
    if opts.filter then
        cmd = cmd .. ' --filter "' .. opts.filter .. '"'
    end
    if opts.verbose then
        cmd = cmd .. ' --verbose'
    end
    cmd = cmd .. ' 2>&1'

    local handle = io.popen(cmd)
    if not handle then
        print(COLORS.red .. "  FAIL: Could not execute " .. filepath .. COLORS.reset)
        return false, 1
    end

    local output = handle:read("*a")
    local ok, exit_type, exit_code = handle:close()

    -- Handle different Lua versions' return values
    local success
    if type(ok) == "boolean" then
        success = ok
    else
        -- Lua 5.1/LuaJIT style
        success = (exit_code == 0) or (exit_type == "exit" and exit_code == 0)
    end

    -- Print output
    print(output)

    return success, success and 0 or 1
end

--------------------------------------------------------------------------------
-- Main
--------------------------------------------------------------------------------

local function main(args)
    local opts = parse_args(args)

    if opts.help then
        print_help()
        os.exit(0)
    end

    if opts.list then
        list_tests()
        os.exit(0)
    end

    -- Check we're in the right directory
    if not file_exists("assets/scripts/tests/test_runner.lua") then
        print(COLORS.red .. "ERROR: Must run from repository root directory" .. COLORS.reset)
        print("Expected to find: assets/scripts/tests/test_runner.lua")
        os.exit(2)
    end

    -- Header
    local start_time = os.clock()

    print(COLORS.cyan .. "=================================================================================" .. COLORS.reset)
    print(COLORS.cyan .. COLORS.bold .. "                    STANDALONE LUA TESTS" .. COLORS.reset)
    print(COLORS.cyan .. "=================================================================================" .. COLORS.reset)
    print("")
    print("  Lua version: " .. _VERSION)
    print("  Running " .. #STANDALONE_TESTS .. " standalone test file(s)")
    if opts.filter then
        print("  Filter: " .. opts.filter)
    end
    if opts.verbose then
        print("  Mode: verbose")
    end
    print("")

    -- Run tests
    local total_passed = 0
    local total_failed = 0

    for _, filepath in ipairs(STANDALONE_TESTS) do
        print(COLORS.cyan .. "─────────────────────────────────────────────────────────────────────────────────" .. COLORS.reset)
        print(COLORS.cyan .. "Running: " .. COLORS.reset .. filepath)
        print("")

        local success, _ = run_test_file(filepath, opts)
        if success then
            total_passed = total_passed + 1
        else
            total_failed = total_failed + 1
        end
    end

    -- Summary
    local elapsed = os.clock() - start_time

    print(COLORS.cyan .. "=================================================================================" .. COLORS.reset)
    print(COLORS.cyan .. "                              SUMMARY" .. COLORS.reset)
    print(COLORS.cyan .. "=================================================================================" .. COLORS.reset)
    print("")
    print(string.format("  Test files: %d total", total_passed + total_failed))
    print(string.format("  " .. COLORS.green .. "Passed: %d" .. COLORS.reset, total_passed))
    if total_failed > 0 then
        print(string.format("  " .. COLORS.red .. "Failed: %d" .. COLORS.reset, total_failed))
    end
    print(string.format("  " .. COLORS.dim .. "Time: %.2fs" .. COLORS.reset, elapsed))
    print(string.format("  " .. COLORS.dim .. "Skipped (game-only): %d" .. COLORS.reset, #GAME_ONLY_TESTS))
    print("")

    if total_failed > 0 then
        print(COLORS.red .. COLORS.bold .. "FAILED" .. COLORS.reset .. " - Some tests did not pass")
        os.exit(1)
    else
        print(COLORS.green .. COLORS.bold .. "PASSED" .. COLORS.reset .. " - All standalone tests passed!")

        -- Performance check
        if elapsed > 5.0 then
            print(COLORS.yellow .. "WARNING: Tests took " .. string.format("%.2fs", elapsed) ..
                  " (target: <5s)" .. COLORS.reset)
        end

        os.exit(0)
    end
end

-- Run
main(arg or {})
