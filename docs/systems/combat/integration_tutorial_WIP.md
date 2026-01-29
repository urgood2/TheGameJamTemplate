# Setup & Basic Structure

```lua
-- In your main file:
local Core = require('part1_core')
local Game = require('part2_gameplay')

-- Create a game context
local ctx = {
    bus = Core.EventBus.new(),
    time = Core.Time.new(),
    debug = true,
    side1 = {},
    side2 = {}
}

ctx.get_enemies_of = function(actor) 
    return actor.side == 1 and ctx.side2 or ctx.side1 
end
ctx.get_allies_of = function(actor) 
    return actor.side == 1 and ctx.side1 or ctx.side2 
end

-- Run demo to see it in action
Game.Demo.run()

Step 1: Add New Stat Definitions

-- After Core is loaded, extend the stat definitions
local defs, DAMAGE_TYPES = Core.StatDef.make()

-- Add custom stats to definitions
function Core.StatDef.make()
    local defs, DAMAGE_TYPES = Core.StatDef.make() -- Get base
    
    -- Add custom stats using the helper
    Core.util.add_basic(defs, 'magic_find')           -- % better loot
    Core.util.add_basic(defs, 'gold_find')            -- % more gold
    Core.util.add_basic(defs, 'thorns')               -- flat thorns damage
    Core.util.add_basic(defs, 'thorns_pct')           -- % of damage reflected as thorns
    Core.util.add_basic(defs, 'area_of_effect_pct')   -- % larger AoE
    Core.util.add_basic(defs, 'projectile_speed_pct') -- % faster projectiles
    Core.util.add_basic(defs, 'minion_damage_pct')    -- % minion damage
    
    -- New damage type
    table.insert(DAMAGE_TYPES, 'holy')
    Core.util.add_basic(defs, 'holy_damage')
    Core.util.add_basic(defs, 'holy_modifier_pct')
    Core.util.add_basic(defs, 'holy_resist_pct')
    
    return defs, DAMAGE_TYPES
end
```

# Step 2: Create Entities with Custom Stats

```lua
local function create_hero(name)
    local defs, DTS = Core.StatDef.make()
    local stats = Core.Stats.new(defs)
    
    -- Apply attribute derivations
    Game.Content.attach_attribute_derivations(stats)
    
    -- Set base stats
    stats:add_base('physique', 20)
    stats:add_base('cunning', 15)
    stats:add_base('spirit', 18)
    stats:add_base('health', 100)
    stats:add_base('weapon_min', 8)
    stats:add_base('weapon_max', 12)
    
    -- Custom stats
    stats:add_base('magic_find', 25)
    stats:add_base('area_of_effect_pct', 15)
    
    stats:recompute()
    
    return {
        name = name,
        stats = stats,
        hp = stats:get('health'),
        max_health = stats:get('health'),
        energy = stats:get('energy'),
        max_energy = stats:get('energy'),
        side = 1,
        equipped = {},
        gear_conversions = {},
        timers = {},
        tags = {}
    }
end

Custom Stat Derivations
Method 1: Attribute-based Derivations


-- Extend the existing attribute derivations
function Game.Content.attach_attribute_derivations(S)
    -- Call original first
    local original_attach = Game.Content.attach_attribute_derivations
    original_attach(S)
    
    -- Add custom derivations
    S:on_recompute(function(S)
        local p = S:get_raw('physique').base
        local c = S:get_raw('cunning').base  
        local s = S:get_raw('spirit').base
        
        -- Spirit increases magic find
        S:derived_add_base('magic_find', s * 0.5)
        
        -- Cunning increases gold find
        S:derived_add_base('gold_find', c * 0.3)
        
        -- Every 10 physique gives 1% AoE
        local physique_bonus = math.floor(p / 10)
        S:derived_add_add_pct('area_of_effect_pct', physique_bonus)
    end)
end
```

Method 2: Item/Skill-based Derivations

