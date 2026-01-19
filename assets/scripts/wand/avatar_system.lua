--[[
================================================================================
AVATAR SYSTEM (Minimal Unlock Tracker)
================================================================================
Tracks avatar unlock progress and state. Designed to be lightweight and data-
driven using assets/scripts/data/avatars.lua. Unlocks can be triggered by:
  - Run-time metrics (kills, distance moved, etc.) stored on the player
  - Tag thresholds (e.g., 7 Fire tags)

API (minimal):
  AvatarSystem.check_unlocks(player, opts) -> {avatar_ids_unlocked_this_call}
    opts.tag_counts : table of tag -> count (optional)
    opts.metrics    : table of metric -> value (optional; falls back to player.avatar_progress)

  AvatarSystem.record_progress(player, metric, delta, opts)
    Increments progress metric, then calls check_unlocks.

  AvatarSystem.equip(player, avatar_id)
    Marks an already-unlocked avatar as equipped for the run.
================================================================================
]] --

local AvatarSystem = {}

local avatarDefs = nil

--[[
================================================================================
PROC EFFECTS REGISTRY
================================================================================
Maps effect names to execution functions. Each receives (player, effect).
]]--

--[[
================================================================================
BLESSING EFFECTS REGISTRY
================================================================================
Maps blessing effect names to execution functions. Each receives (player, effect, config).
Blessings are activated abilities with cooldowns, not passive procs.
]]--

local BLESSING_EFFECTS = {
    --- Fire nova around player
    --- @param player table Player script table
    --- @param effect table Blessing effect definition
    --- @param config table Blessing config (radius, damage, burn_stacks, burn_duration)
    fire_nova = function(player, effect, config)
        config = config or {}
        local radius = config.radius or 150
        local damage = config.damage or 50
        local burn_stacks = config.burn_stacks or 3
        print(string.format("[Blessing] Fire Nova: radius=%d, damage=%d, burn_stacks=%d",
            radius, damage, burn_stacks))
        -- TODO: Apply actual damage and burn to enemies in radius
    end,

    --- Frost barrier that freezes attackers
    --- @param player table Player script table
    --- @param effect table Blessing effect definition
    --- @param config table Blessing config (barrier_pct, freeze_duration)
    frost_barrier = function(player, effect, config)
        config = config or {}
        local barrier_pct = config.barrier_pct or 30
        local freeze_duration = config.freeze_duration or 2.0
        print(string.format("[Blessing] Frost Barrier: barrier=%d%%, freeze=%.1fs",
            barrier_pct, freeze_duration))

        -- Apply barrier
        local combatActor = player.combatTable
        if combatActor and combatActor.stats and combatActor.addBarrier then
            local maxHp = combatActor.stats:get("max_hp") or 100
            local barrier = math.floor(maxHp * (barrier_pct / 100))
            combatActor:addBarrier(barrier)
        end
        -- TODO: Add freeze effect on being hit during duration
    end,

    --- Chain lightning storm that strikes enemies
    --- @param player table Player script table
    --- @param effect table Blessing effect definition
    --- @param config table Blessing config (bolts_per_second, damage_per_bolt, chain_count)
    chain_lightning_storm = function(player, effect, config)
        config = config or {}
        local bolts = config.bolts_per_second or 3
        local damage = config.damage_per_bolt or 25
        local chains = config.chain_count or 2
        print(string.format("[Blessing] Lightning Storm: %d bolts/s, %d dmg, %d chains",
            bolts, damage, chains))
        -- TODO: Spawn lightning bolts over duration
    end,

    --- Gravity well that pulls and damages enemies
    --- @param player table Player script table
    --- @param effect table Blessing effect definition
    --- @param config table Blessing config (radius, pull_strength, damage_per_second)
    gravity_well = function(player, effect, config)
        config = config or {}
        local radius = config.radius or 200
        local pull = config.pull_strength or 100
        local dps = config.damage_per_second or 15
        print(string.format("[Blessing] Void Rift: radius=%d, pull=%d, dps=%d",
            radius, pull, dps))
        -- TODO: Create gravity well entity with pull/damage
    end,
}

