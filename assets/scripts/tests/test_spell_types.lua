-- Test Harness for SpellTypeEvaluator
-- Verifies that CastBlocks are correctly identified as SpellTypes.

-- Mock the module loading since we are running standalone
package.path = package.path .. ";./assets/scripts/wand/?.lua"
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

-- 1. Simple Cast
run_test("Simple Cast (1 Action)", {
    actions = { { id = "fireball", mana_cost = 10 } },
    modifiers = {}
}, SpellTypeEvaluator.Types.SIMPLE)

-- 2. Twin Cast
run_test("Twin Cast (Multicast x1)", {
    actions = { { id = "fireball" } },
    modifiers = { multicast = 1 }
}, SpellTypeEvaluator.Types.TWIN)

-- 3. Scatter Cast
run_test("Scatter Cast (Multicast x3 + Spread)", {
    actions = { { id = "fireball" } },
    modifiers = { multicast = 3, spread = 15 }
}, SpellTypeEvaluator.Types.SCATTER)

-- 4. Precision Cast
run_test("Precision Cast (Speed Up)", {
    actions = { { id = "sniper_shot" } },
    modifiers = { projectile_speed_multiplier = 1.5 }
}, SpellTypeEvaluator.Types.PRECISION)

-- 5. Rapid Fire
run_test("Rapid Fire (Low Delay)", {
    actions = { { id = "machine_gun" } },
    modifiers = { cast_delay_multiplier = 0.5 }
}, SpellTypeEvaluator.Types.RAPID)

-- 6. Mono-Element
run_test("Mono-Element (3 Fire Actions)", {
    actions = {
        { id = "fireball",   tags = { "Fire" } },
        { id = "fire_blast", tags = { "Fire", "Explosive" } },
        { id = "ignite",     tags = { "Fire" } }
    },
    modifiers = {}
}, SpellTypeEvaluator.Types.MONO)

-- 7. Combo Chain
run_test("Combo Chain (3 Distinct Elements)", {
    actions = {
        { id = "fireball",  tags = { "Fire" } },
        { id = "ice_shard", tags = { "Ice" } },
        { id = "void_orb",  tags = { "Void" } }
    },
    modifiers = {}
}, SpellTypeEvaluator.Types.COMBO)

-- 8. Heavy Barrage
run_test("Heavy Barrage (High Cost)", {
    actions = {
        { id = "nuke", mana_cost = 20 },
        { id = "nuke", mana_cost = 20 },
        { id = "nuke", mana_cost = 20 }
    },
    modifiers = {}
}, SpellTypeEvaluator.Types.HEAVY)

-- 9. Chaos (Fallback)
run_test("Chaos (Mixed Bag)", {
    actions = {
        { id = "fireball",  tags = { "Fire" } },
        { id = "ice_shard", tags = { "Ice" } },
        { id = "fireball",  tags = { "Fire" } }
    },
    modifiers = {}
}, SpellTypeEvaluator.Types.CHAOS) -- Should be Chaos because no common element AND not 3 distinct (Fire repeated)

print("--- Test Complete ---")
