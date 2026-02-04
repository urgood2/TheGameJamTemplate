#!/bin/bash
# Serpent Mode Implementation - Beads Creation Script
# Creates 100+ beads based on planning/PLAN.md

set -e

# Helper function to create a bead
create_bead() {
    local title="$1"
    local type="$2"
    local priority="$3"
    local labels="$4"
    local description="$5"

    bd create "$title" -t "$type" -p "$priority" -l "$labels" -d "$description" --silent
}

echo "Creating Epic: Task 1 - Mode Skeleton + Core Integration"

# Task 1 - Mode Skeleton + Core Integration
create_bead "Create serpent_main.lua skeleton with init/update/cleanup" "task" "1" "serpent,core,task-1" "Create assets/scripts/serpent/serpent_main.lua with init(), update(dt), cleanup() functions and MODE_STATE state machine (SHOP, COMBAT, VICTORY, GAME_OVER)"

create_bead "Add GAMESTATE.SERPENT=2 to main.lua" "task" "1" "serpent,core,task-1" "Extend GAMESTATE in assets/scripts/core/main.lua to include SERPENT = 2"

create_bead "Wire changeGameState to support SERPENT mode" "task" "1" "serpent,core,task-1" "Update changeGameState() to call Serpent.init() on enter and Serpent.cleanup() on exit"

create_bead "Add Serpent.update(dt) call in main.update" "task" "1" "serpent,core,task-1" "In main.update(dt), call Serpent.update(dt) when currentGameState == GAMESTATE.SERPENT"

create_bead "Add Serpent button to main menu" "task" "1" "serpent,ui,task-1" "Add MainMenuButtons.setButtons entry for Serpent mode with localized label and changeGameState callback"

create_bead "Require serpent_main once in main.lua" "task" "1" "serpent,core,task-1" "Add idempotent require at top of main.lua: local Serpent = require('serpent.serpent_main')"

create_bead "Create SERPENT_TIMER_GROUP constant" "task" "2" "serpent,core,task-1" "Define SERPENT_TIMER_GROUP = 'serpent' and ensure cleanup calls timer.kill_group('serpent')"

create_bead "Implement mode state machine transitions" "task" "1" "serpent,core,task-1" "Implement SHOP->COMBAT, COMBAT->SHOP, COMBAT->VICTORY, Any->GAME_OVER transitions with proper ordering"

create_bead "Verify serpent_main.lua requires successfully" "task" "2" "serpent,test,task-1" "Manual test: lua -e requiring serpent_main succeeds without errors"

echo "Creating Epic: Task 2 - Localization Keys"

# Task 2 - Localization
create_bead "Add Serpent localization keys to en_us.json" "task" "2" "serpent,localization,task-2" "Add keys: ui.start_serpent_button, ui.serpent_ready, ui.serpent_reroll, ui.serpent_victory_title, ui.serpent_game_over_title, ui.serpent_retry, ui.serpent_main_menu"

create_bead "Add Serpent localization keys to ko_kr.json" "task" "2" "serpent,localization,task-2" "Add Korean stub text for all Serpent UI keys (acceptable placeholder text for v-slice)"

echo "Creating Epic: Task 3 - RNG Utility"

# Task 3 - RNG
create_bead "Create rng.lua with PRNG implementation" "task" "1" "serpent,rng,task-3" "Create assets/scripts/serpent/rng.lua with xorshift/LCG PRNG that doesn't touch global math.randomseed"

create_bead "Implement RNG.new(seed) constructor" "task" "1" "serpent,rng,task-3" "RNG.new(seed) creates seeded generator, stores seed for HUD display"

create_bead "Implement rng:int(min, max) method" "task" "1" "serpent,rng,task-3" "Returns inclusive integer in [min, max] range"

create_bead "Implement rng:float() method" "task" "1" "serpent,rng,task-3" "Returns float in [0,1) range"

create_bead "Implement rng:choice(list) method" "task" "1" "serpent,rng,task-3" "Consumes exactly one int call to select from list uniformly"

create_bead "Create test_rng.lua tests" "task" "2" "serpent,test,task-3" "Test same seed identical sequences, different seeds diverge, int inclusive bounds, choice consumes one int"

echo "Creating Epic: Task 4 - Unit Data + Shop Odds"

# Task 4 - Unit Data + Shop Odds
create_bead "Create data/units.lua with 16 unit definitions" "task" "1" "serpent,data,task-4" "Define all 16 units with id, class, tier, cost, base_hp, base_attack, range, atk_spd, special_id matching PLAN.md table"

