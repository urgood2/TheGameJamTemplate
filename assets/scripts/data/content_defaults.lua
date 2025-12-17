--[[
================================================================================
CONTENT DEFAULTS - Default Values for Cards, Jokers, Projectiles
================================================================================
Provides explicit default values for all content fields. Use these to:
1. Understand what fields are available and their expected types
2. Apply defaults when creating content at runtime
3. Validate content definitions

Usage:
    local defaults = require("data.content_defaults")

    -- Get defaults for a card type
    local action_defaults = defaults.card("action")

    -- Apply defaults to a card definition
    local card = defaults.apply_card_defaults(my_card_def)

    -- Check if a field has a default
    if defaults.CARD_FIELDS.damage then ... end
]]

local ContentDefaults = {}

--===========================================================================
-- CARD FIELD DEFAULTS
-- Fields marked with [REQUIRED] must be provided by content creator
--===========================================================================

ContentDefaults.CARD_FIELDS = {
    -- [REQUIRED] id: string - Must match table key
    -- [REQUIRED] type: "action" | "modifier" | "trigger"
    -- [REQUIRED] tags: string[] - At least empty table {}
    -- [REQUIRED] test_label: string - Display label

    -- Mana/Cost (shared by all types)
    mana_cost = 10,              -- Mana consumed on cast
    max_uses = -1,               -- -1 = infinite, positive = limited uses
    recharge_time = 0,           -- ms between uses

    -- Combat Stats (action cards)
    damage = 0,                  -- Base damage dealt
    damage_type = "physical",    -- fire/ice/lightning/poison/arcane/holy/void/magic/physical
    radius_of_effect = 0,        -- 0 = single target, >0 = AoE radius

    -- Projectile Properties (action cards with projectiles)
    projectile_speed = 500,      -- Pixels per second
    lifetime = 2000,             -- ms before despawn (IMPORTANT: prevents infinite projectiles)
    spread_angle = 0,            -- Degrees of random spread
    homing_strength = 0,         -- 0-15, higher = tighter tracking
    ricochet_count = 0,          -- Number of bounces

    -- Timing
    cast_delay = 0,              -- ms delay before cast executes

    -- Modifier Card Fields
    damage_modifier = 0,         -- Added to damage
    speed_modifier = 0,          -- Added to projectile speed
    lifetime_modifier = 0,       -- Added to lifetime (ms)
    spread_modifier = 0,         -- Added to spread angle
    critical_hit_chance_modifier = 0, -- Added to crit chance %

    -- Trigger Card Fields
    trigger_condition = nil,     -- Function or string identifier
    trigger_chance = 1.0,        -- 0.0-1.0 probability

    -- Misc
    weight = 1,                  -- Spawn weight for random selection
    sprite = nil,                -- nil = use default card sprite
    timer_ms = 0,                -- Timer trigger delay
}

--===========================================================================
-- PROJECTILE FIELD DEFAULTS
--===========================================================================

ContentDefaults.PROJECTILE_FIELDS = {
    -- [REQUIRED] id: string - Must match table key
    -- [REQUIRED] speed: number - Movement speed
    -- [REQUIRED] movement: "straight" | "homing" | "arc" | "orbital" | "custom"
    -- [REQUIRED] collision: "destroy" | "pierce" | "bounce" | "explode" | "pass_through" | "chain"

    damage_type = "physical",
    lifetime = 3000,             -- ms (IMPORTANT: prevents infinite projectiles)
    damage = 0,                  -- Override card damage if set
    sprite = nil,                -- nil = use default projectile sprite

    -- Movement-specific
    homing_strength = 5,         -- For homing movement
    gravity = 500,               -- For arc movement
    orbital_radius = 100,        -- For orbital movement
    orbital_speed = 2.0,         -- Radians per second

    -- Collision-specific
    pierce_count = 1,            -- For pierce collision
    bounce_count = 3,            -- For bounce collision
    explosion_radius = 50,       -- For explode collision
    chain_count = 3,             -- For chain collision
    chain_range = 150,           -- Range to find chain targets

    -- Tags for synergies
    tags = {},
}

--===========================================================================
-- JOKER FIELD DEFAULTS
--===========================================================================

ContentDefaults.JOKER_FIELDS = {
    -- [REQUIRED] id: string - Must match table key
    -- [REQUIRED] name: string - Display name
    -- [REQUIRED] calculate: function - Event handler

    description = "",            -- Tooltip description
    rarity = "Common",           -- Common/Uncommon/Rare/Epic/Legendary
    sprite = nil,                -- nil = use default joker sprite
    cost = 100,                  -- Shop purchase cost
    unlock_condition = nil,      -- Function that returns true when unlocked
}

