-- Avatars are "Ascensions" or "Ultimate Forms" unlocked mid-run.
-- They provide powerful global rule changes.

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

local Avatars = {
    wildfire = {
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
    }
}

--- Get localized name for an avatar (call at runtime when localization is ready)
--- @param avatarId string The avatar key (e.g., "wildfire")
--- @return string The localized name or fallback English name
function Avatars.getLocalizedName(avatarId)
    local avatar = Avatars[avatarId]
    if not avatar then return avatarId end
    return L("avatar." .. avatarId .. ".name", avatar.name)
end

--- Get localized description for an avatar (call at runtime when localization is ready)
--- @param avatarId string The avatar key (e.g., "wildfire")
--- @return string The localized description or fallback English description
function Avatars.getLocalizedDescription(avatarId)
    local avatar = Avatars[avatarId]
    if not avatar then return "" end
    return L("avatar." .. avatarId .. ".description", avatar.description)
end

--- Get localized effect description for an avatar (call at runtime when localization is ready)
--- @param avatarId string The avatar key (e.g., "wildfire")
--- @return string The localized effect description or fallback English effect
function Avatars.getLocalizedEffect(avatarId)
    local avatar = Avatars[avatarId]
    if not avatar then return "" end
    -- Look for the first rule_change effect's desc
    if avatar.effects then
        for _, eff in ipairs(avatar.effects) do
            if eff.type == "rule_change" and eff.desc then
                return L("avatar." .. avatarId .. ".effect", eff.desc)
            end
        end
    end
    return L("avatar." .. avatarId .. ".effect", "")
end

return Avatars