create_bead "Define Warrior units (soldier, knight, berserker, champion)" "task" "2" "serpent,data,task-4" "4 Warrior units across tiers 1-4 with correct stats"

create_bead "Define Mage units (apprentice, pyromancer, archmage, lich)" "task" "2" "serpent,data,task-4" "4 Mage units across tiers 1-4 with correct stats"

create_bead "Define Ranger units (scout, sniper, assassin, windrunner)" "task" "2" "serpent,data,task-4" "4 Ranger units across tiers 1-4 with correct stats"

create_bead "Define Support units (healer, bard, paladin, angel)" "task" "2" "serpent,data,task-4" "4 Support units across tiers 1-4 with correct stats"

create_bead "Create data/shop_odds.lua with tier probability tables" "task" "1" "serpent,data,task-4" "Define shop tier odds for wave brackets 1-5, 6-10, 11-15, 16-20 matching PLAN.md"

create_bead "Create test_units.lua tests" "task" "2" "serpent,test,task-4" "Test 16 entries, 4 per class, IDs match, all numeric fields match expected"

create_bead "Create test_shop_odds.lua tests" "task" "2" "serpent,test,task-4" "Test correct odds per wave bracket, probabilities sum to 1.0"

echo "Creating Epic: Task 5 - Enemy Data + Factory"

# Task 5 - Enemy Data + Factory
create_bead "Create data/enemies.lua with 11 enemy definitions" "task" "1" "serpent,data,task-5" "Define all 11 enemies with id, base_hp, base_damage, speed, boss flag, min_wave, max_wave"

create_bead "Define basic enemies (slime, bat, goblin)" "task" "2" "serpent,data,task-5" "Early game enemies with correct stats and wave ranges"

create_bead "Define mid-tier enemies (orc, skeleton, wizard)" "task" "2" "serpent,data,task-5" "Mid game enemies with correct stats and wave ranges"

create_bead "Define late-game enemies (troll, demon, dragon)" "task" "2" "serpent,data,task-5" "Late game enemies with correct stats and wave ranges"

create_bead "Define boss enemies (swarm_queen, lich_king)" "task" "1" "serpent,data,task-5" "Boss definitions with boss=true tag, exact wave ranges (10-10, 20-20)"

create_bead "Create enemy_factory.lua" "task" "1" "serpent,factory,task-5" "Create assets/scripts/serpent/enemy_factory.lua module"

create_bead "Implement create_snapshot function" "task" "1" "serpent,factory,task-5" "create_snapshot(enemy_def, enemy_id, wave_num, wave_config, x, y) returns EnemySnapshot with scaled hp/damage"

create_bead "Implement HP scaling formula" "task" "2" "serpent,factory,task-5" "hp_max = floor(enemy_def.base_hp * (1 + wave * 0.1) + 0.00001)"

create_bead "Implement damage scaling formula" "task" "2" "serpent,factory,task-5" "damage = floor(enemy_def.base_damage * (1 + wave * 0.05) + 0.00001)"

create_bead "Create test_enemies.lua tests" "task" "2" "serpent,test,task-5" "Test 11 entries, expected IDs, numeric fields match, wave ranges valid"

create_bead "Create test_enemy_factory.lua tests" "task" "2" "serpent,test,task-5" "Test hp/damage scaling formulas, rounding, boss tags preserved, positions set"

echo "Creating Epic: Task 6 - Snake Core Logic"

# Task 6 - Snake Logic
create_bead "Create snake_logic.lua module" "task" "1" "serpent,logic,task-6" "Create assets/scripts/serpent/snake_logic.lua"

create_bead "Implement create_initial function" "task" "1" "serpent,logic,task-6" "create_initial(unit_defs, min_len, max_len, id_state) returns SnakeState with soldier, apprentice, scout"

create_bead "Implement can_sell function" "task" "1" "serpent,logic,task-6" "can_sell(snake_state, instance_id) returns false if would drop below min_len=3"

create_bead "Implement remove_instance function" "task" "1" "serpent,logic,task-6" "remove_instance(snake_state, instance_id) removes segment, allows dropping below 3 for deaths"

create_bead "Implement is_dead function" "task" "2" "serpent,logic,task-6" "is_dead(snake_state) returns true when #segments == 0"

create_bead "Create test_snake_logic.lua tests" "task" "2" "serpent,test,task-6" "Test sell blocking, death removal, length 0 dead, create_initial monotonic ids"

echo "Creating Epic: Task 7 - Unit Factory + Combine"