```lua
-- Custom derivation that activates when wearing specific items
function setup_set_bonus_derivations(entity)
    entity.stats:on_recompute(function(S)
        -- Check for specific item combinations
        local has_wizard_hat = entity.equipped.helm and entity.equipped.helm.id == "wizard_hat"
        local has_arcane_robe = entity.equipped.chest and entity.equipped.chest.id == "arcane_robe"
        
        if has_wizard_hat and has_arcane_robe then
            -- Set bonus: +20% minion damage, +10% cast speed
            S:derived_add_add_pct('minion_damage_pct', 20)
            S:derived_add_add_pct('cast_speed', 10)
        end
        
        -- Check for thorns gear
        local total_thorns = 0
        for slot, item in pairs(entity.equipped) do
            if item.thorns_value then
                total_thorns = total_thorns + item.thorns_value
            end
        end
        S:derived_add_base('thorns', total_thorns)
    end)
end
```

# Creating Custom Items

Basic Item Structure

```lua
local custom_items = {
    -- Weapon with proc effect
    thunderfury = {
        id = 'thunderfury',
        slot = 'sword1',
        requires = { attribute = 'cunning', value = 25, mode = 'sole' },
        
        mods = {
            { stat = 'weapon_min', base = 15 },
            { stat = 'weapon_max', base = 25 },
            { stat = 'lightning_modifier_pct', add_pct = 30 },
            { stat = 'attack_speed', add_pct = 15 }
        },
        
        procs = {
            {
                trigger = 'OnBasicAttack',
                chance = 20,
                effects = function(ctx, wearer, target, ev)
                    -- Chain lightning to 3 nearby enemies
                    local enemies = ctx.get_enemies_of(wearer)
                    local hit = 0
                    for _, enemy in ipairs(enemies) do
                        if enemy ~= target and hit < 3 then
                            Game.Effects.deal_damage {
                                components = { { type = 'lightning', amount = 40 } }
                            }(ctx, wearer, enemy)
                            hit = hit + 1
                        end
                    end
                end
            }
        }
    },
    
    -- Defensive item with custom stat
    thornmail = {
        id = 'thornmail',
        slot = 'chest',
        requires = { attribute = 'physique', value = 30, mode = 'sole' },
        
        mods = {
            { stat = 'armor', base = 45 },
            { stat = 'health', base = 50 }
        },
        
        thorns_value = 25, -- Custom property
        
        procs = {
            {
                trigger = 'OnHitResolved',
                chance = 100,
                filter = function(ev) return ev.target and ev.did_damage end,
                effects = function(ctx, wearer, _, ev)
                    -- Return thorns damage to attacker
                    local thorns_dmg = wearer.stats:get('thorns') or 0
                    if thorns_dmg > 0 then
                        Game.Effects.deal_damage {
                            components = { { type = 'physical', amount = thorns_dmg } },
                            reason = 'thorns'
                        }(ctx, wearer, ev.source)
                    end
                end
            }
        }
    },
    
    -- Item with spell mutator
    pyromancer_gauntlets = {
        id = 'pyromancer_gauntlets',
        slot = 'gloves',
        
        mods = {
            { stat = 'fire_modifier_pct', add_pct = 25 },
            { stat = 'cast_speed', add_pct = 10 }
        },
        
        spell_mutators = {
            Fireball = {
                {
                    pr = 0,
                    wrap = function(orig)
                        return function(ctx, src, tgt)
                            -- Add burning DoT to Fireball
                            if orig then orig(ctx, src, tgt) end
                            Game.Effects.apply_dot {
                                type = 'burn',
                                dps = 15,
                                duration = 4,
                                tick = 1
                            }(ctx, src, tgt)
                        end
                    end
                }
            }
        }
    }
}
```

# Item Sets

```lua
Game.Content.Sets = {
    -- Holy Paladin Set
    redemption_set = {
        bonuses = {
            {
                pieces = 2,
                effects = function(ctx, e)
                    e.stats:add_add_pct('holy_modifier_pct', 20)
                    return function(ent) 
                        ent.stats:add_add_pct('holy_modifier_pct', -20) 
                    end
                end
            },
            {
                pieces = 4,
                mutators = {
                    -- All healing spells also grant a barrier
                    Heal = function(orig)
                        return function(ctx, src, tgt)
                            if orig then orig(ctx, src, tgt) end
                            Game.Effects.grant_barrier {
                                amount = 25,
                                duration = 5
                            }(ctx, src, tgt)
                        end
                    end
                }
            }
        }
    }
}

-- Set items
local redemption_helm = {
    id = 'redemption_helm',
    slot = 'helm',
    set_id = 'redemption_set',
    mods = { { stat = 'health', base = 30 }, { stat = 'spirit', base = 5 } }
}

local redemption_chest = {
    id = 'redemption_chest', 
    slot = 'chest',
    set_id = 'redemption_set',
    mods = { { stat = 'armor', base = 40 }, { stat = 'holy_resist_pct', add_pct = 15 } }
}
```
# Custom Skills & Spells

