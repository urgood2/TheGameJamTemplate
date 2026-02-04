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
---@field SERPENT_SEGMENT string
Constants.CollisionTags = {
    PLAYER = "player",
    ENEMY = "enemy",
    PROJECTILE = "projectile",
    BULLET = "bullet",
    WORLD = "WORLD",
    SENSOR = "sensor",
    SPIKE_HAZARD = "spike_hazard",
    PICKUP = "pickup",
    SERPENT_SEGMENT = "serpent_segment",
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
-- TIMING CONSTANTS
-- Common delay durations for timers, animations, cooldowns
--===========================================================================
---@class TimingConstants
---@field FRAME number One frame (~16ms at 60fps)
---@field SHORT number Short delay (0.1s)
---@field MEDIUM number Medium delay (0.25s)
---@field LONG number Long delay (0.5s)
---@field ATTACK_COOLDOWN number Default attack cooldown
---@field FADE_DURATION number Default fade animation duration
---@field POPUP_DURATION number How long popup text stays visible
Constants.Timing = {
    -- Frame-based
    FRAME = 1/60,               -- Single frame (~16.67ms at 60fps)
    TICK = 0.05,                -- 50ms tick (physics-like)

    -- General delays
    SHORT = 0.1,                -- Quick flash/feedback
    MEDIUM = 0.25,              -- Standard UI feedback
    LONG = 0.5,                 -- Noticeable delay
    VERY_LONG = 1.0,            -- Full second delay

    -- Combat timing
    ATTACK_COOLDOWN = 0.3,      -- Default cooldown between attacks
    HIT_FLASH_DURATION = 0.15,  -- Duration of damage flash effect
    INVULNERABILITY = 0.5,      -- i-frames after taking damage

    -- Animation timing
    FADE_DURATION = 0.3,        -- Standard fade in/out
    POPUP_DURATION = 1.5,       -- Damage numbers, text popups
    HOVER_DELAY = 0.2,          -- Delay before showing tooltip
    TRANSITION_DURATION = 0.4,  -- Screen/UI transitions
}

--===========================================================================
-- STATS CONSTANTS
-- Base values for game balance (health, damage, speed, etc.)
--===========================================================================
---@class StatsConstants
---@field BASE_HEALTH number Default starting health
---@field BASE_DAMAGE number Default damage value
---@field BASE_SPEED number Default movement speed
Constants.Stats = {
    -- Health
    BASE_HEALTH = 100,          -- Default entity health
    MAX_HEALTH_CAP = 999,       -- Maximum possible health

    -- Damage
    BASE_DAMAGE = 10,           -- Default attack damage
    CRIT_MULTIPLIER = 1.5,      -- Critical hit multiplier

    -- Movement
    BASE_SPEED = 100,           -- Default movement speed (pixels/sec)
    DASH_SPEED = 300,           -- Dash/dodge speed
    PROJECTILE_SPEED = 200,     -- Default projectile speed

    -- Physics
    DEFAULT_FRICTION = 0.3,     -- Default physics friction
    DEFAULT_RESTITUTION = 0.2,  -- Default bounciness
}

--===========================================================================
-- UI CONSTANTS
-- Padding, margins, z-orders, font sizes
--===========================================================================
---@class UIConstants
---@field PADDING_SMALL number Small padding (4px)
---@field PADDING_MEDIUM number Medium padding (8px)
---@field PADDING_LARGE number Large padding (16px)
---@field Z_BACKGROUND number Background z-order
---@field Z_GAME number Game elements z-order
---@field Z_UI number UI z-order
---@field Z_OVERLAY number Overlay z-order
---@field FONT_SMALL number Small font size
---@field FONT_MEDIUM number Medium font size
---@field FONT_LARGE number Large font size
Constants.UI = {
    -- Padding
    PADDING_SMALL = 4,
    PADDING_MEDIUM = 8,
    PADDING_LARGE = 16,
    PADDING_XLARGE = 24,

    -- Margins
    MARGIN_SMALL = 4,
    MARGIN_MEDIUM = 8,
    MARGIN_LARGE = 16,

    -- Border radius
    CORNER_SMALL = 4,
    CORNER_MEDIUM = 8,
    CORNER_LARGE = 12,

    -- Z-orders (higher = drawn on top)
    Z_BACKGROUND = -100,
    Z_GAME = 0,
    Z_GAME_OVERLAY = 50,
    Z_UI = 100,
    Z_OVERLAY = 200,
    Z_TOOLTIP = 300,
    Z_MODAL = 400,
    Z_DEBUG = 500,

    -- Font sizes
    FONT_TINY = 8,
    FONT_SMALL = 12,
    FONT_MEDIUM = 16,
    FONT_LARGE = 24,
    FONT_XLARGE = 32,
    FONT_TITLE = 48,
}

--===========================================================================
-- COLOR CONSTANTS
-- Common colors as {r, g, b, a} tables (0-255 range)
--===========================================================================
---@class Color
---@field r number Red (0-255)
---@field g number Green (0-255)
---@field b number Blue (0-255)
---@field a number? Alpha (0-255, optional, defaults to 255)

---@class ColorConstants
---@field WHITE Color
---@field BLACK Color
---@field DAMAGE Color Red for damage numbers
---@field HEAL Color Green for healing
---@field BUFF Color Blue for buffs
---@field DEBUFF Color Purple for debuffs
---@field UI_PRIMARY Color
---@field UI_SECONDARY Color
Constants.Colors = {
    -- Basic colors
    WHITE = { r = 255, g = 255, b = 255, a = 255 },
    BLACK = { r = 0, g = 0, b = 0, a = 255 },
    RED = { r = 255, g = 0, b = 0, a = 255 },
    GREEN = { r = 0, g = 255, b = 0, a = 255 },
    BLUE = { r = 0, g = 0, b = 255, a = 255 },
    YELLOW = { r = 255, g = 255, b = 0, a = 255 },
    TRANSPARENT = { r = 0, g = 0, b = 0, a = 0 },

    -- Semantic colors (for game feedback)
    DAMAGE = { r = 255, g = 80, b = 80, a = 255 },      -- Damage numbers
    HEAL = { r = 80, g = 255, b = 80, a = 255 },        -- Healing numbers
    BUFF = { r = 80, g = 180, b = 255, a = 255 },       -- Buff indicators
    DEBUFF = { r = 200, g = 80, b = 255, a = 255 },     -- Debuff indicators
    MANA = { r = 100, g = 100, b = 255, a = 255 },      -- Mana/energy
    EXPERIENCE = { r = 255, g = 215, b = 0, a = 255 },  -- XP/gold

    -- UI colors
    UI_PRIMARY = { r = 60, g = 60, b = 80, a = 255 },
    UI_SECONDARY = { r = 80, g = 80, b = 100, a = 255 },
    UI_ACCENT = { r = 100, g = 150, b = 255, a = 255 },
    UI_BACKGROUND = { r = 30, g = 30, b = 40, a = 220 },
    UI_TEXT = { r = 240, g = 240, b = 240, a = 255 },
    UI_TEXT_DIM = { r = 160, g = 160, b = 160, a = 255 },
}

--===========================================================================
-- TIMER GROUPS
-- Named groups for timer management and cleanup
--===========================================================================
---@class TimerGroups
---@field SERPENT string Serpent minigame timer group
---@field MAIN string Main game timer group
---@field UI string UI timer group
Constants.TimerGroups = {
    SERPENT = "serpent",
    MAIN = "main",
    UI = "ui",
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
