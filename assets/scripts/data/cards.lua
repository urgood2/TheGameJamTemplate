local z_orders = require("core.z_orders")
local Particles = require("core.particles")

--[[
================================================================================
CARD DEFINITIONS
================================================================================
Centralized registry for all Action and Modifier cards.

Tags (for joker synergies):
  Elements: Fire, Ice, Lightning, Poison, Arcane, Holy, Void
  Mechanics: Projectile, AoE, Hazard, Summon, Buff, Debuff
  Playstyle: Mobility, Defense, Brute

DEFAULTS:
  Fields with default values can be OMITTED. See content_defaults.lua for all defaults.
  Common defaults you can skip:
  - max_uses = -1 (infinite)
  - recharge_time = 0
  - weight = 1
  - radius_of_effect = 0 (no AoE)
  - damage_type = "physical"
  - Modifier fields: damage_modifier, speed_modifier, lifetime_modifier, spread_modifier, critical_hit_chance_modifier (all = 0)
]]

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end

local Cards = {}


Cards.MY_FIREBALL = {
    id = "MY_FIREBALL",
    type = "action",
    mana_cost = 12,
    tags = { "Fire", "Projectile" },
    test_label = "MY\nfireball",
    description = "Launches a fiery projectile that explodes on impact, dealing fire damage in an area.",
    damage = 25,
    damage_type = "fire",
    projectile_speed = 400,
    lifetime = 2000,
    radius_of_effect = 50,
}

Cards.TEST_PROJECTILE = {
    id = "TEST_PROJECTILE",
    type = "action",
    mana_cost = 5,
    damage = 10,
    spread_angle = 5,
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,
    tags = { "Projectile" },
    test_label = "TEST\nprojectile",
    description = "A basic magic bolt for testing purposes.",
}

Cards.TEST_PROJECTILE_TIMER = {
    id = "TEST_PROJECTILE_TIMER",
    type = "action",
    mana_cost = 8,
    damage = 15,
    spread_angle = 3,
    projectile_speed = 400,
    lifetime = 3000,
    cast_delay = 150,
    timer_ms = 1000,
    weight = 2,
    tags = { "Projectile", "Arcane" },
    test_label = "TEST\nprojectile\ntimer",
    description = "Magic bolt that triggers effects after a delay.",
}

Cards.TEST_PROJECTILE_TRIGGER = {
    id = "TEST_PROJECTILE_TRIGGER",
    type = "action",
    mana_cost = 10,
    damage = 20,
    spread_angle = 2,
    projectile_speed = 600,
    lifetime = 2500,
    cast_delay = 200,
    trigger_on_collision = true,
    weight = 2,
    tags = { "Projectile", "Arcane" },
    test_label = "TEST\nprojectile\ntrigger",
    description = "Magic bolt that triggers effects on collision.",
}

Cards.TEST_DAMAGE_BOOST = {
    id = "TEST_DAMAGE_BOOST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 3,
    damage_modifier = 5,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    tags = { "Buff", "Brute" },
    test_label = "TEST\ndamage\nboost",
    description = "Increases damage of the next spell.",
}

Cards.TEST_MULTICAST_2 = {
    id = "TEST_MULTICAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 7,
    multicast_count = 2,
    weight = 2,
    tags = { "Arcane" },
    test_label = "TEST\nmulticast",
    description = "Casts the next spell twice.",
}

Cards.ACTION_BASIC_PROJECTILE = {
    id = "ACTION_BASIC_PROJECTILE",
    type = "action",
    mana_cost = 5,
    damage = 10,
    spread_angle = 5,
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,
    tags = { "Projectile" },
    test_label = "ACTION\nbasic\nprojectile",
    sprite = "action-basic-projectile.png",
    description = "A simple magic bolt that travels in a straight line.",
}

