-- Tag Evaluator
-- Counts tags in a deck and applies bonuses at 3/5/7/9 breakpoints.
-- This is the core synergy system that rewards specialization.

local TagEvaluator = {}

-- Tag Breakpoint Definitions (from TODO_design.md)
-- Each tag has bonuses at 3, 5, 7, and 9 card thresholds
local TAG_BREAKPOINTS = {
    Fire = {
        [3] = { type = "stat", stat = "burn_damage_pct", value = 10 },
        [5] = { type = "stat", stat = "burn_tick_rate_pct", value = 15 },
        [7] = { type = "proc", proc_id = "burn_explosion_on_kill" },
        [9] = { type = "proc", proc_id = "burn_spread" }
    },

    Ice = {
        [3] = { type = "stat", stat = "slow_potency_pct", value = 10 },
        [5] = { type = "proc", proc_id = "bonus_damage_on_chilled" },
        [7] = { type = "proc", proc_id = "shatter_on_kill" },
        [9] = { type = "stat", stat = "damage_vs_frozen_pct", value = 25 }
    },

    Buff = {
        [3] = { type = "stat", stat = "buff_duration_pct", value = 25 },
        [5] = { type = "proc", proc_id = "buffs_apply_to_allies" },
        [7] = { type = "stat", stat = "buff_duration_pct", value = 50 },
        [9] = { type = "stat", stat = "buff_effect_pct", value = 50 }
    },

    Arcane = {
        [3] = { type = "stat", stat = "chain_targets", value = 1 },
        [5] = { type = "proc", proc_id = "chain_restores_cooldown" },
        [7] = { type = "proc", proc_id = "chain_ricochets" },
        [9] = { type = "proc", proc_id = "chain_nova" }
    },

    Mobility = {
        [3] = { type = "stat", stat = "on_move_proc_frequency_pct", value = 50 },
        [5] = { type = "stat", stat = "move_speed_pct", value = 12 },
        [7] = { type = "proc", proc_id = "move_proc_spray" },
        [9] = { type = "proc", proc_id = "move_evade_buff" }
    },

    Defense = {
        [3] = { type = "stat", stat = "damage_taken_reduction_pct", value = 6 },
        [5] = { type = "proc", proc_id = "barrier_on_block" },
        [7] = { type = "proc", proc_id = "thorns_on_block" },
        [9] = { type = "stat", stat = "barrier_refresh_rate_pct", value = 20 }
    },

    Poison = {
        [3] = { type = "stat", stat = "max_poison_stacks_pct", value = 25 },
        [5] = { type = "proc", proc_id = "poison_ramp_damage" },
        [7] = { type = "proc", proc_id = "poison_spore_on_kill" },
        [9] = { type = "proc", proc_id = "poison_spread_on_death" }
    },

    Summon = {
        [3] = { type = "stat", stat = "summon_hp_pct", value = 12 },
        [5] = { type = "stat", stat = "summon_damage_pct", value = 12 },
        [7] = { type = "proc", proc_id = "empower_minion_periodic" },
        [9] = { type = "stat", stat = "summon_persistence", value = 1 }
    },

    Hazard = {
        [3] = { type = "stat", stat = "hazard_radius_pct", value = 10 },
        [5] = { type = "stat", stat = "hazard_damage_pct", value = 10 },
        [7] = { type = "proc", proc_id = "hazard_chain_ignite" },
        [9] = { type = "stat", stat = "hazard_duration", value = 2 }
    },

    Brute = {
        [3] = { type = "stat", stat = "melee_damage_pct", value = 10 },
        [5] = { type = "proc", proc_id = "melee_cleave" },
        [7] = { type = "stat", stat = "damage_taken_reduction_pct", value = 8 },
        [9] = { type = "stat", stat = "melee_crit_chance_pct", value = 15 }
    },

    Fatty = {
        [3] = { type = "stat", stat = "health_pct", value = 10 },
        [5] = { type = "proc", proc_id = "regen_when_low" },
        [7] = { type = "proc", proc_id = "survive_lethal" },
        [9] = { type = "proc", proc_id = "ally_hp_buff" }
    }
}

--- Count tags in a deck
-- @param deck: Table with .cards array, each card has .tags array
-- @return table: { Fire = 5, Ice = 2, ... }
function TagEvaluator.count_tags(deck)
    local counts = {}

    if not deck or not deck.cards then
        return counts
    end

    for _, card in ipairs(deck.cards) do
        if card.tags then
            for _, tag in ipairs(card.tags) do
                counts[tag] = (counts[tag] or 0) + 1
            end
        end
    end

    return counts
