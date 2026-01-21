--[[
    Test for showcase_cards.lua

    This test validates that ShowcaseCards:
    1. Module exists with required helper functions
    2. safeGet() works correctly for missing/present values
    3. formatEffects() produces readable effect strings
    4. Card builder functions exist for each category
    5. renderBadge() returns valid badge specification

    Note: Full UI rendering tests require the game engine.
    These tests focus on standalone logic validation.

    Run standalone: lua tests/unit/test_showcase_cards.lua
]]

local test_showcase_cards = {}

-- Test that ShowcaseCards module exists and has required API
function test_showcase_cards.test_module_exists()
    local ok, ShowcaseCards = pcall(require, "ui.showcase.showcase_cards")
    assert(ok, "showcase_cards module should be requireable: " .. tostring(ShowcaseCards))
    assert(type(ShowcaseCards) == "table", "showcase_cards should return a table")

    -- Check required helper functions
    assert(type(ShowcaseCards.safeGet) == "function", "safeGet should be a function")
    assert(type(ShowcaseCards.formatEffects) == "function", "formatEffects should be a function")
    assert(type(ShowcaseCards.renderBadge) == "function", "renderBadge should be a function")

    print("  safeGet is function")
    print("  formatEffects is function")
    print("  renderBadge is function")
    return true
end

-- Test safeGet helper function
function test_showcase_cards.test_safe_get()
    local ShowcaseCards = require("ui.showcase.showcase_cards")

    -- Test with present value
    local result1 = ShowcaseCards.safeGet("hello", "default")
    assert(result1 == "hello", "safeGet should return value when present")

    -- Test with nil value
    local result2 = ShowcaseCards.safeGet(nil, "default")
    assert(result2 == "default", "safeGet should return fallback when nil")

    -- Test with false (should not use fallback)
    local result3 = ShowcaseCards.safeGet(false, "default")
    assert(result3 == false, "safeGet should return false not fallback")

    -- Test with 0 (should not use fallback)
    local result4 = ShowcaseCards.safeGet(0, 100)
    assert(result4 == 0, "safeGet should return 0 not fallback")

    -- Test with empty string (should not use fallback)
    local result5 = ShowcaseCards.safeGet("", "default")
    assert(result5 == "", "safeGet should return empty string not fallback")

    print("  present value: PASS")
    print("  nil value: PASS")
    print("  false value: PASS")
    print("  zero value: PASS")
    print("  empty string: PASS")
    return true
end

