--[[
================================================================================
CARD METADATA - Rarity and Tags for Existing Cards
================================================================================
This module provides rarity and tag metadata for all existing card definitions.
Use this to enrich card instances at runtime without modifying the original
card_eval_order_test.lua file.

Usage:
  local CardMeta = require("assets.scripts.core.card_metadata")

  -- Get metadata for a card
  local meta = CardMeta.get("ACTION_BASIC_PROJECTILE")
  -- Returns: { rarity = "common", tags = {"brute"} }

  -- Enrich a card instance
  local card = CardMeta.enrich(cardInstance)
  -- Adds rarity and tags fields to the card

  -- Register with shop system
  CardMeta.registerAllWithShop(ShopSystem)

================================================================================
]] --

local CardMetadata = {}

-- ============================================================================
-- METADATA DEFINITIONS
-- ============================================================================

CardMetadata.data = {
    -- ACTIONS - Basic Projectiles
    ACTION_BASIC_PROJECTILE = {
        rarity = "common",
        tags = { "brute" }
    },

    ACTION_FAST_ACCURATE_PROJECTILE = {
        rarity = "common",
        tags = { "tactical" }
    },

    ACTION_SLOW_ORB = {
        rarity = "uncommon",
        tags = { "brute", "elemental" }
    },

    ACTION_EXPLOSIVE_FIRE_PROJECTILE = {
        rarity = "rare",
        tags = { "brute", "elemental", "hazard" }
    },

    ACTION_RICOCHET_PROJECTILE = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    ACTION_HEAVY_OBJECT_PROJECTILE = {
        rarity = "uncommon",
        tags = { "brute" }
    },

    ACTION_VACUUM_PROJECTILE = {
        rarity = "rare",
        tags = { "hazard", "tactical" }
    },

    ACTION_BOUNCE_BALL = {
        rarity = "uncommon",
        tags = { "brute", "tactical" }
    },

    ACTION_BOUNCE_TRIGGER = {
        rarity = "rare",
        tags = { "tactical" }
    },

    ACTION_SPIKE_HAZARD_TIMER = {
        rarity = "rare",
        tags = { "hazard" }
    },

    ACTION_FLYING_CROSS = {
        rarity = "rare",
        tags = { "brute", "elemental" }
    },

    ACTION_TELEPORT_BOLT = {
        rarity = "legendary",
        tags = { "mobility", "tactical" }
    },

    ACTION_PROJECTILE_TIMER_CAST = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    ACTION_SUMMON_MINION = {
        rarity = "rare",
        tags = { "tactical" }
    },

    ACTION_ADD_MANA = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    -- MODIFIERS - Basic
    MOD_SEEKING = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    MOD_SPEED_UP = {
        rarity = "common",
        tags = { "mobility" }
    },

    MOD_SPEED_DOWN = {
        rarity = "common",
        tags = { "tactical" }
    },

    MOD_REDUCE_SPREAD = {
        rarity = "common",
        tags = { "tactical" }
    },

    MOD_DAMAGE_UP = {
        rarity = "uncommon",
        tags = { "brute" }
    },

    MOD_SHORT_LIFETIME = {
        rarity = "common",
        tags = { "tactical" }
    },

    -- MODIFIERS - Triggers
    MOD_TRIGGER_ON_HIT = {
        rarity = "rare",
        tags = { "tactical" }
    },

    MOD_TRIGGER_TIMER = {
        rarity = "rare",
        tags = { "tactical" }
    },

    MOD_TRIGGER_ON_DEATH = {
        rarity = "rare",
        tags = { "hazard" }
    },

    -- MODIFIERS - Advanced
    MOD_DOUBLE_SPELL = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    MOD_TRIPLE_SPELL = {
        rarity = "rare",
        tags = { "tactical" }
    },

    MOD_FORCE_CRIT = {
        rarity = "uncommon",
        tags = { "tactical", "brute" }
    },

    MOD_BIG_SLOW = {
        rarity = "uncommon",
        tags = { "brute" }
    },

    MOD_IMMUNE_AND_ADD_CARD = {
        rarity = "rare",
        tags = { "defense", "tactical" }
    },

    MOD_HEAL_ON_HIT = {
        rarity = "uncommon",
        tags = { "defense" }
    },

    MOD_RANDOM_MODIFIER = {
        rarity = "rare",
        tags = { "tactical" }
    },

    MOD_AUTO_AIM = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    MOD_HOMING = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    MOD_EXPLOSIVE = {
        rarity = "rare",
        tags = { "brute", "hazard" }
    },

    MOD_PHASE_SLOW = {
        rarity = "uncommon",
        tags = { "mobility", "tactical" }
    },

    MOD_LONG_CAST = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    MOD_TELEPORT_CAST = {
        rarity = "rare",
        tags = { "mobility", "tactical" }
    },

    MOD_BLOOD_TO_DAMAGE = {
        rarity = "legendary",
        tags = { "brute" }
    },

    MOD_WAND_REFRESH = {
        rarity = "rare",
        tags = { "tactical" }
    },

    -- MULTICASTS
    MULTI_DOUBLE_CAST = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    MULTI_TRIPLE_CAST = {
        rarity = "rare",
        tags = { "tactical" }
    },

    MULTI_CIRCLE_FIVE_CAST = {
        rarity = "legendary",
        tags = { "tactical", "brute" }
    },

    -- UTILITY
    UTIL_TELEPORT_TO_IMPACT = {
        rarity = "rare",
        tags = { "mobility" }
    },

    UTIL_HEAL_AREA = {
        rarity = "uncommon",
        tags = { "defense" }
    },

    UTIL_SHIELD_BUBBLE = {
        rarity = "rare",
        tags = { "defense" }
    },

    UTIL_SUMMON_ALLY = {
        rarity = "legendary",
        tags = { "tactical" }
    },

    -- META
    META_RECAST_FIRST = {
        rarity = "rare",
        tags = { "tactical" }
    },

    META_APPLY_ALL_MODS_NEXT = {
        rarity = "rare",
        tags = { "tactical" }
    },

    META_CAST_ALL_AT_ONCE = {
        rarity = "legendary",
        tags = { "tactical", "brute" }
    },

    META_CONVERT_WEIGHT_TO_DAMAGE = {
        rarity = "rare",
        tags = { "brute", "tactical" }
    },

    -- TEST CARDS
    TEST_PROJECTILE = {
        rarity = "common",
        tags = { "brute" }
    },

    TEST_PROJECTILE_TIMER = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    TEST_PROJECTILE_TRIGGER = {
        rarity = "uncommon",
        tags = { "tactical" }
    },

    TEST_DAMAGE_BOOST = {
        rarity = "common",
        tags = { "brute" }
    },

    TEST_MULTICAST_2 = {
        rarity = "uncommon",
        tags = { "tactical" }
    },
}