# Task 7 - Unit Factory + Combine
create_bead "Create unit_factory.lua module" "task" "1" "serpent,factory,task-7" "Create assets/scripts/serpent/unit_factory.lua"

create_bead "Implement create_instance function" "task" "1" "serpent,factory,task-7" "create_instance(unit_def, instance_id, acquired_seq) returns level-1 UnitInstance with base stats"

create_bead "Implement apply_level_scaling function" "task" "1" "serpent,factory,task-7" "apply_level_scaling(unit_def, level) returns hp_max_base, attack_base using 2^(level-1) formula"

create_bead "Create combine_logic.lua module" "task" "1" "serpent,logic,task-7" "Create assets/scripts/serpent/combine_logic.lua"

create_bead "Implement apply_combines_until_stable function" "task" "1" "serpent,logic,task-7" "Repeatedly combine triples until no more possible, process def_id ascending then level 1->2"

create_bead "Implement triple detection by def_id and level" "task" "2" "serpent,logic,task-7" "Group by (def_id, level), find 3+ instances with lowest acquired_seq"

create_bead "Implement combine merge logic" "task" "2" "serpent,logic,task-7" "Keep lowest acquired_seq instance, upgrade to level+1, remove other 2, set hp=hp_max_base"

create_bead "Create test_unit_factory.lua tests" "task" "2" "serpent,test,task-7" "Test stat scaling 2^(level-1), cap at level 3"

create_bead "Create test_combines.lua tests" "task" "2" "serpent,test,task-7" "Test lowest acquired_seq triple, chain combine, kept slot preserved, full-heal on combine"

echo "Creating Epic: Task 8 - Synergy System"

# Task 8 - Synergy System
create_bead "Create synergy_system.lua module" "task" "1" "serpent,synergy,task-8" "Create assets/scripts/serpent/synergy_system.lua"

create_bead "Implement calculate function" "task" "1" "serpent,synergy,task-8" "calculate(segments, unit_defs) returns synergy_state with counts per class"

create_bead "Implement get_effective_multipliers function" "task" "1" "serpent,synergy,task-8" "Returns by_instance_id with hp_mult, atk_mult, range_mult, atk_spd_mult, cooldown_period_mult, global_regen_per_sec"

create_bead "Implement Warrior synergy bonuses" "task" "2" "serpent,synergy,task-8" "2: +20% attack damage to Warriors, 4: +40% attack, +20% HP to Warriors"

create_bead "Implement Mage synergy bonuses" "task" "2" "serpent,synergy,task-8" "2: +20% spell damage to Mages, 4: +40% spell damage, cooldown_period_mult=0.8 for Mages"

create_bead "Implement Ranger synergy bonuses" "task" "2" "serpent,synergy,task-8" "2: +20% atk_spd to Rangers, 4: +40% atk_spd, +20% range to Rangers"

create_bead "Implement Support synergy bonuses" "task" "2" "serpent,synergy,task-8" "2: 5 HP/sec global regen, 4: 10 HP/sec global regen, +10% all stats to all units"

create_bead "Create test_synergy_system.lua tests" "task" "2" "serpent,test,task-8" "Test thresholds at 2/4, modifier values match table, mage cooldown rule"

echo "Creating Epic: Task 9 - Specials System"

# Task 9 - Specials System
create_bead "Create specials_system.lua module" "task" "1" "serpent,specials,task-9" "Create assets/scripts/serpent/specials_system.lua"

create_bead "Implement get_passive_mods function" "task" "1" "serpent,specials,task-9" "Returns passive modifiers by instance_id (knight_block, bard buffs)"

create_bead "Implement tick function for heals" "task" "1" "serpent,specials,task-9" "tick(dt, ctx, rng) returns heal events with deterministic ordering"

create_bead "Implement on_attack modifier function" "task" "1" "serpent,specials,task-9" "on_attack(ctx, attack_event, rng) applies sniper_crit 20% chance for 2x damage"

create_bead "Implement on_damage_taken modifier function" "task" "1" "serpent,specials,task-9" "on_damage_taken applies paladin_divine_shield, knight_block 20% reduction"

create_bead "Implement on_enemy_death function" "task" "1" "serpent,specials,task-9" "on_enemy_death increments berserker stacks by 5% attack per credited kill"

create_bead "Implement on_wave_start function" "task" "2" "serpent,specials,task-9" "on_wave_start resets paladin_divine_shield availability"

create_bead "Implement healer_adjacent_regen special" "task" "1" "serpent,specials,task-9" "Healer heals adjacent segments 10 HP/sec each with accumulator"