--===========================================================================
-- AVATAR FIELD DEFAULTS
--===========================================================================

ContentDefaults.AVATAR_FIELDS = {
    -- [REQUIRED] name: string - Display name
    -- [REQUIRED] unlock: table - Unlock conditions
    -- [REQUIRED] effects: table[] - List of effects

    description = "",
    sprite = nil,
    starting_bonus = nil,        -- One-time bonus on select
}

--===========================================================================
-- HELPER FUNCTIONS
--===========================================================================

--- Get defaults for a specific card type
--- @param card_type "action"|"modifier"|"trigger"
--- @return table Default values for that card type
function ContentDefaults.card(card_type)
    local base = {
        mana_cost = ContentDefaults.CARD_FIELDS.mana_cost,
        max_uses = ContentDefaults.CARD_FIELDS.max_uses,
        recharge_time = ContentDefaults.CARD_FIELDS.recharge_time,
        weight = ContentDefaults.CARD_FIELDS.weight,
    }

    if card_type == "action" then
        base.damage = ContentDefaults.CARD_FIELDS.damage
        base.damage_type = ContentDefaults.CARD_FIELDS.damage_type
        base.radius_of_effect = ContentDefaults.CARD_FIELDS.radius_of_effect
        base.projectile_speed = ContentDefaults.CARD_FIELDS.projectile_speed
        base.lifetime = ContentDefaults.CARD_FIELDS.lifetime
        base.spread_angle = ContentDefaults.CARD_FIELDS.spread_angle
        base.homing_strength = ContentDefaults.CARD_FIELDS.homing_strength
        base.ricochet_count = ContentDefaults.CARD_FIELDS.ricochet_count
        base.cast_delay = ContentDefaults.CARD_FIELDS.cast_delay
    elseif card_type == "modifier" then
        base.damage_modifier = ContentDefaults.CARD_FIELDS.damage_modifier
        base.speed_modifier = ContentDefaults.CARD_FIELDS.speed_modifier
        base.lifetime_modifier = ContentDefaults.CARD_FIELDS.lifetime_modifier
        base.spread_modifier = ContentDefaults.CARD_FIELDS.spread_modifier
        base.critical_hit_chance_modifier = ContentDefaults.CARD_FIELDS.critical_hit_chance_modifier
    elseif card_type == "trigger" then
        base.trigger_condition = ContentDefaults.CARD_FIELDS.trigger_condition
        base.trigger_chance = ContentDefaults.CARD_FIELDS.trigger_chance
        base.timer_ms = ContentDefaults.CARD_FIELDS.timer_ms
    end

    return base
end

--- Apply defaults to a card definition (non-destructive)
--- @param card table The card definition
--- @return table New table with defaults applied
function ContentDefaults.apply_card_defaults(card)
    if not card or not card.type then
        return card
    end

    local defaults = ContentDefaults.card(card.type)
    local result = {}

    -- Copy defaults first
    for k, v in pairs(defaults) do
        result[k] = v
    end

    -- Override with card values
    for k, v in pairs(card) do
        result[k] = v
    end

    return result
end

--- Apply defaults to a projectile definition (non-destructive)
--- @param proj table The projectile definition
--- @return table New table with defaults applied
function ContentDefaults.apply_projectile_defaults(proj)
    if not proj then return proj end

    local result = {}

    -- Copy defaults first
    for k, v in pairs(ContentDefaults.PROJECTILE_FIELDS) do
        result[k] = v
    end

    -- Override with projectile values
    for k, v in pairs(proj) do
        result[k] = v
    end

    return result
end

--- Get the default value for a specific field
--- @param content_type "card"|"projectile"|"joker"|"avatar"
--- @param field_name string
--- @return any The default value or nil if no default
function ContentDefaults.get_default(content_type, field_name)
    local fields
    if content_type == "card" then
        fields = ContentDefaults.CARD_FIELDS
    elseif content_type == "projectile" then
        fields = ContentDefaults.PROJECTILE_FIELDS
    elseif content_type == "joker" then
        fields = ContentDefaults.JOKER_FIELDS
    elseif content_type == "avatar" then
        fields = ContentDefaults.AVATAR_FIELDS
    end

    return fields and fields[field_name]
end

--- Check if a field has a known default
--- @param content_type "card"|"projectile"|"joker"|"avatar"
--- @param field_name string
--- @return boolean
function ContentDefaults.has_default(content_type, field_name)
    return ContentDefaults.get_default(content_type, field_name) ~= nil
end

return ContentDefaults
