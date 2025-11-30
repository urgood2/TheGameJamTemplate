local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script

--[[
================================================================================
NOITA-STYLE WAND CASTING SYSTEM
================================================================================
This system simulates Noita's wand mechanics with:
- Trigger slots (wands) with configurable properties
- Action cards (projectiles with various behaviors)
- Modifier cards (damage boosts, multicasts, etc.)
- Always-cast mechanics
- Recursive cast blocks (timers/collision triggers)
- Weight-based overload penalties
================================================================================
]]


-- testing out how noita wand-like eval order would work for cards.

-- trigger slots have:
-- 1. shuffle
-- 2. action cards per cast (cast block size)
-- 3. cast delay (time between spells within cast blocks)
-- 4. recharge time (time to recharge trigger after all cast blocks are done)
-- 5. number of cards total (a numerical slot limit)
-- 6. local mana maximum.
-- 7. local mana recharge rate.
-- 8. random projectile spread angle.
-- 9. "always cast" modifiers. Just an action card/modifier card that always gets included into each cast block.


-- individual cards have:
-- 1. Max use. May be infinite.
-- 2. Mana cost.
-- 3. Damage number and type.
-- 4. Radius of effect, if applicable.
-- 5. Random spread angle, determines accuracy.
-- 6. Speed of projectile, if applicable.
-- 7. Lifetime, how long the projectile will live.
-- 8. Cast delay, which is added to the wand's cast delay after this card is cast.
-- 9. Recharge time, which is added to the wand's total recharge time.
-- 10. Spread modifier, which is added to the wand's spread angle.
-- 11. Speed modifier, which is added to this card's projectile speed.
-- 12. Lifetime modifier, which is added to this card's lifetime.
-- 13. Critical hit chance modifier, if applicable.


