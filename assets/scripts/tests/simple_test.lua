-- Simple test with file output
package.path = package.path .. ";./assets/scripts/wand/?.lua"
local SpellTypeEvaluator = require("spell_type_evaluator")

local output = io.open("test_output.txt", "w")
output:write("--- Testing SpellTypeEvaluator ---\n")

-- Test 1: Simple Cast
local result = SpellTypeEvaluator.evaluate({
    actions = { { id = "fireball", mana_cost = 10 } },
    modifiers = {}
})
output:write(string.format("Simple Cast: %s (Expected: %s)\n", result, SpellTypeEvaluator.Types.SIMPLE))

-- Test 2: Twin Cast
result = SpellTypeEvaluator.evaluate({
    actions = { { id = "fireball" } },
    modifiers = { multicast = 1 }
})
output:write(string.format("Twin Cast: %s (Expected: %s)\n", result, SpellTypeEvaluator.Types.TWIN))

-- Test 3: Mono-Element
result = SpellTypeEvaluator.evaluate({
    actions = {
        { id = "fireball",   tags = { "Fire" } },
        { id = "fire_blast", tags = { "Fire", "Explosive" } },
        { id = "ignite",     tags = { "Fire" } }
    },
    modifiers = {}
})
output:write(string.format("Mono-Element: %s (Expected: %s)\n", result, SpellTypeEvaluator.Types.MONO))

output:write("--- Test Complete ---\n")
output:close()
print("Test output written to test_output.txt")
