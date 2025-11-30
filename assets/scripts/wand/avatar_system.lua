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
        if not state.unlocked[id] then
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

-- Equip an already-unlocked avatar (for session-based choice)
function AvatarSystem.equip(player, avatarId)
    local state = ensureState(player)
    if not state or not state.unlocked[avatarId] then
        return false, "avatar_locked"
    end
    state.equipped = avatarId
    return true
end

return AvatarSystem
