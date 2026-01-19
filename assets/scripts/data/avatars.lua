--[[
================================================================================
AVATARS, GODS, AND CLASSES
================================================================================
Three categories of player archetypes:

1. AVATARS (type = "avatar")
   - "Ascensions" unlocked mid-run via metrics/tags
   - Provide powerful global rule changes
   - Example: wildfire, citadel, conduit

2. GODS (type = "god")
   - Patron deities selected at run start
   - Provide blessings (activated abilities with cooldowns)
   - Example: pyra, frost, storm, void

3. CLASSES (type = "class")
   - Starting archetypes selected at run start
   - Provide passive stat bonuses from the beginning
   - No unlock conditions (always available)
   - Example: warrior, mage, rogue
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

local Avatars = {

    --------------------------------------------------------------------------------
    -- AVATARS (Mid-run ascensions with unlock conditions)
    --------------------------------------------------------------------------------

    wildfire = {
        type = "avatar",
        name = "Avatar of Wildfire",
        description = "Your flames consume everything.",
        -- sprite = "avatar_wildfire",  -- Optional: custom sprite (default: avatar_sample.png)

        -- Unlock Condition (Session-based)
        unlock = {
            kills_with_fire = 100,
            OR_fire_tags = 7
        },

        -- Global Effects
        effects = {
            {
                type = "rule_change",
                rule = "multicast_loops",
                desc = "Multicast modifiers now Loop the cast block instead of simultaneous cast."
            },
            {
                type = "stat_buff",
                stat = "hazard_tick_rate_pct",
                value = 100 -- 2x tick speed
            }
        }
    },

    citadel = {
        type = "avatar",
        name = "Avatar of the Citadel",
        description = "Unmovable object.",

        unlock = {
            damage_blocked = 5000,
            OR_defense_tags = 7
        },

        effects = {
            {
                type = "proc",
                trigger = "on_cast_4th",
                effect = "global_barrier",
                value = 10 -- 10% HP barrier
            },
            {
                type = "rule_change",
                rule = "summons_inherit_block",
                desc = "Summons inherit 100% of your Block Chance and Thorns."
            }
        }
    },

    miasma = {
        type = "avatar",
        name = "Avatar of Miasma",
        description = "Death is in the air.",

        unlock = {
            distance_moved = 500,
            OR_mobility_tags = 5
        },

        effects = {
            {
                type = "rule_change",
                rule = "move_casts_trigger_onhit",
                desc = "Wands triggered by Movement now trigger 'On Hit' effects."
            },
            {
                type = "proc",
                trigger = "distance_moved_5m",
                effect = "poison_spread",
                radius = 8
            }
        }
    },

    stormlord = {
        type = "avatar",
        name = "Avatar of the Storm",
        description = "Ride the lightning.",

        unlock = {
            electrocute_kills = 50,
            OR_lightning_tags = 7
        },

        effects = {
            {
                type = "rule_change",
                rule = "crit_chains",
                desc = "Critical hits always Chain to a nearby enemy."
            },
            {
                type = "rule_change",
                rule = "chain_applies_marks",
                desc = "All chain effects apply Static Charge."
            },
            {
                type = "stat_buff",
                stat = "chain_count_bonus",
                value = 2
            },
            {
                type = "proc",
                trigger = "on_mark_detonated",
                effect = "electrocute_nearby",
                radius = 100
            }
        }
    },

    voidwalker = {
        type = "avatar",
        name = "Voidwalker",
        description = "You are not here.",

        unlock = {
            mana_spent = 1000,
            OR_summon_tags = 6
        },

        effects = {
            {
                type = "rule_change",
                rule = "summon_cast_share",
                desc = "When you cast a projectile, your Summons also cast a copy of it."
            }
        }
    },

    bloodgod = {
        type = "avatar",
        name = "Blood God",
        description = "Pain is power.",

        unlock = {
            hp_lost = 500,
            OR_brute_tags = 7
        },

        effects = {
            {
                type = "rule_change",
                rule = "missing_hp_dmg",
                desc = "Gain +1% Damage for every 1% missing HP."
            },
            {
                type = "proc",
                trigger = "on_kill",
                effect = "heal",
                value = 5 -- Heal 5 flat HP
            }
        }
    },

    conduit = {
        type = "avatar",
        name = "Avatar of the Conduit",
        description = "Pain becomes power. Lightning becomes you.",

        unlock = {
            chain_lightning_propagations = 20
        },

        effects = {
            {
                type = "stat_buff",
                stat = "lightning_resist_pct",
                value = 30
            },
            {
                type = "stat_buff",
                stat = "lightning_modifier_pct",
                value = 30
            },
            {
                type = "proc",
                trigger = "on_physical_damage_taken",
                effect = "conduit_charge",
                config = {
                    damage_per_stack = 10,
                    max_stacks = 20,
                    damage_bonus_per_stack = 5,
                    decay_interval = 5.0
                }
            }
        }
    },

    --------------------------------------------------------------------------------
    -- GODS (Patron deities with blessings - selected at run start)
    --------------------------------------------------------------------------------

    pyra = {
        type = "god",
        name = "Pyra, Goddess of Fire",
        description = "The Burning One demands sacrifice and rewards destruction.",

        -- No unlock - gods are available from run start
        -- unlock = nil,

        effects = {
            -- Passive stat bonus
            {
                type = "stat_buff",
                stat = "fire_modifier_pct",
                value = 15  -- +15% fire damage
            },
            -- Active blessing ability
            {
                type = "blessing",
                id = "inferno_burst",
                name = "Inferno Burst",
                desc = "Unleash a wave of fire around you, burning all nearby enemies.",
                cooldown = 30,  -- 30 seconds
                duration = 0,   -- Instant effect
                effect = "fire_nova",
                config = {
                    radius = 150,
                    damage = 50,
                    burn_stacks = 3,
                    burn_duration = 5.0
                }
            }
        }
    },

    frost = {
        type = "god",
        name = "Frost, Lord of Winter",
        description = "The Cold King slows all who oppose you.",

        effects = {
            -- Passive stat bonus
            {
                type = "stat_buff",
                stat = "ice_modifier_pct",
                value = 15  -- +15% ice damage
            },
            {
                type = "stat_buff",
                stat = "slow_effect_pct",
                value = 20  -- +20% slow effectiveness
            },
            -- Active blessing ability
            {
                type = "blessing",
                id = "frozen_sanctuary",
                name = "Frozen Sanctuary",
                desc = "Create an icy shield that absorbs damage and freezes attackers.",
                cooldown = 25,
                duration = 5.0,  -- Lasts 5 seconds
                effect = "frost_barrier",
                config = {
                    barrier_pct = 30,  -- 30% max HP barrier
                    freeze_duration = 2.0
                }
            }
        }
    },

    storm = {
        type = "god",
        name = "Tempest, Storm Bringer",
        description = "The Thunder God empowers your chains and crits.",

        effects = {
            -- Passive stat bonus
            {
                type = "stat_buff",
                stat = "lightning_modifier_pct",
                value = 15  -- +15% lightning damage
            },
            {
                type = "stat_buff",
                stat = "crit_chance",
                value = 5  -- +5% crit chance
            },
            -- Active blessing ability
            {
                type = "blessing",
                id = "lightning_storm",
                name = "Lightning Storm",
                desc = "Call down lightning bolts on all enemies in sight.",
                cooldown = 35,
                duration = 3.0,  -- Storm lasts 3 seconds
                effect = "chain_lightning_storm",
                config = {
                    bolts_per_second = 3,
                    damage_per_bolt = 25,
                    chain_count = 2
                }
            }
        }
    },

    void = {
        type = "god",
        name = "Nihil, The Void",
        description = "The Endless Nothing grants power over space and summons.",

        effects = {
            -- Passive stat bonus
            {
                type = "stat_buff",
                stat = "summon_damage_pct",
                value = 25  -- +25% summon damage
            },
            {
                type = "stat_buff",
                stat = "mana_regen_pct",
                value = 10  -- +10% mana regeneration
            },
            -- Active blessing ability
            {
                type = "blessing",
                id = "void_rift",
                name = "Void Rift",
                desc = "Open a rift that pulls enemies together and deals damage.",
                cooldown = 40,
                duration = 4.0,  -- Rift lasts 4 seconds
                effect = "gravity_well",
                config = {
                    radius = 200,
                    pull_strength = 100,
                    damage_per_second = 15
                }
            }
        }
    },

    --------------------------------------------------------------------------------
    -- CLASSES (Starting archetypes - no unlock, selected at run start)
    --------------------------------------------------------------------------------

    warrior = {
        type = "class",
        name = "Warrior",
        description = "A stalwart fighter who excels in close combat.",

        -- No unlock - classes are available from run start
        -- unlock = nil,

        effects = {
            {
                type = "stat_buff",
                stat = "max_hp",
                value = 25  -- +25 max HP
            },
            {
                type = "stat_buff",
                stat = "physical_damage_pct",
                value = 10  -- +10% physical damage
            },
            {
                type = "stat_buff",
                stat = "block_chance",
                value = 5  -- +5% block chance
            }
        }
    },

    mage = {
        type = "class",
        name = "Mage",
        description = "A master of the arcane arts with enhanced spell power.",

        effects = {
            {
                type = "stat_buff",
                stat = "max_mana",
                value = 30  -- +30 max mana
            },
            {
                type = "stat_buff",
                stat = "spell_power_pct",
                value = 15  -- +15% spell power
            },
            {
                type = "stat_buff",
                stat = "mana_regen_pct",
                value = 10  -- +10% mana regeneration
            }
        }
    },

    rogue = {
        type = "class",
        name = "Rogue",
        description = "A swift shadow who strikes fast and hard.",

        effects = {
            {
                type = "stat_buff",
                stat = "move_speed_pct",
                value = 15  -- +15% movement speed
            },
            {
                type = "stat_buff",
                stat = "crit_chance",
                value = 10  -- +10% crit chance
            },
            {
                type = "stat_buff",
                stat = "crit_damage_pct",
                value = 25  -- +25% crit damage
            }
        }
    },
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--- Get localized name for an avatar/god/class (call at runtime when localization is ready)
--- @param avatarId string The avatar key (e.g., "wildfire", "pyra", "warrior")
--- @return string The localized name or fallback English name
function Avatars.getLocalizedName(avatarId)
    local avatar = Avatars[avatarId]
    if not avatar then return avatarId end
    local prefix = avatar.type or "avatar"
    return L(prefix .. "." .. avatarId .. ".name", avatar.name)
end

--- Get localized description for an avatar/god/class (call at runtime when localization is ready)
--- @param avatarId string The avatar key (e.g., "wildfire", "pyra", "warrior")
--- @return string The localized description or fallback English description
function Avatars.getLocalizedDescription(avatarId)
    local avatar = Avatars[avatarId]
    if not avatar then return "" end
    local prefix = avatar.type or "avatar"
    return L(prefix .. "." .. avatarId .. ".description", avatar.description)
end

--- Get localized effect description for an avatar/god/class (call at runtime when localization is ready)
--- @param avatarId string The avatar key (e.g., "wildfire", "pyra", "warrior")
--- @return string The localized effect description or fallback English effect
function Avatars.getLocalizedEffect(avatarId)
    local avatar = Avatars[avatarId]
    if not avatar then return "" end
    local prefix = avatar.type or "avatar"
    -- Look for the first rule_change effect's desc
    if avatar.effects then
        for _, eff in ipairs(avatar.effects) do
            if eff.type == "rule_change" and eff.desc then
                return L(prefix .. "." .. avatarId .. ".effect", eff.desc)
            end
            -- For blessings, return the blessing description
            if eff.type == "blessing" and eff.desc then
                return L(prefix .. "." .. avatarId .. ".blessing", eff.desc)
            end
        end
    end
    return L(prefix .. "." .. avatarId .. ".effect", "")
end

--- Get all entries of a specific type
--- @param typeFilter string The type to filter by ("avatar", "god", or "class")
--- @return table Array of {id, definition} pairs matching the type
function Avatars.getByType(typeFilter)
    local results = {}
    for id, def in pairs(Avatars) do
        -- Skip functions (helper methods)
        if type(def) == "table" and def.type == typeFilter then
            results[#results + 1] = { id = id, def = def }
        end
    end
    return results
end

--- Get all gods
--- @return table Array of {id, definition} pairs
function Avatars.getGods()
    return Avatars.getByType("god")
end

--- Get all classes
--- @return table Array of {id, definition} pairs
function Avatars.getClasses()
    return Avatars.getByType("class")
end

--- Get all avatars (ascensions)
--- @return table Array of {id, definition} pairs
function Avatars.getAvatars()
    return Avatars.getByType("avatar")
end

return Avatars
