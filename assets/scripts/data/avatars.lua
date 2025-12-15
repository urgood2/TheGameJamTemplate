-- Avatars are "Ascensions" or "Ultimate Forms" unlocked mid-run.
-- They provide powerful global rule changes.

local Avatars = {
    wildfire = {
        name = "Avatar of Wildfire",
        description = "Your flames consume everything.",
        sprite = "avatar_wildfire",  -- Optional: custom sprite (falls back to avatar_sample.png)

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
            crits_dealt = 50,
            OR_arcane_tags = 7
        },

        effects = {
            {
                type = "rule_change",
                rule = "crit_chains",
                desc = "Critical hits always Chain to a nearby enemy."
            },
            {
                type = "stat_buff",
                stat = "cast_speed",
                value = 0.5 -- +50% cast speed
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
    }
}

return Avatars
