--[[
================================================================================
WAND EXECUTION SYSTEM - TEST EXAMPLES
================================================================================
Demonstrates how to use the wand execution system with working examples.

Examples:
1. Basic Fire Bolt - Simple projectile
2. Piercing Ice Shard - Pierce modifier + action
3. Triple Shot - Multicast modifier
4. Explosive Rounds - Explosion modifier
5. Homing Missiles - Homing modifier
6. Chain Lightning - On-hit trigger
7. Timer Bomb - Timer sub-cast

Usage:
  local WandTests = require("wand.wand_test_examples")
  WandTests.runAllTests()
================================================================================
]]--

local WandTests = {}

-- Dependencies
local cardEval = require("assets.scripts.core.card_eval_order_test")
local WandExecutor = require("assets.scripts.wand.wand_executor")

--[[
================================================================================
EXAMPLE 1: BASIC FIRE BOLT
================================================================================
]]--

function WandTests.example1_BasicFireBolt()
    print("\n" .. string.rep("=", 60))
    print("EXAMPLE 1: Basic Fire Bolt")
    print(string.rep("=", 60))

    -- Create wand definition
    local wandDef = {
        id = "fire_bolt_wand",
        type = "trigger",
        mana_max = 50,
        mana_recharge_rate = 10,
        cast_block_size = 1,
        cast_delay = 100,
        recharge_time = 500,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 1,
        always_cast_cards = {},
    }

    -- Create card pool
    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_BASIC_PROJECTILE),
    }

    -- Create trigger
    local triggerDef = {
        id = "every_N_seconds",
        type = "trigger",
        interval = 1.0,
    }

    -- Load wand
    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    print("Loaded Basic Fire Bolt wand")
    print("- Trigger: Every 1 second")
    print("- Action: Basic Projectile (10 damage)")
    print("- Expected: Spawns projectile every 1 second")

    return wandId
end

--[[
================================================================================
EXAMPLE 2: PIERCING ICE SHARD
================================================================================
]]--

function WandTests.example2_PiercingIceShard()
    print("\n" .. string.rep("=", 60))
    print("EXAMPLE 2: Piercing Ice Shard")
    print(string.rep("=", 60))

    local wandDef = {
        id = "piercing_ice_wand",
        type = "trigger",
        mana_max = 50,
        mana_recharge_rate = 10,
        cast_block_size = 2,  -- modifier + action
        cast_delay = 100,
        recharge_time = 800,
        spread_angle = 3,
        shuffle = false,
        total_card_slots = 2,
        always_cast_cards = {},
    }

    -- Card pool: Pierce modifier + projectile
    local cardPool = {
        -- Create a pierce modifier card
        cardEval.create_card_from_template({
            id = "MOD_PIERCE",
            type = "modifier",
            mana_cost = 5,
            multicast_count = 1,
            test_label = "MOD\npierce",
            -- Add pierce property
            pierce_count = 2,
        }),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_FAST_ACCURATE_PROJECTILE),
    }

    local triggerDef = {
        id = "on_player_attack",
        type = "trigger",
    }

    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    print("Loaded Piercing Ice Shard wand")
    print("- Trigger: On player attack")
    print("- Modifier: Pierce (2 enemies)")
    print("- Action: Fast Accurate Projectile (8 damage)")
    print("- Expected: Projectile pierces through 2 enemies")

    return wandId
end

--[[
================================================================================
EXAMPLE 3: TRIPLE SHOT
================================================================================
]]--

function WandTests.example3_TripleShot()
    print("\n" .. string.rep("=", 60))
    print("EXAMPLE 3: Triple Shot")
    print(string.rep("=", 60))

    local wandDef = {
        id = "triple_shot_wand",
        type = "trigger",
        mana_max = 60,
        mana_recharge_rate = 8,
        cast_block_size = 2,
        cast_delay = 150,
        recharge_time = 1000,
        spread_angle = 10,
        shuffle = false,
        total_card_slots = 2,
        always_cast_cards = {},
    }

    -- Card pool: Multicast + projectile
    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.MULTI_TRIPLE_CAST),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_BASIC_PROJECTILE),
    }

    local triggerDef = {
        id = "every_N_seconds",
        type = "trigger",
        interval = 2.0,
    }

    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    print("Loaded Triple Shot wand")
    print("- Trigger: Every 2 seconds")
    print("- Modifier: Triple Cast (3 projectiles)")
    print("- Action: Basic Projectile (10 damage)")
    print("- Expected: Spawns 3 projectiles in a spread pattern")

    return wandId
end

--[[
================================================================================
EXAMPLE 4: EXPLOSIVE ROUNDS
================================================================================
]]--

function WandTests.example4_ExplosiveRounds()
    print("\n" .. string.rep("=", 60))
    print("EXAMPLE 4: Explosive Rounds")
    print(string.rep("=", 60))

    local wandDef = {
        id = "explosive_rounds_wand",
        type = "trigger",
        mana_max = 70,
        mana_recharge_rate = 6,
        cast_block_size = 2,
        cast_delay = 200,
        recharge_time = 1200,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 2,
        always_cast_cards = {},
    }

    -- Card pool: Explosive modifier + projectile
    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.MOD_EXPLOSIVE),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_SLOW_ORB),
    }

    local triggerDef = {
        id = "on_player_attack",
        type = "trigger",
    }

    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    print("Loaded Explosive Rounds wand")
    print("- Trigger: On player attack")
    print("- Modifier: Explosive (60 radius)")
    print("- Action: Slow Orb (20 damage)")
    print("- Expected: Projectile explodes on hit, dealing AoE damage")

    return wandId
end

