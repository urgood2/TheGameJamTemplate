--[[
================================================================================
SKILL SYSTEM - Runtime for Skill Management
================================================================================
Tracks learned skills and applies/removes stat changes.
Designed to integrate with the existing combat stat system.

API:
  SkillSystem.init(player) - Initialize skill state on player
  SkillSystem.learn_skill(player, skillId) - Learn a skill, apply buffs
  SkillSystem.unlearn_skill(player, skillId) - Unlearn a skill, remove buffs
  SkillSystem.get_learned_skills(player) - Get list of learned skill IDs
  SkillSystem.apply_skill_buffs(player) - Reapply all learned skill buffs
  SkillSystem.remove_skill_buffs(player) - Remove all skill buffs
  SkillSystem.cleanup(player) - Full cleanup on reset/run end
================================================================================
]]

local SkillSystem = {}

local skillDefs = nil

--------------------------------------------------------------------------------
-- INTERNAL HELPERS
--------------------------------------------------------------------------------

local function loadDefs()
    if skillDefs then return skillDefs end
    skillDefs = require("data.skills")
    return skillDefs
end

-- Ensure player has skill state initialized
local function ensureState(player)
    if type(player) ~= "table" then return nil end
    player.skill_state = player.skill_state or {
        learned = {},       -- Set of learned skill IDs (id -> true)
        applied_buffs = {}  -- Track applied buffs for removal
    }
    return player.skill_state
end

-- Get stats object from player (via combatTable link)
local function getPlayerStats(player)
    if not player then return nil end
    local combatActor = player.combatTable
    if combatActor and combatActor.stats then
        return combatActor.stats
    end
    return nil
end

-- Apply stat buffs from a skill to player
local function applySkillBuffs(player, skillId)
    local defs = loadDefs()
    local skill = defs and defs.get and defs.get(skillId)
    if not skill or not skill.effects then return false end

    local stats = getPlayerStats(player)
    if not stats then
        -- Store for later application when combat stats are available
        player._pending_skill_buffs = player._pending_skill_buffs or {}
        player._pending_skill_buffs[skillId] = true
        return true
    end

    local state = ensureState(player)

    for _, effect in ipairs(skill.effects) do
        if effect.type == "stat_buff" then
            local stat = effect.stat
            local value = effect.value or 0

            -- Apply as additive percentage
            stats:add_add_pct(stat, value)

            -- Track for later removal
            state.applied_buffs[#state.applied_buffs + 1] = {
                skill = skillId,
                stat = stat,
                value = value
            }
        end
    end

    stats:recompute()
    return true
end

-- Remove stat buffs from a skill
local function removeSkillBuffs(player, skillId)
    local state = player and player.skill_state
    if not state then return false end

    local stats = getPlayerStats(player)
    if not stats then return true end

    -- Find and remove buffs for this skill
    local newApplied = {}
    for _, buff in ipairs(state.applied_buffs) do
        if buff.skill == skillId then
            stats:add_add_pct(buff.stat, -buff.value)
        else
            newApplied[#newApplied + 1] = buff
        end
    end

    state.applied_buffs = newApplied
    stats:recompute()
    return true
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Initialize skill state on player
--- @param player table Player script table
function SkillSystem.init(player)
    if type(player) ~= "table" then return end
    ensureState(player)
end

--- Learn a skill
--- @param player table Player script table
--- @param skillId string Skill ID to learn
--- @return boolean success
function SkillSystem.learn_skill(player, skillId)
    if not player or not skillId then return false end

    local defs = loadDefs()
    local skill = defs and defs.get and defs.get(skillId)
    if not skill then
        print(string.format("[SkillSystem] Unknown skill: %s", tostring(skillId)))
        return false
    end

    local state = ensureState(player)

    -- Check if already learned
    if state.learned[skillId] then
        return false
    end

    -- Mark as learned
    state.learned[skillId] = true

    -- Apply stat buffs
    applySkillBuffs(player, skillId)

    -- Emit signal for UI
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal then
        signal.emit("skill_learned", {
            player = player,
            skill_id = skillId,
            skill = skill
        })
    end

    print(string.format("[SkillSystem] Learned skill: %s", skill.name))
    return true
end

--- Unlearn a skill
--- @param player table Player script table
--- @param skillId string Skill ID to unlearn
--- @return boolean success
function SkillSystem.unlearn_skill(player, skillId)
    if not player or not skillId then return false end

    local state = player.skill_state
    if not state or not state.learned[skillId] then
        return false
    end

    -- Remove stat buffs first
    removeSkillBuffs(player, skillId)

    -- Mark as unlearned
    state.learned[skillId] = nil

    -- Emit signal for UI
    local ok, signal = pcall(require, "external.hump.signal")
    if ok and signal then
        signal.emit("skill_unlearned", {
            player = player,
            skill_id = skillId
        })
    end

    print(string.format("[SkillSystem] Unlearned skill: %s", skillId))
    return true
end

--- Get list of learned skill IDs
--- @param player table Player script table
--- @return table Array of skill IDs
function SkillSystem.get_learned_skills(player)
    local state = player and player.skill_state
    if not state then return {} end

    local results = {}
    for skillId, _ in pairs(state.learned) do
        results[#results + 1] = skillId
    end
    return results
end

--- Check if a skill is learned
--- @param player table Player script table
--- @param skillId string Skill ID to check
--- @return boolean True if learned
function SkillSystem.has_skill(player, skillId)
    local state = player and player.skill_state
    return state and state.learned[skillId] == true
end

--- Reapply all learned skill buffs (e.g., after combat init)
--- @param player table Player script table
function SkillSystem.apply_skill_buffs(player)
    local state = player and player.skill_state
    if not state then return end

    -- Clear existing applied buffs tracking
    state.applied_buffs = {}

    -- Reapply all learned skills
    for skillId, _ in pairs(state.learned) do
        applySkillBuffs(player, skillId)
    end
end

--- Remove all skill buffs (e.g., before unequip)
--- @param player table Player script table
function SkillSystem.remove_skill_buffs(player)
    local state = player and player.skill_state
    if not state then return end

    local stats = getPlayerStats(player)
    if not stats then return end

    -- Remove all tracked buffs
    for _, buff in ipairs(state.applied_buffs) do
        stats:add_add_pct(buff.stat, -buff.value)
    end

    stats:recompute()
    state.applied_buffs = {}
end

--- Full cleanup on reset/run end
--- @param player table Player script table
function SkillSystem.cleanup(player)
    if not player then return end

    -- Remove all buffs
    SkillSystem.remove_skill_buffs(player)

    -- Clear state
    player.skill_state = nil
    player._pending_skill_buffs = nil
end

--- Get skill count by element
--- @param player table Player script table
--- @param element string Element to filter by
--- @return number Count of learned skills of that element
function SkillSystem.get_skill_count_by_element(player, element)
    local state = player and player.skill_state
    if not state then return 0 end

    local defs = loadDefs()
    local count = 0

    for skillId, _ in pairs(state.learned) do
        local skill = defs and defs.get and defs.get(skillId)
        if skill and skill.element == element then
            count = count + 1
        end
    end

    return count
end

--- Get total skill points used
--- @param player table Player script table
--- @return number Number of learned skills
function SkillSystem.get_total_skills_learned(player)
    local state = player and player.skill_state
    if not state then return 0 end

    local count = 0
    for _ in pairs(state.learned) do
        count = count + 1
    end
    return count
end

return SkillSystem
