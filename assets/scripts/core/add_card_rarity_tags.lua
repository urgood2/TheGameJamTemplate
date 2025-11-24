--[[
================================================================================
CARD RARITY AND TAG ASSIGNMENT SCRIPT
================================================================================
This script adds rarity and tags to all existing card definitions.

Rarity Guidelines:
- Common: Basic, straightforward effects
- Uncommon: Enhanced effects, useful modifiers
- Rare: Powerful effects, complex mechanics
- Legendary: Game-changing effects, unique mechanics

Tag Guidelines:
- brute: Raw damage, knockback, heavy hits
- tactical: Precision, crit, accuracy, control
- mobility: Speed, teleport, dash-related
- defense: Shields, healing, damage reduction
- hazard: DoTs, area denial, lingering effects
- elemental: Fire, ice, lightning, magic damage

Usage:
  lua assets/scripts/core/add_card_rarity_tags.lua

================================================================================
]] --

-- Card rarity and tag assignments
local cardAssignments = {
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

-- Trigger card assignments
local triggerAssignments = {
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

-- Print summary
print("\n" .. string.rep("=", 60))
print("CARD RARITY AND TAG ASSIGNMENTS")
print(string.rep("=", 60))

print("\nAction/Modifier Cards:")
local rarityCount = { common = 0, uncommon = 0, rare = 0, legendary = 0 }
for cardId, assignment in pairs(cardAssignments) do
    rarityCount[assignment.rarity] = rarityCount[assignment.rarity] + 1
    local tagStr = table.concat(assignment.tags, ", ")
    print(string.format("  %-35s [%-10s] %s", cardId, assignment.rarity, tagStr))
end

print("\nTrigger Cards:")
for cardId, assignment in pairs(triggerAssignments) do
    local tagStr = table.concat(assignment.tags, ", ")
    print(string.format("  %-35s [%-10s] %s", cardId, assignment.rarity, tagStr))
end

print("\nRarity Distribution:")
print(string.format("  Common: %d", rarityCount.common))
print(string.format("  Uncommon: %d", rarityCount.uncommon))
print(string.format("  Rare: %d", rarityCount.rare))
print(string.format("  Legendary: %d", rarityCount.legendary))
print(string.format("  Total: %d", rarityCount.common + rarityCount.uncommon + rarityCount.rare + rarityCount.legendary))

print("\n" .. string.rep("=", 60))

-- Export for use in other scripts
return {
    cardAssignments = cardAssignments,
    triggerAssignments = triggerAssignments
}
