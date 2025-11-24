--[[
================================================================================
CARD UPGRADE SYSTEM - Progressive Card Leveling (1-3)
================================================================================
Manages card upgrades from level 1 to level 3 with:
- Stat scaling (damage, speed, radius, etc.)
- Custom behavior hooks (trigger chances, special effects)
- Upgrade cost calculation
- Visual distinction (★, ★★, ★★★)

Key Features:
- Data-driven upgrade paths per card type
- Custom behavior system for non-stat upgrades
- Upgrade preview for UI
- Level tracking per card instance

Usage Example:
  -- Upgrade a card
  local success, newCard = CardUpgrade.upgradeCard(cardInstance)

  -- Get upgrade cost
  local cost = CardUpgrade.getUpgradeCost(cardInstance)

  -- Preview next level
  local preview = CardUpgrade.getUpgradePreview(cardInstance)

  -- Register custom behavior
  CardUpgrade.registerCustomBehavior("ACTION_BOLT", 3, "trigger_chain_lightning", {
    chance = 25,
    targets = 3
  })

================================================================================
]] --

local CardUpgrade = {}

-- ============================================================================
-- UPGRADE PATH DEFINITIONS
-- ============================================================================

--- Upgrade paths define stat changes per level
--- Structure: { cardId = { [level] = { stat = value, ... } } }
CardUpgrade.upgradePaths = {
    -- ACTIONS
    ACTION_BASIC_PROJECTILE = {
        [1] = {
            damage = 10,
            speed = 300,
            lifetime = 2.0
        },
        [2] = {
            damage = 15,
            speed = 350,
            lifetime = 2.5,
            pierce_count = 1
        },
        [3] = {
            damage = 22,
            speed = 400,
            lifetime = 3.0,
            pierce_count = 2,
            explosion_radius = 30
        }
    },

    ACTION_FAST_ACCURATE_PROJECTILE = {
        [1] = {
            damage = 8,
            speed = 450,
            lifetime = 1.5
        },
        [2] = {
            damage = 12,
            speed = 550,
            lifetime = 2.0,
            accuracy_bonus = 15
        },
        [3] = {
            damage = 18,
            speed = 650,
            lifetime = 2.5,
            accuracy_bonus = 30,
            crit_chance_bonus = 10
        }
    },

    ACTION_SLOW_ORB = {
        [1] = {
            damage = 20,
            speed = 150,
            lifetime = 3.0
        },
        [2] = {
            damage = 30,
            speed = 175,
            lifetime = 4.0,
            size_multiplier = 1.2
        },
        [3] = {
            damage = 45,
            speed = 200,
            lifetime = 5.0,
            size_multiplier = 1.5,
            gravity_well = true
        }
    },

    ACTION_EXPLOSIVE_FIRE_PROJECTILE = {
        [1] = {
            damage = 15,
            explosion_radius = 50,
            speed = 300
        },
        [2] = {
            damage = 25,
            explosion_radius = 75,
            speed = 350,
            burn_duration = 2.0
        },
        [3] = {
            damage = 40,
            explosion_radius = 100,
            speed = 400,
            burn_duration = 3.0,
            chain_explosion_chance = 30
        }
    },

    -- MODIFIERS
    MOD_HOMING = {
        [1] = {
            homing_strength = 5,
            turn_rate = 1.0
        },
        [2] = {
            homing_strength = 10,
            turn_rate = 1.5,
            lock_on_range = 200
        },
        [3] = {
            homing_strength = 15,
            turn_rate = 2.0,
            lock_on_range = 300,
            auto_aim = true
        }
    },

    MOD_EXPLOSIVE = {
        [1] = {
            explosion_radius = 60,
            explosion_damage_mult = 1.0
        },
        [2] = {
            explosion_radius = 90,
            explosion_damage_mult = 1.3,
            knockback_strength = 15
        },
        [3] = {
            explosion_radius = 120,
            explosion_damage_mult = 1.6,
            knockback_strength = 30,
            stun_duration = 1.0
        }
    },

    MOD_PIERCE = {
        [1] = {
            pierce_count = 2
        },
        [2] = {
            pierce_count = 4,
            pierce_damage_retention = 0.9
        },
        [3] = {
            pierce_count = 6,
            pierce_damage_retention = 1.0,
            pierce_creates_projectile = true
        }
    },

    -- MULTICASTS
    MULTI_TRIPLE_CAST = {
        [1] = {
            multicast_count = 3,
            spread_angle = 15
        },
        [2] = {
            multicast_count = 4,
            spread_angle = 20,
            damage_bonus = 10
        },
        [3] = {
            multicast_count = 5,
            spread_angle = 25,
            damage_bonus = 20,
            cast_delay_reduction = 20
        }
    }
}

-- ============================================================================
-- CUSTOM BEHAVIOR REGISTRY
-- ============================================================================