-- Expose BLESSING_EFFECTS for test detection
AvatarSystem.BLESSING_EFFECTS = BLESSING_EFFECTS

local PROC_EFFECTS = {
    --- Heal the player for flat HP
    --- @param player table Player script table
    --- @param effect table Effect definition with .value
    heal = function(player, effect)
        local combatActor = player.combatTable
        if combatActor and combatActor.heal then
            combatActor:heal(effect.value or 0)
        end
    end,

    --- Apply barrier as % of max HP
    --- @param player table Player script table
    --- @param effect table Effect definition with .value (percentage)
    global_barrier = function(player, effect)
        local combatActor = player.combatTable
        if combatActor and combatActor.stats and combatActor.addBarrier then
            local maxHp = combatActor.stats:get("max_hp") or 100
            local barrier = math.floor(maxHp * ((effect.value or 0) / 100))
            combatActor:addBarrier(barrier)
        end
    end,

    --- Spread poison in radius around player
    --- @param player table Player script table
    --- @param effect table Effect definition with .radius
    poison_spread = function(player, effect)
        -- TODO: Implement when poison system is ready
        -- For now, just log that it would trigger
        print(string.format("[AvatarProc] poison_spread triggered, radius=%d", effect.radius or 5))
    end,

    --- Initialize Conduit Charge system with decay timer
    --- @param player table Player script table
    --- @param effect table Effect definition with .config
    conduit_charge = function(player, effect)
        local config = effect.config or {}
        local decay_interval = config.decay_interval or 5.0
        local bonus_per_stack = config.damage_bonus_per_stack or 5

        -- Initialize stack counter
        player.conduit_stacks = 0

        -- Start decay timer
        local timer = require("core.timer")
        timer.every_opts({
            delay = decay_interval,
            action = function()
                if player.conduit_stacks and player.conduit_stacks > 0 then
                    player.conduit_stacks = player.conduit_stacks - 1

                    -- Remove one stack's worth of bonus
                    local combatActor = player.combatTable
                    if combatActor and combatActor.stats then
                        combatActor.stats:add_add_pct("all_damage_pct", -bonus_per_stack)
                        combatActor.stats:recompute()
                    end

                    -- Debug: Log decay
                    local totalBonus = player.conduit_stacks * bonus_per_stack
                    print(string.format("[Conduit] Decay: now %d stacks (+%d%% damage)",
                        player.conduit_stacks, totalBonus))
                end
            end,
            tag = "conduit_decay",
            group = "avatar_conduit"
        })

        print("[Conduit] Charge system initialized (decay every 5s)")
    end,
}

--- Execute a proc effect by name
--- @param player table Player script table
--- @param effect table Effect definition with .effect field
local function execute_effect(player, effect)
    if not effect or not effect.effect then return end

    local handler = PROC_EFFECTS[effect.effect]
    if handler then
        handler(player, effect)
    else
        print(string.format("[AvatarSystem] Unknown proc effect: %s", tostring(effect.effect)))
    end
end

--[[
================================================================================
TRIGGER HANDLERS REGISTRY
================================================================================
Maps trigger types to signal registration logic. Each receives (handlers, player, effect).
State (counters, accumulators) lives in closures - cleaned up with signal_group.
]]--