end

--- Apply tag bonuses to a player based on deck composition
-- @param player: Entity with .stats and .procs tables
-- @param deck_snapshot: Deck state with .cards array
-- @param ctx: (Optional) Combat context for event emission
function TagEvaluator.evaluate_and_apply(player, deck_snapshot, ctx)
    local tag_counts = TagEvaluator.count_tags(deck_snapshot)

    -- Store tag counts on player for other systems to reference
    player.tag_counts = tag_counts

    -- NEW: Check for tag threshold discoveries
    local TagDiscoverySystem = require("wand.tag_discovery_system")
    local newDiscoveries = TagDiscoverySystem.checkTagThresholds(player, tag_counts)

    -- Emit discovery events via hump.signal
    if #newDiscoveries > 0 then
        local signal = require("external.hump.signal")
        for _, discovery in ipairs(newDiscoveries) do
            signal.emit("tag_threshold_discovered", {
                tag = discovery.tag,
                threshold = discovery.threshold,
                count = discovery.count
            })

            print(string.format("[DISCOVERY] %s tags reached threshold %d! (current: %d)",
                discovery.tag, discovery.threshold, discovery.count))
        end
    end

    -- Clear previous tag bonuses (to allow re-evaluation)
    player.active_tag_bonuses = player.active_tag_bonuses or {}

    -- Iterate through all tags and check breakpoints
    for tag, breakpoints in pairs(TAG_BREAKPOINTS) do
        local count = tag_counts[tag] or 0

        for threshold, bonus in pairs(breakpoints) do
            if count >= threshold then
                local bonus_key = tag .. "_" .. threshold

                -- Only apply if not already active
                if not player.active_tag_bonuses[bonus_key] then
                    TagEvaluator.apply_bonus(player, bonus, ctx)
                    player.active_tag_bonuses[bonus_key] = true
                end
            else
                -- Remove bonus if count dropped below threshold
                local bonus_key = tag .. "_" .. threshold
                if player.active_tag_bonuses[bonus_key] then
                    TagEvaluator.remove_bonus(player, bonus, ctx)
                    player.active_tag_bonuses[bonus_key] = nil
                end
            end
        end
    end
end

--- Apply a single bonus to a player
-- @param player: Entity
-- @param bonus: Bonus definition { type="stat"|"proc", ... }
-- @param ctx: Combat context
function TagEvaluator.apply_bonus(player, bonus, ctx)
    if bonus.type == "stat" then
        -- Add stat modifier
        if player.stats and player.stats.add_add_pct then
            player.stats:add_add_pct(bonus.stat, bonus.value)
        end
    elseif bonus.type == "proc" then
        -- Enable proc
        player.active_procs = player.active_procs or {}
        player.active_procs[bonus.proc_id] = true

        -- Emit event for game engine to hook up proc behavior
        if ctx and ctx.bus then
            ctx.bus:emit("proc_enabled", {
                entity = player,
                proc_id = bonus.proc_id
            })
        end
    end
end

--- Remove a bonus from a player
-- @param player: Entity
-- @param bonus: Bonus definition
-- @param ctx: Combat context
function TagEvaluator.remove_bonus(player, bonus, ctx)
    if bonus.type == "stat" then
        -- Remove stat modifier
        if player.stats and player.stats.add_add_pct then
            player.stats:add_add_pct(bonus.stat, -bonus.value)
        end
    elseif bonus.type == "proc" then
        -- Disable proc
        if player.active_procs then
            player.active_procs[bonus.proc_id] = nil
        end

        if ctx and ctx.bus then
            ctx.bus:emit("proc_disabled", {
                entity = player,
                proc_id = bonus.proc_id
            })
        end
    end
end

--- Get a summary of active bonuses for UI display
-- @param player: Entity
-- @return table: Array of { tag, threshold, description }
function TagEvaluator.get_active_bonuses(player)
    local bonuses = {}

    if not player.tag_counts then
        return bonuses
    end

    for tag, breakpoints in pairs(TAG_BREAKPOINTS) do
        local count = player.tag_counts[tag] or 0

        for threshold, bonus in pairs(breakpoints) do
            if count >= threshold then
                local desc = ""
                if bonus.type == "stat" then
                    desc = string.format("%s +%d%%", bonus.stat, bonus.value)
                elseif bonus.type == "proc" then
                    desc = bonus.proc_id
                end

                table.insert(bonuses, {
                    tag = tag,
                    threshold = threshold,
                    description = desc
                })
            end
        end
    end

    return bonuses
end

return TagEvaluator
