--[[
================================================================================
ACTION PHASE INTEGRATION TEST
================================================================================
Comprehensive test verifying that all combat system phases are properly hooked up:
  - Lightning Card (ACTION_CHAIN_LIGHTNING)
  - Lightning Rod Joker (damage_mod, extra_chain)
  - Stormlord Avatar (crit_chains rule, cast_speed stat_buff, on_kill proc would go here)

This test simulates a complete action phase flow to ensure:
  1. Joker calculates effects during on_spell_cast
  2. Avatar rule_change is accessible during spell resolution
  3. Avatar stat_buff is applied to player combat stats
  4. Avatar procs fire on relevant signals
  5. All hook points integrate correctly

Run with: lua assets/scripts/tests/test_action_phase_integration.lua
Or via game: --run-lua-tests --headless
================================================================================
]]--

--------------------------------------------------------------------------------
-- TEST INFRASTRUCTURE
--------------------------------------------------------------------------------

-- Add repository paths
local thisFile = debug.getinfo(1, "S").source:match("^@(.+)$")
local scriptsRoot = thisFile:match("(.*/assets/scripts/)") or "./assets/scripts/"
package.path = table.concat({
    package.path,
    scriptsRoot .. "?.lua",
    scriptsRoot .. "?/init.lua",
    scriptsRoot .. "wand/?.lua",
    scriptsRoot .. "data/?.lua",
    scriptsRoot .. "core/?.lua",
    scriptsRoot .. "external/?.lua",
    scriptsRoot .. "external/hump/?.lua",
}, ";")

-- Test counters
local passed = 0
local failed = 0
local test_results = {}

local function assert_true(cond, msg)
    if not cond then
        error(msg or "assert_true failed", 2)
    end
end

local function assert_equals(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%s (got %s, expected %s)",
            msg or "assert_equals failed",
            tostring(actual),
            tostring(expected)), 2)
    end
end

local function assert_near(actual, expected, tolerance, msg)
    if math.abs(actual - expected) > tolerance then
        error(string.format("%s (got %s, expected %s ± %s)",
            msg or "assert_near failed",
            tostring(actual),
            tostring(expected),
            tostring(tolerance)), 2)
    end
end

local function run_test(name, test_fn)
    local ok, err = pcall(test_fn)
    if ok then
        passed = passed + 1
        table.insert(test_results, { name = name, status = "PASS" })
        print(string.format("[PASS] %s", name))
    else
        failed = failed + 1
        table.insert(test_results, { name = name, status = "FAIL", error = err })
        print(string.format("[FAIL] %s\n       %s", name, tostring(err)))
    end
end

--------------------------------------------------------------------------------
-- MOCK INFRASTRUCTURE
--------------------------------------------------------------------------------

-- Track emitted signals for verification
local emitted_signals = {}
local registered_handlers = {}

-- Mock signal module
local mock_signal = {
    emit = function(event, payload)
        table.insert(emitted_signals, { event = event, payload = payload })
        -- Also call registered handlers
        if registered_handlers[event] then
            for _, handler in ipairs(registered_handlers[event]) do
                handler(payload)
            end
        end
    end,
    register = function(event, handler)
        registered_handlers[event] = registered_handlers[event] or {}
        table.insert(registered_handlers[event], handler)
    end,
    remove = function(event, handler)
        if registered_handlers[event] then
            for i, h in ipairs(registered_handlers[event]) do
                if h == handler then
                    table.remove(registered_handlers[event], i)
                    break
                end
            end
        end
    end,
}
package.loaded["external.hump.signal"] = mock_signal

-- Reset signals between tests
local function reset_signals()
    emitted_signals = {}
    registered_handlers = {}
end

-- Find last signal of a given type
local function find_signal(event_name)
    for i = #emitted_signals, 1, -1 do
        if emitted_signals[i].event == event_name then
            return emitted_signals[i].payload
        end
    end
    return nil
end

-- Count signals of a given type
local function count_signals(event_name)
    local count = 0
    for _, sig in ipairs(emitted_signals) do
        if sig.event == event_name then
            count = count + 1
        end
    end
    return count
end

