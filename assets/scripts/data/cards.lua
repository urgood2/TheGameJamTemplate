--[[
================================================================================
CARD DEFINITIONS
================================================================================
Centralized registry for all Action and Modifier cards.

Tags (for joker synergies):
  Elements: Fire, Ice, Lightning, Poison, Arcane, Holy, Void
  Mechanics: Projectile, AoE, Hazard, Summon, Buff, Debuff
  Playstyle: Mobility, Defense, Brute
]]

local Cards = {}

-- Action Cards
Cards.TEST_PROJECTILE = {
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
    tags = { "Projectile" },
    test_label = "TEST\nprojectile",
}

Cards.TEST_PROJECTILE_TIMER = {
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
    tags = { "Projectile", "Arcane" },
    test_label = "TEST\nprojectile\ntimer",
}

Cards.TEST_PROJECTILE_TRIGGER = {
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
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
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
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 2,
    weight = 2,
    tags = { "Arcane" },
    test_label = "TEST\nmulticast",
}

-- Action Cards
Cards.ACTION_BASIC_PROJECTILE = {
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
    tags = { "Projectile" },
    test_label = "ACTION\nbasic\nprojectile",
}

Cards.ACTION_FAST_ACCURATE_PROJECTILE = {
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
    tags = { "Projectile", "Arcane" },
    test_label = "ACTION\nfast\naccurate\nprojectile",
}

Cards.ACTION_SLOW_ORB = {
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
    tags = { "Projectile", "Arcane" },
    test_label = "ACTION\nslow\norb",
}

Cards.ACTION_EXPLOSIVE_FIRE_PROJECTILE = {
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
    tags = { "Fire", "Projectile", "AoE" },
    test_label = "ACTION\nexplosive\nfire\nprojectile",
}

Cards.ACTION_RICOCHET_PROJECTILE = {
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
    tags = { "Projectile" },
    test_label = "ACTION\nricochet\nprojectile",
}

Cards.ACTION_HEAVY_OBJECT_PROJECTILE = {
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
    tags = { "Projectile", "Brute" },
    test_label = "ACTION\nheavy\nobject\nprojectile",
}

Cards.ACTION_VACUUM_PROJECTILE = {
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
    tags = { "Void", "Projectile", "AoE" },
    test_label = "ACTION\nvacuum\nprojectile",
}

-- Modifier Cards
Cards.MOD_SEEKING = {
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
    tags = { "Arcane", "Projectile" },
    test_label = "MOD\nseeking",
}

Cards.MOD_SPEED_UP = {
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
    tags = { "Buff", "Mobility" },
    test_label = "MOD\nspeed\nup",
}

Cards.MOD_SPEED_DOWN = {
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
    tags = { "Debuff" },
    test_label = "MOD\nspeed\ndown",
}

Cards.MOD_REDUCE_SPREAD = {
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
    tags = { "Buff", "Projectile" },
    test_label = "MOD\nreduce\nspread",
}

Cards.MOD_DAMAGE_UP = {
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
    tags = { "Buff", "Brute" },
    test_label = "MOD\ndamage\nup",
}

Cards.MOD_SHORT_LIFETIME = {
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
    tags = { "Debuff" },
    test_label = "MOD\nshort\nlifetime",
}

Cards.MOD_TRIGGER_ON_HIT = {
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
    tags = { "Arcane" },
    test_label = "MOD\ntrigger\non\nhit",
}

Cards.MOD_TRIGGER_TIMER = {
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
    tags = { "Arcane" },
    test_label = "MOD\ntrigger\ntimer",
}

Cards.MOD_TRIGGER_ON_DEATH = {
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
    tags = { "Arcane", "Void" },
    test_label = "MOD\ntrigger\non\ndeath",
}

-- Multicasts
Cards.MULTI_DOUBLE_CAST = {
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
    tags = { "Arcane" },
    test_label = "MULTI\ndouble\ncast",
}

Cards.MULTI_TRIPLE_CAST = {
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
    tags = { "Arcane" },
    test_label = "MULTI\ntriple\ncast",
}

Cards.MULTI_CIRCLE_FIVE_CAST = {
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
    test_label = "TRIGGER\nevery\nN\nseconds",
}

TriggerCards.TEST_TRIGGER_ON_BUMP_ENEMY = {
    id = "on_bump_enemy",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = { "Brute" },
    test_label = "TRIGGER\non\nbump\nenemy",
}

TriggerCards.TEST_TRIGGER_ON_DASH = {
    id = "on_dash",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = { "Mobility" },
    test_label = "TRIGGER\non\ndash",
}

TriggerCards.TEST_TRIGGER_ON_DISTANCE_TRAVELED = {
    id = "on_distance_traveled",
    type = "trigger",
    max_uses = -1,
    mana_cost = 0,
    weight = 0,
    tags = { "Mobility" },
    test_label = "TRIGGER\non\ndistance\ntraveled",
}

return {
    Cards = Cards,
    TriggerCards = TriggerCards
}
