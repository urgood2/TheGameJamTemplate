--[[
================================================================================
VERTICAL SLICE CARD SELECTION
================================================================================
Curated subset of cards for the vertical slice demo.
Import this to filter the main Cards table.

Usage:
    local VS = require("data.vertical_slice_cards")
    local Cards = require("data.cards").Cards

    -- Get only vertical slice cards
    for id, _ in pairs(VS.ACTION_CARDS) do
        local card = Cards[id]
        -- use card...
    end
]]

local VerticalSlice = {}

-- Action Cards (12)
VerticalSlice.ACTION_CARDS = {
    ACTION_BASIC_PROJECTILE = true,         -- Baseline projectile
    ACTION_EXPLOSIVE_FIRE_PROJECTILE = true, -- AoE, Fire element
    ACTION_RICOCHET_PROJECTILE = true,      -- Bouncing mechanic
    ACTION_VACUUM_PROJECTILE = true,        -- Void element, crowd control
    ACTION_TELEPORT_BOLT = true,            -- Mobility + combat
    ACTION_BOUNCE_TRIGGER = true,           -- Trigger chaining
    ACTION_FLYING_CROSS = true,             -- Holy element
    ACTION_PROJECTILE_TIMER_CAST = true,    -- Timer-triggered cast
    UTIL_TELEPORT_TO_IMPACT = true,         -- Pure mobility
    UTIL_HEAL_AREA = true,                  -- Defensive, Holy
    UTIL_SHIELD_BUBBLE = true,              -- Defense archetype
    ACTION_ADD_MANA = true,                 -- Resource management
}

-- Modifier Cards (10)
VerticalSlice.MODIFIER_CARDS = {
    MOD_DAMAGE_UP = true,          -- Damage + crit boost
    MOD_HOMING = true,             -- Transforms projectile behavior
    MOD_EXPLOSIVE = true,          -- Single-target to AoE
    MULTI_DOUBLE_CAST = true,      -- Core multicast
    MOD_TRIGGER_ON_HIT = true,     -- Add trigger to projectiles
    MOD_TRIGGER_TIMER = true,      -- Timer-based triggers
    MOD_FORCE_CRIT = true,         -- Guaranteed crit
    MOD_BIG_SLOW = true,           -- Size vs speed tradeoff
    MOD_HEAL_ON_HIT = true,        -- Sustain option
    MOD_BLOOD_TO_DAMAGE = true,    -- Risk/reward sacrifice
}

-- Trigger Cards (all 4)
VerticalSlice.TRIGGER_CARDS = {
    TEST_TRIGGER_EVERY_N_SECONDS = true,      -- Time-based auto-cast
    TEST_TRIGGER_ON_BUMP_ENEMY = true,        -- Collision trigger
    TEST_TRIGGER_ON_DASH = true,              -- Dash trigger
    TEST_TRIGGER_ON_DISTANCE_TRAVELED = true, -- Movement trigger
}

-- Helper: Check if a card ID is in the vertical slice
function VerticalSlice.includes(card_id)
    return VerticalSlice.ACTION_CARDS[card_id]
        or VerticalSlice.MODIFIER_CARDS[card_id]
        or VerticalSlice.TRIGGER_CARDS[card_id]
        or false
end

-- Helper: Get filtered cards from main Cards table
function VerticalSlice.get_cards(Cards, TriggerCards)
    local result = {
        actions = {},
        modifiers = {},
        triggers = {},
    }

    -- Filter action and modifier cards
    for id, card in pairs(Cards) do
        if VerticalSlice.ACTION_CARDS[id] then
            result.actions[id] = card
        elseif VerticalSlice.MODIFIER_CARDS[id] then
            result.modifiers[id] = card
        end
    end

    -- Filter trigger cards
    if TriggerCards then
        for id, card in pairs(TriggerCards) do
            if VerticalSlice.TRIGGER_CARDS[id] then
                result.triggers[id] = card
            end
        end
    end

    return result
end

-- Stats
VerticalSlice.COUNTS = {
    actions = 12,
    modifiers = 10,
    triggers = 4,
    total = 26,
}

return VerticalSlice
