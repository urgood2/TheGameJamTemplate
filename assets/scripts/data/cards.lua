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
    -- Required fields
    id = "MY_FIREBALL",              -- Must match table key
    type = "action",                  -- "action", "modifier", or "trigger"
    mana_cost = 12,
    tags = { "Fire", "Projectile" },
    test_label = "MY\nfireball",     -- Display label (use \n for line breaks)
    -- sprite = "fireball_icon",     -- Optional: custom sprite (default: sample_card.png)

    -- Action-specific fields (omit defaults from content_defaults.lua)
    damage = 25,
    damage_type = "fire",            -- fire/ice/lightning/poison/arcane/holy/void/magic/physical
    projectile_speed = 400,
    lifetime = 2000,                 -- ms
    radius_of_effect = 50,           -- AoE radius (default: 0 = no AoE)

    -- Fields with default 0 are omitted (spread_angle, cast_delay, homing_strength, ricochet_count)
}

-- Action Cards
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
}

-- Modifier Cards
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
}

-- Action Cards
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

    -- Mark application
    apply_mark = "static_charge",
    mark_stacks = 1,

    tags = { "Lightning", "Debuff" },
    test_label = "STATIC\nCHARGE",
    sprite = "action-chain-lightning.png",  -- TODO: replace with action-static-charge.png
}

-- Defensive counter: applies shield mark to self
Cards.ACTION_STATIC_SHIELD = {
    id = "ACTION_STATIC_SHIELD",
    type = "action",
    mana_cost = 8,
    cast_delay = 50,

    -- Self-applied defensive mark
    apply_to_self = "static_shield",
    self_mark_stacks = 1,

    tags = { "Lightning", "Defense" },
    test_label = "STATIC\nSHIELD",
    sprite = "action-chain-lightning.png",  -- TODO: replace with action-static-shield.png
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
}

-- Modifier Cards
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
}

-- Multicasts
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
}

-- Utility Cards
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
}

-- Meta / Super Recasts
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
}

-- Add max mana to wand
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
}

-- Ball that bounces 3 times
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
}

-- Ball that bounces 3 times and casts another spell on hit
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
}

-- Leave spike hazard, cast another spell after X seconds
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
}

-- Flying cross projectile
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
}

-- Bolt that teleports you to target location on hit
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
}

-- Basic projectile that launches another spell after timer
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
}

-- Summon minion that wanders and attacks
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
}


-- Double spell
Cards.MOD_DOUBLE_SPELL = {
    id = "MOD_DOUBLE_SPELL",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    multicast_count = 2,
    weight = 2,
    tags = { "Arcane" },
    test_label = "MOD\ndouble\nspell",
}

-- Triple spell
Cards.MOD_TRIPLE_SPELL = {
    id = "MOD_TRIPLE_SPELL",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    multicast_count = 3,
    weight = 3,
    tags = { "Arcane" },
    test_label = "MOD\ntriple\nspell",
}

-- Make next spell crit
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
}

-- Greatly increase size but reduce speed
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
}

-- Immunity + add 1 card to cast block
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
}

-- Heal player if projectile hits
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
}

-- Cast random modifier from wand
Cards.MOD_RANDOM_MODIFIER = {
    id = "MOD_RANDOM_MODIFIER",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    cast_random_modifier = true,
    weight = 3,
    tags = { "Arcane" },
    test_label = "MOD\nrandom\nmodifier",
}

-- Auto-aim nearest enemy
Cards.MOD_AUTO_AIM = {
    id = "MOD_AUTO_AIM",
    type = "modifier",
    max_uses = -1,
    mana_cost = 7,
    auto_aim = true,
    weight = 2,
    tags = { "Arcane", "Projectile" },
    test_label = "MOD\nauto\naim",
}

-- Homing projectile
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
}

-- Explosive projectile
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
}

-- Slow phasing projectile
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
}

-- Long-distance cast
Cards.MOD_LONG_CAST = {
    id = "MOD_LONG_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 9,
    long_distance_cast = true,
    weight = 3,
    tags = { "Arcane", "Projectile" },
    test_label = "MOD\nlong\ndistance\ncast",
}

-- Teleporting cast (from nearest enemy)
Cards.MOD_TELEPORT_CAST = {
    id = "MOD_TELEPORT_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 12,
    teleport_cast_from_enemy = true,
    weight = 3,
    tags = { "Arcane", "Mobility" },
    test_label = "MOD\nteleport\ncast",
}

-- Blood to damage (sacrifice health)
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
}

-- Wand refresh
Cards.MOD_WAND_REFRESH = {
    id = "MOD_WAND_REFRESH",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    wand_refresh = true,
    weight = 3,
    tags = { "Arcane" },
    test_label = "MOD\nwand\nrefresh",
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

-- Apply defaults to all cards at load time
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