create_bead "Implement knight_block special" "task" "2" "serpent,specials,task-9" "Knight takes 20% less damage (damage * 0.8, floor)"

create_bead "Implement sniper_crit special" "task" "2" "serpent,specials,task-9" "20% chance per attack to deal 2x damage, roll via rng:float()"

create_bead "Implement bard_adjacent_atkspd special" "task" "2" "serpent,specials,task-9" "Adjacent segments gain +10% atk_spd, multiplicative stacking per adjacent bard"

create_bead "Implement berserker_frenzy special" "task" "2" "serpent,specials,task-9" "+5% attack per credited kill, stacking, persists within run"

create_bead "Implement paladin_divine_shield special" "task" "2" "serpent,specials,task-9" "Once per wave, first nonzero hit becomes 0 damage"

create_bead "Create test_specials.lua tests" "task" "2" "serpent,test,task-9" "Test all 6 implemented specials with deterministic verification"

echo "Creating Epic: Task 10 - Wave Config"

# Task 10 - Wave Config
create_bead "Create wave_config.lua module" "task" "1" "serpent,wave,task-10" "Create assets/scripts/serpent/wave_config.lua"

create_bead "Implement enemy_count formula" "task" "2" "serpent,wave,task-10" "enemy_count(wave) = 5 + wave * 2"

create_bead "Implement hp_mult formula" "task" "2" "serpent,wave,task-10" "hp_mult(wave) = 1 + wave * 0.1"

create_bead "Implement dmg_mult formula" "task" "2" "serpent,wave,task-10" "dmg_mult(wave) = 1 + wave * 0.05"

create_bead "Implement gold_reward formula" "task" "2" "serpent,wave,task-10" "gold_reward(wave) = 10 + wave * 2"

create_bead "Implement get_pool function" "task" "1" "serpent,wave,task-10" "get_pool(wave_num, enemy_defs) returns non-boss enemy ids where min_wave <= wave <= max_wave"

create_bead "Create test_wave_config.lua tests" "task" "2" "serpent,test,task-10" "Test formulas match spec, pool membership per wave bracket"

echo "Creating Epic: Task 11 - Shop System"

# Task 11 - Shop System
create_bead "Create serpent_shop.lua module" "task" "1" "serpent,shop,task-11" "Create assets/scripts/serpent/serpent_shop.lua"

create_bead "Implement enter_shop function" "task" "1" "serpent,shop,task-11" "enter_shop(upcoming_wave, gold, rng, unit_defs, shop_odds) returns shop_state with 5 offers"

create_bead "Implement shop offer generation" "task" "1" "serpent,shop,task-11" "For each slot: roll tier by odds, build stable-sorted tier pool, pick uniformly"

create_bead "Implement reroll function" "task" "1" "serpent,shop,task-11" "reroll(shop_state, rng, unit_defs, shop_odds) regenerates offers, increments cost (2,3,4...)"

create_bead "Implement can_buy function" "task" "2" "serpent,shop,task-11" "Check gold >= cost and purchase+combines results in length <= max_len"

create_bead "Implement buy function" "task" "1" "serpent,shop,task-11" "buy() appends unit to tail, runs combines, updates gold and id_state"

create_bead "Implement sell function" "task" "1" "serpent,shop,task-11" "sell() removes unit if can_sell, returns gold = floor(cost * 3^(level-1) * 0.5)"

create_bead "Create test_serpent_shop.lua tests" "task" "2" "serpent,test,task-11" "Test 5 offers, reroll cost increments, gold accounting, purchase/sell logic"

echo "Creating Epic: Task 12 - Auto-Attack Logic"

# Task 12 - Auto-Attack
create_bead "Create auto_attack_logic.lua module" "task" "1" "serpent,combat,task-12" "Create assets/scripts/serpent/auto_attack_logic.lua"

create_bead "Implement tick function" "task" "1" "serpent,combat,task-12" "tick(dt, segment_combat_snaps, enemy_snaps) returns updated cooldowns and attack events"

create_bead "Implement target selection" "task" "1" "serpent,combat,task-12" "Select nearest enemy within effective_range, tie-break by lowest enemy_id"

create_bead "Implement attack cadence" "task" "2" "serpent,combat,task-12" "While cooldown <= 0 and target exists: emit attack, add effective_period to cooldown"

create_bead "Create test_auto_attack_logic.lua tests" "task" "2" "serpent,test,task-12" "Test multi-attack, nearest selection, tie-break, out-of-range, stable ordering"