-- types of cards:
-- 1. trigger cards (used for trigger slots or "wands")
-- 2. action cards (discrete actions, e.g. shoot projectile, heal, buff, debuff, etc). Some action cards will branch off and make additional cast blocks (e.g., arrow with trigger will trigger a new cast block after it upon collision, and arrow with timer will do the same thing, but after a set time). This will not extend the current cast block, but will rather run as a separate cast block, in parallel.
-- 3. modifier cards (modify other cards, e.g. increase damage, increase speed, add status effect, etc). Utility cards, multicast cards, etc. are all in this category, and they just differ in how many cards they modify. If they modify more than one, they will potentially extend the current cast block. Along with action cards that branch off, these can "wrap around" the trigger slots if not enough cards are present to fill the cast block. Modifiers apply to the entire cast block, rather than just the next spell. If the next spell is a cast block (maybe it's a multicast, followed by actions), then the modifier applies to all spells in that cast block.

-- other implementation details to test:
-- 1. "always cast" cards that are always included in each cast block.
-- 2. card shuffling before each full rotation, if the trigger has shuffle enabled.
-- 3. handling of insufficient mana in the trigger's local mana pool.
-- 4. handling of max uses for cards.
-- 5. cast delay and recharge time from cards should add to the trigger's base cast delay and recharge time.



--------------------------------------------------------------------------------
-- CARD DEFINITIONS
--------------------------------------------------------------------------------

local CardTemplates = {}

-- Action Cards
CardTemplates.TEST_PROJECTILE = {
    id = "TEST_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 5,
    damage = 10,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 5,
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    weight = 1,
    test_label = "TEST\nprojectile",
}

CardTemplates.TEST_PROJECTILE_TIMER = {
    id = "TEST_PROJECTILE_TIMER",
    type = "action",
    max_uses = -1,
    mana_cost = 8,
    damage = 15,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 3,
    projectile_speed = 400,
    lifetime = 3000,
    cast_delay = 150,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    timer_ms = 1000,
    weight = 2,
    test_label = "TEST\nprojectile\ntimer",
}

CardTemplates.TEST_PROJECTILE_TRIGGER = {
    id = "TEST_PROJECTILE_TRIGGER",
    type = "action",
    max_uses = -1,
    mana_cost = 10,
    damage = 20,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 2,
    projectile_speed = 600,
    lifetime = 2500,
    cast_delay = 200,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    trigger_on_collision = true,
    weight = 2,
    test_label = "TEST\nprojectile\ntrigger",
}

-- Modifier Cards
CardTemplates.TEST_DAMAGE_BOOST = {
    id = "TEST_DAMAGE_BOOST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 3,
    damage_modifier = 5,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    test_label = "TEST\ndamage\nboost",
}

CardTemplates.TEST_MULTICAST_2 = {
    id = "TEST_MULTICAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 7,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 2,
    weight = 2,
    test_label = "TEST\nmulticast",
}

-- Action Cards
CardTemplates.ACTION_BASIC_PROJECTILE = {
    id = "ACTION_BASIC_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 5,
    damage = 10,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 5,
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    weight = 1,
    test_label = "ACTION\nbasic\nprojectile",
}

CardTemplates.ACTION_FAST_ACCURATE_PROJECTILE = {
    id = "ACTION_FAST_ACCURATE_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 6,
    damage = 8,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 1,
    projectile_speed = 800,
    lifetime = 1800,
    cast_delay = 80,
    recharge_time = 0,
    spread_modifier = -4,
    speed_modifier = 3,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 5,
    weight = 1,
    test_label = "ACTION\nfast\naccurate\nprojectile",
}

CardTemplates.ACTION_SLOW_ORB = {
    id = "ACTION_SLOW_ORB",
    type = "action",
    max_uses = -1,
    mana_cost = 8,
    damage = 20,
    damage_type = "magic",
    radius_of_effect = 0,
    spread_angle = 6,
    projectile_speed = 250,
    lifetime = 4000,
    cast_delay = 150,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = -2,
    lifetime_modifier = 1,
    critical_hit_chance_modifier = 0,
    weight = 2,
    test_label = "ACTION\nslow\norb",
}

CardTemplates.ACTION_EXPLOSIVE_FIRE_PROJECTILE = {
    id = "ACTION_EXPLOSIVE_FIRE_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 15,
    damage = 35,
    damage_type = "fire",
    radius_of_effect = 60,
    spread_angle = 3,
    projectile_speed = 400,
    lifetime = 2000,
    cast_delay = 200,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    weight = 3,
    test_label = "ACTION\nexplosive\nfire\nprojectile",
}

CardTemplates.ACTION_RICOCHET_PROJECTILE = {
    id = "ACTION_RICOCHET_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 10,
    damage = 15,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 2,
    projectile_speed = 500,
    lifetime = 2500,
    cast_delay = 120,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    ricochet_count = 3,
    weight = 2,
    test_label = "ACTION\nricochet\nprojectile",
}

CardTemplates.ACTION_HEAVY_OBJECT_PROJECTILE = {
    id = "ACTION_HEAVY_OBJECT_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 12,
    damage = 25,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 4,
    projectile_speed = 200,
    lifetime = 3000,
    cast_delay = 150,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = -3,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    gravity_affected = true,
    weight = 2,
    test_label = "ACTION\nheavy\nobject\nprojectile",
}

CardTemplates.ACTION_VACUUM_PROJECTILE = {
    id = "ACTION_VACUUM_PROJECTILE",
    type = "action",
    max_uses = -1,
    mana_cost = 18,
    damage = 10,
    damage_type = "void",
    radius_of_effect = 100,
    spread_angle = 0,
    projectile_speed = 300,
    lifetime = 2500,
    cast_delay = 200,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    suction_strength = 10,
    weight = 3,
    test_label = "ACTION\nvacuum\nprojectile",
}

-- Modifier Cards
CardTemplates.MOD_SEEKING = {
    id = "MOD_SEEKING",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    damage_modifier = 0,
    seek_strength = 8,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 2,
    test_label = "MOD\nseeking",
}

CardTemplates.MOD_SPEED_UP = {
    id = "MOD_SPEED_UP",
    type = "modifier",
    max_uses = -1,
    mana_cost = 4,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 3,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    test_label = "MOD\nspeed\nup",
}

CardTemplates.MOD_SPEED_DOWN = {
    id = "MOD_SPEED_DOWN",
    type = "modifier",
    max_uses = -1,
    mana_cost = 3,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = -2,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    test_label = "MOD\nspeed\ndown",
}

CardTemplates.MOD_REDUCE_SPREAD = {
    id = "MOD_REDUCE_SPREAD",
    type = "modifier",
    max_uses = -1,
    mana_cost = 4,
    damage_modifier = 0,
    spread_modifier = -4,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    test_label = "MOD\nreduce\nspread",
}

CardTemplates.MOD_DAMAGE_UP = {
    id = "MOD_DAMAGE_UP",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    damage_modifier = 10,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 5,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 2,
    test_label = "MOD\ndamage\nup",
}

CardTemplates.MOD_SHORT_LIFETIME = {
    id = "MOD_SHORT_LIFETIME",
    type = "modifier",
    max_uses = -1,
    mana_cost = 2,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = -1,
    critical_hit_chance_modifier = 0,
    multicast_count = 1,
    weight = 1,
    revisit_limit = 2,
    test_label = "MOD\nshort\nlifetime",
}

CardTemplates.MOD_TRIGGER_ON_HIT = {
    id = "MOD_TRIGGER_ON_HIT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    trigger_on_collision = true,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 1,
    test_label = "MOD\ntrigger\non\nhit",
}

CardTemplates.MOD_TRIGGER_TIMER = {
    id = "MOD_TRIGGER_TIMER",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    timer_ms = 1000,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 1,
    test_label = "MOD\ntrigger\ntimer",
}

CardTemplates.MOD_TRIGGER_ON_DEATH = {
    id = "MOD_TRIGGER_ON_DEATH",
    type = "modifier",
    max_uses = -1,
    mana_cost = 9,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    trigger_on_death = true,
    multicast_count = 1,
    weight = 2,
    revisit_limit = 1,
    test_label = "MOD\ntrigger\non\ndeath",
}

-- Multicasts
CardTemplates.MULTI_DOUBLE_CAST = {
    id = "MULTI_DOUBLE_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 2,
    weight = 2,
    test_label = "MULTI\ndouble\ncast",
}

CardTemplates.MULTI_TRIPLE_CAST = {
    id = "MULTI_TRIPLE_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 3,
    weight = 3,
    test_label = "MULTI\ntriple\ncast",
}

CardTemplates.MULTI_CIRCLE_FIVE_CAST = {
    id = "MULTI_CIRCLE_FIVE_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 20,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 5,
    circular_pattern = true,
    weight = 4,
    test_label = "MULTI\ncircle\nfive\ncast",
}

-- Utility Cards
CardTemplates.UTIL_TELEPORT_TO_IMPACT = {
    id = "UTIL_TELEPORT_TO_IMPACT",
    type = "action",
    max_uses = -1,
    mana_cost = 10,
    cast_delay = 0,
    recharge_time = 0,
    teleport_to_impact = true,
    weight = 3,
    test_label = "UTIL\nteleport\nto\nimpact",
}

CardTemplates.UTIL_HEAL_AREA = {
    id = "UTIL_HEAL_AREA",
    type = "action",
    max_uses = -1,
    mana_cost = 12,
    heal_amount = 25,
    radius_of_effect = 80,
    cast_delay = 100,
    recharge_time = 0,
    weight = 2,
    test_label = "UTIL\nheal\narea",
}

CardTemplates.UTIL_SHIELD_BUBBLE = {
    id = "UTIL_SHIELD_BUBBLE",
    type = "action",
    max_uses = -1,
    mana_cost = 15,
    shield_strength = 50,
    radius_of_effect = 60,
    cast_delay = 150,
    recharge_time = 0,
    weight = 3,
    test_label = "UTIL\nshield\nbubble",
}

CardTemplates.UTIL_SUMMON_ALLY = {
    id = "UTIL_SUMMON_ALLY",
    type = "action",
    max_uses = 3,
    mana_cost = 20,
    summon_entity = "ally_basic",
    cast_delay = 200,
    recharge_time = 0,
    weight = 4,
    test_label = "UTIL\nsummon\nally",
}

-- Meta / Super Recasts
CardTemplates.META_RECAST_FIRST = {
    id = "META_RECAST_FIRST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    recast_first_spell = true,
    multicast_count = 1,
    weight = 3,
    test_label = "META\nrecast\nfirst",
}

CardTemplates.META_APPLY_ALL_MODS_NEXT = {
    id = "META_APPLY_ALL_MODS_NEXT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 12,
    apply_all_mods_next = true,
    multicast_count = 1,
    weight = 3,
    test_label = "META\napply\nall\nmods\nnext",
}

CardTemplates.META_CAST_ALL_AT_ONCE = {
    id = "META_CAST_ALL_AT_ONCE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 25,
    cast_all_spells = true,
    multicast_count = 999,
    weight = 5,
    test_label = "META\ncast\nall\nat\nonce",
}

CardTemplates.META_CONVERT_WEIGHT_TO_DAMAGE = {
    id = "META_CONVERT_WEIGHT_TO_DAMAGE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    convert_weight_to_damage = true,
    multicast_count = 1,
    weight = 3,
    test_label = "META\nconvert\nweight\nto\ndamage",
}

-- Add max mana to wand
CardTemplates.ACTION_ADD_MANA = {
    id = "ACTION_ADD_MANA",
    type = "action",
    max_uses = -1,
    mana_cost = 20,
    add_mana_amount = 25,
    cast_delay = 100,
    recharge_time = 0,
    weight = 3,
    test_label = "ACTION\nadd\nmana",
}

-- Ball that bounces 3 times
CardTemplates.ACTION_BOUNCE_BALL = {
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
    test_label = "ACTION\nbounce\nball",
}

-- Ball that bounces 3 times and casts another spell on hit
CardTemplates.ACTION_BOUNCE_TRIGGER = {
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
    test_label = "ACTION\nbounce\ntrigger",
}

-- Leave spike hazard, cast another spell after X seconds
CardTemplates.ACTION_SPIKE_HAZARD_TIMER = {
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
    test_label = "ACTION\nspike\nhazard\ntimer",
}

-- Flying cross projectile
CardTemplates.ACTION_FLYING_CROSS = {
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
    test_label = "ACTION\nflying\ncross",
}

-- Bolt that teleports you to target location on hit
CardTemplates.ACTION_TELEPORT_BOLT = {
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
    test_label = "ACTION\nteleport\nbolt",
}

-- Basic projectile that launches another spell after timer
CardTemplates.ACTION_PROJECTILE_TIMER_CAST = {
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
    test_label = "ACTION\nprojectile\ntimer\ncast",
}

-- Summon minion that wanders and attacks
CardTemplates.ACTION_SUMMON_MINION = {
    id = "ACTION_SUMMON_MINION",
    type = "action",
    max_uses = 3,
    mana_cost = 25,
    summon_entity = "minion_basic",
    summon_ai_behavior = "wander_attack",
    cast_delay = 200,
    recharge_time = 0,
    weight = 4,
    test_label = "ACTION\nsummon\nminion",
}


-- Double spell
CardTemplates.MOD_DOUBLE_SPELL = {
    id = "MOD_DOUBLE_SPELL",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    multicast_count = 2,
    weight = 2,
    test_label = "MOD\ndouble\nspell",
}

-- Triple spell
CardTemplates.MOD_TRIPLE_SPELL = {
    id = "MOD_TRIPLE_SPELL",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    multicast_count = 3,
    weight = 3,
    test_label = "MOD\ntriple\nspell",
}

-- Make next spell crit
CardTemplates.MOD_FORCE_CRIT = {
    id = "MOD_FORCE_CRIT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    force_crit_next = true,
    multicast_count = 1,
    weight = 2,
    test_label = "MOD\nforce\ncrit",
}

-- Greatly increase size but reduce speed
CardTemplates.MOD_BIG_SLOW = {
    id = "MOD_BIG_SLOW",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    size_multiplier = 2.0,
    speed_modifier = -3,
    weight = 2,
    test_label = "MOD\nbig\nslow",
}

-- Immunity + add 1 card to cast block
CardTemplates.MOD_IMMUNE_AND_ADD_CARD = {
    id = "MOD_IMMUNE_AND_ADD_CARD",
    type = "modifier",
    max_uses = -1,
    mana_cost = 12,
    immunity_duration_ms = 2000,
    add_cards_to_block = 1,
    weight = 3,
    test_label = "MOD\nimmune\n+1card",
}

-- Heal player if projectile hits
CardTemplates.MOD_HEAL_ON_HIT = {
    id = "MOD_HEAL_ON_HIT",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    heal_on_hit = 10,
    weight = 2,
    test_label = "MOD\nheal\non\nhit",
}

-- Cast random modifier from wand
CardTemplates.MOD_RANDOM_MODIFIER = {
    id = "MOD_RANDOM_MODIFIER",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    cast_random_modifier = true,
    weight = 3,
    test_label = "MOD\nrandom\nmodifier",
}

-- Auto-aim nearest enemy
CardTemplates.MOD_AUTO_AIM = {
    id = "MOD_AUTO_AIM",
    type = "modifier",
    max_uses = -1,
    mana_cost = 7,
    auto_aim = true,
    weight = 2,
    test_label = "MOD\nauto\naim",
}

-- Homing projectile
CardTemplates.MOD_HOMING = {
    id = "MOD_HOMING",
    type = "modifier",
    max_uses = -1,
    mana_cost = 6,
    homing_strength = 10,
    weight = 2,
    test_label = "MOD\nhoming",
}

-- Explosive projectile
CardTemplates.MOD_EXPLOSIVE = {
    id = "MOD_EXPLOSIVE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 10,
    make_explosive = true,
    radius_of_effect = 60,
    weight = 3,
    test_label = "MOD\nexplosive",
}

-- Slow phasing projectile
CardTemplates.MOD_PHASE_SLOW = {
    id = "MOD_PHASE_SLOW",
    type = "modifier",
    max_uses = -1,
    mana_cost = 8,
    phase_in_out = true,
    speed_modifier = -3,
    weight = 2,
    test_label = "MOD\nphase\nslow",
}

-- Long-distance cast
CardTemplates.MOD_LONG_CAST = {
    id = "MOD_LONG_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 9,
    long_distance_cast = true,
    weight = 3,
    test_label = "MOD\nlong\ndistance\ncast",
}

-- Teleporting cast (from nearest enemy)
CardTemplates.MOD_TELEPORT_CAST = {
    id = "MOD_TELEPORT_CAST",
    type = "modifier",
    max_uses = -1,
    mana_cost = 12,
    teleport_cast_from_enemy = true,
    weight = 3,
    test_label = "MOD\nteleport\ncast",
}

-- Blood to damage (sacrifice health)
CardTemplates.MOD_BLOOD_TO_DAMAGE = {
    id = "MOD_BLOOD_TO_DAMAGE",
    type = "modifier",
    max_uses = -1,
    mana_cost = 0,
    health_sacrifice_ratio = 0.1,
    damage_bonus_ratio = 0.5,
    weight = 4,
    test_label = "MOD\nblood\nto\ndamage",
}

-- Wand refresh
CardTemplates.MOD_WAND_REFRESH = {
    id = "MOD_WAND_REFRESH",
    type = "modifier",
    max_uses = -1,
    mana_cost = 15,
    wand_refresh = true,
    weight = 3,
    test_label = "MOD\nwand\nrefresh",
}



-- -------------------------------------------------------------------------- --
--             WAND-defining trigger cards that DON't GO IN WANDS             --
-- -------------------------------------------------------------------------- 

TriggerCardTemplates = {}

-- triggers that go inside wands.
TriggerCardTemplates.TEST_TRIGGER_EVERY_N_SECONDS = {
    id = "every_N_seconds",
    type = "trigger", -- ignored by evaluation algo
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    test_label = "TRIGGER\nevery\nN\nseconds",
}

TriggerCardTemplates.TEST_TRIGGER_ON_BUMP_ENEMY = {
    id = "on_bump_enemy",
    type = "trigger", -- ignored by evaluation algo
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    test_label = "TRIGGER\non\nbump\nenemy",
}

TriggerCardTemplates.TEST_TRIGGER_ON_DASH = {
    id = "on_dash",
    type = "trigger", -- ignored by evaluation algo
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    test_label = "TRIGGER\non\ndash",
}

TriggerCardTemplates.TEST_TRIGGER_ON_DISTANCE_TRAVELED = {
    id = "on_distance_traveled",
    type = "trigger", -- ignored by evaluation algo
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    test_label = "TRIGGER\non\ndistance\ntraveled",
}


--------------------------------------------------------------------------------
-- WAND (TRIGGER) DEFINITIONS
--------------------------------------------------------------------------------

local WandTemplates = {
    -- Wand with shuffle 
    {
        id = "TEST_WAND_1",
        type = "trigger",
        max_uses = -1,
        mana_max = 50,
        mana_recharge_rate = 5,
        cast_block_size = 2,
        cast_delay = 200,
        recharge_time = 1000,
        spread_angle = 10,
        shuffle = false,
        total_card_slots = 5,
        always_cast_cards = { },
        
    },

    -- Simple wand with no shuffle or always-cast
    {
        id = "TEST_WAND_2",
        type = "trigger",
        max_uses = -1,
        mana_max = 30,
        mana_recharge_rate = 10,
        cast_block_size = 1,
        cast_delay = 100,
        recharge_time = 500,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 10,
        always_cast_cards = {},
    },
    
    -- Wand with always-cast cards
    {
        id = "TEST_WAND_3",
        type = "trigger",
        max_uses = -1,
        mana_max = 60,
        mana_recharge_rate = 8,
        cast_block_size = 3,
        cast_delay = 150,
        recharge_time = 800,
        spread_angle = 15,
        shuffle = true,
        total_card_slots = 7,
        always_cast_cards = {
            "ACTION_BASIC_PROJECTILE"
        },
    },
    
    -- Wand with low mana and high overload potential
    {
        id = "TEST_WAND_4",
        type = "trigger",
        max_uses = -1,
        mana_max = 20,
        mana_recharge_rate = 4,
        cast_block_size = 2,
        cast_delay = 250,
        recharge_time = 1200,
        spread_angle = 20,
        shuffle = true,
        total_card_slots = 8,
        always_cast_cards = {
            "MOD_DAMAGE_UP",
            "ACTION_FAST_ACCURATE_PROJECTILE"
        },
    },
}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--- Copies card properties from a template to an object
--- @param obj table Destination object
--- @param card_table table Card template
--- @param card_type string|nil Optional type filter
--- @return table The modified object
local function apply_card_properties(obj, card_table, card_type)
    if card_type and card_table.type ~= card_type then
        return obj
    end

    for k, v in pairs(card_table) do
        if k ~= "id" and k ~= "handle" then
            local vtype = type(v)
            if vtype == "number" or vtype == "boolean" or vtype == "string" or vtype == "table" then
                if obj[k] == nil then
                    obj[k] = v
                end
            end
        end
    end

    if not obj.card_id then
        obj.card_id = card_table.id
    end
    if (not obj.cardID or obj.cardID == "unknown") and card_table.id then
        obj.cardID = card_table.id
    end

    return obj
end

--- Creates a card instance from a template
--- @param template table Card template
--- @return table Card instance
local function create_card_from_template(template)
    local card = Node {}
    card:attach_ecs { create_new = true }
    apply_card_properties(card, template)
    return card
end

--- Returns a human-readable card identifier
--- @param card table Card instance
--- @return string Formatted card ID
local function readable_card_id(card)
    return card.card_id .. ":" .. card:handle()
end


--- Copies all key–value pairs from a card definition table into an object.
--- Optionally filters by card type (e.g. "action", "modifier", "trigger").
--- Does not overwrite existing keys on the target unless they are nil.
---
--- @param obj table  The destination object (e.g., a Lua entity or component)
--- @param card_table table  The card definition table (e.g., TEST_PROJECTILE)
--- @param card_type string|nil  Optional. Only apply if card_table.type matches.
--- @return table obj  The same object, now enriched with card properties.
function apply_card_properties(obj, card_table, card_type)
    -- Skip if the card has a type mismatch (when filter is specified)
    if card_type and card_table.type ~= card_type then
        return obj
    end

    -- Copy all numeric, boolean, and string fields
    for k, v in pairs(card_table) do
        -- Avoid copying reserved/meta keys
        if k ~= "id" and k ~= "handle" then
            -- Only copy plain values (avoid functions/metatables)
            local vtype = type(v)
            if vtype == "number" or vtype == "boolean" or vtype == "string" or vtype == "table" then
                if obj[k] == nil then
                    obj[k] = v
                end
            end
        end
    end

    -- Optionally tag it with the card id
    if not obj.card_id then
        obj.card_id = card_table.id
    end
    if (not obj.cardID or obj.cardID == "unknown") and card_table.id then
        obj.cardID = card_table.id
    end

    return obj
end

-- Simulate Noita-like cast block division, with trigger/timer behavior

--==============================================================
-- [OK] simulate_wand (modifier inheritance + global modifier persistence)
--==============================================================
local function simulate_wand(wand, card_pool)
    print("\n=== Simulating " .. wand.id .. " ===")
    
    -- Track execution status of every card
    local card_execution = {}   -- card object -> "unused" | "partial" | "full"

    -- Initialize all cards to unused
    for _, card in ipairs(card_pool) do
        card_execution[card:handle()] = "unused"
    end

    ----------------------------------------------------------------------
    -- [+] Step 1. Build Card Lookup
    ----------------------------------------------------------------------
    local card_lookup = {}
    for _, card in ipairs(card_pool) do
        
        card_lookup[card.card_id] = card
    end

    ----------------------------------------------------------------------
    -- [+] Step 2. Build Deck (store card tables directly)
    ----------------------------------------------------------------------
    local deck = {}
    local max_cards = math.min(wand.total_card_slots, #card_pool)

    for i = 1, max_cards do
        table.insert(deck, card_pool[i])
    end

    -- Shuffle deck if wand has shuffle flag
    if wand.shuffle then
        math.randomseed(os.time())
        for i = #deck, 2, -1 do
            local j = math.random(i)
            deck[i], deck[j] = deck[j], deck[i]
        end
    end

    -- Print deck summary
    print("Deck: {")
    for _, card in ipairs(deck) do
        print(string.format("  %s:%s", card.card_id, card:handle()))
    end
    print("}")
    print(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- [+] Step 3. Calculate Weight / Overload
    ----------------------------------------------------------------------
    local total_weight = 0
    for _, card in ipairs(deck) do
        total_weight = total_weight + (card.weight or 1)
    end

    local overload_ratio = 1.0
    if wand.mana_max and total_weight > wand.mana_max then
        local excess = total_weight - wand.mana_max
        overload_ratio = 1.0 + (excess / wand.mana_max) * 0.5

        print(string.format(
            "[!] Wand overloaded: weight %.1f / %.1f > +%.0f%% cast/recharge delay",
            total_weight, wand.mana_max, (overload_ratio - 1.0) * 100
        ))
    else
        print(string.format(
            "[OK] Wand within weight limit: weight %.1f / %.1f",
            total_weight, wand.mana_max or total_weight
        ))
    end

    print(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- [+] Step 4. Utility Functions
    ----------------------------------------------------------------------
    local function readable_card_id(card)
        return string.format("%s:%s", card.card_id, card:handle())
    end

    ----------------------------------------------------------------------
    -- [+] Step 5. Global Modifier Setup
    ----------------------------------------------------------------------
    local global_active_modifiers = {}

    -- [MODS] Initialize global always-cast modifiers once per wand
    local global_always_modifiers = {}
    if wand.always_cast_cards and #wand.always_cast_cards > 0 then
        for _, always_id in ipairs(wand.always_cast_cards) do
            local always_card = card_lookup[always_id]
            if always_card then
                local mod = {
                    card = always_card,
                    remaining = always_card.multicast_count or 1,
                    persistent_until_chain_end = true,
                }

                print(string.format("  [+] [ALWAYS CAST INIT] '%s' x%d", always_id, mod.remaining))
                table.insert(global_always_modifiers, mod)
            else
                print(string.format("  [!] Missing always-cast card '%s'", always_id))
            end
        end
    end

    ----------------------------------------------------------------------
    -- Helper: deep copy modifiers (used for inheritance)
    ----------------------------------------------------------------------
    local function copy_modifiers(source)
        local result = {}
        for _, m in ipairs(source or {}) do
            table.insert(result, {
                card = m.card,
                remaining = m.remaining,
                persistent_until_chain_end = m.persistent_until_chain_end or false
            })
        end
        return result
    end


    ----------------------------------------------------------------------
    -- Helper: merge inherited + global modifiers
    ----------------------------------------------------------------------
    local function merge_modifiers(inherited_modifiers)
        local merged = copy_modifiers(inherited_modifiers)

        for _, m in ipairs(global_active_modifiers) do
            table.insert(merged, { card = m.card, remaining = m.remaining })
        end
        return merged
    end


    ----------------------------------------------------------------------
    -- Helper: apply modifiers after an action executes
    ----------------------------------------------------------------------
    local function apply_modifiers(indent, modifiers, card)
        for j = #modifiers, 1, -1 do
            local m = modifiers[j]
            print(string.format("%s     |-> under modifier '%s' (%d left)",
                indent, readable_card_id(m.card), m.remaining - 1))

            m.remaining = m.remaining - 1
            if m.remaining <= 0 then
                print(string.format("%s     [-] [MOD EXHAUSTED] '%s' (persists=%s)",
                    indent, readable_card_id(m.card),
                    tostring(m.persistent_until_chain_end)))
                if not m.persistent_until_chain_end then
                    table.remove(modifiers, j)
                end
            end
        end
    end


    ----------------------------------------------------------------------
    -- Helper: spawn sub-cast (timer or trigger)
    ----------------------------------------------------------------------
    local function spawn_sub_cast(i, depth, indent, trigger_card, modifiers, visited_cards)
        -- Trigger cards that spawn a sub-cast are considered "partial" unless executed later.
        if card_execution[trigger_card:handle()] == "unused" then
            card_execution[trigger_card:handle()] = "partial"
        end

        local label = trigger_card.timer_ms
            and string.format("+%dms timer", trigger_card.timer_ms)
            or "on collision"

        print(string.format("%s     |-> Spawning sub-cast (%s)", indent, label))
        print(string.format("%s     └─── [RECURSION TREE] Enter sub-cast (Depth %d -> %d)",
            indent, depth, depth + 1))

        -- Inherit modifiers (minus global duplicates)
        local inherited_copy = copy_modifiers(modifiers)
        for _, m in ipairs(global_always_modifiers) do
            for idx = #inherited_copy, 1, -1 do
                if inherited_copy[idx].card == m.card then
                    table.remove(inherited_copy, idx)
                    break
                end
            end
        end

        -- Recurse
        local sub_block, new_i = build_cast_block(i, depth + 1, inherited_copy, visited_cards, 1, true)
        print(string.format("%s     └─── [RECURSION TREE] Exit sub-cast (Back to Depth %d)", indent, depth))
        print(string.format("%s     [END] Ending block after trigger '%s' (no further actions in this block)",
            indent, readable_card_id(trigger_card)))

        return sub_block, new_i
    end


    ----------------------------------------------------------------------
    -- Helper: handle always-cast cards (run before deck)
    ----------------------------------------------------------------------
    local function handle_always_casts(indent, depth, block, modifiers, visited_cards, i, target_actions)
        if not wand.always_cast_cards or #wand.always_cast_cards == 0 then
            return i, target_actions
        end

        print(string.format("%s  [-] [ALWAYS CAST EXEC] running %d always-cast cards at start",
            indent, #wand.always_cast_cards))

        for _, always_id in ipairs(wand.always_cast_cards) do
            local acard = card_lookup[always_id]
            if not acard then
                print(string.format("%s    [!] Missing always-cast card '%s'", indent, always_id))
                goto continue
            end

            print(string.format("%s    * Executing always-cast '%s'", indent, readable_card_id(acard)))

            if acard.type == "modifier" then
                -- Modifier adds multicast
                local mod = {
                    card = acard,
                    remaining = acard.multicast_count or 1,
                    persistent_until_chain_end = true,
                }

                print(string.format("%s      [+] [ALWAYS MOD OPEN] '%s' x%d",
                    indent, readable_card_id(acard), mod.remaining))

                table.insert(modifiers, mod)
                table.insert(block.applied_modifiers, { card = acard, remaining = mod.remaining })

                -- Expand target size if multicast
                if (acard.multicast_count or 1) > 1 then
                    local extra = (acard.multicast_count - 1)
                    target_actions = target_actions + extra
                    print(string.format("%s     =>> Expanded block target to %d due to multicast (%+d)",
                        indent, target_actions, extra))
                end
            elseif acard.type == "action" then
                print(string.format("%s      [+] [ALWAYS ACTION] '%s'", indent, readable_card_id(acard)))
                table.insert(block.cards, acard)

                block.total_cast_delay = block.total_cast_delay + (acard.cast_delay or 0)
                block.total_recharge   = block.total_recharge + (acard.recharge_time or 0)

                apply_modifiers(indent, modifiers, acard)

                if (acard.timer_ms or acard.trigger_on_collision) then
                    local sub_block
                    sub_block, i = spawn_sub_cast(i, depth, indent, acard, modifiers, visited_cards)
                    table.insert(block.children, {
                        trigger = acard,
                        delay = acard.timer_ms,
                        collision = acard.trigger_on_collision,
                        block = sub_block,
                        recursion_depth = depth + 1,
                    })
                    break
                end
            end

            ::continue::
        end
        return i, target_actions
    end


    ----------------------------------------------------------------------
    -- Helper: process a single card during deck evaluation
    ----------------------------------------------------------------------
    local function process_card(indent, card, modifiers, block, depth, i, visited_cards, target_actions,
                                actions_collected)
        if card.type == "modifier" then
            -- Mark card as fully executed
            card_execution[card:handle()] = "full"
            
            local mod = {
                card = card,
                remaining = card.multicast_count or 1,
                persistent_until_chain_end = true,
            }

            print(string.format("%s  [+] [MOD OPEN] '%s' x%d",
                indent, readable_card_id(card), mod.remaining))

            table.insert(modifiers, mod)
            table.insert(block.applied_modifiers, { card = card, remaining = mod.remaining })

            if (card.multicast_count or 1) > 1 then
                local extra = (card.multicast_count - 1)
                target_actions = target_actions + extra
                print(string.format("%s     =>> Expanded block target to %d due to multicast (%+d)",
                    indent, target_actions, extra))
            end
        elseif card.type == "action" then
            -- Mark card as fully executed
            card_execution[card:handle()] = "full"
            
            actions_collected = actions_collected + 1
            table.insert(block.cards, card)
            
            -- Add cast delay BEFORE updating total
            local cardCastDelay = card.cast_delay or 0
            
            -- Record cumulative delay for this card
            table.insert(block.card_delays, {
                card = card,
                card_index = actions_collected,
                individual_delay = cardCastDelay,
                cumulative_delay = block.total_cast_delay + cardCastDelay,  -- Delay up to and including this card
            })
            
            block.total_cast_delay = block.total_cast_delay + cardCastDelay
            block.total_recharge   = block.total_recharge + (card.recharge_time or 0)

            print(string.format("%s  [+] Action '%s' (%d/%d actions filled)",
                indent, readable_card_id(card), actions_collected, target_actions))

            apply_modifiers(indent, modifiers, card)

            if (card.timer_ms or card.trigger_on_collision) then
                local sub_block
                sub_block, i = spawn_sub_cast(i, depth, indent, card, modifiers, visited_cards)
                table.insert(block.children, {
                    trigger = card,
                    delay = card.timer_ms,
                    collision = card.trigger_on_collision,
                    block = sub_block,
                    recursion_depth = depth + 1,
                })
                return i, target_actions, actions_collected, true
            end
        end

        return i, target_actions, actions_collected, false
    end


    ----------------------------------------------------------------------
    -- Helper: record remaining modifiers at the end
    ----------------------------------------------------------------------
    local function finalize_modifiers(indent, block, modifiers)
        for _, m in ipairs(modifiers) do
            table.insert(block.remaining_modifiers, { card = m.card, remaining = m.remaining })
            print(string.format("%s  [-] [FORCE CLOSE MOD] '%s' (%d unfilled)",
                indent, readable_card_id(m.card), m.remaining))
        end
    end


    ----------------------------------------------------------------------
    -- Main: build_cast_block
    ----------------------------------------------------------------------
    function build_cast_block(start_index, depth, inherited_modifiers, visited_cards, sub_block_override,
                              suppress_always_casts)
        depth = depth or 1
        visited_cards = visited_cards or {}
        local indent = string.rep("  ", depth - 1)

        local block = {
            cards = {},
            children = {},
            applied_modifiers = {},
            remaining_modifiers = {},
            total_cast_delay = 0,
            total_recharge = 0,
            target_override = sub_block_override,
            card_delays = {},  -- Track cumulative delay after each card
        }

        ------------------------------------------------------------
        -- Merge modifiers
        ------------------------------------------------------------
        local modifiers = merge_modifiers(inherited_modifiers)
        for _, m in ipairs(modifiers) do
            table.insert(block.applied_modifiers, { card = m.card, remaining = m.remaining })
        end

        ------------------------------------------------------------
        -- Setup casting parameters
        ------------------------------------------------------------
        local actions_collected = 0
        local i = start_index
        local safety = 0
        local target_actions = block.target_override or wand.cast_block_size or 1

        ------------------------------------------------------------
        -- Handle always-casts
        ------------------------------------------------------------
        if not suppress_always_casts then
            i, target_actions = handle_always_casts(indent, depth, block, modifiers, visited_cards, i, target_actions)
        end

        ------------------------------------------------------------
        -- Begin deck evaluation loop
        ------------------------------------------------------------
        print(string.format("%s[Depth %d] >>> Building cast block starting at %d (target %d actions)",
            indent, depth, start_index, target_actions))

        while actions_collected < target_actions and safety < #deck * 4 do
            safety = safety + 1
            local idx = ((i - 1) % #deck) + 1
            local card = deck[idx]
            
            -- If card is seen but not guaranteed to execute, mark it partial.
            -- process_card(...) will upgrade it to "full" if it actually executes.
            if card_execution[card:handle()] == "unused" then
                card_execution[card:handle()] = "partial"
            end
            
            if not card then break end
            i = i + 1

            -- Visit / recursion guards
            local count = visited_cards[card] or 0
            if count > 0 then
                local limit = card.revisit_limit or 0
                if limit == 0 then
                    print(string.format("%s  [!] Card '%s' already used %dx; halting (no revisit).", indent,
                        readable_card_id(card), count))
                    break
                elseif limit > 0 and count >= limit then
                    print(string.format("%s  [!] Card '%s' revisit limit reached (%d).", indent, readable_card_id(card),
                        limit))
                    break
                else
                    print(string.format("%s  [REV] Revisiting card '%s' (%d/%s)",
                        indent, readable_card_id(card), count + 1,
                        (limit == -1 and "INF" or tostring(limit))))
                end
            end
            visited_cards[card] = count + 1

            if card.allow_recursion and card.recursion_depth and depth > card.recursion_depth then
                print(string.format("%s  [!] Card '%s' recursion depth limit reached (%d).",
                    indent, readable_card_id(card), card.recursion_depth))
                break
            end

            -- Process card
            local sub_ended
            i, target_actions, actions_collected, sub_ended =
                process_card(indent, card, modifiers, block, depth, i, visited_cards, target_actions, actions_collected)

            if sub_ended then break end

            if actions_collected < target_actions then
                print(string.format("%s    ...still need %d more actions to fill block...",
                    indent, target_actions - actions_collected))
            end
        end

        ------------------------------------------------------------
        -- Finalize
        ------------------------------------------------------------
        finalize_modifiers(indent, block, modifiers)
        print(string.format("%s  [OK] Finished block (%d/%d actions) at depth %d",
            indent, #block.cards, target_actions, depth))

        return block, i, block.total_cast_delay, block.total_recharge
    end

    ----------------------------------------------------------------------
    -- Pretty printer helpers
    ----------------------------------------------------------------------

    -- Describes a single card, including type, modifiers, and delays
    local function describe_card(c)
        local desc = readable_card_id(c)

        if c.type == "modifier" then
            desc = desc .. string.format(" (modifier x%d)", c.multicast_count or 1)
        elseif c.type == "action" then
            desc = desc .. " (action)"
            if c.timer_ms then
                desc = desc .. string.format(", delayed trigger +%dms", c.timer_ms)
            elseif c.trigger_on_collision then
                desc = desc .. " (collision trigger)"
            end
        end

        local base_delay = wand.cast_delay or 0
        local total_delay = (base_delay + (c.cast_delay or 0)) * overload_ratio

        return string.format("%s - cast_delay +%dms (total %.1fms w/ overload)",
            desc, c.cast_delay or 0, total_delay)
    end


    -- Prints a list of modifiers with consistent formatting
    local function print_modifiers(indent, modifiers, header, suffix)
        if modifiers and #modifiers > 0 then
            print(indent .. string.format("  %s %d", header, #modifiers))
            for _, m in ipairs(modifiers) do
                print(string.format("%s    * '%s' (%d %s)",
                    indent, m.card.card_id, m.remaining, suffix))
            end
        end
    end


    -- Finds a child block triggered by a specific card (if any)
    local function find_child_for_card(block, card)
        for _, child in ipairs(block.children or {}) do
            if child.trigger == card then
                return child
            end
        end
        return nil
    end


    -- Recursively prints a block and its children
    local function print_block(block, depth, label)
        local indent = string.rep("  ", depth)
        if label then print(indent .. label) end

        -- Modifiers (start and end state)
        print_modifiers(indent, block.applied_modifiers, "[MODS] Applied modifiers at block start:", "left at start")
        print_modifiers(indent, block.remaining_modifiers, "[REM] Remaining modifiers after cast:", "left after")

        -- Cards and sub-blocks
        for _, c in ipairs(block.cards) do
            print(indent .. "  * " .. describe_card(c))

            local child = find_child_for_card(block, c)
            if child then
                local lbl = child.delay
                    and string.format("[TIME] After %dms:", child.delay)
                    or "[COLL] On Collision:"
                print(indent .. "  " .. lbl)
                print_block(child.block, depth + 1)
            end
        end
    end


    ----------------------------------------------------------------------
    -- Summary printer
    ----------------------------------------------------------------------

    local function print_execution_summary(blocks, wand, total_cast_delay, total_recharge_time)
        local line = string.rep("-", 60)
        print(line)

        for idx, block in ipairs(blocks) do
            print(string.format("Cast Block %d:", idx))
            print_block(block, 1)
            print("")
        end

        print(line)
        print(string.format("Wand '%s' Execution Complete", wand.id))
        print(string.format("-> Total Cast Delay: %.1f ms", total_cast_delay))
        print(string.format("-> Total Recharge Time: %.1f ms", total_recharge_time))
        print(string.rep("=", 60))
    end


    ----------------------------------------------------------------------
    -- Execution driver
    ----------------------------------------------------------------------
    -- -----------------------------
    -- Add this local table BEFORE execute_wand(deck)
    -- -----------------------------
    local simulation_result = {
        wand_id = wand.id,

        deck = deck,
        total_cast_delay = 0,
        total_recharge_time = 0,
        blocks = nil,  -- filled in after execution
        total_weight = total_weight,
        overload_ratio = overload_ratio,
        global_always_modifiers = global_always_modifiers,
        card_execution = card_execution,
    }

    -- -----------------------------
    -- Replace execute_wand() so it writes into simulation_result
    -- -----------------------------
    local function execute_wand(deck)
        local blocks = {}
        local total_cast_delay, total_recharge_time = 0, 0
        local i = 1
        local safety = 0
        local max_iterations = #deck * 2  -- Prevent infinite loops

        local base_cast_delay = wand.cast_delay or 0
        local base_recharge_time = wand.recharge_time or 0

        while i <= #deck and safety < max_iterations do
            safety = safety + 1
            
            local block, next_i, c_delay, c_recharge = build_cast_block(i)
            
            -- Only add block if it actually cast any cards
            if #block.cards > 0 then
                table.insert(blocks, block)
                total_cast_delay  = total_cast_delay  + (base_cast_delay  + c_delay) * overload_ratio
                total_recharge_time = total_recharge_time + (base_recharge_time + c_recharge) * overload_ratio
            end

            -- If we didn't advance past the current card, we're stuck - break out
            if next_i == i then
                break
            end

            i = next_i
        end

        simulation_result.blocks = blocks
        simulation_result.total_cast_delay = total_cast_delay
        simulation_result.total_recharge_time = total_recharge_time

        -- keep the existing printer (optional)
        print_execution_summary(blocks, wand, total_cast_delay, total_recharge_time)
    end

    execute_wand(deck)

    return simulation_result
end

function testWands()
    -- local card_pool = {
    --     create_card_from_template(TEST_PROJECTILE),
    --     create_card_from_template(TEST_PROJECTILE),
    --     create_card_from_template(TEST_PROJECTILE),
    --     create_card_from_template(TEST_DAMAGE_BOOST),
    --     create_card_from_template(TEST_PROJECTILE_TIMER),
    --     create_card_from_template(TEST_PROJECTILE_TRIGGER),
    --     create_card_from_template(TEST_DAMAGE_BOOST),
    --     create_card_from_template(TEST_MULTICAST_2),
    --     create_card_from_template(TEST_MULTICAST_2),
    --     create_card_from_template(TEST_MULTICAST_2),
    --     create_card_from_template(TEST_MULTICAST_2),

    -- }

    local card_pool = {
        create_card_from_template(CardTemplates.TEST_PROJECTILE),
        create_card_from_template(CardTemplates.TEST_PROJECTILE),
        create_card_from_template(CardTemplates.TEST_PROJECTILE),
        create_card_from_template(CardTemplates.TEST_DAMAGE_BOOST),
        create_card_from_template(CardTemplates.TEST_PROJECTILE_TIMER),
        create_card_from_template(CardTemplates.TEST_PROJECTILE_TRIGGER),
        create_card_from_template(CardTemplates.TEST_DAMAGE_BOOST),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
    }


    simulate_wand(WandTemplates[2], card_pool) -- wand with no shuffle, no always cast, no shuffle, cast block size 1

    simulate_wand(WandTemplates[1], card_pool) -- wand with shuffle and always cast modifier, cast block size 2
end

-- return the various features of this file
return {
    wand_defs = WandTemplates,
    card_defs = CardTemplates,
    trigger_card_defs = TriggerCardTemplates,
    testWands = testWands,
    
    -- functions that might be useful
    apply_card_properties = apply_card_properties,
    create_card_from_template = create_card_from_template,
    readable_card_id = readable_card_id,
    simulate_wand = simulate_wand,
}