-- Mock stats system
local function create_mock_stats()
    return {
        _base = {},
        _add_pct = {},

        add_add_pct = function(self, stat, value)
            self._add_pct[stat] = (self._add_pct[stat] or 0) + value
        end,

        get = function(self, stat)
            local base = self._base[stat] or 0
            local add_pct = self._add_pct[stat] or 0
            return base * (1 + add_pct)
        end,

        recompute = function(self)
            -- No-op for mock
        end,

        -- For test inspection
        get_add_pct = function(self, stat)
            return self._add_pct[stat] or 0
        end,
    }
end

-- Mock combat actor
local function create_mock_combat_actor()
    local stats = create_mock_stats()
    stats._base.max_hp = 100
    stats._base.cast_speed = 1.0

    return {
        stats = stats,
        hp = 100,
        barrier = 0,

        heal = function(self, amount)
            self.hp = math.min(self.hp + amount, stats:get("max_hp"))
        end,

        addBarrier = function(self, amount)
            self.barrier = self.barrier + amount
        end,
    }
end

-- Mock player
local function create_mock_player()
    return {
        combatTable = create_mock_combat_actor(),
        avatar_state = { unlocked = {}, equipped = nil },
        avatar_progress = {},
        tag_counts = {},
    }
end

--------------------------------------------------------------------------------
-- LOAD SYSTEMS
--------------------------------------------------------------------------------

local JokerSystem = require("wand.joker_system")
local AvatarSystem = require("wand.avatar_system")
local CardsModule = require("data.cards")
local Cards = CardsModule.Cards  -- Extract nested Cards table
local Avatars = require("data.avatars")
local Jokers = require("data.jokers")

--------------------------------------------------------------------------------
-- PHASE 1: JOKER HOOK POINT TESTS
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print("PHASE 1: JOKER HOOK POINTS")
print(string.rep("=", 60))

