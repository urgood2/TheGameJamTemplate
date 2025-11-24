-- Example Prayer Definitions
-- These are referenced by Origins in data/origins.lua

local ActionAPI = require("combat.action_api")


local Prayers = {
    ember_psalm = {
        id = "ember_psalm",
        name = "Ember Psalm",
        description = "Next 3 actions leave fire hazards",
        cooldown = 30,

        effect = function(ctx, caster)
            -- Apply a buff that tracks remaining charges
            ActionAPI.apply_status(ctx, caster, "ember_psalm_buff", { duration = 10, stacks = 3 })

            -- The buff's on_action_cast hook would be defined in StatusEngine
            -- For now, emit an event that the wand system can listen to
            if ctx.bus then
                ctx.bus:emit("prayer_buff_applied", {
                    caster = caster,
                    buff_id = "ember_psalm_buff",
                    charges = 3
                })
            end
        end
    },

    glacier_litany = {
        id = "glacier_litany",
        name = "Glacier Litany",
        description = "Freeze nearby enemies and gain barrier. Cooldown reduced when you block.",
        cooldown = 45,

        effect = function(ctx, caster)
            -- Freeze nearby enemies (emit event for game engine to handle)
            if ctx.bus then
                ctx.bus:emit("aoe_freeze", {
                    source = caster,
                    radius = 8,
                    duration = 3
                })
            end

            -- Grant barrier using new helper
            local barrier_amount = (caster.max_health or 100) * 0.15 -- 15% max HP
            ActionAPI.grant_barrier(ctx, caster, barrier_amount, 5)
        end
    },

    contagion = {
        id = "contagion",
        name = "Contagion",
        description = "Spread all poison stacks to nearby enemies",
        cooldown = 45,

        effect = function(ctx, caster)
            -- Emit event for poison spread mechanic
            if ctx.bus then
                ctx.bus:emit("poison_spread_aoe", {
                    source = caster,
                    radius = 10
                })
            end
        end
    },

    void_rift = {
        id = "void_rift",
        name = "Void Rift",
        description = "Summon a rift that pulls enemies and deals damage",
        cooldown = 40,

        effect = function(ctx, caster)
            -- Spawn rift hazard
            if ctx.bus then
                ctx.bus:emit("spawn_hazard", {
                    pos = caster.position,
                    type = "void_rift",
                    radius = 5,
                    dps = 30,
                    duration = 6,
                    pull_strength = 5 -- Custom property
                })
            end
        end
    }
}

return Prayers
