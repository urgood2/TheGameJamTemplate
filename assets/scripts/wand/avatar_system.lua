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
}

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

    for _, effect in ipairs(avatar.effects) do
        if effect.type == "stat_buff" then
            local stat = effect.stat
            local value = effect.value or 0

            -- Apply as additive percentage (like items)
            stats:add_add_pct(stat, value)
            table.insert(state._applied_buffs, { stat = stat, value = value })
        end
    end

    stats:recompute()
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
-- Handles stat buff application/removal when switching avatars
function AvatarSystem.equip(player, avatarId)
    local state = ensureState(player)
    if not state or not state.unlocked[avatarId] then
        return false, "avatar_locked"
    end

    -- Remove old avatar's stat buffs if switching
    if state.equipped and state.equipped ~= avatarId then
        AvatarSystem.remove_stat_buffs(player)
    end

    state.equipped = avatarId

    -- Apply new avatar's stat buffs
    AvatarSystem.apply_stat_buffs(player, avatarId)

    return true
end

--- Unequip current avatar (removes stat buffs)
--- @param player table Player script table
--- @return boolean success
function AvatarSystem.unequip(player)
    local state = player and player.avatar_state
    if not state or not state.equipped then return true end

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

return AvatarSystem