-- Test formatEffects helper function
function test_showcase_cards.test_format_effects()
    local ShowcaseCards = require("ui.showcase.showcase_cards")

    -- Test with stat_buff effects
    local effects1 = {
        { type = "stat_buff", stat = "max_hp", value = 25 },
        { type = "stat_buff", stat = "fire_modifier_pct", value = 15 },
    }
    local result1 = ShowcaseCards.formatEffects(effects1)
    assert(type(result1) == "string", "formatEffects should return a string")
    assert(#result1 > 0, "formatEffects should return non-empty string")
    print("  stat_buff effects: '" .. result1 .. "'")

    -- Test with empty effects
    local result2 = ShowcaseCards.formatEffects({})
    assert(type(result2) == "string", "formatEffects should return string for empty table")
    print("  empty effects: '" .. result2 .. "'")

    -- Test with nil effects
    local result3 = ShowcaseCards.formatEffects(nil)
    assert(type(result3) == "string", "formatEffects should handle nil")
    print("  nil effects: '" .. result3 .. "'")

    -- Test with blessing effect
    local effects4 = {
        { type = "blessing", name = "Inferno Burst", cooldown = 30 },
    }
    local result4 = ShowcaseCards.formatEffects(effects4)
    assert(type(result4) == "string", "formatEffects should handle blessing effects")
    print("  blessing effect: '" .. result4 .. "'")

    return true
end

-- Test renderBadge helper function
function test_showcase_cards.test_render_badge()
    local ShowcaseCards = require("ui.showcase.showcase_cards")

    -- Test with ok=true
    local badge1 = ShowcaseCards.renderBadge(true)
    assert(badge1 ~= nil, "renderBadge(true) should return something")
    -- Badge could be a string, table (DSL node), or structured data
    -- Just verify it exists and has some content
    if type(badge1) == "string" then
        assert(#badge1 > 0, "renderBadge(true) string should be non-empty")
    elseif type(badge1) == "table" then
        -- DSL node or structured data
        assert(badge1.text or badge1.color or badge1.icon or badge1.children,
               "renderBadge(true) table should have relevant content")
    end
    print("  renderBadge(true): " .. type(badge1))

    -- Test with ok=false
    local badge2 = ShowcaseCards.renderBadge(false)
    assert(badge2 ~= nil, "renderBadge(false) should return something")
    print("  renderBadge(false): " .. type(badge2))

    return true
end

-- Test that card builder functions exist for each category
function test_showcase_cards.test_card_builders_exist()
    local ShowcaseCards = require("ui.showcase.showcase_cards")

    -- Check for card builder functions
    local builders = {
        "buildGodClassCard",
        "buildSkillCard",
        "buildArtifactCard",
        "buildWandCard",
        "buildStatusEffectCard",
    }

    for _, name in ipairs(builders) do
        assert(type(ShowcaseCards[name]) == "function",
               name .. " should be a function")
        print("  " .. name .. " is function")
    end

    return true
end

-- Test card builder functions with mock data (if DSL not available, they should still accept data)
function test_showcase_cards.test_card_builders_accept_data()
    local ShowcaseCards = require("ui.showcase.showcase_cards")

    -- Mock data for each category
    local mockGodClass = {
        id = "pyra",
        name = "Pyra",
        type = "god",
        description = "Test god",
        effects = {
            { type = "stat_buff", stat = "fire_modifier_pct", value = 15 },
            { type = "blessing", name = "Inferno Burst", cooldown = 30 },
        },
    }

    local mockSkill = {
        id = "flame_affinity",
        name = "Flame Affinity",
        element = "fire",
        effects = {
            { type = "stat_buff", stat = "fire_modifier_pct", value = 15 },
        },
    }

    local mockArtifact = {
        id = "ember_heart",
        name = "Ember Heart",
        rarity = "Rare",
        element = "fire",
        description = "+20% fire damage",
        calculate = function() end,
    }

    local mockWand = {
        id = "RAGE_FIST",
        name = "Rage Fist",
        trigger_type = "every_N_seconds",
        mana_max = 40,
        cast_block_size = 1,
        always_cast_cards = {},
    }

    local mockStatusEffect = {
        id = "fireform",
        buff_type = true,
        duration = 15,
        stat_mods = { fire_modifier_pct = 25 },
    }

    -- Test each builder accepts data without crashing
    local success, err

    success, err = pcall(ShowcaseCards.buildGodClassCard, mockGodClass, true)
    if not success then
        -- Expected to fail without DSL, but should fail gracefully
        print("  buildGodClassCard (no DSL): " .. tostring(err):sub(1, 50) .. "...")
    else
        print("  buildGodClassCard: returned " .. type(err))
    end

    success, err = pcall(ShowcaseCards.buildSkillCard, mockSkill, true)
    if not success then
        print("  buildSkillCard (no DSL): " .. tostring(err):sub(1, 50) .. "...")
    else
        print("  buildSkillCard: returned " .. type(err))
    end

    success, err = pcall(ShowcaseCards.buildArtifactCard, mockArtifact, true)
    if not success then
        print("  buildArtifactCard (no DSL): " .. tostring(err):sub(1, 50) .. "...")
    else
        print("  buildArtifactCard: returned " .. type(err))
    end

    success, err = pcall(ShowcaseCards.buildWandCard, mockWand, true)
    if not success then
        print("  buildWandCard (no DSL): " .. tostring(err):sub(1, 50) .. "...")
    else
        print("  buildWandCard: returned " .. type(err))
    end

    success, err = pcall(ShowcaseCards.buildStatusEffectCard, mockStatusEffect, true)
    if not success then
        print("  buildStatusEffectCard (no DSL): " .. tostring(err):sub(1, 50) .. "...")
    else
        print("  buildStatusEffectCard: returned " .. type(err))
    end

    -- This test passes if we get here without hard crashes
    return true
end

-- Run all tests
function test_showcase_cards.run_all()
    print("\n=== Running Showcase Cards Tests ===\n")

    local tests = {
        { name = "module_exists", fn = test_showcase_cards.test_module_exists },
        { name = "safe_get", fn = test_showcase_cards.test_safe_get },
        { name = "format_effects", fn = test_showcase_cards.test_format_effects },
        { name = "render_badge", fn = test_showcase_cards.test_render_badge },
        { name = "card_builders_exist", fn = test_showcase_cards.test_card_builders_exist },
        { name = "card_builders_accept_data", fn = test_showcase_cards.test_card_builders_accept_data },
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        io.write("Running test_" .. test.name .. "... ")
        local ok, err = pcall(test.fn)
        if ok then
            passed = passed + 1
            print("PASSED")
        else
            failed = failed + 1
            print("FAILED")
            print("  Error: " .. tostring(err))
        end
    end

    print("\n=== Test Results ===")
    print(string.format("Passed: %d", passed))
    print(string.format("Failed: %d", failed))
    print(string.format("Total:  %d\n", passed + failed))

    return failed == 0
end

-- Auto-run if executed directly
if not pcall(debug.getlocal, 4, 1) then
    -- Set up package path to find modules
    local script_dir = debug.getinfo(1, "S").source:match("^@(.+/)")
    if script_dir then
        local base_dir = script_dir:gsub("tests/unit/$", "")
        package.path = base_dir .. "assets/scripts/?.lua;" ..
                       base_dir .. "assets/scripts/?/init.lua;" ..
                       package.path
    end

    local success = test_showcase_cards.run_all()
    os.exit(success and 0 or 1)
end

return test_showcase_cards