Cards.ACTION_CHAIN_LIGHTNING = {
    id = "ACTION_CHAIN_LIGHTNING",
    type = "action",
    mana_cost = 5,
    damage = 10,
    spread_angle = 5,
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,

    -- Chain-specific fields
    chain_count = 3,
    chain_range = 150,
    chain_damage_mult = 0.5,
    
    -- sprite projectiles
    use_sprite = true,                         -- Enable sprite rendering
    projectileSprite = "lightning-projectile.png",   -- Sprite to use (or animation)

    -- Custom projectile colors (lightning theme)
    -- projectile_color = "CYAN",
    -- projectile_core_color = "WHITE",
    
    -- OR full custom rendering (NOTE: use snake_case)
    -- custom_render = function(eid, data, transform, dt, script, ctx)
    --     -- ctx contains: cx, cy, vx, vy, angle, speed, visualSize
    --     command_buffer.queueDrawLine(layers.sprites, function(c)
    --         c.x1 = ctx.cx - 10
    --         c.y1 = ctx.cy
    --         c.x2 = ctx.cx + 10
    --         c.y2 = ctx.cy
    --         c.color = util.getColor("CYAN")
    --         c.lineWidth = 2
    --     end, z_orders.projectiles, layer.DrawCommandSpace.World)
    -- end,

    -- Size (affects collision and visual)
    size = 7,                 -- base size in pixels (small, zippy bolt)
    collision_radius = 12,

    -- Trail particles (electric sparks behind the bolt)
    trail_particles = function()
        return Particles.define()
            :shape("circle")
            :size(2, 4)
            :color("cyan", "blue")
            :velocity(20, 50)
            :lifespan(0.1, 0.2)
            :fade()
    end,
    trail_rate = 0.02,  -- Spawn every 20ms for dense trail
    
    on_spawn = function(projectileEntity, params, actionCard, modifiers, context)
          -- Play spawn sound
          playSoundEffect("effects", "electric_spell_cast_2")

          -- Or spawn particles, apply effects, etc.
    end,
    
    -- these are specific to chain lightning (spawnChainLightning)
    chain_start_sfx = "electric_layer",           -- plays once at start
    chain_hit_sfx = "electric_individual_hit",  -- plays per enemy hit

    -- Status effect application
    apply_status = "electrocute",
    status_duration = 3,
    status_dps = 5,

    -- wall_hit_sfx = "ice_shatter",  -- Custom wall hit sound

    tags = { "Arcane", "Lightning" },
    damage_type = "lightning",
    sprite = "action-chain-lightning.png",
    description = "Lightning arcs between enemies, chaining up to 3 times.",
}

-- Setup card: applies static_charge mark
Cards.ACTION_STATIC_CHARGE = {
    id = "ACTION_STATIC_CHARGE",
    type = "action",
    mana_cost = 4,
    damage = 5,
    damage_type = "lightning",
    projectile_speed = 600,
    lifetime = 1500,
    cast_delay = 80,
    apply_mark = "static_charge",
    mark_stacks = 1,
    tags = { "Lightning", "Debuff" },
    test_label = "STATIC\nCHARGE",
    sprite = "action-chain-lightning.png",
    description = "Marks the target with static charge for combo potential.",
}

Cards.ACTION_STATIC_SHIELD = {
    id = "ACTION_STATIC_SHIELD",
    type = "action",
    mana_cost = 8,
    cast_delay = 50,
    apply_to_self = "static_shield",
    self_mark_stacks = 1,
    tags = { "Lightning", "Defense" },
    test_label = "STATIC\nSHIELD",
    sprite = "action-chain-lightning.png",
    description = "Creates a protective lightning barrier around you.",
}



Cards.ACTION_FAST_ACCURATE_PROJECTILE = {
    id = "ACTION_FAST_ACCURATE_PROJECTILE",
    type = "action",
    mana_cost = 6,
    damage = 8,
    spread_angle = 1,
    projectile_speed = 800,
    lifetime = 1800,
    cast_delay = 80,
    tags = { "Projectile", "Arcane" },
    test_label = "ACTION\nfast\naccurate\nprojectile",
    description = "A precise, fast-moving bolt with minimal spread.",
}

Cards.ACTION_SLOW_ORB = {
    id = "ACTION_SLOW_ORB",
    type = "action",
    mana_cost = 8,
    damage = 20,
    damage_type = "magic",
    spread_angle = 6,
    projectile_speed = 250,
    lifetime = 4000,
    cast_delay = 150,
    weight = 2,
    tags = { "Projectile", "Arcane" },
    test_label = "ACTION\nslow\norb",
    description = "A powerful but slow-moving magical orb.",
}

Cards.ACTION_EXPLOSIVE_FIRE_PROJECTILE = {
    id = "ACTION_EXPLOSIVE_FIRE_PROJECTILE",
    type = "action",
    mana_cost = 15,
    damage = 35,
    damage_type = "fire",
    radius_of_effect = 60,
    spread_angle = 3,
    projectile_speed = 400,
    lifetime = 2000,
    cast_delay = 200,
    weight = 3,
    tags = { "Fire", "Projectile", "AoE" },
    test_label = "ACTION\nexplosive\nfire\nprojectile",
    sprite = "action-explosive-fire-projectile.png",
    description = "Fiery projectile that explodes on impact.",
}