Active Spells

```lua
Game.Content.Spells.HolyLight = {
    name = 'Holy Light',
    class = 'holy',
    trigger = 'OnCast',
    cost = 25,
    cooldown = 3,
    
    targeter = function(ctx) 
        return Core.Targeters.all_allies(ctx) 
    end,
    
    build = function(level, mods)
        level = level or 1
        mods = mods or {}
        
        local base_heal = 80 + (level - 1) * 20
        local heal_scale = 1 + (mods.dmg_pct or 0) / 100
        
        return function(ctx, src, tgt)
            -- Heal with holy power component
            Game.Effects.heal { 
                flat = base_heal * heal_scale,
                percent_of_max = 5 
            }(ctx, src, tgt)
            
            -- Cleanse debuffs
            Game.Effects.cleanse {
                predicate = function(id, entry)
                    -- Remove all debuffs (simplified logic)
                    return id:match("debuff_") or id:match("curse_")
                end
            }(ctx, src, tgt)
        end
    end
}

Game.Content.Spells.Meteor = {
    name = 'Meteor',
    class = 'fire',
    trigger = 'OnCast', 
    cost = 60,
    cooldown = 8,
    
    targeter = function(ctx)
        return { ctx.target } -- Single target, but with AoE splash
    end,
    
    effects = function(ctx, src, tgt)
        -- Main impact
        Game.Effects.deal_damage {
            components = { { type = 'fire', amount = 200 } },
            tags = { aoe = true }
        }(ctx, src, tgt)
        
        -- Splash damage to nearby enemies
        local enemies = ctx.get_enemies_of(src)
        for _, enemy in ipairs(enemies) do
            if enemy ~= tgt then
                -- Simple distance check (in real game, use actual positions)
                Game.Effects.deal_damage {
                    components = { { type = 'fire', amount = 80 } },
                    tags = { aoe = true, splash = true }
                }(ctx, src, enemy)
            end
        end
        
        -- Burning ground effect
        Game.Effects.apply_dot {
            type = 'burn',
            dps = 30,
            duration = 6,
            tick = 2
        }(ctx, src, tgt)
    end
}
```
# Passive Skills

```lua
Game.Skills.DB.ElementalMastery = {
    id = 'ElementalMastery',
    kind = 'passive',
    soft_cap = 10,
    ult_cap = 20,
    
    apply_stats = function(S, rank)
        -- Increase all elemental damage
        S:add_add_pct('fire_modifier_pct', 3 * rank)
        S:add_add_pct('cold_modifier_pct', 3 * rank) 
        S:add_add_pct('lightning_modifier_pct', 3 * rank)
        
        -- Elemental resistance
        S:add_add_pct('fire_resist_pct', 2 * rank)
        S:add_add_pct('cold_resist_pct', 2 * rank)
        S:add_add_pct('lightning_resist_pct', 2 * rank)
    end
}

Game.Skills.DB.SpellEcho = {
    id = 'SpellEcho',
    kind = 'passive', 
    soft_cap = 5,
    ult_cap = 10,
    
    apply_stats = function(S, rank)
        -- Chance to cast spells twice
        -- This would need custom handling in your cast system
        S:add_base('spell_echo_chance', 5 * rank)
    end
}
```

# Advanced: Custom Triggers & Event Hooks

