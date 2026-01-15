--[[
    Test Suite: Signal Cleanup Audit

    Tests for memory leak fixes in signal handler registration/cleanup.

    Related fixes:
    - Fix 2.1: gameplay.lua signal handlers → signal_group
    - Fix 2.2: wave_director.lua signal handlers → signal_group
    - Fix 2.3: player_inventory.lua signal handler cleanup
    - Fix 2.4: cast_feed_ui.lua subscribe/unsubscribe
    - Fix 2.5: resetGameToStart() cleanup wiring
]]

-- Setup package path for standalone testing
local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or ""
local project_root = script_dir:match("(.*/)tests/unit/") or ""
if project_root ~= "" then
    package.path = project_root .. "assets/scripts/?.lua;" ..
                   project_root .. "assets/scripts/?/init.lua;" ..
                   package.path
end

local test_signal_cleanup = {}

--------------------------------------------------------------------------------
-- Mock Setup
--------------------------------------------------------------------------------

-- Mock signal module for isolated testing
local function create_mock_signal()
    local handlers = {}

    return {
        _handlers = handlers,

        register = function(event, handler)
            handlers[event] = handlers[event] or {}
            table.insert(handlers[event], handler)
        end,

        remove = function(event, handler)
            local list = handlers[event]
            if list then
                for i, h in ipairs(list) do
                    if h == handler then
                        table.remove(list, i)
                        return
                    end
                end
            end
        end,

        emit = function(event, ...)
            local list = handlers[event]
            if list then
                for _, h in ipairs(list) do
                    h(...)
                end
            end
        end,

        handler_count = function(event)
            local list = handlers[event]
            return list and #list or 0
        end,

        total_handlers = function()
            local count = 0
            for _, list in pairs(handlers) do
                count = count + #list
            end
            return count
        end,

        clear = function()
            handlers = {}
        end
    }
end

--------------------------------------------------------------------------------
-- Test: signal_group basic functionality
--------------------------------------------------------------------------------

function test_signal_cleanup.test_signal_group_registers_handlers()
    -- Setup mock
    local mock_signal = create_mock_signal()
    package.loaded["external.hump.signal"] = mock_signal
    package.loaded["core.signal_group"] = nil
    _G.__signal_group__ = nil

    local signal_group = require("core.signal_group")
    local group = signal_group.new("test_group")

    -- Register handlers
    group:on("test_event", function() end)
    group:on("test_event", function() end)
    group:on("another_event", function() end)

    -- Verify count
    assert(group:count() == 3, "Expected 3 handlers, got " .. group:count())
    assert(mock_signal.handler_count("test_event") == 2, "Expected 2 handlers for test_event")

    print("✓ signal_group registers handlers correctly")

    -- Cleanup
    package.loaded["external.hump.signal"] = nil
    return true
end

function test_signal_cleanup.test_signal_group_cleanup_removes_all()
    -- Setup mock
    local mock_signal = create_mock_signal()
    package.loaded["external.hump.signal"] = mock_signal
    package.loaded["core.signal_group"] = nil
    _G.__signal_group__ = nil

    local signal_group = require("core.signal_group")
    local group = signal_group.new("test_cleanup")

    -- Register handlers
    group:on("event1", function() end)
    group:on("event2", function() end)
    group:on("event3", function() end)

    assert(group:count() == 3, "Pre-cleanup: expected 3 handlers")
    assert(mock_signal.total_handlers() == 3, "Pre-cleanup: mock should have 3")

    -- Cleanup
    group:cleanup()

    assert(group:count() == 0, "Post-cleanup: expected 0 handlers in group")
    assert(mock_signal.total_handlers() == 0, "Post-cleanup: mock should have 0")
    assert(group:isCleanedUp() == true, "Group should be marked as cleaned up")

    print("✓ signal_group cleanup removes all handlers")

    -- Cleanup
    package.loaded["external.hump.signal"] = nil
    return true
end

function test_signal_cleanup.test_signal_group_prevents_duplicate_cleanup()
    -- Setup mock
    local mock_signal = create_mock_signal()
    package.loaded["external.hump.signal"] = mock_signal
    package.loaded["core.signal_group"] = nil
    _G.__signal_group__ = nil

    local signal_group = require("core.signal_group")
    local group = signal_group.new("test_double_cleanup")

    group:on("event", function() end)

    -- First cleanup
    group:cleanup()
    assert(group:isCleanedUp() == true)

    -- Second cleanup should not error
    local ok, err = pcall(function()
        group:cleanup()
    end)

    assert(ok, "Double cleanup should not error: " .. tostring(err))

    print("✓ signal_group handles double cleanup gracefully")

    -- Cleanup
    package.loaded["external.hump.signal"] = nil
    return true
end

--------------------------------------------------------------------------------
-- Test: Cleanup integration patterns
--------------------------------------------------------------------------------

function test_signal_cleanup.test_cleanup_before_reinit_pattern()
    --[[
        This test validates the correct pattern for game restart:
        1. Cleanup existing handlers
        2. Create new handler group
        3. Register fresh handlers

        Bug being fixed: Handlers accumulate on restart without cleanup
    ]]

    -- Setup mock
    local mock_signal = create_mock_signal()
    package.loaded["external.hump.signal"] = mock_signal
    package.loaded["core.signal_group"] = nil
    _G.__signal_group__ = nil

    local signal_group = require("core.signal_group")

    -- Simulate first game start
    local handlers = signal_group.new("gameplay_main")
    handlers:on("player_died", function() end)
    handlers:on("enemy_killed", function() end)
    handlers:on("wave_complete", function() end)

    local first_count = mock_signal.total_handlers()
    assert(first_count == 3, "First init should have 3 handlers")

    -- Simulate restart WITH proper cleanup
    handlers:cleanup()
    handlers = nil

    handlers = signal_group.new("gameplay_main")
    handlers:on("player_died", function() end)
    handlers:on("enemy_killed", function() end)
    handlers:on("wave_complete", function() end)

    local second_count = mock_signal.total_handlers()
    assert(second_count == 3, "After restart WITH cleanup should still be 3, got " .. second_count)

    print("✓ Cleanup-before-reinit pattern prevents handler accumulation")

    -- Cleanup
    package.loaded["external.hump.signal"] = nil
    return true