Cards.ACTION_RICOCHET_PROJECTILE = {
    id = "ACTION_RICOCHET_PROJECTILE",
    type = "action",
    mana_cost = 10,
    damage = 15,
    spread_angle = 2,
    projectile_speed = 500,
    lifetime = 2500,
    cast_delay = 120,
    ricochet_count = 3,
    weight = 2,
    tags = { "Projectile" },
    test_label = "ACTION\nricochet\nprojectile",
    sprite = "action-richochet-projectile.png",
    description = "Bounces off walls up to 3 times.",
}

Cards.ACTION_HEAVY_OBJECT_PROJECTILE = {
    id = "ACTION_HEAVY_OBJECT_PROJECTILE",
    type = "action",
    mana_cost = 12,
    damage = 25,
    spread_angle = 4,
    projectile_speed = 200,
    lifetime = 3000,
    cast_delay = 150,
    gravity_affected = true,
    weight = 2,
    tags = { "Projectile", "Brute" },
    test_label = "ACTION\nheavy\nobject\nprojectile",
    description = "A heavy projectile affected by gravity.",
}

Cards.ACTION_VACUUM_PROJECTILE = {
    id = "ACTION_VACUUM_PROJECTILE",
    type = "action",
    mana_cost = 18,
    damage = 10,
    damage_type = "void",
    radius_of_effect = 100,
    projectile_speed = 300,
    lifetime = 2500,
    cast_delay = 200,
    suction_strength = 10,
    weight = 3,
    tags = { "Void", "Projectile", "AoE" },
    test_label = "ACTION\nvacuum\nprojectile",
    sprite = "action-vacuum-projectile.png",
    description = "Creates a void that pulls enemies inward.",
}

Cards.MOD_SEEKING = {
    id = "MOD_SEEKING",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    seek_strength = 8,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 2,
    tags = { "Arcane", "Projectile" },
    test_label = "MOD\nseeking",
    description = "Projectiles gently curve toward enemies.",
}

Cards.MOD_SPEED_UP = {
    id = "MOD_SPEED_UP",
    type = "modifier",
    max_uses = -1,
    mana_cost = 4,
    speed_modifier = 3,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    tags = { "Buff", "Mobility" },
    test_label = "MOD\nspeed\nup",
    description = "Increases projectile speed.",
}

Cards.MOD_SPEED_DOWN = {
    id = "MOD_SPEED_DOWN",
    type = "modifier",
    max_uses = -1,
    mana_cost = 3,
    speed_modifier = -2,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    tags = { "Debuff" },
    test_label = "MOD\nspeed\ndown",
    description = "Decreases projectile speed.",
}

Cards.MOD_REDUCE_SPREAD = {
    id = "MOD_REDUCE_SPREAD",
    type = "modifier",
    max_uses = -1,
    mana_cost = 4,
    spread_modifier = -4,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    tags = { "Buff", "Projectile" },
    test_label = "MOD\nreduce\nspread",
    description = "Improves accuracy by reducing spread.",
}

Cards.MOD_DAMAGE_UP = {
    id = "MOD_DAMAGE_UP",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    damage_modifier = 10,
    critical_hit_chance_modifier = 5,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 2,
    tags = { "Buff", "Brute" },
    test_label = "MOD\ndamage\nup",
    sprite = "mod-damage-up.png",
    description = "Increases damage and critical hit chance.",
}

Cards.MOD_SHORT_LIFETIME = {
    id = "MOD_SHORT_LIFETIME",
    type = "modifier",
    max_uses = -1,
    mana_cost = 2,
    lifetime_modifier = -1,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    tags = { "Debuff" },
    test_label = "MOD\nshort\nlifetime",
    description = "Reduces projectile lifetime.",
}

Cards.MOD_TRIGGER_ON_HIT = {
    id = "MOD_TRIGGER_ON_HIT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    trigger_on_collision = true,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 1,
    tags = { "Arcane" },
    test_label = "MOD\ntrigger\non\nhit",
    sprite = "mod-trigger-on-hit.png",
    description = "Casts wrapped spells when projectile hits.",
}

Cards.MOD_TRIGGER_TIMER = {
    id = "MOD_TRIGGER_TIMER",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    timer_ms = 1000,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 1,
    tags = { "Arcane" },
    test_label = "MOD\ntrigger\ntimer",
    sprite = "mod-trigger-on-timer.png",
    description = "Casts wrapped spells after a 1 second delay.",
}

