local Triggers = require("data.triggers")

local Equipment = {}

local function getStatusEngine()
    local CombatSystem = require("combat.combat_system")
    return CombatSystem.StatusEngine
end

Equipment.flaming_sword = {
    id = "flaming_sword",
    name = "Flaming Sword",
    slot = "main_hand",
    rarity = "Rare",

    stats = {
        weapon_min = 50,
        weapon_max = 80,
        fire_damage = 20,
        attack_speed = 0.1,
    },

    requires = { attribute = "physique", value = 20, mode = "sole" },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            chance = 30,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.target, "burning", {
                    stacks = 3,
                    source = src,
                })
            end,
        },
        {
            trigger = Triggers.COMBAT.ON_KILL,
            effect = function(ctx, src, ev)
                local Q = require("core.Q")
                if ctx.get_enemies_of then
                    local enemies = ctx.get_enemies_of(src)
                    for _, e in ipairs(enemies) do
                        if Q.isInRange(src, e, 100) then
                            getStatusEngine().apply(ctx, e, "burning", {
                                stacks = 5,
                                source = src,
                            })
                        end
                    end
                end
            end,
        },
    },

    conversions = {
        { from = "physical", to = "fire", pct = 50 },
    },
}

Equipment.frost_armor = {
    id = "frost_armor",
    name = "Frost Armor",
    slot = "chest",
    rarity = "Rare",

    stats = {
        armor = 100,
        cold_resist_pct = 25,
    },

    requires = { attribute = "physique", value = 25, mode = "sole" },

    procs = {
        {
            trigger = Triggers.DEFENSIVE.ON_BEING_HIT,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.source, "frozen", {
                    stacks = 2,
                    source = src,
                })
            end,
        },
        {
            trigger = Triggers.DEFENSIVE.ON_BLOCK,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.attacker, "frozen", {
                    stacks = 5,
                    source = src,
                })
            end,
        },
    },
}

Equipment.berserker_helm = {
    id = "berserker_helm",
    name = "Berserker's Helm",
    slot = "head",
    rarity = "Uncommon",

    stats = {
        armor = 30,
        offensive_ability = 20,
    },

    requires = { attribute = "physique", value = 15, mode = "sole" },

    per_empty_armor_bonus = {
        offensive_ability = 20,
        run_speed = 5,
    },

    procs = {
        {
            trigger = Triggers.DEFENSIVE.ON_BEING_HIT,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, src, "bloodrage", {
                    stacks = 2,
                    source = src,
                })
            end,
        },
    },
}

Equipment.doom_blade = {
    id = "doom_blade",
    name = "Doom Blade",
    slot = "main_hand",
    rarity = "Epic",

    stats = {
        weapon_min = 60,
        weapon_max = 100,
        death_damage = 15,
    },

    requires = { attribute = "cunning", value = 30, mode = "sole" },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_ATTACK,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.target, "doom", {
                    stacks = 5,
                    source = src,
                })
            end,
        },
        {
            trigger = Triggers.COMBAT.ON_HIT,
            effect = function(ctx, src, ev)
                local doom_stacks = getStatusEngine().getStacks(ev.target, "doom")
                if doom_stacks > 0 then
                    local CombatSystem = require("combat.combat_system")
                    if CombatSystem and CombatSystem.Effects then
                        CombatSystem.Effects.deal_damage({
                            components = {{ type = "death", amount = doom_stacks * 2 }},
                            tags = { doom_bonus = true },
                        })(ctx, src, ev.target)
                    end
                end
            end,
        },
    },
}

Equipment.vampiric_ring = {
    id = "vampiric_ring",
    name = "Vampiric Ring",
    slot = "ring1",
    rarity = "Rare",

    stats = {
        life_steal_pct = 10,
        blood_damage = 5,
        blood_resist_pct = 15,
    },

    requires = { attribute = "spirit", value = 20, mode = "sole" },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_KILL,
            effect = function(ctx, src, ev)
                local heal_amount = 20
                if src.hp and src.max_health then
                    src.hp = math.min(src.hp + heal_amount, src.max_health)
                end
            end,
        },
    },
}

Equipment.amulet_of_fortitude = {
    id = "amulet_of_fortitude",
    name = "Amulet of Fortitude",
    slot = "necklace",
    rarity = "Uncommon",

    stats = {
        health = 50,
        armor = 20,
        all_resist_pct = 5,
    },

    requires = { attribute = "spirit", value = 15, mode = "sole" },

    procs = {
        {
            trigger = Triggers.RESOURCE.ON_LOW_HEALTH,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, src, "fortify", {
                    stacks = 5,
                    source = src,
                    duration = 5,
                })
            end,
        },
    },
}