echo "Creating Epic: Task 13 - Combat Logic"

# Task 13 - Combat Logic
create_bead "Create combat_logic.lua module" "task" "1" "serpent,combat,task-13" "Create assets/scripts/serpent/combat_logic.lua"

create_bead "Implement init_state function" "task" "1" "serpent,combat,task-13" "init_state(snake_state, wave_num) returns combat_state with accumulators and cooldown map"

create_bead "Implement tick function core loop" "task" "1" "serpent,combat,task-13" "tick() orchestrates all combat phases in correct order"

create_bead "Implement position merge phase" "task" "2" "serpent,combat,task-13" "Update enemy_snaps x/y from enemy_pos_snaps, build segment_positions_by_instance_id"

create_bead "Implement cooldown decrement phase" "task" "2" "serpent,combat,task-13" "Decrement unit cooldowns by dt for each segment head->tail"

create_bead "Implement synergy/passive computation phase" "task" "2" "serpent,combat,task-13" "Compute synergy_state and passive mods, calculate effective stats"

create_bead "Implement healing phase" "task" "1" "serpent,combat,task-13" "Emit global regen heals (cursor-driven), then healer targeted heals in order"

create_bead "Implement global regen accumulator" "task" "2" "serpent,combat,task-13" "Accumulate regen, emit 1 HP heals round-robin via cursor, wrap head->tail"

create_bead "Implement attack production phase" "task" "2" "serpent,combat,task-13" "Generate auto-attacks in head->tail order using auto_attack_logic"

create_bead "Implement attack modifier phase" "task" "2" "serpent,combat,task-13" "Apply on-attack specials (sniper_crit), emit DamageEventEnemy"

create_bead "Implement enemy damage and death phase" "task" "1" "serpent,combat,task-13" "Apply damage, emit DeathEventEnemy when hp<=0, remove dead from enemy_snaps"

create_bead "Implement contact damage phase" "task" "1" "serpent,combat,task-13" "Process ContactSnapshot sorted (enemy_id, instance_id), apply 0.5s cooldown gating"

create_bead "Implement unit damage and death phase" "task" "1" "serpent,combat,task-13" "Apply on_damage_taken modifiers, apply damage, emit DeathEventUnit when hp<=0"

create_bead "Implement cleanup phase" "task" "2" "serpent,combat,task-13" "Remove dead units from snake_state.segments, prune stale contact_cooldowns"

create_bead "Implement special event hooks phase" "task" "2" "serpent,combat,task-13" "Feed events to specials: enemy_dead->berserker, wave_start->paladin reset"

create_bead "Create test_combat_logic.lua tests" "task" "2" "serpent,test,task-13" "Test class multipliers, global regen, contact cooldown, deaths, berserker stacks"

echo "Creating Epic: Task 14 - Wave Director"

# Task 14 - Wave Director
create_bead "Create serpent_wave_director.lua module" "task" "1" "serpent,wave,task-14" "Create assets/scripts/serpent/serpent_wave_director.lua"

create_bead "Define spawn rate constants" "task" "2" "serpent,wave,task-14" "SPAWN_RATE_PER_SEC = 10, MAX_SPAWNS_PER_FRAME = 3"

create_bead "Implement start_wave function" "task" "1" "serpent,wave,task-14" "start_wave(wave_num, rng, enemy_defs, wave_config) builds base_spawn_list via RNG"

create_bead "Implement base enemy selection algorithm" "task" "1" "serpent,wave,task-14" "Build spawn list of length enemy_count(wave) using rng:choice(pool) for each"

create_bead "Implement boss injection" "task" "1" "serpent,wave,task-14" "Wave 10: prepend swarm_queen to forced_queue, Wave 20: prepend lich_king"

create_bead "Implement tick function" "task" "1" "serpent,wave,task-14" "tick(dt, director_state, id_state, rng, combat_events, alive_set) returns spawn events"

create_bead "Implement delayed timer processing" "task" "2" "serpent,wave,task-14" "Decrement delayed_queue timers, move expired to forced_queue in order"

create_bead "Implement boss event processing" "task" "1" "serpent,wave,task-14" "Process enemy_dead events for lich_king raise scheduling"

create_bead "Implement boss periodic spawns" "task" "1" "serpent,wave,task-14" "swarm_queen: 5 slimes every 10s, lich_king: queue skeleton raises"

create_bead "Implement spawn emission" "task" "1" "serpent,wave,task-14" "Emit from forced_queue first (FIFO), then base_spawn_list via spawn_budget"