Cards.MOD_TRIGGER_ON_DEATH = {
    id = "MOD_TRIGGER_ON_DEATH",
    type = "modifier",
    max_uses = -1,
    mana_cost = 9,
    trigger_on_death = true,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 1,
    tags = { "Arcane", "Void" },
    test_label = "MOD\ntrigger\non\ndeath",
    description = "Casts wrapped spells when projectile expires.",
}

Cards.MULTI_DOUBLE_CAST = {
    id = "MULTI_DOUBLE_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    multicast_count = 2,
    weight = 2,
    tags = { "Arcane" },
    test_label = "MULTI\ndouble\ncast",
    sprite = "mod-multi-double-cast.png",
    description = "Casts the next spell twice simultaneously.",
}

Cards.MULTI_TRIPLE_CAST = {
    id = "MULTI_TRIPLE_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    multicast_count = 3,
    weight = 3,
    tags = { "Arcane" },
    test_label = "MULTI\ntriple\ncast",
    description = "Casts the next spell three times.",
}

Cards.MULTI_CIRCLE_FIVE_CAST = {
    id = "MULTI_CIRCLE_FIVE_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 20,
    multicast_count = 5,
    circular_pattern = true,
    weight = 4,
    tags = { "Arcane", "AoE" },
    test_label = "MULTI\ncircle\nfive\ncast",
    description = "Casts 5 projectiles in a circular pattern.",
}

Cards.UTIL_TELEPORT_TO_IMPACT = {
    id = "UTIL_TELEPORT_TO_IMPACT",
    type = "action",
    max_uses = -1,
    mana_cost = 10,
    cast_delay = 0,
    recharge_time = 0,
    teleport_to_impact = true,
    weight = 3,
    tags = { "Mobility", "Arcane" },
    test_label = "UTIL\nteleport\nto\nimpact",
    sprite = "action-teleport-to-impact.png",
    description = "Teleport to where your projectile lands.",
}

Cards.UTIL_HEAL_AREA = {
    id = "UTIL_HEAL_AREA",
    type = "action",
    max_uses = -1,
    mana_cost = 12,
    heal_amount = 25,
    radius_of_effect = 80,
    cast_delay = 100,
    recharge_time = 0,
    weight = 2,
    tags = { "Buff", "AoE", "Holy" },
    test_label = "UTIL\nheal\narea",
    sprite = "action-heal-area.png",
    description = "Creates a healing zone for allies.",
}

Cards.UTIL_SHIELD_BUBBLE = {
    id = "UTIL_SHIELD_BUBBLE",
    type = "action",
    max_uses = -1,
    mana_cost = 15,
    shield_strength = 50,
    radius_of_effect = 60,
    cast_delay = 150,
    recharge_time = 0,
    weight = 3,
    tags = { "Defense", "Buff", "AoE" },
    test_label = "UTIL\nshield\nbubble",
    sprite = "action-shield-bubble.png",
    description = "Generates a protective shield bubble.",
}

Cards.UTIL_SUMMON_ALLY = {
    id = "UTIL_SUMMON_ALLY",
    type = "action",
    max_uses = 3,
    mana_cost = 20,
    summon_entity = "ally_basic",
    cast_delay = 200,
    recharge_time = 0,
    weight = 4,
    tags = { "Summon" },
    test_label = "UTIL\nsummon\nally",
    description = "Summons a friendly unit to fight for you.",
}

Cards.META_RECAST_FIRST = {
    id = "META_RECAST_FIRST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    recast_first_spell = true,
    multicast_count = 1,
    weight = 3,
    tags = { "Arcane" },
    test_label = "META\nrecast\nfirst",
    description = "Recasts the first spell in your wand.",
}

Cards.META_APPLY_ALL_MODS_NEXT = {
    id = "META_APPLY_ALL_MODS_NEXT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 12,
    apply_all_mods_next = true,
    multicast_count = 1,
    weight = 3,
    tags = { "Arcane" },
    test_label = "META\napply\nall\nmods\nnext",
    description = "Applies all modifiers to the next action.",
}

Cards.META_CAST_ALL_AT_ONCE = {
    id = "META_CAST_ALL_AT_ONCE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 25,
    cast_all_spells = true,
    multicast_count = 999,
    weight = 5,
    tags = { "Arcane" },
    test_label = "META\ncast\nall\nat\nonce",
    description = "Casts all remaining spells simultaneously.",
}