Equipment.swift_boots = {
    id = "swift_boots",
    name = "Swift Boots",
    slot = "boots",
    rarity = "Common",

    stats = {
        armor = 15,
        run_speed = 30,
        dodge_chance_pct = 5,
    },

    requires = { attribute = "cunning", value = 10, mode = "sole" },

    procs = {
        {
            trigger = Triggers.MOVEMENT.ON_STEP,
            chance = 5,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, src, "charge", {
                    stacks = 1,
                    source = src,
                })
            end,
        },
    },
}

Equipment.gauntlets_of_might = {
    id = "gauntlets_of_might",
    name = "Gauntlets of Might",
    slot = "glove",
    rarity = "Uncommon",

    stats = {
        armor = 25,
        physique = 5,
        weapon_damage_pct = 10,
    },

    requires = { attribute = "physique", value = 18, mode = "sole" },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_CRIT,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, src, "poise", {
                    stacks = 3,
                    source = src,
                })
            end,
        },
    },
}

Equipment.pants_of_stability = {
    id = "pants_of_stability",
    name = "Pants of Stability",
    slot = "pants",
    rarity = "Common",

    stats = {
        armor = 20,
        stun_resist_pct = 20,
        freeze_resist_pct = 15,
    },

    requires = { attribute = "physique", value = 12, mode = "sole" },
}

Equipment.ring_of_meditation = {
    id = "ring_of_meditation",
    name = "Ring of Meditation",
    slot = "ring2",
    rarity = "Uncommon",

    stats = {
        spirit = 5,
        energy_regen = 3,
        cold_modifier_pct = 10,
    },

    requires = { attribute = "spirit", value = 18, mode = "sole" },

    procs = {
        {
            trigger = Triggers.MOVEMENT.ON_STAND_STILL,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, src, "meditate", {
                    stacks = 1,
                    source = src,
                })
            end,
        },
    },
}

-- Phase 5 additions to reach 12 equipment items

Equipment.stormbringer_staff = {
    id = "stormbringer_staff",
    name = "Stormbringer Staff",
    slot = "main_hand",
    rarity = "Rare",

    stats = {
        weapon_min = 30,
        weapon_max = 60,
        lightning_damage = 25,
        cast_speed_pct = 10,
    },

    requires = { attribute = "spirit", value = 25, mode = "sole" },

    procs = {
        {
            trigger = Triggers.COMBAT.ON_CRIT,
            effect = function(ctx, src, ev)
                -- Chain lightning on crit
                getStatusEngine().apply(ctx, ev.target, "electrocute", {
                    stacks = 3,
                    source = src,
                })
            end,
        },
        {
            trigger = Triggers.COMBAT.ON_KILL,
            chance = 30,
            effect = function(ctx, src, ev)
                -- Chance to restore mana on kill
                if src.mana and src.max_mana then
                    src.mana = math.min(src.mana + 10, src.max_mana)
                end
            end,
        },
    },

    conversions = {
        { from = "physical", to = "lightning", pct = 75 },
    },
}

Equipment.cloak_of_shadows = {
    id = "cloak_of_shadows",
    name = "Cloak of Shadows",
    slot = "chest",
    rarity = "Epic",

    stats = {
        armor = 60,
        dodge_chance_pct = 15,
        move_speed_pct = 10,
    },

    requires = { attribute = "cunning", value = 30, mode = "sole" },

    procs = {
        {
            trigger = Triggers.DEFENSIVE.ON_DODGE,
            effect = function(ctx, src, ev)
                -- Gain invisibility briefly on dodge
                getStatusEngine().apply(ctx, src, "stealth", {
                    stacks = 1,
                    source = src,
                    duration = 2,
                })
            end,
        },
        {
            trigger = Triggers.DEFENSIVE.ON_BEING_HIT,
            chance = 20,
            effect = function(ctx, src, ev)
                -- Chance to phase through attack
                return { damage_reduction = ev.damage }
            end,
        },
    },
}

function Equipment.get(id)
    return Equipment[id]
end

function Equipment.getAll()
    local items = {}
    for k, v in pairs(Equipment) do
        if type(v) == "table" and v.id then
            items[#items + 1] = v
        end
    end
    return items
end

function Equipment.getBySlot(slot)
    local items = {}
    for k, v in pairs(Equipment) do
        if type(v) == "table" and v.slot == slot then
            items[#items + 1] = v
        end
    end
    return items
end

function Equipment.getByRarity(rarity)
    local items = {}
    for k, v in pairs(Equipment) do
        if type(v) == "table" and v.rarity == rarity then
            items[#items + 1] = v
        end
    end
    return items
end

return Equipment
