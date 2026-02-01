-- assets/scripts/tests/descent/test_scrolls.lua
--[[
================================================================================
SCROLL IDENTIFICATION TESTS
================================================================================
Tests for items_scrolls.lua scroll identification system.

Requirements from bd-2qf.40:
- Seeded labels (deterministic per seed)
- Uniqueness (no duplicate labels)
- Persistence (identification persists)

Acceptance: All scroll tests pass.
================================================================================
]]

local T = {}

local scrolls = require("descent.items_scrolls")
local rng = require("descent.rng")

--------------------------------------------------------------------------------
-- Seeded Labels Tests
--------------------------------------------------------------------------------

function T.test_labels_deterministic_same_seed()
    scrolls.init(42)
    local labels1 = scrolls.get_label_state()
    
    scrolls.init(42)
    local labels2 = scrolls.get_label_state()
    
    local types = scrolls.get_all_types()
    for _, type_id in ipairs(types) do
        assert(labels1[type_id] == labels2[type_id],
            "Label for " .. type_id .. " should be same for same seed")
    end
    
    return true
end

function T.test_labels_different_seeds()
    scrolls.init(1)
    local labels1 = scrolls.get_label_state()
    
    scrolls.init(2)
    local labels2 = scrolls.get_label_state()
    
    -- At least some labels should differ
    local differences = 0
    local types = scrolls.get_all_types()
    for _, type_id in ipairs(types) do
        if labels1[type_id] ~= labels2[type_id] then
            differences = differences + 1
        end
    end
    
    assert(differences > 0,
        "Different seeds should produce different label assignments")
    
    return true
end

function T.test_labels_consistent_multiple_calls()
    scrolls.init(42)
    
    local label1 = scrolls.get_label("identify")
    local label2 = scrolls.get_label("identify")
    
    assert(label1 == label2,
        "Same scroll type should return same label on multiple calls")
    
    return true
end

function T.test_labels_format()
    scrolls.init(42)
    
    local types = scrolls.get_all_types()
    for _, type_id in ipairs(types) do
        local label = scrolls.get_label(type_id)
        assert(type(label) == "string", "Label should be string")
        assert(label:match("^scroll of "), 
            "Label should start with 'scroll of': " .. label)
    end
    
    return true
end

function T.test_raw_label_no_prefix()
    scrolls.init(42)
    
    local types = scrolls.get_all_types()
    for _, type_id in ipairs(types) do
        local raw = scrolls.get_raw_label(type_id)
        assert(raw, "Raw label should exist for " .. type_id)
        assert(not raw:match("^scroll of"),
            "Raw label should NOT have prefix: " .. raw)
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Uniqueness Tests
--------------------------------------------------------------------------------

function T.test_labels_unique_within_run()
    scrolls.init(42)
    
    local labels = scrolls.get_label_state()
    local seen = {}
    
    for type_id, label in pairs(labels) do
        assert(not seen[label],
            "Label '" .. label .. "' used twice (already used by " .. 
            (seen[label] or "unknown") .. ", now " .. type_id .. ")")
        seen[label] = type_id
    end
    
    return true
end

function T.test_labels_unique_multiple_seeds()
    for seed = 1, 10 do
        scrolls.init(seed)
        
        local labels = scrolls.get_label_state()
        local seen = {}
        
        for type_id, label in pairs(labels) do
            assert(not seen[label],
                "Seed " .. seed .. ": Label '" .. label .. 
                "' used twice (already used by " .. (seen[label] or "unknown") .. ")")
            seen[label] = type_id
        end
    end
    
    return true
end

function T.test_find_by_label_returns_correct_type()
    scrolls.init(42)
    
    local types = scrolls.get_all_types()
    for _, type_id in ipairs(types) do
        local raw_label = scrolls.get_raw_label(type_id)
        local found_type = scrolls.find_by_label(raw_label)
        
        assert(found_type == type_id,
            "find_by_label should return " .. type_id .. " for its label")
    end
    
    return true
end

--------------------------------------------------------------------------------
-- Persistence Tests
--------------------------------------------------------------------------------

function T.test_identification_persists()
    scrolls.init(42)
    
    scrolls.identify("identify")
    assert(scrolls.is_identified("identify"),
        "Scroll should be identified after identify()")
    
    -- Call something else and check again
    scrolls.get_label("teleport")
    assert(scrolls.is_identified("identify"),
        "Identification should persist")
    
    return true
end

function T.test_identification_initially_false()
    scrolls.init(42)
    
    local types = scrolls.get_all_types()
    for _, type_id in ipairs(types) do
        assert(not scrolls.is_identified(type_id),
            type_id .. " should not be identified initially")
    end
    
    return true
end

function T.test_identification_only_affects_target()
    scrolls.init(42)
    
    scrolls.identify("identify")
    
    assert(scrolls.is_identified("identify"),
        "identify should be identified")
    assert(not scrolls.is_identified("teleport"),
        "teleport should NOT be identified")
    
    return true
end

function T.test_identification_returns_true_first_time()
    scrolls.init(42)
    
    local newly = scrolls.identify("identify")
    assert(newly == true,
        "identify() should return true when newly identified")
    
    return true
end

function T.test_identification_returns_false_second_time()
    scrolls.init(42)
    
    scrolls.identify("identify")
    local newly = scrolls.identify("identify")
    
    assert(newly == false,
        "identify() should return false when already identified")
    
    return true
end