Cards.META_CONVERT_WEIGHT_TO_DAMAGE = {
    id = "META_CONVERT_WEIGHT_TO_DAMAGE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    convert_weight_to_damage = true,
    multicast_count = 1,
    weight = 3,
    tags = { "Arcane", "Brute" },
    test_label = "META\nconvert\nweight\nto\ndamage",
    description = "Converts spell weight into bonus damage.",
}

Cards.ACTION_ADD_MANA = {
    id = "ACTION_ADD_MANA",
    type = "action",
    max_uses = -1,
    mana_cost = 20,
    add_mana_amount = 25,
    cast_delay = 100,
    recharge_time = 0,
    weight = 3,
    tags = { "Arcane", "Buff" },
    test_label = "ACTION\nadd\nmana",
    sprite = "action-add-mana.png",
    description = "Permanently increases your wand's max mana.",
}

Cards.ACTION_BOUNCE_BALL = {
    id = "ACTION_BOUNCE_BALL",
    type = "action",
    max_uses = -1,
    mana_cost = 10,
    damage = 15,
    damage_type = "physical",
    ricochet_count = 3,
    projectile_speed = 450,
    lifetime = 2500,
    cast_delay = 120,
    recharge_time = 0,
    weight = 2,
    tags = { "Projectile" },
    test_label = "ACTION\nbounce\nball",
    description = "A bouncing projectile that ricochets 3 times.",
}

Cards.ACTION_BOUNCE_TRIGGER = {
    id = "ACTION_BOUNCE_TRIGGER",
    type = "action",
    max_uses = -1,
    mana_cost = 15,
    damage = 15,
    damage_type = "physical",
    ricochet_count = 3,
    trigger_on_collision = true,
    projectile_speed = 450,
    lifetime = 2500,
    cast_delay = 150,
    recharge_time = 0,
    weight = 3,
    tags = { "Projectile", "Arcane" },
    test_label = "ACTION\nbounce\ntrigger",
    sprite = "action-bounce-trigger.png",
    description = "Bouncing projectile that triggers spells on each hit.",
}

Cards.ACTION_SPIKE_HAZARD_TIMER = {
    id = "ACTION_SPIKE_HAZARD_TIMER",
    type = "action",
    max_uses = -1,
    mana_cost = 18,
    damage = 25,
    damage_type = "physical",
    radius_of_effect = 50,
    timer_ms = 2000,
    leave_hazard = true,
    trigger_on_timer = true,
    cast_delay = 200,
    recharge_time = 0,
    weight = 3,
    tags = { "Hazard", "AoE" },
    test_label = "ACTION\nspike\nhazard\ntimer",
    description = "Leaves a damaging hazard that triggers after delay.",
}

Cards.ACTION_FLYING_CROSS = {
    id = "ACTION_FLYING_CROSS",
    type = "action",
    max_uses = -1,
    mana_cost = 20,
    damage = 30,
    damage_type = "holy",
    cross_projectile = true,
    projectile_speed = 600,
    lifetime = 2000,
    cast_delay = 150,
    recharge_time = 0,
    weight = 4,
    tags = { "Holy", "Projectile" },
    test_label = "ACTION\nflying\ncross",
    sprite = "action-flying-cross.png",
    description = "A holy cross projectile that pierces enemies.",
}

Cards.ACTION_TELEPORT_BOLT = {
    id = "ACTION_TELEPORT_BOLT",
    type = "action",
    max_uses = -1,
    mana_cost = 25,
    damage = 15,
    damage_type = "arcane",
    projectile_speed = 700,
    lifetime = 1800,
    trigger_on_collision = true,
    teleport_on_hit = true,
    cast_delay = 150,
    recharge_time = 0,
    weight = 4,
    tags = { "Arcane", "Projectile", "Mobility" },
    test_label = "ACTION\nteleport\nbolt",
    sprite = "action-teleport-bolt.png",
    description = "Bolt that teleports you to its impact location.",
}

Cards.ACTION_PROJECTILE_TIMER_CAST = {
    id = "ACTION_PROJECTILE_TIMER_CAST",
    type = "action",
    max_uses = -1,
    mana_cost = 10,
    damage = 10,
    damage_type = "physical",
    projectile_speed = 500,
    lifetime = 2000,
    timer_ms = 1500,
    trigger_on_timer = true,
    cast_delay = 120,
    recharge_time = 0,
    weight = 2,
    tags = { "Projectile", "Arcane" },
    test_label = "ACTION\nprojectile\ntimer\ncast",
    sprite = "action-projectile-timer-cast.png",
    description = "Projectile that casts another spell after 1.5s.",
}