--- Custom behaviors for non-stat upgrades
--- Structure: { cardId = { [level] = { behaviorId = params } } }
--- These are applied as special flags/hooks during card execution
CardUpgrade.customBehaviors = {
    ACTION_BASIC_PROJECTILE = {
        [3] = {
            on_hit_explosion = {
                enabled = true,
                radius = 30,
                damage_mult = 0.5
            }
        }
    },

    ACTION_SLOW_ORB = {
        [3] = {
            gravity_well = {
                enabled = true,
                pull_strength = 50,
                radius = 100
            }
        }
    },

    ACTION_EXPLOSIVE_FIRE_PROJECTILE = {
        [3] = {
            chain_explosion = {
                enabled = true,
                chance = 30,
                max_chains = 2,
                damage_mult = 0.7
            }
        }
    },

    MOD_PIERCE = {
        [3] = {
            pierce_spawn_projectile = {
                enabled = true,
                projectile_type = "ACTION_BASIC_PROJECTILE",
                angle_offset = 90
            }
        }
    }
}

-- ============================================================================
-- CARD INSTANCE MANAGEMENT
-- ============================================================================

--- Initializes upgrade tracking on a card instance
--- @param card table Card instance
function CardUpgrade.initializeCard(card)
    if not card.level then
        card.level = 1
    end
    if not card.upgrade_count then
        card.upgrade_count = 0
    end
    if not card.max_level then
        card.max_level = 3
    end
end

--- Checks if a card can be upgraded
--- @param card table Card instance
--- @return boolean True if upgradeable
--- @return string|nil Reason if not upgradeable
function CardUpgrade.canUpgrade(card)
    CardUpgrade.initializeCard(card)

    if card.level >= card.max_level then
        return false, "Already at max level"
    end

    local upgradePath = CardUpgrade.upgradePaths[card.id]
    if not upgradePath then
        return false, "No upgrade path defined"
    end

    if not upgradePath[card.level + 1] then
        return false, "Next level not defined"
    end

    return true
end

-- ============================================================================
-- UPGRADE EXECUTION
-- ============================================================================

--- Upgrades a card to the next level
--- @param card table Card instance (will be modified)
--- @return boolean Success
--- @return table|nil Upgraded card (same reference as input)
function CardUpgrade.upgradeCard(card)
    local canUpgrade, reason = CardUpgrade.canUpgrade(card)
    if not canUpgrade then
        print(string.format("[CardUpgrade] Cannot upgrade %s: %s", card.id, reason))
        return false, nil
    end

    local oldLevel = card.level
    local newLevel = oldLevel + 1

    -- Get upgrade path for new level
    local upgradePath = CardUpgrade.upgradePaths[card.id]
    local newStats = upgradePath[newLevel]

    -- Apply stat changes
    for statName, value in pairs(newStats) do
        card[statName] = value
    end

    -- Apply custom behaviors
    local customBehavior = CardUpgrade.customBehaviors[card.id]
    if customBehavior and customBehavior[newLevel] then
        if not card.custom_behaviors then
            card.custom_behaviors = {}
        end
        for behaviorId, params in pairs(customBehavior[newLevel]) do
            card.custom_behaviors[behaviorId] = params
        end
    end

    -- Update level tracking
    card.level = newLevel
    card.upgrade_count = card.upgrade_count + 1

    print(string.format("[CardUpgrade] Upgraded %s from level %d to %d", card.id, oldLevel, newLevel))

    return true, card
end

-- ============================================================================
-- UPGRADE COST CALCULATION
-- ============================================================================

--- Gets the gold cost to upgrade a card
--- @param card table Card instance
--- @return number|nil Cost in gold, or nil if not upgradeable
function CardUpgrade.getUpgradeCost(card)
    local canUpgrade, reason = CardUpgrade.canUpgrade(card)
    if not canUpgrade then
        return nil
    end

    -- Cost scales with level: 3g for 1->2, 5g for 2->3
    local costTable = {
        [1] = 3, -- Level 1 -> 2
        [2] = 5 -- Level 2 -> 3
    }

    return costTable[card.level] or 0
end

-- ============================================================================
-- UPGRADE PREVIEW
-- ============================================================================

--- Gets a preview of what upgrading would change
--- @param card table Card instance
--- @return table|nil Preview data { level, stats, behaviors, cost }
function CardUpgrade.getUpgradePreview(card)
    local canUpgrade, reason = CardUpgrade.canUpgrade(card)
    if not canUpgrade then
        return nil
    end

    local newLevel = card.level + 1
    local upgradePath = CardUpgrade.upgradePaths[card.id]
    local newStats = upgradePath[newLevel]

    local preview = {
        currentLevel = card.level,
        newLevel = newLevel,
        cost = CardUpgrade.getUpgradeCost(card),
        statChanges = {},
        newBehaviors = {}
    }

    -- Calculate stat changes
    for statName, newValue in pairs(newStats) do
        local oldValue = card[statName]
        if oldValue then
            preview.statChanges[statName] = {
                old = oldValue,
                new = newValue,
                delta = newValue - oldValue
            }
        else
            preview.statChanges[statName] = {
                old = 0,
                new = newValue,
                delta = newValue,
                isNew = true
            }
        end
    end

    -- List new behaviors
    local customBehavior = CardUpgrade.customBehaviors[card.id]
    if customBehavior and customBehavior[newLevel] then
        for behaviorId, params in pairs(customBehavior[newLevel]) do
            preview.newBehaviors[behaviorId] = params
        end
    end

    return preview