create_bead "Implement is_done_spawning function" "task" "2" "serpent,wave,task-14" "is_done_spawning returns true when pending_count == 0"

create_bead "Create test_serpent_wave_director.lua tests" "task" "2" "serpent,test,task-14" "Test spawn counts, determinism, boss behaviors, pending_count accuracy"

echo "Creating Epic: Task 15 - Contact Collector + Physics"

# Task 15 - Contact Collector
create_bead "Add SERPENT_SEGMENT collision tag to constants.lua" "task" "1" "serpent,physics,task-15" "Add CollisionTags.SERPENT_SEGMENT = 'serpent_segment' to constants.lua"

create_bead "Create contact_collector.lua module" "task" "1" "serpent,physics,task-15" "Create assets/scripts/serpent/contact_collector.lua"

create_bead "Implement physics callback registration" "task" "1" "serpent,physics,task-15" "Register on_pair_begin and on_pair_separate once globally"

create_bead "Implement set_enabled function" "task" "2" "serpent,physics,task-15" "Toggle whether callbacks mutate internal overlap state"

create_bead "Implement enemy entity registration" "task" "1" "serpent,physics,task-15" "register_enemy_entity(enemy_id, entity_id), unregister with overlap cleanup"

create_bead "Implement segment entity registration" "task" "1" "serpent,physics,task-15" "register_segment_entity(instance_id, entity_id), unregister with overlap cleanup"

create_bead "Implement overlap tracking" "task" "1" "serpent,physics,task-15" "Store overlaps as set keyed by enemy_id..':'..instance_id to avoid duplicates"

create_bead "Implement build_snapshot function" "task" "1" "serpent,physics,task-15" "build_snapshot() returns ContactSnapshot sorted by (enemy_id, instance_id)"

create_bead "Implement clear function" "task" "2" "serpent,physics,task-15" "clear() wipes all overlap state, called on disable/cleanup"

create_bead "Wire collision tags in serpent_main.lua" "task" "1" "serpent,physics,task-15" "AddCollisionTag(SERPENT_SEGMENT), enable_collision_between SERPENT_SEGMENT and ENEMY"

echo "Creating Epic: Task 16 - Runtime Entities + Controllers"

# Task 16 - Snake/Enemy Entities + Controllers
create_bead "Create snake_entity_adapter.lua module" "task" "1" "serpent,runtime,task-16" "Create assets/scripts/serpent/snake_entity_adapter.lua"

create_bead "Implement segment entity spawning" "task" "1" "serpent,runtime,task-16" "Spawn segment entities tagged SERPENT_SEGMENT with physics bodies"

create_bead "Implement segment entity mapping" "task" "2" "serpent,runtime,task-16" "Maintain instance_id -> entity_id mapping, register with contact_collector"

create_bead "Implement segment despawn and unregister" "task" "2" "serpent,runtime,task-16" "On despawn, unregister from contact_collector"

create_bead "Implement build_pos_snapshots for segments" "task" "1" "serpent,runtime,task-16" "build_pos_snapshots() returns SegmentPosSnapshot[] in head->tail order"

create_bead "Create snake_controller.lua module" "task" "1" "serpent,runtime,task-16" "Create assets/scripts/serpent/snake_controller.lua"

create_bead "Implement head steering via WASD/arrows" "task" "1" "serpent,runtime,task-16" "Read input, set head velocity using physics.SetVelocity"

create_bead "Implement arena boundary clamping" "task" "2" "serpent,runtime,task-16" "Clamp head position to arena bounds via physics.SetPosition"

create_bead "Implement tail following" "task" "1" "serpent,runtime,task-16" "Each segment follows previous at SEGMENT_SPACING=40px"

create_bead "Create enemy_entity_adapter.lua module" "task" "1" "serpent,runtime,task-16" "Create assets/scripts/serpent/enemy_entity_adapter.lua"

create_bead "Implement enemy entity spawning" "task" "1" "serpent,runtime,task-16" "Spawn enemy entities tagged ENEMY with physics bodies"

create_bead "Implement enemy entity mapping" "task" "2" "serpent,runtime,task-16" "Maintain enemy_id -> entity_id mapping, register with contact_collector"

create_bead "Implement enemy despawn and unregister" "task" "2" "serpent,runtime,task-16" "On despawn, unregister from contact_collector"

create_bead "Implement build_pos_snapshots for enemies" "task" "1" "serpent,runtime,task-16" "build_pos_snapshots() returns EnemyPosSnapshot[] sorted by enemy_id"

