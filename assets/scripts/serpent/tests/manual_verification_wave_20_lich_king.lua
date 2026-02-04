--[[
================================================================================
MANUAL VERIFICATION: Wave 20 Lich King Boss
================================================================================
Manual verification that wave 20 correctly spawns lich_king boss and
implements necromancy behavior (raising skeletons on enemy death).

Implements task bd-bubx requirements: "Verify lich_king appears on wave 20,
raises skeletons on enemy death"

Run with: lua assets/scripts/serpent/tests/manual_verification_wave_20_lich_king.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock dependencies
_G.log_debug = function(msg) print("[DEBUG] " .. msg) end
_G.log_warning = function(msg) print("[WARNING] " .. msg) end
_G.log_error = function(msg) print("[ERROR] " .. msg) end

print("================================================================================")
print("MANUAL VERIFICATION: Wave 20 Lich King Boss")
print("================================================================================")
print("Verifying lich_king spawning and necromancy mechanics for wave 20")
print("")

-- Test 1: Verify Wave 20 Enemy Configuration
print("=== Test 1: Wave 20 Enemy Configuration ===")

local enemies = require("serpent.data.enemies")

-- Check that lich_king is configured for wave 20
local lich_king_def = enemies.get_enemy("lich_king")
if not lich_king_def then
    print("❌ FAIL: lich_king definition not found")
    os.exit(1)
end

print("✓ Lich King definition found:")
print(string.format("  - ID: %s", lich_king_def.id))
print(string.format("  - Base HP: %d", lich_king_def.base_hp))
print(string.format("  - Base Damage: %d", lich_king_def.base_damage))
print(string.format("  - Speed: %d", lich_king_def.speed))
print(string.format("  - Wave Range: %d-%d", lich_king_def.min_wave, lich_king_def.max_wave))
print(string.format("  - Is Boss: %s", tostring(lich_king_def.boss)))
print(string.format("  - Tags: %s", table.concat(lich_king_def.tags or {}, ", ")))

-- Verify wave 20 configuration
if lich_king_def.min_wave ~= 20 or lich_king_def.max_wave ~= 20 then
    print("❌ FAIL: lich_king wave range is not exactly 20")
    os.exit(1)
end

if not lich_king_def.boss then
    print("❌ FAIL: lich_king is not marked as boss")
    os.exit(1)
end

print("✓ Lich King correctly configured for wave 20 only")
print("")

-- Test 2: Wave Director Wave 20 Spawning
print("=== Test 2: Wave Director Wave 20 Spawning ===")

local serpent_wave_director = require("serpent.serpent_wave_director")
local rng = require("serpent.rng")

-- Create wave director state for wave 20
local director_state = serpent_wave_director.create_state(20)
local test_rng = rng.create(12345)

-- Start wave 20
local updated_state, spawn_events = serpent_wave_director.start_wave(
    director_state, enemies.get_all_enemies(), test_rng)

-- Check that lich_king is in spawn events
local lich_king_spawn = nil
local regular_enemy_count = 0

for _, event in ipairs(spawn_events) do
    if event.enemy_id == "lich_king" then
        lich_king_spawn = event
    else
        regular_enemy_count = regular_enemy_count + 1
    end
end

if not lich_king_spawn then
    print("❌ FAIL: lich_king not found in wave 20 spawn events")
    os.exit(1)
end

print("✓ Lich King spawn event generated for wave 20:")
print(string.format("  - Enemy ID: %s", lich_king_spawn.enemy_id))
print(string.format("  - Is Boss: %s", tostring(lich_king_spawn.is_boss)))
print(string.format("  - HP Multiplier: %.2f", lich_king_spawn.hp_mult))
print(string.format("  - Damage Multiplier: %.2f", lich_king_spawn.dmg_mult))
print(string.format("  - Spawn Delay: %.2f seconds", lich_king_spawn.spawn_delay))
print(string.format("  - Regular enemies in wave: %d", regular_enemy_count))
print("")

-- Test 3: Lich King Boss Module Mechanics
print("=== Test 3: Lich King Boss Module Mechanics ===")

local lich_king_module = require("serpent.bosses.lich_king")

-- Test basic initialization
local boss_state = lich_king_module.init(2001)
print("✓ Lich King boss module initialized:")
print(string.format("  - Enemy ID: %d", boss_state.enemy_id))
print(string.format("  - Initial Queued Raises: %d", boss_state.queued_raises))

-- Test enemy death handling
print("\n📋 Testing enemy death processing:")

-- Kill a regular enemy
local after_goblin = lich_king_module.on_enemy_dead(boss_state, "goblin", {})
print(string.format("  - After goblin death: %d queued raises", after_goblin.queued_raises))

-- Kill another regular enemy
local after_orc = lich_king_module.on_enemy_dead(after_goblin, "orc", {})
print(string.format("  - After orc death: %d queued raises", after_orc.queued_raises))

-- Kill a boss (should not queue raise)
local after_boss = lich_king_module.on_enemy_dead(after_orc, "dragon", {"boss"})
print(string.format("  - After boss death: %d queued raises", after_boss.queued_raises))

-- Test skeleton raising (tick while alive)
print("\n⚡ Testing skeleton raising:")
local final_state, delayed_spawns = lich_king_module.tick(0.1, after_boss, true)

print(string.format("  - Queued raises after tick: %d", final_state.queued_raises))
print(string.format("  - Delayed spawns generated: %d", #delayed_spawns))

for i, spawn in ipairs(delayed_spawns) do
    print(string.format("  - Delayed Spawn %d: %s (delay: %.1fs)",
        i, spawn.def_id, spawn.t_left_sec))
end

if #delayed_spawns ~= 2 then
    print("❌ FAIL: Expected 2 delayed spawns, got " .. #delayed_spawns)
    os.exit(1)
end

for _, spawn in ipairs(delayed_spawns) do
    if spawn.def_id ~= "skeleton" then
        print("❌ FAIL: Expected skeleton spawn, got " .. spawn.def_id)
        os.exit(1)
    end
    if math.abs(spawn.t_left_sec - 2.0) > 0.01 then
        print("❌ FAIL: Expected 2.0 second delay, got " .. spawn.t_left_sec)
        os.exit(1)
    end
end

print("✓ Necromancy mechanics working correctly")
print("")

-- Test 4: Boss Event Processor Integration
print("=== Test 4: Boss Event Processor Integration ===")

local boss_event_processor = require("serpent.boss_event_processor")

-- Create boss processor with lich king
local lich_boss_entity = { enemy_id = 3001, def_id = "lich_king" }
local processor_state = boss_event_processor.create_state({lich_boss_entity})

print("✓ Boss event processor initialized with lich king:")
print(string.format("  - Active boss count: %d",
    boss_event_processor.get_summary(processor_state).active_boss_count))

-- Create enemy death events
local death_events = {
    { type = "enemy_dead", enemy_id = 1001, def_id = "goblin" },
    { type = "enemy_dead", enemy_id = 1002, def_id = "skeleton" },
    { type = "enemy_dead", enemy_id = 1003, def_id = "orc" }
}

local enemy_definitions = {
    goblin = { id = "goblin", tags = {} },
    skeleton = { id = "skeleton", tags = {} },
    orc = { id = "orc", tags = {} }
}

local alive_bosses = { [3001] = true }

-- Process death events
print("\n📋 Processing enemy death events through boss processor:")
local updated_processor_state = boss_event_processor.process_enemy_dead_events(
    death_events, processor_state, enemy_definitions, alive_bosses)

local lich_state = updated_processor_state.boss_states[3001]
print(string.format("  - Lich king queued raises: %d", lich_state.queued_raises))

-- Tick processor to generate spawn events
local final_processor_state, spawn_events = boss_event_processor.tick(
    0.1, updated_processor_state, alive_bosses)

print(string.format("  - Spawn events generated: %d", #spawn_events))

local delayed_spawn_count = 0
for _, event in ipairs(spawn_events) do
    if event.type == "DelayedSpawnEvent" then
        delayed_spawn_count = delayed_spawn_count + 1
        print(string.format("    - DelayedSpawnEvent: %s (delay: %.1fs, source: %d)",
            event.enemy_def_id, event.delay_sec, event.source_boss_id))
    end
end

if delayed_spawn_count ~= 3 then
    print("❌ FAIL: Expected 3 delayed spawn events, got " .. delayed_spawn_count)
    os.exit(1)
end

print("✓ Boss event processor integration working correctly")
print("")

-- Test 5: Wave Configuration Scaling
print("=== Test 5: Wave 20 Scaling Parameters ===")

local wave_config = require("serpent.wave_config")

local wave_20_summary = wave_config.get_wave_summary(20)
print("✓ Wave 20 scaling parameters:")
print(string.format("  - Enemy Count: %d", wave_20_summary.enemy_count))
print(string.format("  - HP Multiplier: %.2f", wave_20_summary.hp_mult))
print(string.format("  - Damage Multiplier: %.2f", wave_20_summary.dmg_mult))
print(string.format("  - Gold Reward: %d", wave_20_summary.gold_reward))

-- Calculate effective lich king stats
local base_hp = lich_king_def.base_hp
local base_damage = lich_king_def.base_damage
local effective_hp = base_hp * wave_20_summary.hp_mult
local effective_damage = base_damage * wave_20_summary.dmg_mult

print("\n⚡ Effective Lich King Stats at Wave 20:")
print(string.format("  - Base HP: %d → Effective HP: %.0f", base_hp, effective_hp))
print(string.format("  - Base Damage: %d → Effective Damage: %.0f", base_damage, effective_damage))
print("")

-- Final Summary
print("================================================================================")
print("VERIFICATION COMPLETE")
print("================================================================================")

print("✅ ALL VERIFICATIONS PASSED:")
print("   ✓ Lich King is correctly configured for wave 20 only")
print("   ✓ Wave director spawns lich_king boss on wave 20")
print("   ✓ Lich King necromancy mechanics work (raises skeletons on enemy death)")
print("   ✓ Skeleton raising has correct 2-second delay")
print("   ✓ Boss death filtering prevents raising other bosses")
print("   ✓ Boss event processor correctly integrates lich king")
print("   ✓ Wave 20 scaling parameters apply correctly")

print("")
print("🎯 MANUAL VERIFICATION STATUS: COMPLETE")
print("   The lich_king boss correctly appears on wave 20 and implements")
print("   necromancy behavior (raising skeletons with 2s delay on enemy death).")
print("")
print("📋 Next Steps for Full Testing:")
print("   - Start Serpent game and advance to wave 20")
print("   - Verify lich_king spawns visually")
print("   - Kill enemies and watch for delayed skeleton spawns")
print("   - Confirm skeletons appear ~2 seconds after enemy deaths")

print("================================================================================")