local TRIGGER_HANDLERS = {
    --- Trigger on enemy kill
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition
    on_kill = function(handlers, player, effect)
        handlers:on("enemy_killed", function(enemyEntity)
            execute_effect(player, effect)
        end)
    end,

    --- Trigger every 4th spell cast
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition
    on_cast_4th = function(handlers, player, effect)
        local count = 0
        handlers:on("on_spell_cast", function(castData)
            count = count + 1
            if count % 4 == 0 then
                execute_effect(player, effect)
            end
        end)
    end,

    --- Trigger every 5 meters moved
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition
    -- TODO: Requires player_moved signal to be emitted from movement system
    distance_moved_5m = function(handlers, player, effect)
        local accumulated = 0
        local THRESHOLD = 80  -- ~5 meters in pixels (16px per unit)
        handlers:on("player_moved", function(data)
            accumulated = accumulated + (data.delta or 0)
            while accumulated >= THRESHOLD do
                accumulated = accumulated - THRESHOLD
                execute_effect(player, effect)
            end
        end)
    end,

    --- Trigger when player takes physical damage
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition with .config
    on_physical_damage_taken = function(handlers, player, effect)
        local config = effect.config or {}
        local damage_per_stack = config.damage_per_stack or 10
        local max_stacks = config.max_stacks or 20
        local bonus_per_stack = config.damage_bonus_per_stack or 5

        -- Initialize conduit system (starts decay timer)
        execute_effect(player, effect)

        -- Track accumulated damage for partial stacks
        player.conduit_damage_accumulated = 0

        handlers:on("player_damaged", function(entity, data)
            print(string.format("[Conduit] Hit! amount=%.1f type=%s", data.amount or 0, data.damage_type or "?"))

            -- Only process physical damage
            if data.damage_type ~= "physical" then
                print("[Conduit] Ignoring non-physical damage")
                return
            end

            -- Accumulate damage for partial stacks
            player.conduit_damage_accumulated = (player.conduit_damage_accumulated or 0) + (data.amount or 0)
            local stacks_gained = math.floor(player.conduit_damage_accumulated / damage_per_stack)

            if stacks_gained < 1 then
                print(string.format("[Conduit] Accumulating: %.1f/%d damage",
                    player.conduit_damage_accumulated, damage_per_stack))
                return
            end

            -- Consume the damage used for stacks
            player.conduit_damage_accumulated = player.conduit_damage_accumulated - (stacks_gained * damage_per_stack)

            -- Get or create conduit state
            player.conduit_stacks = player.conduit_stacks or 0
            local old_stacks = player.conduit_stacks
            player.conduit_stacks = math.min(max_stacks, old_stacks + stacks_gained)
            local actual_gained = player.conduit_stacks - old_stacks

            if actual_gained > 0 then
                -- Apply damage bonus
                local combatActor = player.combatTable
                if combatActor and combatActor.stats then
                    local before = combatActor.stats:get("all_damage_pct") or 0
                    combatActor.stats:add_add_pct("all_damage_pct", actual_gained * bonus_per_stack)
                    combatActor.stats:recompute()
                    local after = combatActor.stats:get("all_damage_pct") or 0

                    print(string.format("[Conduit] +%d stacks! Total: %d stacks (+%d%% damage)",
                        actual_gained, player.conduit_stacks, player.conduit_stacks * bonus_per_stack))
                    print(string.format("[Conduit] all_damage_pct: %.1f%% -> %.1f%%", before, after))
                else
                    print("[Conduit] WARNING: No combatActor.stats available!")
                end
            end
        end)
    end,
}

--[[
================================================================================
HELPER FUNCTIONS
================================================================================
Local helper functions used by the public API.
]]--

local function loadDefs()
    if avatarDefs then return avatarDefs end
    avatarDefs = require("data.avatars")
    return avatarDefs
end

-- Ensure player has the required avatar state/progress tables
local function ensureState(player)
    if type(player) ~= "table" then return nil end
    player.avatar_state = player.avatar_state or { unlocked = {}, equipped = nil }
    player.avatar_progress = player.avatar_progress or {}
    return player.avatar_state, player.avatar_progress
end

--[[
================================================================================
PROC REGISTRATION AND CLEANUP
================================================================================
]]--