create_bead "Create enemy_controller.lua module" "task" "1" "serpent,runtime,task-16" "Create assets/scripts/serpent/enemy_controller.lua"

create_bead "Implement enemy movement toward head" "task" "1" "serpent,runtime,task-16" "Move toward head position at enemy.speed using physics.SetVelocity"

echo "Creating Epic: Task 17 - Spawner + Combat Adapter"

# Task 17 - Spawner + Combat Adapter
create_bead "Create enemy_spawner_adapter.lua module" "task" "1" "serpent,runtime,task-17" "Create assets/scripts/serpent/enemy_spawner_adapter.lua"

create_bead "Implement SpawnEnemyEvent consumption" "task" "1" "serpent,runtime,task-17" "Process spawn events with explicit enemy_id"

create_bead "Implement spawn position calculation" "task" "1" "serpent,runtime,task-17" "Compute deterministic spawn positions via RNG + edge_random spawn rule"

create_bead "Implement enemy creation and list update" "task" "1" "serpent,runtime,task-17" "Use enemy_factory.create_snapshot, return sorted enemy_snaps list"

create_bead "Create combat_adapter.lua module" "task" "1" "serpent,runtime,task-17" "Create assets/scripts/serpent/combat_adapter.lua"

create_bead "Implement enemy damage/death event handling" "task" "1" "serpent,runtime,task-17" "Apply DamageEventEnemy/DeathEventEnemy to runtime entities"

create_bead "Implement unit damage/death event handling" "task" "1" "serpent,runtime,task-17" "Apply DamageEventUnit/DeathEventUnit to runtime segments"

create_bead "Implement entity despawn and contact unregister" "task" "2" "serpent,runtime,task-17" "Despawn entities on death, unregister from contact_collector"

echo "Creating Epic: Task 18 - UI Components"

# Task 18 - UI
create_bead "Create ui/shop_ui.lua module" "task" "1" "serpent,ui,task-18" "Create assets/scripts/serpent/ui/shop_ui.lua"

create_bead "Implement shop slot view-model helpers" "task" "2" "serpent,ui,task-18" "Slot labels, affordability checks, enable/disable states"

create_bead "Implement reroll button view-model" "task" "2" "serpent,ui,task-18" "Reroll label with cost, enable/disable based on gold"

create_bead "Implement sell button view-model" "task" "2" "serpent,ui,task-18" "Sell enable/disable based on can_sell check"

create_bead "Implement ready button view-model" "task" "2" "serpent,ui,task-18" "Ready button enable based on minimum snake length"

create_bead "Implement shop UI interactions" "task" "1" "serpent,ui,task-18" "Buy/reroll/sell/ready callbacks drive pure shop operations"

create_bead "Create ui/synergy_ui.lua module" "task" "1" "serpent,ui,task-18" "Create assets/scripts/serpent/ui/synergy_ui.lua"

create_bead "Implement synergy display view-model" "task" "2" "serpent,ui,task-18" "Show class counts and active synergy bonuses from synergy_state"

create_bead "Create ui/hud.lua module" "task" "1" "serpent,ui,task-18" "Create assets/scripts/serpent/ui/hud.lua"

create_bead "Implement HP bar view-model" "task" "1" "serpent,ui,task-18" "HP as sum(hp)/sum(effective_hp_max) across segments"

create_bead "Implement gold/wave/seed display" "task" "2" "serpent,ui,task-18" "Show current gold, wave number, and seed on HUD"

create_bead "Create test_shop_ui.lua tests" "task" "2" "serpent,test,task-18" "Test view-model helpers only"

create_bead "Create test_synergy_ui.lua tests" "task" "2" "serpent,test,task-18" "Test synergy view-model formatting"

create_bead "Create test_hud.lua tests" "task" "2" "serpent,test,task-18" "Test HP formatting and aggregation helpers"

echo "Creating Epic: Task 19 - Boss Modules"

# Task 19 - Bosses
create_bead "Create bosses/swarm_queen.lua module" "task" "1" "serpent,boss,task-19" "Create assets/scripts/serpent/bosses/swarm_queen.lua"

create_bead "Implement swarm_queen init function" "task" "2" "serpent,boss,task-19" "init(enemy_id) returns boss_state with spawn timer"

create_bead "Implement swarm_queen tick function" "task" "1" "serpent,boss,task-19" "tick(dt, boss_state, is_alive) returns 5 slimes every 10s while alive"

create_bead "Create bosses/lich_king.lua module" "task" "1" "serpent,boss,task-19" "Create assets/scripts/serpent/bosses/lich_king.lua"