end

--- Formats upgrade preview for display
--- @param preview table Result from getUpgradePreview
--- @return string Formatted text
function CardUpgrade.formatUpgradePreview(preview)
    if not preview then
        return "Cannot upgrade"
    end

    local lines = {}
    table.insert(lines, string.format("Upgrade to Level %d (Cost: %dg)", preview.newLevel, preview.cost))
    table.insert(lines, "")
    table.insert(lines, "Stat Changes:")

    for statName, change in pairs(preview.statChanges) do
        if change.isNew then
            table.insert(lines, string.format("  %s: NEW -> %.1f", statName, change.new))
        else
            local sign = change.delta >= 0 and "+" or ""
            table.insert(lines, string.format("  %s: %.1f -> %.1f (%s%.1f)",
                statName, change.old, change.new, sign, change.delta))
        end
    end

    if next(preview.newBehaviors) then
        table.insert(lines, "")
        table.insert(lines, "New Behaviors:")
        for behaviorId, _ in pairs(preview.newBehaviors) do
            table.insert(lines, string.format("  - %s", behaviorId))
        end
    end

    return table.concat(lines, "\n")
end

-- ============================================================================
-- CUSTOM BEHAVIOR REGISTRATION
-- ============================================================================

--- Registers a custom behavior for a card at a specific level
--- @param cardId string Card ID
--- @param level number Level (1-3)
--- @param behaviorId string Behavior identifier
--- @param params table Behavior parameters
function CardUpgrade.registerCustomBehavior(cardId, level, behaviorId, params)
    if not CardUpgrade.customBehaviors[cardId] then
        CardUpgrade.customBehaviors[cardId] = {}
    end
    if not CardUpgrade.customBehaviors[cardId][level] then
        CardUpgrade.customBehaviors[cardId][level] = {}
    end

    CardUpgrade.customBehaviors[cardId][level][behaviorId] = params

    print(string.format("[CardUpgrade] Registered custom behavior: %s level %d -> %s",
        cardId, level, behaviorId))
end

--- Gets custom behaviors for a card instance
--- @param card table Card instance
--- @return table Map of behaviorId -> params
function CardUpgrade.getCustomBehaviors(card)
    return card.custom_behaviors or {}
end

--- Checks if a card has a specific custom behavior
--- @param card table Card instance
--- @param behaviorId string Behavior identifier
--- @return boolean True if behavior is active
--- @return table|nil Behavior parameters
function CardUpgrade.hasCustomBehavior(card, behaviorId)
    local behaviors = CardUpgrade.getCustomBehaviors(card)
    if behaviors[behaviorId] then
        return true, behaviors[behaviorId]
    end
    return false, nil
end

-- ============================================================================
-- VISUAL HELPERS
-- ============================================================================

--- Gets visual indicator for card level (★, ★★, ★★★)
--- @param card table Card instance
--- @return string Star indicator
function CardUpgrade.getLevelIndicator(card)
    CardUpgrade.initializeCard(card)
    local stars = { "★", "★★", "★★★" }
    return stars[card.level] or "?"
end

--- Gets color for card level
--- @param card table Card instance
--- @return string Hex color
function CardUpgrade.getLevelColor(card)
    CardUpgrade.initializeCard(card)
    local colors = {
        [1] = "#FFFFFF", -- White
        [2] = "#4A90E2", -- Blue
        [3] = "#F39C12" -- Gold
    }
    return colors[card.level] or "#FFFFFF"
end

-- ============================================================================
-- BATCH OPERATIONS
-- ============================================================================

--- Registers an upgrade path for a card
--- @param cardId string Card ID
--- @param upgradePath table Upgrade path definition
function CardUpgrade.registerUpgradePath(cardId, upgradePath)
    CardUpgrade.upgradePaths[cardId] = upgradePath
    print(string.format("[CardUpgrade] Registered upgrade path for %s", cardId))
end

--- Lists all cards with upgrade paths
--- @return table Array of card IDs
function CardUpgrade.listUpgradeableCards()
    local cards = {}
    for cardId, _ in pairs(CardUpgrade.upgradePaths) do
        table.insert(cards, cardId)
    end
    table.sort(cards)
    return cards
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CardUpgrade.init()
    local count = 0
    for _ in pairs(CardUpgrade.upgradePaths) do
        count = count + 1
    end
    print(string.format("[CardUpgrade] Initialized with %d upgrade paths", count))
end

return CardUpgrade
