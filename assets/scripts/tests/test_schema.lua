--[[
================================================================================
TEST: core/schema.lua
================================================================================
Verifies schema validation catches typos, missing fields, and type errors.

Run standalone: lua assets/scripts/tests/test_schema.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local function test_schema()
    print("Testing core/schema.lua...")

    -- Load module
    local ok, Schema = pcall(require, "core.schema")
    if not ok then
        print("FAIL: Could not load schema module: " .. tostring(Schema))
        return false
    end

    -- Test 1: Schema definitions exist
    assert(Schema.CARD, "Missing CARD schema")
    assert(Schema.JOKER, "Missing JOKER schema")
    assert(Schema.PROJECTILE, "Missing PROJECTILE schema")
    assert(Schema.ENEMY, "Missing ENEMY schema")
    print("  OK: Schema definitions exist")

    -- Test 2: validate() catches missing required fields
    local invalid_card = {
        -- Missing id, type, tags
        mana_cost = 10,
    }
    local check_ok, errors = Schema.check(invalid_card, Schema.CARD)
    assert(not check_ok, "Should fail when required fields missing")
    assert(#errors >= 3, "Should report at least 3 missing fields")
    print("  OK: Catches missing required fields")

    -- Test 3: validate() catches wrong types
    local wrong_type_card = {
        id = 123,       -- Should be string
        type = "action",
        tags = {},
        mana_cost = "ten",  -- Should be number
    }
    check_ok, errors = Schema.check(wrong_type_card, Schema.CARD)
    assert(not check_ok, "Should fail with wrong types")
    local found_type_error = false
    for _, err in ipairs(errors) do
        if err:find("string") or err:find("number") then
            found_type_error = true
            break
        end
    end
    assert(found_type_error, "Should report type errors")
    print("  OK: Catches wrong types")

    -- Test 4: validate() catches invalid enum values
    local invalid_enum_card = {
        id = "TEST",
        type = "invalid_type",  -- Not in enum
        tags = {},
    }
    check_ok, errors = Schema.check(invalid_enum_card, Schema.CARD)
    assert(not check_ok, "Should fail with invalid enum")
    local found_enum_error = false
    for _, err in ipairs(errors) do
        if err:find("one of") then
            found_enum_error = true
            break
        end
    end
    assert(found_enum_error, "Should report enum error")
    print("  OK: Catches invalid enum values")

    -- Test 5: validate() passes valid data
    local valid_card = {
        id = "TEST_CARD",
        type = "action",
        tags = { "Fire" },
        mana_cost = 10,
        damage = 25,
    }
    check_ok, errors = Schema.check(valid_card, Schema.CARD)
    assert(check_ok, "Valid card should pass: " .. table.concat(errors or {}, ", "))
    print("  OK: Passes valid data")

    -- Test 6: validate() warns about unknown fields (typo detection)
    local typo_card = {
        id = "TYPO_CARD",
        type = "action",
        tags = {},
        mana_cosy = 10,  -- Typo! (should suggest mana_cost)
        damge = 25,      -- Typo! (should suggest damage)
    }
    check_ok, errors, warnings = Schema.check(typo_card, Schema.CARD)
    assert(check_ok, "Card with typos should pass (warnings only)")
    assert(warnings and #warnings >= 2, "Should have at least 2 warnings for typos")
    print("  OK: Warns about unknown fields (typo detection)")

    -- Test 6b: Typo suggestions are accurate
    local found_mana_cost_suggestion = false
    local found_damage_suggestion = false
    for _, warn in ipairs(warnings) do
        if warn:find("mana_cosy") and warn:find("mana_cost") then
            found_mana_cost_suggestion = true
        end
        if warn:find("damge") and warn:find("damage") then
            found_damage_suggestion = true
        end
    end
    assert(found_mana_cost_suggestion, "Should suggest 'mana_cost' for 'mana_cosy'")
    assert(found_damage_suggestion, "Should suggest 'damage' for 'damge'")
    print("  OK: Typo suggestions are accurate")

    -- Test 7: validate() throws on error (with name context)
    local threw = false
    local error_msg = ""
    local bad_card = { mana_cost = 10 }  -- Missing required fields
    local ok_call = pcall(function()
        Schema.validate(bad_card, Schema.CARD, "Card:BAD_CARD")
    end)
    assert(not ok_call, "validate() should throw on error")
    print("  OK: validate() throws with context on error")

    -- Test 8: validateAll() validates multiple items
    local cards = {
        CARD_A = { id = "CARD_A", type = "action", tags = {} },
        CARD_B = { id = "CARD_B", type = "modifier", tags = {} },
    }
    local result = Schema.validateAll(cards, Schema.CARD, "Card")
    assert(result == cards, "validateAll should return same table")
    print("  OK: validateAll validates multiple items")

    -- Test 9: JOKER schema validates jokers
    local valid_joker = {
        id = "test_joker",
        name = "Test Joker",
        description = "A test joker",
        rarity = "Common",
    }
    check_ok, errors = Schema.check(valid_joker, Schema.JOKER)
    assert(check_ok, "Valid joker should pass: " .. table.concat(errors or {}, ", "))
    print("  OK: JOKER schema works")

    -- Test 10: ENABLED flag can disable validation
    Schema.ENABLED = false
    local bad = { }
    check_ok, errors = Schema.check(bad, Schema.CARD)
    assert(check_ok, "Should pass when ENABLED=false")
    Schema.ENABLED = true  -- Re-enable for other tests
    print("  OK: ENABLED flag disables validation")

    -- Test 11: String similarity functions
    -- Test levenshtein distance
    assert(Schema._levenshtein("", "") == 0, "Empty strings should have distance 0")
    assert(Schema._levenshtein("abc", "abc") == 0, "Identical strings should have distance 0")
    assert(Schema._levenshtein("abc", "abd") == 1, "One char difference should be distance 1")
    assert(Schema._levenshtein("kitten", "sitting") == 3, "kitten->sitting should be 3")
    print("  OK: Levenshtein distance works correctly")

    -- Test similarity function
    assert(Schema._similarity("abc", "abc") == 1, "Identical strings should have similarity 1")
    assert(Schema._similarity("", "") == 1, "Empty strings should have similarity 1")
    local sim = Schema._similarity("mana_cost", "mana_cosy")
    assert(sim > 0.8, "mana_cost/mana_cosy should be highly similar: " .. sim)
    print("  OK: Similarity function works correctly")

    -- Test findBestMatch
    local testFields = { mana_cost = true, damage = true, speed = true }
    assert(Schema._findBestMatch("mana_cosy", testFields) == "mana_cost", "Should match mana_cost")
    assert(Schema._findBestMatch("damge", testFields) == "damage", "Should match damage")
    assert(Schema._findBestMatch("xyz_completely_different", testFields) == nil, "Should not match anything")
    print("  OK: findBestMatch finds correct suggestions")

    print("PASS: All schema tests passed")
    return true
end

-- Run tests
local success = test_schema()
os.exit(success and 0 or 1)