Custom Event System
```lua
-- Define custom events
local CUSTOM_EVENTS = {
    'OnLowHealth',
    'OnSkillChain',
    'OnComboPointSpend',
    'OnResourceCritical',
    'OnAuraExpiring'
}

-- Register custom event handlers
function setup_custom_triggers(ctx)
    -- Low health trigger
    Core.hook(ctx, 'OnHitResolved', {
        condition = function(ctx, ev)
            return ev.target and ev.target.hp and ev.target.hp / ev.target.max_health < 0.3
        end,
        run = function(ctx, ev)
            ctx.bus:emit('OnLowHealth', { 
                entity = ev.target,
                health_pct = (ev.target.hp / ev.target.max_health) * 100
            })
        end
    })
    
    -- Combo point tracking
    local combo_points = {}
    
    Core.hook(ctx, 'OnHitResolved', {
        filter = function(ev) return ev.reason == 'basic_attack' end,
        run = function(ctx, ev)
            combo_points[ev.source] = (combo_points[ev.source] or 0) + 1
            if combo_points[ev.source] >= 5 then
                ctx.bus:emit('OnComboPointSpend', {
                    entity = ev.source,
                    points = combo_points[ev.source]
                })
                combo_points[ev.source] = 0
            end
        end
    })
end
```

# Advanced Item with Custom Triggers
```lua
local berserker_axe = {
    id = 'berserker_axe',
    slot = 'axe1',
    
    mods = {
        { stat = 'weapon_min', base = 20 },
        { stat = 'weapon_max', base = 35 },
        { stat = 'attack_speed', add_pct = 10 }
    },
    
    procs = {
        {
            trigger = 'OnLowHealth',
            effects = function(ctx, wearer, _, ev)
                -- Berserker rage when low health
                Game.Effects.modify_stat {
                    id = 'berserker_rage',
                    name = 'attack_speed',
                    add_pct_add = 50,
                    duration = 6
                }(ctx, wearer, wearer)
                
                Game.Effects.modify_stat {
                    id = 'berserker_rage_dmg',
                    name = 'physical_modifier_pct', 
                    add_pct_add = 30,
                    duration = 6
                }(ctx, wearer, wearer)
            end
        },
        {
            trigger = 'OnComboPointSpend',
            effects = function(ctx, wearer, _, ev)
                -- Extra damage when spending combo points
                local bonus_dmg = (ev.points or 0) * 15
                Game.Effects.deal_damage {
                    components = { { type = 'physical', amount = bonus_dmg } },
                    reason = 'finisher'
                }(ctx, wearer, wearer._last_target)
            end
        }
    },
    
    -- Track last target for combo finishers
    on_equip = function(ctx, e)
        local last_target = nil
        
        local unsub = ctx.bus:on('OnHitResolved', function(ev)
            if ev.source == e then
                last_target = ev.target
            end
        end)
        
        e._last_target = last_target
        
        return function()
            unsub()
            e._last_target = nil
        end
    end
}
```
# Status Effects & DoTs
Custom Status Effects

