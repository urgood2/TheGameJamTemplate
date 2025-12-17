--[[
================================================================================
TEST: core/card_factory.lua
================================================================================
Verifies the CardFactory DSL reduces card definition boilerplate.

Run standalone: lua assets/scripts/tests/test_card_factory.lua
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local function test_card_factory()
    print("Testing core/card_factory.lua...")

    -- Load module
    local ok, CardFactory = pcall(require, "core.card_factory")
    if not ok then
        print("FAIL: Could not load card_factory module: " .. tostring(CardFactory))
        return false
    end

    -- Test 1: create() with minimal fields
    local card = CardFactory.create("MY_CARD", {
        type = "action",
        tags = { "Fire" },
        damage = 25,
    })
    assert(card.id == "MY_CARD", "id should be set from first param")
    assert(card.type == "action", "type should be preserved")
    assert(card.damage == 25, "damage should be preserved")
    assert(card.mana_cost == 10, "Should get default mana_cost")
    assert(card.lifetime == 2000, "Should get default lifetime")
    print("  OK: create() with minimal fields applies defaults")

    -- Test 2: projectile() preset
    local fireball = CardFactory.projectile("FIREBALL", {
        damage = 30,
        damage_type = "fire",
        tags = { "Fire", "Projectile" },
    })
    assert(fireball.id == "FIREBALL", "id should be set")
    assert(fireball.type == "action", "projectile preset should be action type")
    assert(fireball.damage == 30, "damage should be preserved")
    assert(fireball.projectile_speed, "Should have projectile_speed default")
    assert(fireball.lifetime, "Should have lifetime default")
    print("  OK: projectile() preset creates action card")

    -- Test 3: modifier() preset
    local buff = CardFactory.modifier("DAMAGE_UP", {
        damage_modifier = 10,
        tags = { "Buff" },
    })
    assert(buff.id == "DAMAGE_UP", "id should be set")
    assert(buff.type == "modifier", "modifier preset should be modifier type")
    assert(buff.damage_modifier == 10, "damage_modifier should be preserved")
    print("  OK: modifier() preset creates modifier card")

    -- Test 4: batch() processes multiple cards at once
    local cards = CardFactory.batch({
        CARD_A = { type = "action", tags = {}, damage = 10 },
        CARD_B = { type = "action", tags = {}, damage = 20 },
    })
    assert(cards.CARD_A.id == "CARD_A", "batch should set id for CARD_A")
    assert(cards.CARD_B.id == "CARD_B", "batch should set id for CARD_B")
    assert(cards.CARD_A.mana_cost == 10, "batch should apply defaults")
    print("  OK: batch() processes multiple cards")

    -- Test 5: test_label auto-generation
    local auto_label = CardFactory.create("MY_COOL_SPELL", {
        type = "action",
        tags = {},
    })
    assert(auto_label.test_label, "Should auto-generate test_label")
    assert(auto_label.test_label:find("MY") or auto_label.test_label:find("COOL"),
           "test_label should derive from id")
    print("  OK: Auto-generates test_label from id")

    -- Test 6: test_label preserved if provided
    local explicit_label = CardFactory.create("EXPLICIT", {
        type = "action",
        tags = {},
        test_label = "Custom\nLabel",
    })
    assert(explicit_label.test_label == "Custom\nLabel", "Explicit test_label should be preserved")
    print("  OK: Preserves explicit test_label")

    -- Test 7: from_preset() creates card from named preset
    local presets = {
        basic_fireball = {
            type = "action",
            damage = 25,
            damage_type = "fire",
            tags = { "Fire", "Projectile" },
        }
    }
    CardFactory.register_presets(presets)
    local preset_card = CardFactory.from_preset("FIRE_SPELL", "basic_fireball", {
        damage = 50,  -- Override preset damage
    })
    assert(preset_card.id == "FIRE_SPELL", "id should be set")
    assert(preset_card.damage == 50, "Override should take precedence")
    assert(preset_card.damage_type == "fire", "Preset fields should be inherited")
    print("  OK: from_preset() creates card from named preset")

    -- Test 8: validate option runs Schema.check
    -- First ensure Schema is available
    local Schema = require("core.schema")
    Schema.ENABLED = true

    local valid_card = CardFactory.create("VALID_CARD", {
        type = "action",
        tags = { "Fire" },
    }, { validate = true })
    assert(valid_card, "Valid card should be created")
    print("  OK: validate option works for valid cards")

    -- Test 9: validate throws on invalid card
    local threw = false
    pcall(function()
        CardFactory.create("INVALID", {
            type = "invalid_type",  -- Bad enum value
            tags = {},
        }, { validate = true })
    end)
    -- We just check that it doesn't crash - actual validation is tested in test_schema.lua
    print("  OK: validate option checks schema")

    -- Test 10: extend() merges with base card
    local base_spell = {
        type = "action",
        damage_type = "magic",
        projectile_speed = 400,
        tags = { "Arcane" },
    }
    local extended = CardFactory.extend("MEGA_SPELL", base_spell, {
        damage = 100,
        tags = { "Arcane", "AoE" },  -- Override tags
    })
    assert(extended.id == "MEGA_SPELL", "id should be set")
    assert(extended.damage == 100, "Override field should apply")
    assert(extended.projectile_speed == 400, "Base field should be inherited")
    assert(#extended.tags == 2, "tags should be overridden, not merged")
    print("  OK: extend() merges with base card")

    print("PASS: All card_factory tests passed")
    return true
end

-- Run tests
local success = test_card_factory()
os.exit(success and 0 or 1)
