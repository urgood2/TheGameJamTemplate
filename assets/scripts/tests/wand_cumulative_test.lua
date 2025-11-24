--[[
    Test harness for Wand Cumulative State & Player Stats Integration
    Run with: lua assets/scripts/tests/wand_cumulative_test.lua
]]

-- Mock engine dependencies
package.path = package.path .. ";./?.lua;./assets/scripts/?.lua"

-- Mock Node/Monobehavior
local MockNode = {}
MockNode.__index = MockNode
function MockNode:new(o)
    o = o or {}
    setmetatable(o, self)
    return o
end

function MockNode:attach_ecs() end

function MockNode:handle() return "mock_handle_" .. (self.id or "unknown") end

setmetatable(MockNode, {
    __call = function(cls, o) return cls:new(o) end
})

package.loaded["monobehavior.behavior_script_v2"] = MockNode

-- Mock Timer
package.loaded["core.timer"] = {
    after = function(delay, fn) fn() end
}

-- Mock ProjectileSystem
package.loaded["combat.projectile_system"] = {
    init = function() end,
    update = function() end,
    cleanup = function() end,
    CollisionBehavior = {
        DESTROY = "destroy",
        BOUNCE = "bounce",
        PIERCE = "pierce",
        EXPLODE = "explode"
    }
}

-- Mock WandTriggers
package.loaded["wand.wand_triggers"] = {
    init = function() end,
    update = function() end,
    cleanup = function() end,
    register = function() end,
    unregister = function() end
}

-- Mock WandActions (we want to capture execution to verify stats)
local ExecutedActions = {}
package.loaded["wand.wand_actions"] = {
    execute = function(actionCard, modifiers, context)
        table.insert(ExecutedActions, {
            card = actionCard,
            modifiers = modifiers,
            context = context
        })
        return true
    end
}