```lua
-- Bleeding status that scales with physical damage
local bleeding_status = Game.Effects.status({
    id = 'bleeding',
    duration = 6,
    stack = { mode = 'count', max = 5 },
    
    apply = function(e, ctx, src, tgt)
        -- Calculate bleed damage based on source's physical damage
        local phys_dmg = src.stats:get('physical_damage') or 0
        local bleed_dps = phys_dmg * 0.1 -- 10% of physical damage as DPS
        
        -- Store the DPS value for the DoT system to use
        e._bleed_dps = (e._bleed_dps or 0) + bleed_dps
    end,
    
    remove = function(e, ctx)
        e._bleed_dps = (e._bleed_dps or 0) - bleed_dps
    end
})

-- Freeze status that prevents action
local freeze_status = Game.Effects.status({
    id = 'freeze',
    duration = 3,
    stack = { mode = 'replace' },
    
    apply = function(e, ctx, src, tgt)
        e.tags.frozen = true
        -- In a real game, this would disable AI/controls
        print(e.name .. " is frozen!")
    end,
    
    remove = function(e, ctx)
        e.tags.frozen = false
        print(e.name .. " is no longer frozen!")
    end
})

-- Custom DoT types
Game.Effects.apply_custom_dot = function(p)
    return function(ctx, src, tgt)
        tgt.dots = tgt.dots or {}
        table.insert(tgt.dots, {
            type = p.type,
            dps = p.dps,
            tick = p.tick or 1.0,
            until_time = ctx.time.now + (p.duration or 0),
            next_tick = ctx.time.now + (p.tick or 1.0),
            source = src,
            on_tick = p.on_tick -- Custom tick behavior
        })
    end
end

-- Poison that reduces healing received
local venom_doom = Game.Effects.apply_custom_dot({
    type = 'poison',
    dps = 20,
    duration = 8,
    tick = 2,
    
    on_tick = function(ctx, src, tgt, dot)
        -- Reduce healing received by 50% while poisoned
        Game.Effects.modify_stat {
            id = 'venom_healing_reduction',
            name = 'healing_received_pct',
            add_pct_add = -50,
            duration = 2.1 -- Slightly longer than tick interval
        }(ctx, src, tgt)
    end
})
```
# Skill Trees & WPS
Custom Skill Tree Nodes
```lua
Game.Skills.DB.ChainLightningMastery = {
    id = 'ChainLightningMastery',
    kind = 'modifier',
    base = 'ChainLightning', -- Assuming this spell exists
    soft_cap = 8,
    ult_cap = 15,
    
    apply_mutator = function(rank)
        return function(orig)
            return function(ctx, src, tgt)
                if orig then orig(ctx, src, tgt) end
                
                -- Chain to additional targets based on rank
                local extra_chains = math.floor(rank / 2)
                local enemies = ctx.get_enemies_of(src)
                
                local chained = { [tgt] = true }
                local chain_count = 0
                
                for _, enemy in ipairs(enemies) do
                    if not chained[enemy] and chain_count < extra_chains then
                        -- Chain to this enemy with reduced damage
                        Game.Effects.deal_damage {
                            components = { { type = 'lightning', amount = 40 * (0.7 ^ chain_count) } },
                            reason = 'chain_lightning'
                        }(ctx, src, enemy)
                        
                        chained[enemy] = true
                        chain_count = chain_count + 1
                    end
                end
            end
        end
    end
}

Game.Skills.DB.DualWieldMastery = {
    id = 'DualWieldMastery',
    kind = 'passive',
    soft_cap = 10,
    ult_cap = 20,
    
    apply_stats = function(S, rank)
        -- Bonus when dual wielding
        S:add_add_pct('attack_speed', 2 * rank)
        S:add_base('offensive_ability', rank)
    end
}
```

Custom WPS (Weapon Pool Skills)
```lua
Game.WPS.DB.WhirlwindAttack = {
    id = 'WhirlwindAttack',
    chance = 15,
    effects = function(ctx, src, tgt)
        -- Attack all enemies around
        local enemies = ctx.get_enemies_of(src)
        for _, enemy in ipairs(enemies) do
            Game.Effects.deal_damage {
                weapon = true,
                scale_pct = 60,
                reason = 'whirlwind'
            }(ctx, src, enemy)
        end
    end
}

Game.WPS.DB.PowerStrike = {
    id = 'PowerStrike', 
    chance = 10,
    effects = function(ctx, src, tgt)
        -- Single powerful strike with knockback effect
        Game.Effects.deal_damage {
            weapon = true,
            scale_pct = 200,
            reason = 'power_strike'
        }(ctx, src, tgt)
        
        -- Apply trauma DoT
        Game.Effects.apply_dot {
            type = 'trauma',
            dps = 25,
            duration = 4,
            tick = 1
        }(ctx, src, tgt)
    end
}
```

# Complete Example

