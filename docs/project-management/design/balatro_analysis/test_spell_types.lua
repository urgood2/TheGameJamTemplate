-- Test Harness for SpellTypeEvaluator
-- Verifies that CastBlocks are correctly identified as SpellTypes.
-- Uses actual cast block structure from card_eval_order_test.lua

-- Mock the module loading since we are running standalone
package.path = package.path .. ";./docs/project-management/design/balatro_analysis/?.lua"
local SpellTypeEvaluator = require("spell_type_evaluator")

local function run_test(name, block, expected_type)
    local result = SpellTypeEvaluator.evaluate(block)
    if result == expected_type then
        print(string.format("[PASS] %s: Got '%s'", name, result))
    else
        print(string.format("[FAIL] %s: Expected '%s', Got '%s'", name, expected_type, tostring(result)))
    end
end

print("--- Testing SpellTypeEvaluator ---")

-- 1. Simple Cast (1 Action, No Modifiers)
run_test("Simple Cast (1 Action)", {
    cards = {
        { type = "action", id = "FIREBALL", mana_cost = 10 }
    },
    applied_modifiers = {},
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.SIMPLE)

-- 2. Twin Cast (1 Action + Multicast x1)
run_test("Twin Cast (Multicast x1)", {
    cards = {
        { type = "modifier", id = "DOUBLE_CAST" },
        { type = "action",   id = "FIREBALL" }
    },
    applied_modifiers = {
        { card = { multicast = 1 }, remaining = 1 }
    },
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.TWIN)

-- 3. Scatter Cast (1 Action + Multicast x3 + Spread)
run_test("Scatter Cast (Multicast x3 + Spread)", {
    cards = {
        { type = "modifier", id = "TRIPLE_CAST" },
        { type = "modifier", id = "SPREAD" },
        { type = "action",   id = "FIREBALL" }
    },
    applied_modifiers = {
        { card = { multicast = 3 }, remaining = 1 },
        { card = { spread = 15 },   remaining = 1 }
    },
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.SCATTER)

-- 4. Precision Cast (1 Action + Speed Up)
run_test("Precision Cast (Speed Up)", {
    cards = {
        { type = "modifier", id = "SPEED_UP" },
        { type = "action",   id = "SNIPER_SHOT" }
    },
    applied_modifiers = {
        { card = { projectile_speed_multiplier = 1.5 }, remaining = 1 }
    },
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.PRECISION)

-- 5. Rapid Fire (1 Action + Low Delay)
run_test("Rapid Fire (Low Delay)", {
    cards = {
        { type = "modifier", id = "RAPID" },
        { type = "action",   id = "MACHINE_GUN" }
    },
    applied_modifiers = {
        { card = { cast_delay_multiplier = 0.5 }, remaining = 1 }
    },
    total_cast_delay = 10,
    total_recharge = 0
}, SpellTypeEvaluator.Types.RAPID)

-- 6. Mono-Element (3 Fire Actions)
run_test("Mono-Element (3 Fire Actions)", {
    cards = {
        { type = "action", id = "FIREBALL",   tags = { "Fire" } },
        { type = "action", id = "FIRE_BLAST", tags = { "Fire", "Explosive" } },
        { type = "action", id = "IGNITE",     tags = { "Fire" } }
    },
    applied_modifiers = {},
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.MONO)

-- 7. Combo Chain (3 Distinct Elements)
run_test("Combo Chain (3 Distinct Elements)", {
    cards = {
        { type = "action", id = "FIREBALL",  tags = { "Fire" } },
        { type = "action", id = "ICE_SHARD", tags = { "Ice" } },
        { type = "action", id = "VOID_ORB",  tags = { "Void" } }
    },
    applied_modifiers = {},
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.COMBO)

-- 8. Heavy Barrage (High Cost)
run_test("Heavy Barrage (High Cost)", {
    cards = {
        { type = "action", id = "NUKE", mana_cost = 20 },
        { type = "action", id = "NUKE", mana_cost = 20 },
        { type = "action", id = "NUKE", mana_cost = 20 }
    },
    applied_modifiers = {},
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.HEAVY)

-- 9. Chaos (Mixed Bag - Fire + Ice + Fire, but only 2 distinct)
run_test("Chaos (Mixed Bag)", {
    cards = {
        { type = "action", id = "FIREBALL",  tags = { "Fire" } },
        { type = "action", id = "ICE_SHARD", tags = { "Ice" } },
        { type = "action", id = "FIREBALL",  tags = { "Fire" } }
    },
    applied_modifiers = {},
    total_cast_delay = 0,
    total_recharge = 0
}, SpellTypeEvaluator.Types.CHAOS)

print("--- Test Complete ---")
