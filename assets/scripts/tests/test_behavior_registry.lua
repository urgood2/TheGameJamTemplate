--[[
================================================================================
BEHAVIOR REGISTRY - TEST AND EXAMPLES
================================================================================
Demonstrates how to use the behavior registry for complex custom effects.
]] --

local BehaviorRegistry = require("wand.card_behavior_registry")

print("\n" .. string.rep("=", 60))
print("BEHAVIOR REGISTRY - EXAMPLES")
print(string.rep("=", 60))

-- Initialize example behaviors
BehaviorRegistry.initExamples()

-- List all behaviors
BehaviorRegistry.printAll()

-- Test 1: Chain explosion
print("\n[Test 1] Chain Explosion:")
local ctx1 = {
    position = { x = 100, y = 100 },
    damage = 50,
    params = {
        max_chains = 5,
        radius = 100,
        chain_chance = 60,
        damage_mult = 0.8
    }
}
local success, chains = BehaviorRegistry.execute("chain_explosion_recursive", ctx1)
print(string.format("Result: %d total explosions", chains or 0))

-- Test 2: Summon on low health
print("\n[Test 2] Summon on Low Health:")
local player = { hp = 30, max_health = 100 }
local ctx2 = {
    player = player,
    params = {
        health_threshold = 0.5 -- 50%
    }
}
local success2, summoned = BehaviorRegistry.execute("summon_on_low_health", ctx2)
print(string.format("Result: Summoned = %s", tostring(summoned)))

-- Test 3: Momentum stacks
print("\n[Test 3] Momentum Stacks:")
local player2 = { hp = 100, max_health = 100 }
local ctx3 = {
    player = player2,
    time = 0,
    params = {
        max_stacks = 10,
        damage_per_stack = 5,
        decay_time = 2.0
    }
}

-- Hit 5 times quickly
for i = 1, 5 do
    ctx3.time = i * 0.5
    BehaviorRegistry.execute("momentum_stacks", ctx3)
end

-- Wait too long, stacks should decay
ctx3.time = 10
BehaviorRegistry.execute("momentum_stacks", ctx3)

-- Test 4: Trigger with cooldown
print("\n[Test 4] Trigger with Cooldown:")
local player3 = {}
local ctx4 = {
    player = player3,
    time = 0,
    params = {
        behavior_id = "lightning_storm",
        chance = 100, -- Always trigger if off cooldown
        cooldown = 3.0
    }
}

-- Try triggering multiple times
for i = 1, 5 do
    ctx4.time = i * 1.0
    local success4, triggered = BehaviorRegistry.execute("trigger_with_cooldown", ctx4)
    if not triggered then
        print(string.format("  Time %.1fs: On cooldown", ctx4.time))
    end
end

print("\n" .. string.rep("=", 60))
print("✓ BEHAVIOR REGISTRY EXAMPLES COMPLETE")
print(string.rep("=", 60))