create_bead "Implement lich_king init function" "task" "2" "serpent,boss,task-19" "init(enemy_id) returns boss_state with raise queue"

create_bead "Implement lich_king on_enemy_dead function" "task" "1" "serpent,boss,task-19" "Queue skeleton raise with 2s delay for non-boss enemy deaths"

create_bead "Implement lich_king tick function" "task" "1" "serpent,boss,task-19" "tick(dt, boss_state, is_alive) returns delayed spawn entries"

create_bead "Create test_bosses.lua tests" "task" "2" "serpent,test,task-19" "Test swarm_queen cadence, lich_king raise scheduling, boss death filtering"

echo "Creating Epic: Task 20 - End Screens"

# Task 20 - End Screens
create_bead "Create ui/game_over_screen.lua module" "task" "1" "serpent,ui,task-20" "Create assets/scripts/serpent/ui/game_over_screen.lua"

create_bead "Implement game over view-model" "task" "2" "serpent,ui,task-20" "Show ui.serpent_game_over_title, run stats, retry/menu buttons"

create_bead "Create ui/victory_screen.lua module" "task" "1" "serpent,ui,task-20" "Create assets/scripts/serpent/ui/victory_screen.lua"

create_bead "Implement victory view-model" "task" "2" "serpent,ui,task-20" "Show ui.serpent_victory_title, run stats, retry/menu buttons"

create_bead "Implement retry button callback" "task" "2" "serpent,ui,task-20" "Retry performs full cleanup and re-enters SERPENT state"

create_bead "Implement main menu button callback" "task" "2" "serpent,ui,task-20" "Main menu performs full cleanup and transitions to GAMESTATE.MAIN_MENU"

create_bead "Track run stats in serpent_main.lua" "task" "2" "serpent,core,task-20" "Track waves_cleared, gold_earned, units_purchased for end screens"

create_bead "Create test_screens.lua tests" "task" "2" "serpent,test,task-20" "Test required labels present, buttons configured, localization keys used"

echo "Creating verification and integration beads"

# Verification and Integration
create_bead "Manual verification: Enter/exit SERPENT mode" "task" "2" "serpent,manual-test,verification" "Verify entering SERPENT from main menu and exiting without duplicate state"

create_bead "Manual verification: Snake movement and boundaries" "task" "2" "serpent,manual-test,verification" "Verify snake spawns correctly, movement stable, head stays in arena"

create_bead "Manual verification: Enemy spawning and movement" "task" "2" "serpent,manual-test,verification" "Verify enemies spawn at edges, move toward snake head"

create_bead "Manual verification: Contact damage works" "task" "2" "serpent,manual-test,verification" "Verify enemy touching segment deals damage once per 0.5s"

create_bead "Manual verification: Unit/enemy death despawn" "task" "2" "serpent,manual-test,verification" "Verify death removes entities cleanly from both sides"

create_bead "Manual verification: Shop buy/sell/reroll" "task" "2" "serpent,manual-test,verification" "Verify shop operations work correctly with gold accounting"

create_bead "Manual verification: Combine system" "task" "2" "serpent,manual-test,verification" "Verify 3 same units combine into upgraded unit"

create_bead "Manual verification: Wave progression" "task" "2" "serpent,manual-test,verification" "Verify wave clears when all enemies dead and spawns complete"

create_bead "Manual verification: Boss wave 10 (swarm_queen)" "task" "2" "serpent,manual-test,verification" "Verify swarm_queen appears on wave 10, spawns slimes every 10s"

create_bead "Manual verification: Boss wave 20 (lich_king)" "task" "2" "serpent,manual-test,verification" "Verify lich_king appears on wave 20, raises skeletons on enemy death"

create_bead "Manual verification: Victory screen" "task" "2" "serpent,manual-test,verification" "Verify victory screen shows after wave 20 cleared"

create_bead "Manual verification: Game over screen" "task" "2" "serpent,manual-test,verification" "Verify game over triggers at length 0 from combat deaths"

create_bead "Manual verification: Determinism spot-check" "task" "2" "serpent,manual-test,verification" "Same SERPENT_SEED yields identical shop offers and spawn positions"

create_bead "Run all Serpent unit tests" "task" "1" "serpent,test,verification" "Execute: lua assets/scripts/tests/test_runner.lua assets/scripts/serpent/tests/"

create_bead "Full playthrough verification" "task" "1" "serpent,manual-test,verification" "Complete run from start to victory without errors"

echo "Done! Created all Serpent implementation beads."