Here's a complete example putting everything together:
```lua
local Core = require('part1_core')
local Game = require('part2_gameplay')

-- Custom content definition
local function setup_custom_content()
    -- Custom stats
    local defs, DTS = Core.StatDef.make()
    Core.util.add_basic(defs, 'magic_find')
    Core.util.add_basic(defs, 'minion_damage_pct')
    table.insert(DTS, 'holy')
    Core.util.add_basic(defs, 'holy_damage')
    Core.util.add_basic(defs, 'holy_modifier_pct')
    Core.util.add_basic(defs, 'holy_resist_pct')
    
    -- Custom spells
    Game.Content.Spells.HolySmite = {
        name = 'Holy Smite',
        class = 'holy',
        trigger = 'OnCast',
        cost = 20,
        cooldown = 2,
        
        targeter = function(ctx) return { ctx.target } end,
        
        build = function(level, mods)
            level = level or 1
            local base_dmg = 60 + (level - 1) * 15
            local dmg_scale = 1 + (mods.dmg_pct or 0) / 100
            
            return function(ctx, src, tgt)
                Game.Effects.deal_damage {
                    components = { { type = 'holy', amount = base_dmg * dmg_scale } }
                }(ctx, src, tgt)
                
                -- Heal caster for 20% of damage done
                Game.Effects.heal {
                    flat = base_dmg * 0.2
                }(ctx, src, src)
            end
        end
    }
    
    -- Custom items
    local sacred_hammer = {
        id = 'sacred_hammer',
        slot = 'mace1',
        requires = { attribute = 'spirit', value = 20, mode = 'sole' },
        
        mods = {
            { stat = 'weapon_min', base = 12 },
            { stat = 'weapon_max', base = 18 },
            { stat = 'holy_modifier_pct', add_pct = 25 },
            { stat = 'spirit', base = 5 }
        },
        
        ability_mods = {
            HolySmite = { dmg_pct = 15, cd_add = -0.5 }
        },
        
        procs = {
            {
                trigger = 'OnBasicAttack',
                chance = 25,
                effects = function(ctx, wearer, target)
                    -- Chance to cast free Holy Smite
                    Game.Cast.cast(ctx, wearer, 'HolySmite', target)
                end
            }
        }
    }
    
    -- Custom skills
    Game.Skills.DB.HolyMastery = {
        id = 'HolyMastery',
        kind = 'passive',
        soft_cap = 10,
        ult_cap = 20,
        
        apply_stats = function(S, rank)
            S:add_add_pct('holy_modifier_pct', 4 * rank)
            S:add_add_pct('healing_received_pct', 2 * rank)
            S:add_base('spirit', rank)
        end
    }
    
    return sacred_hammer
end

-- Main execution
function run_custom_example()
    math.randomseed(os.time())
    
    local ctx = {
        bus = Core.EventBus.new(),
        time = Core.Time.new(),
        debug = true,
        side1 = {},
        side2 = {}
    }
    
    ctx.get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end
    ctx.get_allies_of = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end
    
    -- Setup custom content
    local sacred_hammer = setup_custom_content()
    
    -- Create hero
    local hero = Game.Demo.make_actor('Paladin', Core.StatDef.make(), Game.Content.attach_attribute_derivations)
    hero.side = 1
    hero.stats:add_base('physique', 18)
    hero.stats:add_base('spirit', 22)
    hero.stats:add_base('health', 120)
    hero.stats:recompute()
    
    -- Create enemy
    local skeleton = Game.Demo.make_actor('Skeleton', Core.StatDef.make(), Game.Content.attach_attribute_derivations)
    skeleton.side = 2
    skeleton.stats:add_base('health', 80)
    skeleton.stats:recompute()
    
    ctx.side1 = { hero }
    ctx.side2 = { skeleton }
    
    -- Equip custom item
    Game.ItemSystem.equip(ctx, hero, sacred_hammer)
    
    -- Set up skill
    Game.Skills.SkillTree.set_rank(hero, 'HolyMastery', 5)
    set_ability_level(hero, 'HolySmite', 3)
    
    -- Add event logging
    ctx.bus:on('OnHitResolved', function(ev)
        print(string.format('[%s] hit [%s] for %.1f %s damage',
            ev.source.name, ev.target.name, ev.damage, 
            ev.components and next(ev.components) or 'unknown'))
    end)
    
    ctx.bus:on('OnHealed', function(ev)
        print(string.format('[%s] healed for %.1f HP', 
            ev.target.name, ev.amount))
    end)
    
    -- Run combat sequence
    print("=== COMBAT START ===")
    
    -- Basic attack (may trigger proc)
    Game.Effects.deal_damage { weapon = true, scale_pct = 100 }(ctx, hero, skeleton)
    
    -- Cast custom spell
    Game.Cast.cast(ctx, hero, 'HolySmite', skeleton)
    
    -- Show final stats
    Core.util.dump_stats(hero, ctx)
    Core.util.dump_stats(skeleton, ctx)
    
    print("=== COMBAT END ===")
end

-- Execute the example
run_custom_example()

```
<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
