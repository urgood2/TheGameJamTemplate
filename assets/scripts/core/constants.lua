--[[
================================================================================
CONSTANTS - Central registry for magic strings and enums
================================================================================
Provides type-safe constants for collision tags, state tags, damage types,
shader names, and other frequently-used string values.

This module helps prevent typos and enables IDE autocomplete support.

Usage:
    local C = require("core.constants")

    -- Collision tags
    PhysicsBuilder.for_entity(e):tag(C.CollisionTags.ENEMY):apply()

    -- State tags
    add_state_tag(entity, C.States.PLANNING)

    -- Damage types
    card.damage_type = C.DamageTypes.FIRE
]]

---@class Constants
---@field CollisionTags CollisionTags
---@field States GameStates
---@field DamageTypes DamageTypes
---@field Tags ContentTags
---@field CardTypes CardTypes
---@field Rarities Rarities
---@field MovementTypes MovementTypes
---@field CollisionTypes CollisionTypes
---@field Shaders Shaders
---@field DrawSpace DrawSpace
---@field SyncModes SyncModes
---@field PhysicsShapes PhysicsShapes
---@field Components ComponentNames
---@field Layers LayerNames
local Constants = {}

--===========================================================================
-- COLLISION TAGS
-- Used with PhysicsBuilder and physics.create_physics_for_transform()
--===========================================================================
---@class CollisionTags
---@field PLAYER string
---@field ENEMY string
---@field PROJECTILE string
---@field BULLET string
---@field WORLD string
---@field SENSOR string
---@field SPIKE_HAZARD string
---@field PICKUP string
Constants.CollisionTags = {
    PLAYER = "player",
    ENEMY = "enemy",
    PROJECTILE = "projectile",
    BULLET = "bullet",
    WORLD = "WORLD",
    SENSOR = "sensor",
    SPIKE_HAZARD = "spike_hazard",
    PICKUP = "pickup",
}

--===========================================================================
-- GAME STATES
-- Used with add_state_tag(), remove_default_state_tag(), is_state_active()
--===========================================================================
Constants.States = {
    PLANNING = "PLANNING",
    ACTION = "SURVIVORS",  -- Note: ACTION uses "SURVIVORS" internally
    MENU = "MENU",
    PAUSED = "PAUSED",
    GAME_OVER = "GAME_OVER",
    DEFAULT = "default",
}

--===========================================================================
-- DAMAGE TYPES
-- Used in cards, projectiles, and combat calculations
--===========================================================================
Constants.DamageTypes = {
    PHYSICAL = "physical",
    FIRE = "fire",
    ICE = "ice",
    LIGHTNING = "lightning",
    POISON = "poison",
    ARCANE = "arcane",
    HOLY = "holy",
    VOID = "void",
    MAGIC = "magic",
}

--===========================================================================
-- CONTENT TAGS
-- Used for card/joker synergies and tag threshold bonuses
--===========================================================================
Constants.Tags = {
    -- Elements
    FIRE = "Fire",
    ICE = "Ice",
    LIGHTNING = "Lightning",
    POISON = "Poison",
    ARCANE = "Arcane",
    HOLY = "Holy",
    VOID = "Void",
    -- Mechanics
    PROJECTILE = "Projectile",
    AOE = "AoE",
    HAZARD = "Hazard",
    SUMMON = "Summon",
    BUFF = "Buff",
    DEBUFF = "Debuff",
    -- Playstyle
    MOBILITY = "Mobility",
    DEFENSE = "Defense",
    BRUTE = "Brute",
}

--===========================================================================
-- CARD TYPES
-- Used in card definitions
--===========================================================================
Constants.CardTypes = {
    ACTION = "action",
    MODIFIER = "modifier",
    TRIGGER = "trigger",
}

--===========================================================================
-- RARITIES
-- Used for jokers, cards, and items
--===========================================================================
Constants.Rarities = {
    COMMON = "Common",
    UNCOMMON = "Uncommon",
    RARE = "Rare",
    EPIC = "Epic",
    LEGENDARY = "Legendary",
}

--===========================================================================
-- PROJECTILE MOVEMENT TYPES
-- Used in projectile preset definitions
--===========================================================================
Constants.MovementTypes = {
    STRAIGHT = "straight",
    HOMING = "homing",
    ARC = "arc",
    ORBITAL = "orbital",
    CUSTOM = "custom",
}

--===========================================================================
-- PROJECTILE COLLISION TYPES
-- Used in projectile preset definitions
--===========================================================================
Constants.CollisionTypes = {
    DESTROY = "destroy",
    PIERCE = "pierce",
    BOUNCE = "bounce",
    EXPLODE = "explode",
    PASS_THROUGH = "pass_through",
    CHAIN = "chain",
}

--===========================================================================
-- COMMON SHADERS
-- Used with ShaderBuilder
--===========================================================================
Constants.Shaders = {
    -- 3D Card effects
    HOLO = "3d_skew_holo",
    PRISMATIC = "3d_skew_prismatic",
    POLYCHROME = "3d_skew_polychrome",
    FOIL = "3d_skew_foil",
    -- Utility effects
    DISSOLVE = "dissolve",
    FLASH = "flash",
    OUTLINE = "outline",
    SHADOW = "shadow",
    GLOW = "glow",
    -- Damage/hit effects
    HIT_FLASH = "hit_flash",
    DAMAGE_FLASH = "damage_flash",
}

--===========================================================================
-- DRAW COMMAND SPACES
-- Used with draw commands and command_buffer
--===========================================================================
Constants.DrawSpace = {
    WORLD = "World",
    SCREEN = "Screen",
}

--===========================================================================
-- PHYSICS SYNC MODES
-- Used with PhysicsBuilder or physics.set_sync_mode()
--===========================================================================
Constants.SyncModes = {
    PHYSICS = "physics",          -- Physics controls position
    TRANSFORM = "transform",      -- Transform controls position
    AUTHORITATIVE_PHYSICS = "AuthoritativePhysics",
    AUTHORITATIVE_TRANSFORM = "AuthoritativeTransform",
}

--===========================================================================
-- PHYSICS SHAPES
-- Used with PhysicsBuilder or physics configuration
--===========================================================================
Constants.PhysicsShapes = {
    CIRCLE = "circle",
    RECTANGLE = "rectangle",
    POLYGON = "polygon",
    CHAIN = "chain",
}

--===========================================================================
-- COMPONENT NAMES
-- String names for common ECS components
--===========================================================================
Constants.Components = {
    TRANSFORM = "Transform",
    GAME_OBJECT = "GameObject",
    SCRIPT_COMPONENT = "ScriptComponent",
    ANIMATION_QUEUE = "AnimationQueueComponent",
    STATE_TAG = "StateTag",
    LAYER_CONFIG = "LayerConfig",
    SHADOW = "Shadow",
}

--===========================================================================
-- LAYER NAMES
-- Render layer identifiers
--===========================================================================
Constants.Layers = {
    SPRITES = "sprites",
    UI = "ui",
    BACKGROUND = "background",
    FOREGROUND = "foreground",
    EFFECTS = "effects",
}

--===========================================================================
-- HELPER: Get all values of a constant table as array
--===========================================================================
function Constants.values(constant_table)
    local result = {}
    for _, v in pairs(constant_table) do
        table.insert(result, v)
    end
    return result
end

--===========================================================================
-- HELPER: Check if a value exists in a constant table
--===========================================================================
function Constants.is_valid(constant_table, value)
    for _, v in pairs(constant_table) do
        if v == value then return true end
    end
    return false
end

-- Make module available globally for convenience (optional)
if not _G.C then
    _G.C = Constants
end

return Constants
