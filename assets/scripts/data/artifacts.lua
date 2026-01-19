--[[
================================================================================
ARTIFACTS - Passive Items with Calculate Pattern
================================================================================
Artifacts use the Joker schema with calculate(self, context) for reactive effects.
These provide powerful passive bonuses that trigger on specific events.

Context events:
- "on_spell_cast" - When player casts a spell
- "on_player_damaged" - When player takes damage
- "calculate_damage" - During damage calculation
- "on_kill" - When player kills an enemy
- "on_chain_hit" - When chain lightning hits
- "on_mark_detonated" - When a mark is detonated
================================================================================
]]

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

local Artifacts = {

    --------------------------------------------------------------------------------
    -- FIRE ARTIFACTS
    --------------------------------------------------------------------------------

    ember_heart = {
        id = "ember_heart",
        name = "Ember Heart",
        description = "+20% fire damage. Kills with fire restore 5 HP.",
        rarity = "Rare",
        element = "fire",
        sprite = "artifact_ember_heart",

        calculate = function(self, context)
            if context.event == "calculate_damage" and context.damage_type == "fire" then
                return {
                    damage_mult = 1.2,
                    message = "Ember Heart!"
                }
            end
            if context.event == "on_kill" and context.damage_type == "fire" then
                return {
                    heal_player = 5,
                    message = "Ember Heal!"
                }
            end
        end
    },

    inferno_lens = {
        id = "inferno_lens",
        name = "Inferno Lens",
        description = "Fire spells have +15% crit chance. Burns spread to nearby enemies on crit.",
        rarity = "Epic",
        element = "fire",
        sprite = "artifact_inferno_lens",

        calculate = function(self, context)
            if context.event == "on_spell_cast" then
                if context.tags and context.tags.Fire then
                    return {
                        crit_bonus = 15,
                        message = "Inferno Focus!"
                    }
                end
            end
            if context.event == "on_crit" and context.damage_type == "fire" then
                return {
                    spread_burn = { radius = 100, stacks = 2 },
                    message = "Burn Spread!"
                }
            end
        end
    },

    --------------------------------------------------------------------------------
    -- ICE ARTIFACTS
    --------------------------------------------------------------------------------

    frost_core = {
        id = "frost_core",
        name = "Frost Core",
        description = "+20% ice damage. Frozen enemies take +30% damage from all sources.",
        rarity = "Rare",
        element = "ice",
        sprite = "artifact_frost_core",

        calculate = function(self, context)
            if context.event == "calculate_damage" and context.damage_type == "ice" then
                return {
                    damage_mult = 1.2,
                    message = "Frost Core!"
                }
            end
            if context.event == "calculate_damage" and context.target_frozen then
                return {
                    damage_mult = 1.3,
                    message = "Shatter!"
                }
            end
        end
    },

    glacial_ward = {
        id = "glacial_ward",
        name = "Glacial Ward",
        description = "Taking damage has 25% chance to freeze nearby enemies.",
        rarity = "Uncommon",
        element = "ice",
        sprite = "artifact_glacial_ward",

        calculate = function(self, context)
            if context.event == "on_player_damaged" then
                local roll = math.random(100)
                if roll <= 25 then
                    return {
                        freeze_nearby = { radius = 80, stacks = 3 },
                        message = "Glacial Ward!"
                    }
                end
            end
        end
    },

    --------------------------------------------------------------------------------
    -- LIGHTNING ARTIFACTS
    --------------------------------------------------------------------------------

    storm_core = {
        id = "storm_core",
        name = "Storm Core",
        description = "+20% lightning damage. Chain lightning bounces +2 times.",
        rarity = "Rare",
        element = "lightning",
        sprite = "artifact_storm_core",

        calculate = function(self, context)
            if context.event == "calculate_damage" and context.damage_type == "lightning" then
                return {
                    damage_mult = 1.2,
                    message = "Storm Core!"
                }
            end
            if context.event == "on_spell_cast" then
                if context.tags and context.tags.Lightning and context.is_chain then
                    return {
                        extra_chain = 2,
                        message = "Storm Chain!"
                    }
                end
            end
        end
    },

    static_field = {
        id = "static_field",
        name = "Static Field",
        description = "Moving generates Static Charge. At 10 stacks, release lightning nova.",
        rarity = "Epic",
        element = "lightning",
        sprite = "artifact_static_field",

        calculate = function(self, context)
            if context.event == "on_move" then
                return {
                    add_static = 1,
                    message = "Static+"
                }
            end
            if context.event == "on_static_max" then
                return {
                    lightning_nova = { radius = 150, damage = 30 },
                    message = "Static Discharge!"
                }
            end
        end
    },

    --------------------------------------------------------------------------------
    -- VOID ARTIFACTS
    --------------------------------------------------------------------------------

    void_heart = {
        id = "void_heart",
        name = "Void Heart",
        description = "+25% summon damage. Summons last 50% longer.",
        rarity = "Rare",
        element = "void",
        sprite = "artifact_void_heart",

        calculate = function(self, context)
            if context.event == "calculate_damage" and context.source_type == "summon" then
                return {
                    damage_mult = 1.25,
                    message = "Void Heart!"
                }
            end
            if context.event == "on_summon" then
                return {
                    duration_mult = 1.5,
                    message = "Extended!"
                }
            end
        end
    },

    entropy_shard = {
        id = "entropy_shard",
        name = "Entropy Shard",
        description = "Kills have 20% chance to summon a void minion for 5 seconds.",
        rarity = "Epic",
        element = "void",
        sprite = "artifact_entropy_shard",

        calculate = function(self, context)
            if context.event == "on_kill" then
                local roll = math.random(100)
                if roll <= 20 then
                    return {
                        spawn_minion = { type = "void_wisp", duration = 5 },
                        message = "Void Spawn!"
                    }
                end
            end
        end
    },

    --------------------------------------------------------------------------------
    -- UNIVERSAL ARTIFACTS
    --------------------------------------------------------------------------------

    battle_trophy = {
        id = "battle_trophy",
        name = "Battle Trophy",
        description = "+2% damage per kill this wave (max +40%).",
        rarity = "Uncommon",
        element = "universal",
        sprite = "artifact_battle_trophy",

        calculate = function(self, context)
            if context.event == "calculate_damage" then
                local kills = context.wave_kills or 0
                local bonus = math.min(kills * 2, 40)
                if bonus > 0 then
                    return {
                        damage_mult = 1 + (bonus / 100),
                        message = string.format("Trophy +%d%%", bonus)
                    }
                end
            end
        end
    },

    desperate_power = {
        id = "desperate_power",
        name = "Desperate Power",
        description = "+30% damage when below 50% HP. +50% damage when below 25% HP.",
        rarity = "Rare",
        element = "universal",
        sprite = "artifact_survival_instinct",

        calculate = function(self, context)
            if context.event == "calculate_damage" then
                local hp_pct = context.player_hp_pct or 100
                if hp_pct < 25 then
                    return {
                        damage_mult = 1.5,
                        message = "Desperate!"
                    }
                elseif hp_pct < 50 then
                    return {
                        damage_mult = 1.3,
                        message = "Survival!"
                    }
                end
            end
        end
    },
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--- Get localized name for an artifact
--- @param artifactId string The artifact key
--- @return string The localized name or fallback
function Artifacts.getLocalizedName(artifactId)
    local artifact = Artifacts[artifactId]
    if not artifact then return artifactId end
    return L("artifact." .. artifactId .. ".name", artifact.name)
end

--- Get localized description for an artifact
--- @param artifactId string The artifact key
--- @return string The localized description or fallback
function Artifacts.getLocalizedDescription(artifactId)
    local artifact = Artifacts[artifactId]
    if not artifact then return "" end
    return L("artifact." .. artifactId .. ".description", artifact.description)
end

--- Get artifact by ID
--- @param id string Artifact ID
--- @return table|nil Artifact definition
function Artifacts.get(id)
    local artifact = Artifacts[id]
    if type(artifact) == "table" and artifact.name then
        return artifact
    end
    return nil
end

--- Get all artifacts
--- @return table Array of artifact definitions
function Artifacts.getAll()
    local results = {}
    for id, def in pairs(Artifacts) do
        if type(def) == "table" and def.name then
            results[#results + 1] = def
        end
    end
    return results
end

--- Get artifacts by rarity
--- @param rarity string Rarity level ("Common", "Uncommon", "Rare", "Epic")
--- @return table Array of artifact definitions
function Artifacts.getByRarity(rarity)
    local results = {}
    for id, def in pairs(Artifacts) do
        if type(def) == "table" and def.rarity == rarity then
            results[#results + 1] = def
        end
    end
    return results
end

--- Get artifacts by element
--- @param element string Element type ("fire", "ice", "lightning", "void", "universal")
--- @return table Array of artifact definitions
function Artifacts.getByElement(element)
    local results = {}
    for id, def in pairs(Artifacts) do
        if type(def) == "table" and def.element == element then
            results[#results + 1] = def
        end
    end
    return results
end

return Artifacts
