local Triggers = require("data.triggers")

local DemoEquipment = {}

local function getStatusEngine()
    local CombatSystem = require("combat.combat_system")
    return CombatSystem.StatusEngine
end

-- CHEST ARMOR (4 items)

DemoEquipment.flame_robes = {
    id = "flame_robes",
    name = "Flame Robes",
    slot = "chest",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {
        fire_modifier_pct = 15,
    },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.source, "scorch", {
                    stacks = 2,
                    source = src,
                })
            end,
        },
    },
}

DemoEquipment.frost_plate = {
    id = "frost_plate",
    name = "Frost Plate",
    slot = "chest",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {
        armor = 30,
    },

    procs = {
        {
            trigger = Triggers.DEFENSIVE.ON_BLOCK,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.source, "frozen", {
                    stacks = 3,
                    source = src,
                })
            end,
        },
    },
}

DemoEquipment.storm_cloak = {
    id = "storm_cloak",
    name = "Storm Cloak",
    slot = "chest",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {
        run_speed = 10,
    },

    procs = {
        {
            trigger = Triggers.DEFENSIVE.ON_DODGE,
            effect = function(ctx, src, ev)
                -- Chain lightning to 2 enemies
                if ctx.get_enemies_of then
                    local enemies = ctx.get_enemies_of(src)
                    local count = 0
                    for _, e in ipairs(enemies) do
                        if count < 2 then
                            getStatusEngine().apply(ctx, e, "electrocute", {
                                stacks = 1,
                                source = src,
                            })
                            count = count + 1
                        end
                    end
                end
            end,
        },
    },
}

DemoEquipment.void_vestments = {
    id = "void_vestments",
    name = "Void Vestments",
    slot = "chest",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {
        death_modifier_pct = 10,
    },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.source, "doom", {
                    stacks = 1,
                    source = src,
                })
            end,
        },
    },
}

-- GLOVES (4 items)

DemoEquipment.ignition_gauntlets = {
    id = "ignition_gauntlets",
    name = "Ignition Gauntlets",
    slot = "gloves",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {},

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            effect = function(ctx, src, ev)
                -- Projectiles apply +3 Scorch
                getStatusEngine().apply(ctx, ev.target, "scorch", {
                    stacks = 3,
                    source = src,
                })
            end,
        },
    },
}

DemoEquipment.glacier_grips = {
    id = "glacier_grips",
    name = "Glacier Grips",
    slot = "gloves",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {},

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            effect = function(ctx, src, ev)
                -- AoE casts apply +2 Freeze to all targets
                if ctx.get_enemies_of then
                    local enemies = ctx.get_enemies_of(src)
                    for _, e in ipairs(enemies) do
                        getStatusEngine().apply(ctx, e, "frozen", {
                            stacks = 2,
                            source = src,
                        })
                    end
                end
            end,
        },
    },
}

DemoEquipment.surge_bracers = {
    id = "surge_bracers",
    name = "Surge Bracers",
    slot = "gloves",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {
        attack_speed_pct = 15,
    },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_CRIT,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, src, "swift", {
                    stacks = 5,
                    source = src,
                    duration = 2,
                })
            end,
        },
    },
}

DemoEquipment.reapers_touch = {
    id = "reapers_touch",
    name = "Reaper's Touch",
    slot = "gloves",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {},

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            effect = function(ctx, src, ev)
                -- If target has Doom: +10% damage
                local doom_stacks = getStatusEngine().getStacks(ev.target, "doom")
                if doom_stacks and doom_stacks > 0 then
                    -- Apply bonus damage modifier
                    if src.damage_mult then
                        src.damage_mult = (src.damage_mult or 1.0) * 1.1
                    end
                end
            end,
        },
    },
}

-- BOOTS (4 items)

DemoEquipment.ember_greaves = {
    id = "ember_greaves",
    name = "Ember Greaves",
    slot = "boots",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {},

    procs = {
        {
            trigger = Triggers.MOVEMENT.ON_STEP,
            effect = function(ctx, src, ev)
                -- Leave fire trail: 10 damage/sec for 1s
                if ctx.create_pool_effect then
                    ctx.create_pool_effect(src.x, src.y, "fire", {
                        damage = 10,
                        duration = 1,
                        source = src,
                    })
                end
            end,
        },
    },
}

DemoEquipment.frozen_treads = {
    id = "frozen_treads",
    name = "Frozen Treads",
    slot = "boots",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {
        run_speed = -5,
        freeze_duration_pct = 25,
        armor = 30,
    },
}

DemoEquipment.lightning_striders = {
    id = "lightning_striders",
    name = "Lightning Striders",
    slot = "boots",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {
        run_speed = 10,
        dodge_chance_pct = 20,
    },
}

DemoEquipment.death_walkers = {
    id = "death_walkers",
    name = "Death Walkers",
    slot = "boots",
    rarity = "Rare",
    sprite = "frame0012.png",

    stats = {},

    procs = {
        {
            trigger = Triggers.COMBAT.ON_KILL,
            effect = function(ctx, src, ev)
                -- On kill: apply 2 Doom to 2 nearby enemies
                if ctx.get_enemies_of then
                    local enemies = ctx.get_enemies_of(src)
                    local count = 0
                    for _, e in ipairs(enemies) do
                        if count < 2 then
                            getStatusEngine().apply(ctx, e, "doom", {
                                stacks = 2,
                                source = src,
                            })
                            count = count + 1
                        end
                    end
                end
            end,
        },
    },
}

-- Helper Functions

function DemoEquipment.getAll()
    local items = {}
    for k, v in pairs(DemoEquipment) do
        if type(v) == "table" and v.id then
            items[#items + 1] = v
        end
    end
    return items
end

function DemoEquipment.getBySlot(slot)
    local items = {}
    for k, v in pairs(DemoEquipment) do
        if type(v) == "table" and v.slot == slot then
            items[#items + 1] = v
        end
    end
    return items
end

function DemoEquipment.getStarterEquipment()
    return {
        DemoEquipment.flame_robes,
        DemoEquipment.ignition_gauntlets,
        DemoEquipment.ember_greaves,
    }
end

return DemoEquipment