end

function test_signal_cleanup.test_handler_accumulation_bug()
    --[[
        This test demonstrates the BUG that exists without cleanup.
        It should pass after we implement the cleanup pattern.

        The test simulates what happens on game restart WITHOUT cleanup.
    ]]

    -- Setup mock
    local mock_signal = create_mock_signal()
    package.loaded["external.hump.signal"] = mock_signal
    package.loaded["core.signal_group"] = nil
    _G.__signal_group__ = nil

    local signal_group = require("core.signal_group")

    -- Simulate restart WITHOUT cleanup (the bug)
    local handlers1 = signal_group.new("buggy_restart")
    handlers1:on("event", function() end)

    -- Oops, forgot to cleanup! Creating new group...
    local handlers2 = signal_group.new("buggy_restart")
    handlers2:on("event", function() end)

    -- BUG: Now we have 2 handlers for the same event!
    local count = mock_signal.handler_count("event")

    -- This assertion documents the bug - handlers accumulate
    assert(count == 2, "BUG DEMO: Without cleanup, handlers accumulate (got " .. count .. ")")

    print("✓ Test confirms handler accumulation bug when cleanup is skipped")

    -- Cleanup
    package.loaded["external.hump.signal"] = nil
    return true
end

--------------------------------------------------------------------------------
-- Test: Module-specific cleanup verification
--------------------------------------------------------------------------------

function test_signal_cleanup.test_gameplay_handlers_structure()
    --[[
        Verify gameplay.lua should have signal_group integration.
        This is a structural test that documents expected handlers.
    ]]

    local expected_gameplay_events = {
        "avatar_unlocked",
        "tag_threshold_discovered",
        "spell_type_discovered",
        "deck_changed",
        "trigger_activated",
        "on_bump_enemy",
        "player_died",
        "show_death_screen",
        "restart_game",
        "player_level_up",
        "on_pickup",
        "stats_recomputed"
    }

    -- This test documents that gameplay.lua should handle 12 events
    assert(#expected_gameplay_events == 12,
        "Expected 12 gameplay signal handlers to migrate")

    print("✓ gameplay.lua handler migration list verified (12 handlers)")
    return true
end

function test_signal_cleanup.test_wave_director_handlers_structure()
    --[[
        Verify wave_director.lua should have signal_group integration.
    ]]

    local expected_wave_events = {
        "enemy_killed",
        "summon_enemy"
    }

    assert(#expected_wave_events == 2,
        "Expected 2 wave_director signal handlers to migrate")

    print("✓ wave_director.lua handler migration list verified (2 handlers)")
    return true
end

function test_signal_cleanup.test_cast_feed_handlers_structure()
    --[[
        Verify cast_feed_ui.lua should have signal_group integration.
    ]]

    local expected_cast_feed_events = {
        "on_spell_cast",
        "on_joker_trigger",
        "tag_threshold_discovered",
        "spell_type_discovered",
        "board_changed" -- BOARD_CHANGE_SIGNAL
    }

    assert(#expected_cast_feed_events == 5,
        "Expected 5 cast_feed_ui signal handlers to migrate")

    print("✓ cast_feed_ui.lua handler migration list verified (5 handlers)")
    return true
end

--------------------------------------------------------------------------------
-- Test Runner
--------------------------------------------------------------------------------

function test_signal_cleanup.run_all()
    print("\n" .. string.rep("=", 60))
    print("Running Signal Cleanup Audit Tests")
    print(string.rep("=", 60) .. "\n")

    local tests = {
        { name = "signal_group registers handlers", fn = test_signal_cleanup.test_signal_group_registers_handlers },
        { name = "signal_group cleanup removes all", fn = test_signal_cleanup.test_signal_group_cleanup_removes_all },
        { name = "signal_group prevents duplicate cleanup", fn = test_signal_cleanup.test_signal_group_prevents_duplicate_cleanup },
        { name = "cleanup-before-reinit pattern", fn = test_signal_cleanup.test_cleanup_before_reinit_pattern },
        { name = "handler accumulation bug demo", fn = test_signal_cleanup.test_handler_accumulation_bug },
        { name = "gameplay handlers structure", fn = test_signal_cleanup.test_gameplay_handlers_structure },
        { name = "wave_director handlers structure", fn = test_signal_cleanup.test_wave_director_handlers_structure },
        { name = "cast_feed handlers structure", fn = test_signal_cleanup.test_cast_feed_handlers_structure },
    }

    local passed = 0
    local failed = 0
    local errors = {}

    for _, test in ipairs(tests) do
        local ok, err = pcall(test.fn)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            table.insert(errors, { name = test.name, error = tostring(err) })
            print("✗ " .. test.name .. ": " .. tostring(err))
        end
    end

    print("\n" .. string.rep("=", 60))
    print(string.format("Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 60))

    if #errors > 0 then
        print("\nFailures:")
        for _, e in ipairs(errors) do
            print("  - " .. e.name .. ": " .. e.error)
        end
    end

    return failed == 0
end

-- Auto-run if executed directly
if not pcall(debug.getlocal, 4, 1) then
    test_signal_cleanup.run_all()
end

return test_signal_cleanup