--[[
================================================================================
EXAMPLE 5: HOMING MISSILES
================================================================================
]]--

function WandTests.example5_HomingMissiles()
    print("\n" .. string.rep("=", 60))
    print("EXAMPLE 5: Homing Missiles")
    print(string.rep("=", 60))

    local wandDef = {
        id = "homing_missiles_wand",
        type = "trigger",
        mana_max = 60,
        mana_recharge_rate = 8,
        cast_block_size = 2,
        cast_delay = 150,
        recharge_time = 1000,
        spread_angle = 0,
        shuffle = false,
        total_card_slots = 2,
        always_cast_cards = {},
    }

    -- Card pool: Homing modifier + projectile
    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.MOD_HOMING),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_FAST_ACCURATE_PROJECTILE),
    }

    local triggerDef = {
        id = "every_N_seconds",
        type = "trigger",
        interval = 1.5,
    }

    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    print("Loaded Homing Missiles wand")
    print("- Trigger: Every 1.5 seconds")
    print("- Modifier: Homing (strength 10)")
    print("- Action: Fast Accurate Projectile (8 damage)")
    print("- Expected: Projectile seeks nearest enemy")

    return wandId
end

--[[
================================================================================
EXAMPLE 6: CHAIN LIGHTNING (On-Hit Trigger)
================================================================================
]]--

function WandTests.example6_ChainLightning()
    print("\n" .. string.rep("=", 60))
    print("EXAMPLE 6: Chain Lightning")
    print(string.rep("=", 60))

    local wandDef = {
        id = "chain_lightning_wand",
        type = "trigger",
        mana_max = 80,
        mana_recharge_rate = 7,
        cast_block_size = 3,
        cast_delay = 150,
        recharge_time = 1500,
        spread_angle = 2,
        shuffle = false,
        total_card_slots = 3,
        always_cast_cards = {},
    }

    -- Card pool: Chain lightning modifier + projectile
    local cardPool = {
        -- Chain lightning mod (custom)
        cardEval.create_card_from_template({
            id = "MOD_CHAIN_LIGHTNING",
            type = "modifier",
            mana_cost = 10,
            multicast_count = 1,
            chain_lightning = true,
            chain_targets = 3,
            chain_damage_mult = 0.5,
            test_label = "MOD\nchain\nlightning",
        }),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_FAST_ACCURATE_PROJECTILE),
    }

    local triggerDef = {
        id = "on_player_attack",
        type = "trigger",
    }

    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    print("Loaded Chain Lightning wand")
    print("- Trigger: On player attack")
    print("- Modifier: Chain Lightning (3 targets, 50% damage)")
    print("- Action: Fast Accurate Projectile (8 damage)")
    print("- Expected: On hit, spawns 3 chain projectiles to nearby enemies")

    return wandId
end

--[[
================================================================================
EXAMPLE 7: TIMER BOMB (Delayed Sub-Cast)
================================================================================
]]--

function WandTests.example7_TimerBomb()
    print("\n" .. string.rep("=", 60))
    print("EXAMPLE 7: Timer Bomb")
    print(string.rep("=", 60))

    local wandDef = {
        id = "timer_bomb_wand",
        type = "trigger",
        mana_max = 70,
        mana_recharge_rate = 6,
        cast_block_size = 3,
        cast_delay = 200,
        recharge_time = 2000,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 3,
        always_cast_cards = {},
    }

    -- Card pool: Projectile with timer + sub-cast action
    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.TEST_PROJECTILE_TIMER),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_EXPLOSIVE_FIRE_PROJECTILE),
    }

    local triggerDef = {
        id = "every_N_seconds",
        type = "trigger",
        interval = 3.0,
    }

    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    print("Loaded Timer Bomb wand")
    print("- Trigger: Every 3 seconds")
    print("- Action 1: Projectile with 1s timer")
    print("- Action 2: Explosive Fire Projectile (spawned after 1s)")
    print("- Expected: Projectile flies for 1s, then spawns explosion")

    return wandId
end

--[[
================================================================================
TEST RUNNER
================================================================================
]]--

--- Runs all test examples
function WandTests.runAllTests()
    print("\n" .. string.rep("=", 60))
    print("WAND EXECUTION SYSTEM - TEST SUITE")
    print(string.rep("=", 60))

    -- Initialize executor
    WandExecutor.init()

    -- Load all example wands
    local wands = {
        WandTests.example1_BasicFireBolt(),
        WandTests.example2_PiercingIceShard(),
        WandTests.example3_TripleShot(),
        WandTests.example4_ExplosiveRounds(),
        WandTests.example5_HomingMissiles(),
        WandTests.example6_ChainLightning(),
        WandTests.example7_TimerBomb(),
    }

    print("\n" .. string.rep("=", 60))
    print("Loaded", #wands, "test wands")
    print("Call WandExecutor.update(dt) each frame to activate triggers")
    print(string.rep("=", 60))

    return wands
end

--- Runs a single test by name
--- @param testName string Test function name (e.g., "example1_BasicFireBolt")
function WandTests.runTest(testName)
    if WandTests[testName] and type(WandTests[testName]) == "function" then
        WandExecutor.init()
        return WandTests[testName]()
    else
        print("Error: Test", testName, "not found")
        return nil
    end
end

--- Lists all available tests
function WandTests.listTests()
    print("\nAvailable tests:")
    print("  1. example1_BasicFireBolt")
    print("  2. example2_PiercingIceShard")
    print("  3. example3_TripleShot")
    print("  4. example4_ExplosiveRounds")
    print("  5. example5_HomingMissiles")
    print("  6. example6_ChainLightning")
    print("  7. example7_TimerBomb")
end

return WandTests