Cards.ACTION_SUMMON_MINION = {
    id = "ACTION_SUMMON_MINION",
    type = "action",
    max_uses = 3,
    mana_cost = 25,
    summon_entity = "minion_basic",
    summon_ai_behavior = "wander_attack",
    cast_delay = 200,
    recharge_time = 0,
    weight = 4,
    tags = { "Summon" },
    test_label = "ACTION\nsummon\nminion",
    description = "Summons a wandering minion that attacks enemies.",
}


Cards.MOD_DOUBLE_SPELL = {
    id = "MOD_DOUBLE_SPELL",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    multicast_count = 2,
    weight = 2,
    tags = { "Arcane" },
    test_label = "MOD\ndouble\nspell",
    description = "Casts the next spell twice.",
}

Cards.MOD_TRIPLE_SPELL = {
    id = "MOD_TRIPLE_SPELL",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    multicast_count = 3,
    weight = 3,
    tags = { "Arcane" },
    test_label = "MOD\ntriple\nspell",
    description = "Casts the next spell three times.",
}

Cards.MOD_FORCE_CRIT = {
    id = "MOD_FORCE_CRIT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    force_crit_next = true,
    multicast_count = 1,
    weight = 2,
    tags = { "Buff", "Brute" },
    test_label = "MOD\nforce\ncrit",
    sprite = "mod-force-crit.png",
    description = "Guarantees the next spell is a critical hit.",
}

Cards.MOD_BIG_SLOW = {
    id = "MOD_BIG_SLOW",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    size_multiplier = 2.0,
    speed_modifier = -3,
    weight = 2,
    tags = { "Brute", "Projectile" },
    test_label = "MOD\nbig\nslow",
    sprite = "mod-big-slow.png",
    description = "Doubles size but reduces speed.",
}

Cards.MOD_IMMUNE_AND_ADD_CARD = {
    id = "MOD_IMMUNE_AND_ADD_CARD",
    type = "modifier",
    max_uses = -1,
    mana_cost = 12,
    immunity_duration_ms = 2000,
    add_cards_to_block = 1,
    weight = 3,
    tags = { "Defense", "Buff" },
    test_label = "MOD\nimmune\n+1card",
    description = "Grants brief immunity and adds a card to cast.",
}

Cards.MOD_HEAL_ON_HIT = {
    id = "MOD_HEAL_ON_HIT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    heal_on_hit = 10,
    weight = 2,
    tags = { "Buff", "Holy" },
    test_label = "MOD\nheal\non\nhit",
    sprite = "mod-heal-on-hit.png",
    description = "Heals you when projectile hits an enemy.",
}

Cards.MOD_RANDOM_MODIFIER = {
    id = "MOD_RANDOM_MODIFIER",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    cast_random_modifier = true,
    weight = 3,
    tags = { "Arcane" },
    test_label = "MOD\nrandom\nmodifier",
    description = "Applies a random modifier from your wand.",
}

Cards.MOD_AUTO_AIM = {
    id = "MOD_AUTO_AIM",
    type = "modifier",
    max_uses = -1,
    mana_cost = 7,
    auto_aim = true,
    weight = 2,
    tags = { "Arcane", "Projectile" },
    test_label = "MOD\nauto\naim",
    description = "Projectiles automatically target nearest enemy.",
}

Cards.MOD_HOMING = {
    id = "MOD_HOMING",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    homing_strength = 10,
    weight = 2,
    tags = { "Arcane", "Projectile" },
    test_label = "MOD\nhoming",
    sprite = "mod-homing.png",
    description = "Projectiles track toward enemies.",
}

Cards.MOD_EXPLOSIVE = {
    id = "MOD_EXPLOSIVE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    make_explosive = true,
    radius_of_effect = 60,
    weight = 3,
    tags = { "Fire", "AoE" },
    test_label = "MOD\nexplosive",
    sprite = "mod-explosive.png",
    description = "Adds explosion on impact.",
}

Cards.MOD_PHASE_SLOW = {
    id = "MOD_PHASE_SLOW",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    phase_in_out = true,
    speed_modifier = -3,
    weight = 2,
    tags = { "Arcane", "Void" },
    test_label = "MOD\nphase\nslow",
    description = "Projectile phases in and out of reality.",
}

Cards.MOD_LONG_CAST = {
    id = "MOD_LONG_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 9,
    long_distance_cast = true,
    weight = 3,
    tags = { "Arcane", "Projectile" },
    test_label = "MOD\nlong\ndistance\ncast",
    description = "Casts from a greater distance.",
}