-- Trigger metadata
CardMetadata.triggerData = {
    TEST_TRIGGER_EVERY_N_SECONDS = {
        rarity = "common",
        tags = {}
    },

    TEST_TRIGGER_ON_BUMP_ENEMY = {
        rarity = "uncommon",
        tags = { "brute" }
    },

    TEST_TRIGGER_ON_DASH = {
        rarity = "uncommon",
        tags = { "mobility" }
    },

    TEST_TRIGGER_ON_DISTANCE_TRAVELED = {
        rarity = "uncommon",
        tags = { "mobility" }
    },
}

-- ============================================================================
-- API
-- ============================================================================

--- Gets metadata for a card
--- @param cardId string Card ID
--- @return table|nil Metadata {rarity, tags} or nil if not found
function CardMetadata.get(cardId)
    return CardMetadata.data[cardId] or CardMetadata.triggerData[cardId]
end

--- Enriches a card instance with metadata
--- @param card table Card instance (must have .id field)
--- @return table Enriched card (same reference)
function CardMetadata.enrich(card)
    if not card or not card.id then
        return card
    end

    local meta = CardMetadata.get(card.id)
    if meta then
        card.rarity = meta.rarity
        card.tags = {}
        for _, tag in ipairs(meta.tags) do
            table.insert(card.tags, tag)
        end
    else
        -- Default metadata for unknown cards
        card.rarity = card.rarity or "common"
        card.tags = card.tags or {}
    end

    return card
end

--- Enriches multiple card instances
--- @param cards table Array of card instances
--- @return table Enriched cards (same reference)
function CardMetadata.enrichAll(cards)
    for _, card in ipairs(cards) do
        CardMetadata.enrich(card)
    end
    return cards
end

--- Registers all cards with the shop system
--- @param ShopSystem table Shop system module
function CardMetadata.registerAllWithShop(ShopSystem)
    local cardEval = require("assets.scripts.core.card_eval_order_test")

    -- Register action/modifier cards
    for cardId, meta in pairs(CardMetadata.data) do
        local cardDef = cardEval.card_defs[cardId]
        if cardDef then
            -- Enrich card definition
            cardDef.rarity = meta.rarity
            cardDef.tags = meta.tags

            -- Register with shop
            ShopSystem.registerCard(cardDef)
        end
    end

    -- Register trigger cards
    for cardId, meta in pairs(CardMetadata.triggerData) do
        local triggerDef = cardEval.trigger_card_defs[cardId]
        if triggerDef then
            -- Enrich trigger definition
            triggerDef.rarity = meta.rarity
            triggerDef.tags = meta.tags

            -- Register with shop
            ShopSystem.registerCard(triggerDef)
        end
    end

    print(string.format("[CardMetadata] Registered %d cards with shop",
        CardMetadata.getCount()))
end

--- Gets count of cards with metadata
--- @return number Count
function CardMetadata.getCount()
    local count = 0
    for _ in pairs(CardMetadata.data) do
        count = count + 1
    end
    for _ in pairs(CardMetadata.triggerData) do
        count = count + 1
    end
    return count
end

--- Gets rarity distribution
--- @return table Map of rarity -> count
function CardMetadata.getRarityDistribution()
    local dist = { common = 0, uncommon = 0, rare = 0, legendary = 0 }

    for _, meta in pairs(CardMetadata.data) do
        dist[meta.rarity] = (dist[meta.rarity] or 0) + 1
    end

    for _, meta in pairs(CardMetadata.triggerData) do
        dist[meta.rarity] = (dist[meta.rarity] or 0) + 1
    end

    return dist
end

--- Prints summary
function CardMetadata.printSummary()
    print("\n[CardMetadata] Summary:")
    print(string.format("  Total cards: %d", CardMetadata.getCount()))

    local dist = CardMetadata.getRarityDistribution()
    print("  Rarity distribution:")
    print(string.format("    Common: %d", dist.common))
    print(string.format("    Uncommon: %d", dist.uncommon))
    print(string.format("    Rare: %d", dist.rare))
    print(string.format("    Legendary: %d", dist.legendary))
end

return CardMetadata
