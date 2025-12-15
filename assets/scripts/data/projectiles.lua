--[[
================================================================================
PROJECTILE DEFINITIONS
================================================================================
Registry for projectile visual and behavioral presets.
Define a projectile once and reference it from cards via `projectile_preset`.

Movement types: straight, homing, arc, orbital, custom
Collision types: destroy, pierce, bounce, explode, pass_through, chain

Tags (for joker synergies):
  Elements: Fire, Ice, Lightning, Poison, Arcane, Holy, Void
  Mechanics: Projectile, AoE, Hazard
]]

local Projectiles = {
    --===========================================================================
    -- BASIC
    --===========================================================================
    basic_bolt = {
        id = "basic_bolt",
        speed = 500,
        damage_type = "physical",
        movement = "straight",
        collision = "destroy",
        lifetime = 2000,
        tags = { "Projectile" },
    },

    --===========================================================================
    -- ELEMENTAL
    --===========================================================================
    fireball = {
        id = "fireball",
        speed = 400,
        damage_type = "fire",
        movement = "straight",
        collision = "explode",
        explosion_radius = 60,
        lifetime = 2000,
        on_hit_effect = "burn",
        on_hit_duration = 3000,
        tags = { "Fire", "Projectile", "AoE" },
    },

    ice_shard = {
        id = "ice_shard",
        speed = 600,
        damage_type = "ice",
        movement = "straight",
        collision = "pierce",
        pierce_count = 2,
        lifetime = 1800,
        on_hit_effect = "freeze",
        on_hit_duration = 1000,
        tags = { "Ice", "Projectile" },
    },

    lightning_bolt = {
        id = "lightning_bolt",
        speed = 900,
        damage_type = "lightning",
        movement = "straight",
        collision = "chain",
        chain_count = 3,
        chain_range = 100,
        chain_damage_decay = 0.7,
        lifetime = 1000,
        tags = { "Lightning", "Projectile" },
    },

    --===========================================================================
    -- BEHAVIORS
    --===========================================================================
    homing_missile = {
        id = "homing_missile",
        speed = 350,
        damage_type = "arcane",
        movement = "homing",
        homing_strength = 8,
        homing_delay = 100,
        homing_range = 300,
        collision = "destroy",
        lifetime = 3000,
        trail = true,
        tags = { "Arcane", "Projectile" },
    },

    bouncing_ball = {
        id = "bouncing_ball",
        speed = 450,
        damage_type = "physical",
        movement = "straight",
        collision = "bounce",
        bounce_count = 3,
        bounce_dampening = 0.9,
        lifetime = 2500,
        tags = { "Projectile" },
    },

    gravity_bomb = {
        id = "gravity_bomb",
        speed = 300,
        damage_type = "physical",
        movement = "arc",
        gravity = 400,
        collision = "explode",
        explosion_radius = 80,
        lifetime = 3000,
        tags = { "Projectile", "AoE" },
    },

    piercing_arrow = {
        id = "piercing_arrow",
        speed = 700,
        damage_type = "physical",
        movement = "straight",
        collision = "pierce",
        pierce_count = 5,
        lifetime = 1500,
        tags = { "Projectile" },
    },

    --===========================================================================
    -- SPECIAL
    --===========================================================================
    orbital_orb = {
        id = "orbital_orb",
        speed = 200,
        damage_type = "arcane",
        movement = "orbital",
        orbital_radius = 80,
        orbital_speed = 3,
        collision = "pass_through",
        lifetime = 5000,
        tags = { "Arcane", "Projectile" },
    },

    poison_cloud = {
        id = "poison_cloud",
        speed = 150,
        damage_type = "poison",
        movement = "straight",
        collision = "pass_through",
        leaves_hazard = true,
        hazard_duration = 3000,
        lifetime = 2000,
        on_hit_effect = "poison",
        on_hit_duration = 5000,
        tags = { "Poison", "Hazard" },
    },

    void_rift = {
        id = "void_rift",
        speed = 250,
        damage_type = "void",
        movement = "straight",
        collision = "destroy",
        suction_strength = 10,
        suction_radius = 100,
        lifetime = 2500,
        tags = { "Void", "Projectile" },
    },

    holy_beam = {
        id = "holy_beam",
        speed = 1000,
        damage_type = "holy",
        movement = "straight",
        collision = "pierce",
        pierce_count = 999,
        lifetime = 500,
        tags = { "Holy", "Projectile" },
    },

    --===========================================================================
    -- ENEMY PROJECTILES
    --===========================================================================
    enemy_basic_shot = {
        id = "enemy_basic_shot",
        speed = 300,
        damage_type = "physical",
        movement = "straight",
        collision = "destroy",
        lifetime = 3000,
        enemy = true,
        tags = { "Projectile" },
    },

    enemy_fireball = {
        id = "enemy_fireball",
        speed = 250,
        damage_type = "fire",
        movement = "straight",
        collision = "destroy",
        lifetime = 2500,
        on_hit_effect = "burn",
        on_hit_duration = 2000,
        enemy = true,
        tags = { "Fire", "Projectile" },
    },

    enemy_ice_shard = {
        id = "enemy_ice_shard",
        speed = 350,
        damage_type = "ice",
        movement = "straight",
        collision = "destroy",
        lifetime = 2000,
        on_hit_effect = "freeze",
        on_hit_duration = 1500,
        enemy = true,
        tags = { "Ice", "Projectile" },
    },

    enemy_homing_orb = {
        id = "enemy_homing_orb",
        speed = 200,
        damage_type = "arcane",
        movement = "homing",
        homing_strength = 4,
        collision = "destroy",
        lifetime = 4000,
        enemy = true,
        tags = { "Arcane", "Projectile" },
    },

    enemy_spread_shot = {
        id = "enemy_spread_shot",
        speed = 280,
        damage_type = "physical",
        movement = "straight",
        collision = "destroy",
        lifetime = 2000,
        enemy = true,
        tags = { "Projectile" },
    },
}

return Projectiles
