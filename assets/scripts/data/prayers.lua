-- Example Prayer Definitions
-- These are referenced by Origins in data/origins.lua

local ActionAPI = require("combat.action_api")

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end


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
    },

    thunderclap = {
        id = "thunderclap",
        name = "Thunderclap",
        description = "Stun all nearby enemies for 1.5s and apply Static Charge.",
        cooldown = 15,
        range = 150,

        effect = function(ctx, caster)
            local MarkSystem = require("systems.mark_system")
            local PhysicsManager = require("core.physics_manager")
            local Particles = require("core.particles")

            local caster_transform = component_cache.get(caster, Transform)
            if not caster_transform then return end

            local cx = caster_transform.actualX + (caster_transform.actualW or 0) * 0.5
            local cy = caster_transform.actualY + (caster_transform.actualH or 0) * 0.5

            -- Find nearby enemies using physics spatial query
            local nearby = {}
            local range = 150
            local world = PhysicsManager and PhysicsManager.get_world and PhysicsManager.get_world("world")

            if physics and physics.GetObjectsInArea and world then
                -- AABB query (first pass - fast)
                local candidates = physics.GetObjectsInArea(world, cx - range, cy - range, cx + range, cy + range) or {}
                local rangeSq = range * range

                for _, eid in ipairs(candidates) do
                    -- Skip non-enemies
                    if isEnemyEntity(eid) then
                        local t = component_cache.get(eid, Transform)
                        if t then
                            local ex = (t.actualX or 0) + (t.actualW or 0) * 0.5
                            local ey = (t.actualY or 0) + (t.actualH or 0) * 0.5
                            local dx, dy = ex - cx, ey - cy
                            local distSq = dx * dx + dy * dy

                            -- Circular range check
                            if distSq <= rangeSq then
                                nearby[#nearby + 1] = eid
                            end
                        end
                    end
                end
            end

            for _, enemy in ipairs(nearby) do
                -- Apply stun
                if ActionAPI then
                    ActionAPI.apply_stun(ctx, enemy, 1.5)
                end
                -- Apply static_charge mark
                MarkSystem.apply(enemy, "static_charge", { stacks = 1, source = caster })
            end

            -- Play sound
            playSoundEffect("effects", "thunderclap")

            -- Visual effect - radial burst of cyan/white particles
            local thunderBurst = Particles.define()
                :shape("circle")
                :size(4, 8)
                :color("cyan", "white")
                :velocity(150, 250)
                :lifespan(0.3)
                :fade()

            thunderBurst:burst(20):at(cx, cy):outward()
        end
    }
}

--- Get localized name for a prayer (call at runtime when localization is ready)
--- @param prayerId string The prayer key (e.g., "ember_psalm")
--- @return string The localized name or fallback English name
function Prayers.getLocalizedName(prayerId)
    local prayer = Prayers[prayerId]
    if not prayer then return prayerId end
    return L("prayer." .. prayerId .. ".name", prayer.name)
end

--- Get localized description for a prayer (call at runtime when localization is ready)
--- @param prayerId string The prayer key (e.g., "ember_psalm")
--- @return string The localized description or fallback English description
function Prayers.getLocalizedDescription(prayerId)
    local prayer = Prayers[prayerId]
    if not prayer then return "" end
    return L("prayer." .. prayerId .. ".description", prayer.description)
end

return Prayers