Cards.MOD_TELEPORT_CAST = {
    id = "MOD_TELEPORT_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 12,
    teleport_cast_from_enemy = true,
    weight = 3,
    tags = { "Arcane", "Mobility" },
    test_label = "MOD\nteleport\ncast",
    description = "Casts from the nearest enemy's location.",
}

Cards.MOD_CAST_FROM_EVENT = {
    id = "MOD_CAST_FROM_EVENT",
    type = "modifier",
    sprite = "mod-cast-from-event.png",
    max_uses = -1,
    mana_cost = 5,
    cast_from_event = true,
    weight = 3,
    tags = { "Arcane" },
    description = "Spells originate from the trigger location.",
    test_label = "MOD\ncast\nfrom\nevent",
}

Cards.MOD_BLOOD_TO_DAMAGE = {
    id = "MOD_BLOOD_TO_DAMAGE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 0,
    health_sacrifice_ratio = 0.1,
    damage_bonus_ratio = 0.5,
    weight = 4,
    tags = { "Brute", "Void" },
    test_label = "MOD\nblood\nto\ndamage",
    sprite = "mod-blood-to-damage.png",
    description = "Sacrifice health for bonus damage.",
}

Cards.MOD_WAND_REFRESH = {
    id = "MOD_WAND_REFRESH",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    wand_refresh = true,
    weight = 3,
    tags = { "Arcane" },
    test_label = "MOD\nwand\nrefresh",
    description = "Immediately recharges your wand.",
}


-- Trigger Cards (for Wands)
local TriggerCards = {}

TriggerCards.TEST_TRIGGER_EVERY_N_SECONDS = {
    id = "every_N_seconds",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = {},
    description = "Casts spells automatically every few seconds",
    trigger_type = "time",
    trigger_interval = 2000,
    test_label = "TRIGGER\nevery\nN\nseconds",
    sprite = "trigger-every-5.png",
}

TriggerCards.TRIGGER_ON_KILL = {
    id = "enemy_killed",                    -- Must match event name in wand_triggers.lua
    type = "trigger",                  -- Required: identifies as trigger card
    max_uses = -1,                     -- -1 = infinite uses
    mana_cost = 0,                     -- Triggers typically cost no mana
    weight = 0,                        -- 0 = not in random pools
    tags = { "Combat" },               -- Tags for joker synergies
    description = "Casts spells when you kill an enemy.",
    trigger_type = "kill",             -- For UI categorization
    test_label = "TRIGGER\non\nkill",  -- Display label
    sprite = "trigger-on-kill.png",    -- Visual
}

TriggerCards.TEST_TRIGGER_ON_BUMP_ENEMY = {
    id = "on_bump_enemy",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = { "Brute" },
    description = "Casts spells when you collide with an enemy",
    trigger_type = "collision",
    test_label = "TRIGGER\non\nbump\nenemy",
    sprite = "trigger-on-bump.png",
}

TriggerCards.TEST_TRIGGER_ON_DASH = {
    id = "on_dash",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = { "Mobility" },
    description = "Casts spells when you dash",
    trigger_type = "dash",
    test_label = "TRIGGER\non\ndash",
    sprite = "trigger-on-dash.png",
}

TriggerCards.TEST_TRIGGER_ON_DISTANCE_TRAVELED = {
    id = "on_distance_traveled",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = { "Mobility" },
    description = "Casts spells after traveling a certain distance",
    trigger_type = "movement",
    trigger_distance = 200,
    test_label = "TRIGGER\non\ndistance\ntraveled",
    sprite = "trigger-on-distance-travelled.png",
}

Cards.SPARK_BOLT = {
    id = "SPARK_BOLT",
    type = "action",
    mana_cost = 5,
    damage = 3,
    projectile_speed = 800,
    lifetime = 0.67,
    cast_delay = 50,
    spread_angle = -1,
    critical_hit_chance = 5,
    tags = { "Projectile", "Arcane" },
    description = "A weak but enchanting sparkling projectile",
}

Cards.BOUNCING_BURST = {
    id = "BOUNCING_BURST",
    type = "action",
    mana_cost = 5,
    damage = 3,
    projectile_speed = 700,
    lifetime = 12.5,
    cast_delay = -30,
    ricochet_count = 10,
    spread_angle = -1,
    tags = { "Projectile" },
    description = "A bouncing projectile with long lifetime",
}