--- Register proc handlers for an avatar's effects
--- @param player table Player script table
--- @param avatarId string Avatar ID to register procs for
function AvatarSystem.register_procs(player, avatarId)
    log_debug("[AvatarSystem] register_procs called: avatarId=", avatarId, "player=", player)
    if not player or not avatarId then return end

    local defs = loadDefs()
    local avatar = defs and defs[avatarId]
    if not avatar or not avatar.effects then
        log_debug("[AvatarSystem] No avatar or effects found for:", avatarId)
        return
    end

    local state = ensureState(player)

    -- Create signal group for cleanup
    local signal_group = require("core.signal_group")
    local handlers = signal_group.new("avatar_procs_" .. avatarId)
    state._proc_handlers = handlers

    -- Register each proc effect
    for _, effect in ipairs(avatar.effects) do
        if effect.type == "proc" then
            local triggerHandler = TRIGGER_HANDLERS[effect.trigger]
            if triggerHandler then
                log_debug("[AvatarSystem] Registering trigger:", effect.trigger, "->", effect.effect)
                triggerHandler(handlers, player, effect)
            else
                log_debug("[AvatarSystem] Unknown trigger:", effect.trigger)
            end
        end
    end
    log_debug("[AvatarSystem] Proc registration complete, handler count:", handlers:count())
end

--- Cleanup all proc handlers for player
--- @param player table Player script table
function AvatarSystem.cleanup_procs(player)
    local state = player and player.avatar_state
    if state and state._proc_handlers then
        state._proc_handlers:cleanup()
        state._proc_handlers = nil
    end

    -- Clean up Conduit Charge stacks and timer
    if player.conduit_stacks and player.conduit_stacks > 0 then
        local combatActor = player.combatTable
        if combatActor and combatActor.stats then
            -- Remove all stacks' worth of bonus (5% per stack)
            combatActor.stats:add_add_pct("all_damage_pct", -player.conduit_stacks * 5)
            combatActor.stats:recompute()
        end
        player.conduit_stacks = 0
    end
    player.conduit_damage_accumulated = nil

    -- Kill the decay timer
    local timer = require("core.timer")
    timer.kill_group("avatar_conduit")
end

-- Normalize a tag key from unlock fields like "OR_fire_tags" or "fire_tags"
local function tagFromKey(key)
    local tagToken = key:gsub("^OR_", ""):gsub("_tags$", "")
    if tagToken == "" then return nil end
    -- Capitalize first letter to match TagEvaluator style (e.g., Fire, Defense)
    return tagToken:sub(1, 1):upper() .. tagToken:sub(2)
end

-- Evaluate whether the unlock conditions are satisfied
local function isUnlocked(unlock, tagCounts, metrics)
    if not unlock then return false end
    tagCounts = tagCounts or {}
    metrics = metrics or {}

    local baseSatisfied = true
    local altSatisfied = false

    for key, threshold in pairs(unlock) do
        if key:match("^OR_") then
            -- Alternative path (any of these is enough)
            local tag = key:match("_tags$") and tagFromKey(key)
            local value = tag and (tagCounts[tag] or 0) or (metrics[key:sub(4)] or 0)
            if value >= threshold then altSatisfied = true end
        else
            -- Primary path (all must be satisfied)
            local value
            if key:match("_tags$") then
                local tag = tagFromKey(key)
                value = tag and (tagCounts[tag] or 0) or 0
            else
                value = metrics[key] or 0
            end

            if value < threshold then
                baseSatisfied = false
            end
        end
    end

    return baseSatisfied or altSatisfied
end

-- Unlock avatars whose conditions are met; returns list of newly unlocked ids
function AvatarSystem.check_unlocks(player, opts)
    local state, progress = ensureState(player)
    if not state then return {} end

    local defs = loadDefs()
    local tagCounts = (opts and opts.tag_counts) or player.tag_counts or {}
    local metrics = (opts and opts.metrics) or progress

    local newlyUnlocked = {}

    for id, def in pairs(defs or {}) do
        -- Skip non-table entries (e.g., localization helper functions)
        if type(def) == "table" and not state.unlocked[id] then
            if isUnlocked(def.unlock, tagCounts, metrics) then
                state.unlocked[id] = true
                table.insert(newlyUnlocked, id)
            end
        end
    end

    -- Emit signal for UI/telemetry if available
    if #newlyUnlocked > 0 then
        local ok, signal = pcall(require, "external.hump.signal")
        if ok and signal then
            for _, avatarId in ipairs(newlyUnlocked) do
                signal.emit("avatar_unlocked", { avatar_id = avatarId })
            end
        end
    end

    return newlyUnlocked