run_test("Joker: lightning_rod triggers on Lightning tag", function()
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("lightning_rod")

    -- Simulate on_spell_cast with Lightning tag
    local result = JokerSystem.trigger_event("on_spell_cast", {
        tags = { Lightning = true },
        spell_type = "Mono-Element",
    })

    assert_equals(result.damage_mod, 15, "lightning_rod should add +15 damage_mod")
    assert_equals(result.extra_chain, 1, "lightning_rod should add +1 extra_chain")
    assert_true(#result.messages > 0, "should have UI message")
    assert_equals(result.messages[1].joker, "Lightning Rod", "message should identify joker")

    JokerSystem.clear_jokers()
end)

run_test("Joker: lightning_rod does NOT trigger on Fire tag", function()
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("lightning_rod")

    local result = JokerSystem.trigger_event("on_spell_cast", {
        tags = { Fire = true },
        spell_type = "Mono-Element",
    })

    assert_true(result.damage_mod == nil or result.damage_mod == 0,
        "lightning_rod should not trigger on Fire")

    JokerSystem.clear_jokers()
end)

run_test("Joker: pyromaniac triggers on Fire mono-element", function()
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("pyromaniac")

    local result = JokerSystem.trigger_event("on_spell_cast", {
        spell_type = "Mono-Element",
        tags = { Fire = true },
    })

    assert_equals(result.damage_mod, 10, "pyromaniac should add +10 damage_mod")

    JokerSystem.clear_jokers()
end)

run_test("Joker: multiple jokers stack effects (add mode)", function()
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("lightning_rod")
    JokerSystem.add_joker("lightning_rod")  -- Stack two

    local result = JokerSystem.trigger_event("on_spell_cast", {
        tags = { Lightning = true },
    })

    assert_equals(result.damage_mod, 30, "two lightning_rods should stack to +30")
    assert_equals(result.extra_chain, 2, "two lightning_rods should stack to +2 chain")

    JokerSystem.clear_jokers()
end)

run_test("Joker: tag_master uses calculate_damage event", function()
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("tag_master")

    local result = JokerSystem.trigger_event("calculate_damage", {
        player = { tag_counts = { Fire = 5, Ice = 5, Lightning = 10 } }  -- Total 20 tags
    })

    -- Expected: 1 + (20 * 0.01) = 1.2
    assert_near(result.damage_mult, 1.2, 0.001, "tag_master should multiply by 1.2 for 20 tags")

    JokerSystem.clear_jokers()
end)

run_test("Joker: defensive joker (iron_skin) on_player_damaged", function()
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("iron_skin")

    local result = JokerSystem.trigger_event("on_player_damaged", {
        source = "enemy_projectile",
        damage = 20,
    })

    assert_equals(result.damage_reduction, 5, "iron_skin should reduce damage by 5")

    JokerSystem.clear_jokers()
end)

--------------------------------------------------------------------------------
-- PHASE 2: AVATAR STAT_BUFF TESTS
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print("PHASE 2: AVATAR STAT_BUFF HOOKS")
print(string.rep("=", 60))

run_test("Avatar: stormlord applies cast_speed stat_buff on equip", function()
    reset_signals()
    local player = create_mock_player()

    -- Unlock stormlord
    player.avatar_state.unlocked.stormlord = true

    -- Equip
    local ok = AvatarSystem.equip(player, "stormlord")
    assert_true(ok, "equip should succeed")

    -- Check stat was applied
    local cast_speed_buff = player.combatTable.stats:get_add_pct("cast_speed")
    assert_equals(cast_speed_buff, 0.5, "stormlord should apply +0.5 (50%) cast_speed")
end)

run_test("Avatar: stat_buff removed on unequip", function()
    local player = create_mock_player()
    player.avatar_state.unlocked.stormlord = true

    AvatarSystem.equip(player, "stormlord")
    assert_equals(player.combatTable.stats:get_add_pct("cast_speed"), 0.5)

    AvatarSystem.unequip(player)
    assert_equals(player.combatTable.stats:get_add_pct("cast_speed"), 0,
        "unequip should reverse stat_buff")
end)

run_test("Avatar: switching avatars updates stat_buffs", function()
    local player = create_mock_player()
    player.avatar_state.unlocked.stormlord = true
    player.avatar_state.unlocked.wildfire = true

    -- Equip stormlord first
    AvatarSystem.equip(player, "stormlord")
    assert_equals(player.combatTable.stats:get_add_pct("cast_speed"), 0.5)

    -- Switch to wildfire
    AvatarSystem.equip(player, "wildfire")
    assert_equals(player.combatTable.stats:get_add_pct("cast_speed"), 0,
        "cast_speed should be removed after switching from stormlord")
    assert_equals(player.combatTable.stats:get_add_pct("hazard_tick_rate_pct"), 100,
        "wildfire hazard_tick_rate_pct should be applied")
end)

--------------------------------------------------------------------------------
-- PHASE 3: AVATAR RULE_CHANGE TESTS
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print("PHASE 3: AVATAR RULE_CHANGE HOOKS")
print(string.rep("=", 60))

run_test("Avatar: has_rule returns true for stormlord crit_chains", function()
    local player = create_mock_player()
    player.avatar_state.unlocked.stormlord = true
    AvatarSystem.equip(player, "stormlord")

    assert_true(AvatarSystem.has_rule(player, "crit_chains"),
        "stormlord should have crit_chains rule")
end)

run_test("Avatar: has_rule returns false for unrelated rule", function()
    local player = create_mock_player()
    player.avatar_state.unlocked.stormlord = true
    AvatarSystem.equip(player, "stormlord")

    assert_true(not AvatarSystem.has_rule(player, "multicast_loops"),
        "stormlord should NOT have multicast_loops rule")
end)

run_test("Avatar: has_rule returns false when no avatar equipped", function()
    local player = create_mock_player()

    assert_true(not AvatarSystem.has_rule(player, "crit_chains"),
        "no avatar should mean no rules")
end)

run_test("Avatar: wildfire has multicast_loops rule", function()
    local player = create_mock_player()
    player.avatar_state.unlocked.wildfire = true
    AvatarSystem.equip(player, "wildfire")

    assert_true(AvatarSystem.has_rule(player, "multicast_loops"),
        "wildfire should have multicast_loops rule")
end)

run_test("Avatar: voidwalker has summon_cast_share rule", function()
    local player = create_mock_player()
    player.avatar_state.unlocked.voidwalker = true
    AvatarSystem.equip(player, "voidwalker")

    assert_true(AvatarSystem.has_rule(player, "summon_cast_share"),
        "voidwalker should have summon_cast_share rule")
end)

--------------------------------------------------------------------------------
-- PHASE 4: AVATAR PROC TRIGGER TESTS
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print("PHASE 4: AVATAR PROC TRIGGERS")
print(string.rep("=", 60))

run_test("Avatar: bloodgod on_kill proc heals player", function()
    reset_signals()
    local player = create_mock_player()
    player.avatar_state.unlocked.bloodgod = true
    player.combatTable.hp = 50  -- Start at half health

    AvatarSystem.equip(player, "bloodgod")

    -- Simulate killing an enemy
    mock_signal.emit("enemy_killed", { entity_id = 12345 })

    -- bloodgod heals 5 HP on kill
    assert_equals(player.combatTable.hp, 55, "bloodgod should heal 5 HP on kill")
end)

run_test("Avatar: citadel on_cast_4th grants barrier", function()
    reset_signals()
    local player = create_mock_player()
    player.avatar_state.unlocked.citadel = true

    AvatarSystem.equip(player, "citadel")

    -- Cast 4 spells
    for i = 1, 4 do
        mock_signal.emit("on_spell_cast", { spell_id = i })
    end

    -- citadel gives 10% max HP as barrier on every 4th cast
    -- max_hp = 100, so barrier = 10
    assert_equals(player.combatTable.barrier, 10,
        "citadel should grant 10% HP barrier on 4th cast")
end)

run_test("Avatar: proc cleanup on unequip prevents further triggers", function()
    reset_signals()
    local player = create_mock_player()
    player.avatar_state.unlocked.bloodgod = true
    player.combatTable.hp = 50

    AvatarSystem.equip(player, "bloodgod")

    -- Kill and verify healing works
    mock_signal.emit("enemy_killed", { entity_id = 1 })
    assert_equals(player.combatTable.hp, 55)

    -- Unequip
    AvatarSystem.unequip(player)

    -- Kill again - should NOT heal
    mock_signal.emit("enemy_killed", { entity_id = 2 })
    assert_equals(player.combatTable.hp, 55, "after unequip, proc should not trigger")
end)

run_test("Avatar: switching avatars cleans up old procs", function()
    reset_signals()
    local player = create_mock_player()
    player.avatar_state.unlocked.bloodgod = true
    player.avatar_state.unlocked.citadel = true
    player.combatTable.hp = 50

    -- Equip bloodgod
    AvatarSystem.equip(player, "bloodgod")

    -- Switch to citadel
    AvatarSystem.equip(player, "citadel")

    -- bloodgod's on_kill should no longer work
    mock_signal.emit("enemy_killed", { entity_id = 1 })
    assert_equals(player.combatTable.hp, 50, "bloodgod proc should be cleaned up after switch")
end)

--------------------------------------------------------------------------------
-- PHASE 5: FULL INTEGRATION (CARD + JOKER + AVATAR)
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print("PHASE 5: FULL ACTION PHASE INTEGRATION")
print(string.rep("=", 60))

run_test("Integration: Lightning card + lightning_rod joker + stormlord avatar", function()
    reset_signals()
    JokerSystem.clear_jokers()

    -- Setup player with stormlord avatar
    local player = create_mock_player()
    player.avatar_state.unlocked.stormlord = true
    AvatarSystem.equip(player, "stormlord")

    -- Add lightning_rod joker
    JokerSystem.add_joker("lightning_rod")

    -- Get the chain lightning card
    local card = Cards.ACTION_CHAIN_LIGHTNING
    assert_true(card ~= nil, "ACTION_CHAIN_LIGHTNING should exist")

    -- Tags can be array format {"Lightning", "Arcane"} - check for Lightning in array
    local hasLightning = false
    for _, tag in ipairs(card.tags or {}) do
        if tag == "Lightning" then hasLightning = true; break end
    end
    assert_true(hasLightning, "Card should have Lightning tag")

    -- Simulate the action phase spell cast flow:

    -- 1. Check avatar rule (crit_chains affects combat resolution)
    local has_crit_chain_rule = AvatarSystem.has_rule(player, "crit_chains")
    assert_true(has_crit_chain_rule, "stormlord crit_chains rule should be active")

    -- 2. Trigger joker system for on_spell_cast
    local castContext = {
        tags = { Lightning = true },
        spell_type = "Mono-Element",
        card = card,
        player = player,
    }
    local jokerEffects = JokerSystem.trigger_event("on_spell_cast", castContext)

    -- 3. Verify joker effects were calculated
    assert_equals(jokerEffects.damage_mod, 15, "lightning_rod +15 damage")
    assert_equals(jokerEffects.extra_chain, 1, "lightning_rod +1 chain")

    -- 4. Verify avatar stat_buff is active
    local cast_speed_buff = player.combatTable.stats:get_add_pct("cast_speed")
    assert_equals(cast_speed_buff, 0.5, "stormlord +50% cast_speed")

    -- 5. Calculate final damage (base card damage + joker mods)
    local baseDamage = card.damage or 10
    local finalDamage = baseDamage + (jokerEffects.damage_mod or 0)
    assert_equals(finalDamage, 25, "final damage should be 10 + 15 = 25")

    -- 6. Simulate crit behavior with rule check
    local baseChainTargets = 1  -- Default chain lightning
    local bonusChain = jokerEffects.extra_chain or 0
    local critChainBonus = has_crit_chain_rule and 1 or 0
    local totalChainTargets = baseChainTargets + bonusChain + critChainBonus
    assert_equals(totalChainTargets, 3, "chain targets: 1 base + 1 joker + 1 crit_rule = 3")

    JokerSystem.clear_jokers()
end)

run_test("Integration: Fire card + pyromaniac joker + wildfire avatar", function()
    reset_signals()
    JokerSystem.clear_jokers()

    -- Setup player with wildfire avatar
    local player = create_mock_player()
    player.avatar_state.unlocked.wildfire = true
    AvatarSystem.equip(player, "wildfire")

    -- Add pyromaniac joker
    JokerSystem.add_joker("pyromaniac")

    -- Get fireball card
    local card = Cards.MY_FIREBALL
    assert_true(card ~= nil, "MY_FIREBALL should exist")

    -- Check avatar rule
    local has_multicast_loop = AvatarSystem.has_rule(player, "multicast_loops")
    assert_true(has_multicast_loop, "wildfire multicast_loops rule should be active")

    -- Check stat buff
    local hazard_rate = player.combatTable.stats:get_add_pct("hazard_tick_rate_pct")
    assert_equals(hazard_rate, 100, "wildfire +100% hazard tick rate")

    -- Trigger joker
    local jokerEffects = JokerSystem.trigger_event("on_spell_cast", {
        tags = { Fire = true },
        spell_type = "Mono-Element",
    })
    assert_equals(jokerEffects.damage_mod, 10, "pyromaniac +10 damage")

    -- Final damage
    local finalDamage = (card.damage or 25) + (jokerEffects.damage_mod or 0)
    assert_equals(finalDamage, 35, "25 base + 10 pyromaniac = 35")

    JokerSystem.clear_jokers()
end)

run_test("Integration: Multiple jokers + avatar stack correctly", function()
    reset_signals()
    JokerSystem.clear_jokers()

    local player = create_mock_player()
    player.avatar_state.unlocked.stormlord = true
    AvatarSystem.equip(player, "stormlord")

    -- Add multiple jokers that both affect Lightning
    JokerSystem.add_joker("lightning_rod")

    -- Also add tag_master for damage multiplier
    JokerSystem.add_joker("tag_master")
    player.tag_counts = { Lightning = 10 }  -- 10 tags = +10% damage

    -- Trigger on_spell_cast
    local castEffects = JokerSystem.trigger_event("on_spell_cast", {
        tags = { Lightning = true },
    })
    assert_equals(castEffects.damage_mod, 15)
    assert_equals(castEffects.extra_chain, 1)

    -- Trigger calculate_damage (separate phase)
    local dmgEffects = JokerSystem.trigger_event("calculate_damage", {
        player = { tag_counts = player.tag_counts }
    })
    assert_near(dmgEffects.damage_mult, 1.1, 0.001, "10 tags = 1.1x multiplier")

    -- Apply both to base damage
    local baseDamage = 10
    local withFlat = baseDamage + (castEffects.damage_mod or 0)  -- 10 + 15 = 25
    local withMult = withFlat * (dmgEffects.damage_mult or 1)     -- 25 * 1.1 = 27.5
    assert_near(withMult, 27.5, 0.01, "final damage with all mods")

    JokerSystem.clear_jokers()
end)

run_test("Integration: Kill triggers avatar proc during action resolution", function()
    reset_signals()
    JokerSystem.clear_jokers()

    local player = create_mock_player()
    player.avatar_state.unlocked.bloodgod = true
    player.combatTable.hp = 80
    AvatarSystem.equip(player, "bloodgod")

    JokerSystem.add_joker("lightning_rod")

    -- Simulate action phase:
    -- 1. Cast lightning spell
    local jokerEffects = JokerSystem.trigger_event("on_spell_cast", {
        tags = { Lightning = true },
    })

    -- 2. Apply damage (would happen in combat system)
    -- 3. Enemy dies -> emit signal
    mock_signal.emit("enemy_killed", { entity_id = 999, damage_type = "lightning" })

    -- 4. Bloodgod proc should heal
    assert_equals(player.combatTable.hp, 85, "bloodgod heal on kill during action")

    -- Kill more enemies
    mock_signal.emit("enemy_killed", { entity_id = 1000 })
    mock_signal.emit("enemy_killed", { entity_id = 1001 })
    assert_equals(player.combatTable.hp, 95, "multiple kills = multiple heals")

    JokerSystem.clear_jokers()
end)

--------------------------------------------------------------------------------
-- PHASE 6: EDGE CASES & ERROR HANDLING
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print("PHASE 6: EDGE CASES")
print(string.rep("=", 60))

run_test("Edge: Joker with no matching event returns empty aggregate", function()
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("lightning_rod")

    -- Trigger unrelated event
    local result = JokerSystem.trigger_event("unrelated_event", {
        tags = { Lightning = true },
    })

    -- Should have empty aggregate (no numeric fields)
    assert_true(result.damage_mod == nil or result.damage_mod == 0)

    JokerSystem.clear_jokers()
end)

run_test("Edge: Avatar equip fails for locked avatar", function()
    local player = create_mock_player()
    -- Don't unlock stormlord

    local ok, err = AvatarSystem.equip(player, "stormlord")
    assert_true(not ok, "equip should fail")
    assert_equals(err, "avatar_locked", "error should be avatar_locked")
end)

run_test("Edge: No jokers returns empty aggregate", function()
    JokerSystem.clear_jokers()

    local result = JokerSystem.trigger_event("on_spell_cast", {
        tags = { Lightning = true },
    })

    assert_true(result.damage_mod == nil or result.damage_mod == 0)
    assert_true(#result.messages == 0)
end)

run_test("Edge: Proc state resets correctly on avatar switch", function()
    reset_signals()
    local player = create_mock_player()
    player.avatar_state.unlocked.citadel = true
    player.avatar_state.unlocked.bloodgod = true

    -- Equip citadel and cast 3 times
    AvatarSystem.equip(player, "citadel")
    for i = 1, 3 do
        mock_signal.emit("on_spell_cast", { spell_id = i })
    end
    assert_equals(player.combatTable.barrier, 0, "no barrier after 3 casts")

    -- Switch to bloodgod (should reset citadel counter)
    AvatarSystem.equip(player, "bloodgod")

    -- Switch back to citadel
    AvatarSystem.equip(player, "citadel")

    -- Cast 4 more times - counter should have reset
    for i = 1, 4 do
        mock_signal.emit("on_spell_cast", { spell_id = i + 10 })
    end
    assert_equals(player.combatTable.barrier, 10, "counter reset, 4th cast triggers barrier")
end)

--------------------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------------------

print("\n" .. string.rep("=", 60))
print("TEST SUMMARY")
print(string.rep("=", 60))

print(string.format("\nPassed: %d", passed))
print(string.format("Failed: %d", failed))
print(string.format("Total:  %d", passed + failed))

if failed > 0 then
    print("\nFailed tests:")
    for _, result in ipairs(test_results) do
        if result.status == "FAIL" then
            print(string.format("  - %s", result.name))
            print(string.format("    Error: %s", result.error))
        end
    end
end

print("\n" .. (failed == 0 and "ALL TESTS PASSED!" or "SOME TESTS FAILED") .. "\n")

-- Return exit code for CI
if failed > 0 then
    os.exit(1)
end