-- Load real modules
local WandModifiers = require("wand.wand_modifiers")
local WandExecutor = require("wand.wand_executor")
local CardEval = require("core.card_eval_order_test")
-- Mock util.deep_copy to avoid importing complex dependencies
local util = {}
function util.deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[util.deep_copy(orig_key)] = util.deep_copy(orig_value)
        end
        setmetatable(copy, util.deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- Setup Test Data
-- Import Real Definitions
local CardTemplates = CardEval.card_defs
local WandTemplates = CardEval.wand_defs

-- Helper to create a mock card from a template (preserving MockNode behavior for test harness)
local function createMockCardFromTemplate(template)
    local card = MockNode(template)
    -- Ensure type is set correctly for MockNode logic if needed, though template has it
    return card
end

local function createTestWand()
    -- Use a specific wand template or create one based on real structure
    -- Let's use WandTemplates[2] (no shuffle) as a base but override for specific test needs if required
    local wand = util.deep_copy(WandTemplates[2])
    wand.id = "TEST_WAND_CUMULATIVE"
    wand.cast_delay = 100
    wand.recharge_time = 500
    wand.mana_max = 1000
    wand.mana_charge_speed = 100
    wand.capacity = 10
    wand.spread = 0
    return wand
end

local function createTestDeck()
    local deck = {}

    -- 1. Damage Modifier (TEST_DAMAGE_BOOST)
    local modTemplate = CardTemplates.TEST_DAMAGE_BOOST
    local modDamage = createMockCardFromTemplate(modTemplate)
    modDamage.id = "MOD_DAMAGE_TEST" -- Keep consistent ID for test assertions
    modDamage.card_id = "MOD_DAMAGE_TEST"
    -- Ensure damage_modifier is set (template has it as 5, test expected 10 originally, let's adjust expectation or override)
    modDamage.damage_modifier = 10 -- Override to match previous test logic for now
    table.insert(deck, modDamage)

    -- 2. Basic Projectile (ACTION_BASIC_PROJECTILE)
    local actionTemplate = CardTemplates.ACTION_BASIC_PROJECTILE
    local actionProj = createMockCardFromTemplate(actionTemplate)
    actionProj.id = "ACTION_TEST_PROJ"
    actionProj.card_id = "ACTION_TEST_PROJ"
    actionProj.damage = 10     -- Match previous test expectation
    actionProj.cast_delay = 50 -- Match previous test expectation
    table.insert(deck, actionProj)

    return deck
end

-- Mock Stats Object
local MockStats = {}
MockStats.__index = MockStats
function MockStats:new(values)
    local o = { values = values or {} }
    setmetatable(o, self)
    return o
end

function MockStats:get(name)
    return self.values[name] or 0
end

-- Test Case: Verify Player Stats Integration
local function testPlayerStatsIntegration()
    print("\n=== Test: Player Stats Integration ===")

    -- Reset state
    ExecutedActions = {}
    WandExecutor.init()

    local wandDef = createTestWand()
    local deck = createTestDeck()

    -- Load wand
    WandExecutor.loadWand(wandDef, deck, nil)

    -- Mock Player Stats in Context
    local originalCreateContext = WandExecutor.createExecutionContext
    WandExecutor.createExecutionContext = function(wandId, state, activeWand)
        local ctx = originalCreateContext(wandId, state, activeWand)
        -- Inject test stats using MockStats
        ctx.playerStats = MockStats:new({
            all_damage_pct = 100,             -- +100% damage (2x)
            physical_modifier_pct = 50,       -- +50% physical damage
            cast_speed = 20,                  -- +20% cast speed
            cooldown_reduction = 10,          -- 10% CDR
            skill_energy_cost_reduction = 10, -- 10% cost reduction
        })
        return ctx
    end

    -- Execute
    WandExecutor.execute(wandDef.id, "trigger")

    -- Verify
    if #ExecutedActions == 0 then
        print("[FAIL] No actions executed")
        return
    end

    local action = ExecutedActions[1]
    local mods = action.modifiers

    -- Check Cooldowns (indirectly via print or we can inspect state if accessible)
    -- We can't easily inspect the local 'totalCooldown' variable in execute(),
    -- but we can check state.cooldownRemaining if we have access to the state object passed to execute.
    -- Wait, execute() takes wandId, trigger. It gets state internally.
    -- But we can inspect WandExecutor.wandStates[wandDef.id].cooldownRemaining

    local state = WandExecutor.wandStates[wandDef.id]
    print("Cooldown Remaining:", state.cooldownRemaining)

    -- Expected:
    -- Cast Delay: (100 + 50) = 150ms = 0.15s
    -- Cast Speed 20%: 0.15 / 1.2 = 0.125s
    -- Recharge: 500ms = 0.5s
    -- CDR 10%: 0.5 * 0.9 = 0.45s
    -- Total: 0.125 + 0.45 = 0.575s

    if math.abs(state.cooldownRemaining - 0.575) < 0.001 then
        print("[PASS] Cooldown calculation correct")
    else
        print("[FAIL] Cooldown calculation incorrect")
        print("  Expected: 0.575", "Got:", state.cooldownRemaining)
    end

    -- Expected Damage:
    -- Base: 10
    -- Card Mod: +10 damage (flat)
    -- Total Flat: 20
    -- Player Stats:
    --   all_damage_pct: 100
    --   physical_modifier_pct: 50
    --   Total %: 150%
    -- Multiplier: 1.0 (default)
    -- Final Damage: 20 * (1 + 1.50) * 1.0 = 20 * 2.5 = 50

    -- Check snapshot
    print("Stats Snapshot:")
    print("  All Damage %:", mods.statsSnapshot.all_damage_pct)
    print("  Physical %:", mods.statsSnapshot.physical_damage_pct)

    if mods.statsSnapshot.all_damage_pct == 100 and mods.statsSnapshot.physical_damage_pct == 50 then
        print("[PASS] Stats snapshot correct")
    else
        print("[FAIL] Stats snapshot incorrect")
    end

    -- Check resolved action properties
    local resolved = WandModifiers.applyToAction(action.card, mods)
    print("Resolved Action:")
    print("  Damage:", resolved.damage)

    local expectedFinalDamage = 20 * 2.5 -- 50
    if resolved.damage == expectedFinalDamage then
        print("[PASS] Final damage calculation correct")
    else
        print("[FAIL] Final damage calculation incorrect")
        print("  Expected:", expectedFinalDamage, "Got:", resolved.damage)
    end

    -- Check Mana Cost Multiplier
    print("  Mana Cost Mult:", mods.manaCostMultiplier)
    local expectedManaMult = 0.9 -- 1.0 * (1 - 0.10)
    if math.abs(mods.manaCostMultiplier - expectedManaMult) < 0.001 then
        print("[PASS] Mana cost multiplier correct")
    else
        print("[FAIL] Mana cost multiplier incorrect")
        print("  Expected:", expectedManaMult, "Got:", mods.manaCostMultiplier)
    end

    -- Restore original function
    WandExecutor.createExecutionContext = originalCreateContext
end

-- Test Case: Verify Cumulative State Tracking
local function testCumulativeState()
    print("\n=== Test: Cumulative State Tracking ===")

    -- Reset state
    ExecutedActions = {}
    WandExecutor.init()

    local wandDef = createTestWand()
    local deck = createTestDeck()

    WandExecutor.loadWand(wandDef, deck, nil)

    -- Execute
    WandExecutor.execute(wandDef.id, "trigger")

    local state = WandExecutor.getWandState(wandDef.id)

    if state.lastExecutionState then
        print("Last Execution State:")
        print("  Mana Spent:", state.lastExecutionState.totalManaSpent)
        print("  Projectiles:", state.lastExecutionState.totalProjectiles)
        print("  Blocks:", state.lastExecutionState.blocksExecuted)

        -- Expected Mana: 5 (ACTION_BASIC_PROJECTILE cost)
        -- Note: MOD_DAMAGE_TEST cost is 3, but in this specific test setup we might only be checking the action cost
        -- or the mod cost might not be consumed if it's not fully processed in the way we expect?
        -- Wait, the log says "Mana Spent: 5".
        -- ACTION_BASIC_PROJECTILE cost is 5.
        -- MOD_DAMAGE_TEST cost is 3.
        -- Total should be 8 if both are consumed.
        -- Let's check why only 5.
        -- Ah, in the test deck creation for "Cumulative State Tracking", we reuse createTestDeck()
        -- which adds both cards.
        -- If the modifier is applied, its cost should be consumed.
        -- Let's check WandExecutor logic for modifier mana consumption.
        -- It seems WandExecutor consumes mana for the action card being executed.
        -- Does it consume mana for modifiers attached to it?
        -- Looking at WandExecutor.lua:
        -- "local manaCost = actionCard.mana_cost or 0"
        -- It doesn't seem to sum up modifier costs in the current implementation!
        -- This is a bug/feature gap in WandExecutor.
        -- For now, let's update the test expectation to 5 to match current behavior,
        -- and note this as a potential future fix.

        -- Expected Mana: 8 (5 Action + 3 Mod)
        -- We now consume modifier mana in WandExecutor.

        if state.lastExecutionState.totalManaSpent == 8 then
            print("[PASS] Mana spent tracked correctly (Action + Mod)")
        else
            print("[FAIL] Mana spent incorrect. Expected 8, Got:", state.lastExecutionState.totalManaSpent)
        end

        if state.lastExecutionState.totalProjectiles == 1 then
            print("[PASS] Projectile count tracked correctly")
        else
            print("[FAIL] Projectile count incorrect. Expected 1, Got:", state.lastExecutionState.totalProjectiles)
        end
    else
        print("[FAIL] No lastExecutionState found")
    end
end

local function testOverheatMechanic()
    print("\n=== Test: Overheat Mechanic ===")

    -- Reset state
    ExecutedActions = {}
    WandExecutor.init()

    local wandDef = createTestWand()
    wandDef.mana_max = 100       -- Set low max mana for easy calculation
    wandDef.recharge_time = 1000 -- 1.0s recharge
    wandDef.cast_delay = 0

    local deck = createTestDeck()
    -- Modify deck to have high cost
    -- Action cost 5. Mod cost 3. Total 8.
    -- We need to drain mana first or set initial mana low.

    -- Load wand
    WandExecutor.loadWand(wandDef, deck, nil)

    -- Force low mana
    local state = WandExecutor.wandStates[wandDef.id]
    state.currentMana = 5 -- Not enough for 8 cost

    -- Execute
    WandExecutor.execute(wandDef.id, "trigger")

    -- Verify
    -- Expected Mana: 5 - 8 = -3
    -- Deficit: 3
    -- Max Flux: 100
    -- Ratio: 3 / 100 = 0.03
    -- Penalty Factor: 5.0
    -- Multiplier: 1 + (0.03 * 5) = 1 + 0.15 = 1.15
    -- Base Cooldown: 1.0s (recharge)
    -- Expected Cooldown: 1.15s

    print("Current Mana:", state.currentMana)
    if state.currentMana == -3 then
        print("[PASS] Negative mana allowed (Overheat)")
    else
        print("[FAIL] Mana incorrect. Expected -3, Got:", state.currentMana)
    end

    print("Cooldown Remaining:", state.cooldownRemaining)
    -- Base Cooldown: 1.0s (recharge) + 0.05s (cast delay) = 1.05s
    -- Multiplier: 1.15
    -- Expected: 1.05 * 1.15 = 1.2075
    if math.abs(state.cooldownRemaining - 1.2075) < 0.001 then
        print("[PASS] Overheat penalty applied correctly")
    else
        print("[FAIL] Overheat penalty incorrect. Expected 1.2075, Got:", state.cooldownRemaining)
    end
end

-- Run Tests
testPlayerStatsIntegration()
testCumulativeState()
testOverheatMechanic()
