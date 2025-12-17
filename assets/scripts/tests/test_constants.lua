--[[
================================================================================
TEST: core/constants.lua
================================================================================
Verifies the constants module loads and provides expected values.
]]

local function test_constants()
    print("Testing core/constants.lua...")

    local ok, C = pcall(require, "core.constants")
    if not ok then
        print("FAIL: Could not load constants module: " .. tostring(C))
        return false
    end

    -- Test collision tags exist
    assert(C.CollisionTags, "Missing CollisionTags")
    assert(C.CollisionTags.PLAYER == "player", "CollisionTags.PLAYER mismatch")
    assert(C.CollisionTags.ENEMY == "enemy", "CollisionTags.ENEMY mismatch")
    assert(C.CollisionTags.WORLD == "WORLD", "CollisionTags.WORLD mismatch")
    print("  OK: CollisionTags")

    -- Test states exist
    assert(C.States, "Missing States")
    assert(C.States.PLANNING == "PLANNING", "States.PLANNING mismatch")
    assert(C.States.ACTION == "SURVIVORS", "States.ACTION mismatch")
    print("  OK: States")

    -- Test damage types exist
    assert(C.DamageTypes, "Missing DamageTypes")
    assert(C.DamageTypes.FIRE == "fire", "DamageTypes.FIRE mismatch")
    print("  OK: DamageTypes")

    -- Test content tags exist
    assert(C.Tags, "Missing Tags")
    assert(C.Tags.FIRE == "Fire", "Tags.FIRE mismatch")
    assert(C.Tags.PROJECTILE == "Projectile", "Tags.PROJECTILE mismatch")
    print("  OK: Tags")

    -- Test card types exist
    assert(C.CardTypes, "Missing CardTypes")
    assert(C.CardTypes.ACTION == "action", "CardTypes.ACTION mismatch")
    print("  OK: CardTypes")

    -- Test shaders exist
    assert(C.Shaders, "Missing Shaders")
    assert(C.Shaders.HOLO == "3d_skew_holo", "Shaders.HOLO mismatch")
    print("  OK: Shaders")

    -- Test helper functions
    assert(type(C.values) == "function", "Missing values() helper")
    assert(type(C.is_valid) == "function", "Missing is_valid() helper")

    local collision_values = C.values(C.CollisionTags)
    assert(#collision_values > 0, "values() returned empty")
    print("  OK: Helper functions")

    assert(C.is_valid(C.DamageTypes, "fire") == true, "is_valid() failed for valid value")
    assert(C.is_valid(C.DamageTypes, "invalid") == false, "is_valid() failed for invalid value")
    print("  OK: is_valid() helper")

    -- Test global export
    assert(_G.C == C, "Global C not set")
    print("  OK: Global C export")

    print("PASS: All constants tests passed")
    return true
end

test_constants()