Cards.BOMB = {
    id = "BOMB",
    type = "action",
    max_uses = 3,
    mana_cost = 25,
    damage = 125,
    radius_of_effect = 60,
    projectile_speed = 60,
    lifetime = 3.0,
    cast_delay = 1670,
    gravity_affected = true,
    friendly_fire = true,
    tags = { "AoE", "Brute" },
    description = "An explosive bomb affected by gravity",
}

Cards.TELEPORT_BOLT = {
    id = "TELEPORT_BOLT",
    type = "action",
    mana_cost = 40,
    projectile_speed = 800,
    lifetime = 2.0,
    cast_delay = 50,
    teleport_on_hit = true,
    tags = { "Mobility", "Arcane" },
    description = "Teleports you to where the bolt lands",
}

Cards.FORMATION_PENTAGON = {
    id = "FORMATION_PENTAGON",
    type = "modifier",
    mana_cost = 5,
    formation = "pentagon",
    tags = { "Arcane", "AoE" },
    description = "Casts in 5 directions",
}

Cards.FORMATION_HEXAGON = {
    id = "FORMATION_HEXAGON",
    type = "modifier",
    mana_cost = 6,
    formation = "hexagon",
    tags = { "Arcane", "AoE" },
    description = "Casts in 6 directions",
}

Cards.FORMATION_BEHIND_BACK = {
    id = "FORMATION_BEHIND_BACK",
    type = "modifier",
    mana_cost = 0,
    formation = "behind_back",
    tags = { "Defense" },
    description = "Also casts behind you",
}

Cards.MOD_BOOMERANG = {
    id = "MOD_BOOMERANG",
    type = "modifier",
    mana_cost = 10,
    movement_type = "boomerang",
    tags = { "Projectile" },
    description = "Projectile returns to caster",
}

Cards.MOD_SPIRAL_ARC = {
    id = "MOD_SPIRAL_ARC",
    type = "modifier",
    mana_cost = 0,
    cast_delay = -100,
    lifetime_modifier = 50,
    movement_type = "spiral",
    tags = { "Projectile" },
    description = "Spiraling corkscrew path",
}

Cards.DIVIDE_BY_2 = {
    id = "DIVIDE_BY_2",
    type = "modifier",
    mana_cost = 35,
    cast_delay = 330,
    divide_count = 2,
    divide_damage_multiplier = 0.6,
    tags = { "Arcane" },
    description = "Splits the next spell into 2 weaker copies",
}

Cards.DIVIDE_BY_4 = {
    id = "DIVIDE_BY_4",
    type = "modifier",
    mana_cost = 70,
    cast_delay = 830,
    divide_count = 4,
    divide_damage_multiplier = 0.4,
    tags = { "Arcane" },
    description = "Splits the next spell into 4 weaker copies",
}

Cards.PIERCING_SHOT = {
    id = "PIERCING_SHOT",
    type = "modifier",
    mana_cost = 20,
    pierce_count = 3,
    friendly_fire = true,
    tags = { "Projectile", "Brute" },
    description = "Pierces enemies but can hurt you",
}

Cards.LIGHTNING_BOLT = {
    id = "LIGHTNING_BOLT",
    type = "action",
    mana_cost = 60,
    damage = 25,
    damage_type = "lightning",
    projectile_speed = 2000,
    lifetime = 0.5,
    friendly_fire = true,
    tags = { "Projectile", "Lightning" },
    description = "Extremely fast lightning. Can hurt you!",
}

local ContentDefaults = require("data.content_defaults")

for key, card in pairs(Cards) do
    Cards[key] = ContentDefaults.apply_card_defaults(card)
end

for key, card in pairs(TriggerCards) do
    TriggerCards[key] = ContentDefaults.apply_card_defaults(card)
end

--- Get localized trigger description by trigger_type (call at runtime when localization is ready)
--- @param triggerType string The trigger type (e.g., "time", "collision", "dash", "movement")
--- @return string The localized description or fallback English description
local function getLocalizedTriggerDescription(triggerType)
    local typeToKey = {
        time = "timer",
        collision = "collision",
        dash = "dash",
        movement = "distance"
    }
    local locKey = typeToKey[triggerType] or triggerType
    -- Find the default description from one of the trigger cards
    local fallback = ""
    for _, card in pairs(TriggerCards) do
        if card.trigger_type == triggerType and card.description then
            fallback = card.description
            break
        end
    end
    return L("card.trigger." .. locKey, fallback)
end

return {
    Cards = Cards,
    TriggerCards = TriggerCards,
    getLocalizedTriggerDescription = getLocalizedTriggerDescription
}