end

-- Increment a progress metric (e.g., kills_with_fire) and re-run unlock checks
function AvatarSystem.record_progress(player, metric, delta, opts)
    local _, progress = ensureState(player)
    if not progress then return {} end

    delta = delta or 0
    progress[metric] = (progress[metric] or 0) + delta

    return AvatarSystem.check_unlocks(player, opts)
end

--[[
================================================================================
STAT BUFF APPLICATION
================================================================================
Applies/removes stat_buff effects from avatars to the player's combat stats.
Uses player.combatTable.stats (the combat actor's stat system).
]] --

-- Get the stats object from player (via combatTable link)
local function getPlayerStats(player)
    if not player then return nil end
    local combatActor = player.combatTable
    if combatActor and combatActor.stats then
        return combatActor.stats
    end
    return nil
end

--- Apply stat_buff effects from an avatar to player stats
--- @param player table Player script table
--- @param avatarId string Avatar ID to apply
--- @return boolean success
function AvatarSystem.apply_stat_buffs(player, avatarId)
    if not player or not avatarId then return false end

    local defs = loadDefs()
    local avatar = defs and defs[avatarId]
    if not avatar or not avatar.effects then return false end

    local stats = getPlayerStats(player)
    if not stats then
        -- No combat stats available yet (may be called before combat init)
        -- Store pending buffs to apply later
        player._pending_avatar_buffs = avatarId
        return true
    end

    local state = ensureState(player)
    state._applied_buffs = state._applied_buffs or {}

    print(string.format("[Avatar] Applying stat buffs for '%s':", avatarId))
    for _, effect in ipairs(avatar.effects) do
        if effect.type == "stat_buff" then
            local stat = effect.stat
            local value = effect.value or 0

            -- Apply as additive percentage (like items)
            stats:add_add_pct(stat, value)
            table.insert(state._applied_buffs, { stat = stat, value = value })
            print(string.format("  +%d%% %s", value, stat))
        end
    end

    stats:recompute()
    print("[Avatar] Stat buffs applied and recomputed")
    return true
end

--- Remove previously applied stat_buff effects from player
--- @param player table Player script table
--- @return boolean success
function AvatarSystem.remove_stat_buffs(player)
    if not player then return false end

    local state = player.avatar_state
    if not state or not state._applied_buffs then return true end

    local stats = getPlayerStats(player)
    if not stats then return true end

    -- Reverse all applied buffs
    for _, buff in ipairs(state._applied_buffs) do
        stats:add_add_pct(buff.stat, -buff.value)
    end

    stats:recompute()
    state._applied_buffs = {}
    return true
end

-- Equip an already-unlocked avatar (for session-based choice)
-- Handles stat buff and proc handler application/removal when switching avatars
function AvatarSystem.equip(player, avatarId)
    local state = ensureState(player)
    if not state or not state.unlocked[avatarId] then
        return false, "avatar_locked"
    end

    -- Remove old avatar's effects if switching
    if state.equipped and state.equipped ~= avatarId then
        AvatarSystem.cleanup_procs(player)
        AvatarSystem.remove_stat_buffs(player)
    end

    state.equipped = avatarId

    -- Apply new avatar's effects
    AvatarSystem.apply_stat_buffs(player, avatarId)
    AvatarSystem.register_procs(player, avatarId)

    return true
end

--- Unequip current avatar (removes stat buffs and procs)
--- @param player table Player script table
--- @return boolean success
function AvatarSystem.unequip(player)
    local state = player and player.avatar_state
    if not state or not state.equipped then return true end

    AvatarSystem.cleanup_procs(player)
    AvatarSystem.remove_stat_buffs(player)
    state.equipped = nil
    return true
end

-- Get the currently equipped avatar for a player
function AvatarSystem.get_equipped(player)
    if type(player) ~= "table" then return nil end
    local state = player.avatar_state
    return state and state.equipped or nil
end

--- Check if player has a specific avatar rule active
--- @param player table Player script table
--- @param rule string Rule ID to check (e.g., "crit_chains")
--- @return boolean True if rule is active
function AvatarSystem.has_rule(player, rule)
    local avatarId = AvatarSystem.get_equipped(player)
    if not avatarId then return false end

    local defs = loadDefs()
    local avatar = defs and defs[avatarId]
    if not avatar or not avatar.effects then return false end

    for _, effect in ipairs(avatar.effects) do
        if effect.type == "rule_change" and effect.rule == rule then
            return true
        end
    end
    return false
end

--[[
================================================================================
BLESSING ACTIVATION
================================================================================
Activate god blessings with cooldown tracking.
]]--

--- Get all blessing effects from currently equipped avatar/god
--- @param player table Player script table
--- @return table Array of blessing effect definitions
function AvatarSystem.get_blessings(player)
    local avatarId = AvatarSystem.get_equipped(player)
    if not avatarId then return {} end

    local defs = loadDefs()
    local avatar = defs and defs[avatarId]
    if not avatar or not avatar.effects then return {} end

    local blessings = {}
    for _, effect in ipairs(avatar.effects) do
        if effect.type == "blessing" then
            blessings[#blessings + 1] = effect
        end
    end
    return blessings
end

--- Check if a blessing is on cooldown
--- @param player table Player script table
--- @param blessingId string Blessing ID to check
--- @return boolean True if on cooldown
--- @return number Remaining cooldown time (0 if ready)
function AvatarSystem.is_blessing_on_cooldown(player, blessingId)
    if not player then return true, 0 end

    local state = player.avatar_state
    if not state then return false, 0 end

    local cooldowns = state._blessing_cooldowns or {}
    local readyAt = cooldowns[blessingId] or 0

    local currentTime = os.time()
    if currentTime < readyAt then
        return true, readyAt - currentTime
    end
    return false, 0
end

--- Activate a blessing ability (respects cooldowns)
--- @param player table Player script table
--- @param blessingId string Blessing ID to activate (from effect.id)
--- @return boolean success
--- @return string|nil error message if failed
function AvatarSystem.activate_blessing(player, blessingId)
    if not player or not blessingId then
        return false, "invalid_args"
    end

    -- Find the blessing in equipped avatar
    local blessings = AvatarSystem.get_blessings(player)
    local blessing = nil
    for _, b in ipairs(blessings) do
        if b.id == blessingId then
            blessing = b
            break
        end
    end

    if not blessing then
        return false, "blessing_not_found"
    end

    -- Check cooldown
    local onCooldown, remaining = AvatarSystem.is_blessing_on_cooldown(player, blessingId)
    if onCooldown then
        return false, string.format("on_cooldown:%.1f", remaining)
    end

    -- Execute the blessing effect
    local handler = BLESSING_EFFECTS[blessing.effect]
    if handler then
        handler(player, blessing, blessing.config)
    else
        print(string.format("[AvatarSystem] Unknown blessing effect: %s", tostring(blessing.effect)))
    end

    -- Set cooldown
    local state = ensureState(player)
    state._blessing_cooldowns = state._blessing_cooldowns or {}
    state._blessing_cooldowns[blessingId] = os.time() + (blessing.cooldown or 30)

    -- Emit signal for UI
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal then
        signal.emit("blessing_activated", {
            player = player,
            blessing_id = blessingId,
            cooldown = blessing.cooldown or 30,
            duration = blessing.duration or 0
        })
    end

    print(string.format("[Blessing] Activated '%s' (cooldown: %ds)", blessingId, blessing.cooldown or 30))
    return true
end

--- Reset all blessing cooldowns (e.g., on new run)
--- @param player table Player script table
function AvatarSystem.reset_blessing_cooldowns(player)
    if not player then return end
    local state = player.avatar_state
    if state then
        state._blessing_cooldowns = {}
    end
end

return AvatarSystem