function T.test_identification_state_save_load()
    scrolls.init(42)
    
    scrolls.identify("identify")
    scrolls.identify("teleport")
    
    local saved_state = scrolls.get_identification_state()
    
    -- Reset and load
    scrolls.reset_identification()
    assert(not scrolls.is_identified("identify"),
        "Should not be identified after reset")
    
    scrolls.load_identification_state(saved_state)
    assert(scrolls.is_identified("identify"),
        "Should be identified after load")
    assert(scrolls.is_identified("teleport"),
        "teleport should be identified after load")
    
    return true
end

function T.test_label_state_save_load()
    scrolls.init(42)
    
    local saved_labels = scrolls.get_label_state()
    local identify_label = saved_labels["identify"]
    
    scrolls.init(99)  -- Different seed
    assert(scrolls.get_raw_label("identify") ~= identify_label,
        "Different seed should have different label")
    
    scrolls.load_label_state(saved_labels)
    assert(scrolls.get_raw_label("identify") == identify_label,
        "Should have original label after load")
    
    return true
end

--------------------------------------------------------------------------------
-- Display Name Tests
--------------------------------------------------------------------------------

function T.test_display_name_unidentified()
    scrolls.init(42)
    
    local display = scrolls.get_display_name("identify")
    local label = scrolls.get_label("identify")
    
    assert(display == label,
        "Unidentified scroll should display label")
    
    return true
end

function T.test_display_name_identified()
    scrolls.init(42)
    
    scrolls.identify("identify")
    local display = scrolls.get_display_name("identify")
    
    assert(display == "Scroll of Identify",
        "Identified scroll should display real name: " .. display)
    
    return true
end

--------------------------------------------------------------------------------
-- Progress Tracking Tests
--------------------------------------------------------------------------------

function T.test_identification_progress_initial()
    scrolls.init(42)
    
    local identified, total = scrolls.get_identification_progress()
    
    assert(identified == 0, "Initially 0 identified")
    assert(total > 0, "Should have some scroll types")
    
    return true
end

function T.test_identification_progress_after_identify()
    scrolls.init(42)
    
    scrolls.identify("identify")
    scrolls.identify("teleport")
    
    local identified, total = scrolls.get_identification_progress()
    
    assert(identified == 2, "Should have 2 identified")
    assert(total > identified, "Total should be > identified")
    
    return true
end

--------------------------------------------------------------------------------
-- Edge Case Tests
--------------------------------------------------------------------------------

function T.test_unknown_scroll_type()
    scrolls.init(42)
    
    local label = scrolls.get_label("nonexistent")
    assert(label == "scroll of unknown",
        "Unknown type should return 'scroll of unknown': " .. label)
    
    return true
end

function T.test_scroll_type_definitions()
    local types = scrolls.get_all_types()
    
    for _, type_id in ipairs(types) do
        local def = scrolls.get_scroll_type(type_id)
        
        assert(def, "Should have definition for " .. type_id)
        assert(def.id == type_id, "Definition id should match")
        assert(def.name, "Definition should have name")
        assert(def.effect, "Definition should have effect")
    end
    
    return true
end

function T.test_reset_clears_identification()
    scrolls.init(42)
    
    scrolls.identify("identify")
    assert(scrolls.is_identified("identify"))
    
    scrolls.reset_identification()
    assert(not scrolls.is_identified("identify"),
        "reset_identification should clear identified state")
    
    return true
end

--------------------------------------------------------------------------------
-- Test Runner
--------------------------------------------------------------------------------

function T.run_all()
    local tests = {
        -- Seeded labels
        { name = "labels_deterministic_same_seed", fn = T.test_labels_deterministic_same_seed },
        { name = "labels_different_seeds", fn = T.test_labels_different_seeds },
        { name = "labels_consistent_multiple_calls", fn = T.test_labels_consistent_multiple_calls },
        { name = "labels_format", fn = T.test_labels_format },
        { name = "raw_label_no_prefix", fn = T.test_raw_label_no_prefix },
        
        -- Uniqueness
        { name = "labels_unique_within_run", fn = T.test_labels_unique_within_run },
        { name = "labels_unique_multiple_seeds", fn = T.test_labels_unique_multiple_seeds },
        { name = "find_by_label_returns_correct_type", fn = T.test_find_by_label_returns_correct_type },
        
        -- Persistence
        { name = "identification_persists", fn = T.test_identification_persists },
        { name = "identification_initially_false", fn = T.test_identification_initially_false },
        { name = "identification_only_affects_target", fn = T.test_identification_only_affects_target },
        { name = "identification_returns_true_first_time", fn = T.test_identification_returns_true_first_time },
        { name = "identification_returns_false_second_time", fn = T.test_identification_returns_false_second_time },
        { name = "identification_state_save_load", fn = T.test_identification_state_save_load },
        { name = "label_state_save_load", fn = T.test_label_state_save_load },
        
        -- Display name
        { name = "display_name_unidentified", fn = T.test_display_name_unidentified },
        { name = "display_name_identified", fn = T.test_display_name_identified },
        
        -- Progress
        { name = "identification_progress_initial", fn = T.test_identification_progress_initial },
        { name = "identification_progress_after_identify", fn = T.test_identification_progress_after_identify },
        
        -- Edge cases
        { name = "unknown_scroll_type", fn = T.test_unknown_scroll_type },
        { name = "scroll_type_definitions", fn = T.test_scroll_type_definitions },
        { name = "reset_clears_identification", fn = T.test_reset_clears_identification },
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local ok, err = pcall(test.fn)
        if ok then
            print("[PASS] " .. test.name)
            passed = passed + 1
        else
            print("[FAIL] " .. test.name .. ": " .. tostring(err))
            failed = failed + 1
        end
    end
    
    print("")
    print(string.format("Scroll identification tests: %d passed, %d failed", passed, failed))
    
    return failed == 0
end

return T
