--[[
================================================================================
CARD SYNERGY SYSTEM - Tag-Based Sets and Curated Combos
================================================================================
Manages card synergies through two mechanisms:
1. Tag-based sets: Any 3/6/9 cards with same tag = bonus
2. Curated combos: Specific card combinations with unique effects

Key Features:
- Flexible tag system (mobility, defense, hazard, brute, elemental, tactical)
- Threshold-based bonuses (3/6/9 cards)
- Curated combo framework for hand-crafted synergies
- Bonus application to player stats or wand modifiers
- Visual feedback for active sets

Usage Example:
  -- Detect active sets
  local activeSets = CardSynergy.detectSets(wandCardList)
  -- Returns: { mobility = 6, defense = 3 }

  -- Apply bonuses to player
  CardSynergy.applySetBonuses(player, activeSets)

  -- Get bonus details for UI
  local bonusInfo = CardSynergy.getActiveBonusInfo(activeSets)

================================================================================
]] --

local CardSynergy = {}

-- ============================================================================
-- TAG DEFINITIONS
-- ============================================================================

CardSynergy.tags = {
    mobility = {
        name = "Mobility",
        description = "Swift movement and evasion",
        color = "#4A90E2", -- Blue
        icon = "icon_mobility"
    },
    defense = {
        name = "Defense",
        description = "Protection and damage mitigation",
        color = "#50C878", -- Green
        icon = "icon_defense"
    },
    hazard = {
        name = "Hazard",
        description = "Area denial and damage over time",
        color = "#FF6B6B", -- Red
        icon = "icon_hazard"
    },
    brute = {
        name = "Brute",
        description = "Raw damage and impact",
        color = "#D35400", -- Dark Orange
        icon = "icon_brute"
    },
    elemental = {
        name = "Elemental",
        description = "Fire, ice, and lightning power",
        color = "#9B59B6", -- Purple
        icon = "icon_elemental"
    },
    tactical = {
        name = "Tactical",
        description = "Precision and control",
        color = "#F39C12", -- Gold
        icon = "icon_tactical"
    }
}

-- ============================================================================
-- SET BONUS DEFINITIONS
-- ============================================================================

--- Set bonuses for tag-based synergies
--- Structure: { tagName = { [threshold] = { statName = value, ... } } }
CardSynergy.setBonuses = {
    mobility = {
        [3] = {
            cast_speed = 10,
            projectile_speed = 15,
            description = "Swift Caster I: +10% cast speed, +15% projectile speed"
        },
        [6] = {
            cast_speed = 25,
            projectile_speed = 30,
            dash_cooldown_reduction = 20,
            description = "Swift Caster II: +25% cast speed, +30% projectile speed, -20% dash cooldown"
        },
        [9] = {
            cast_speed = 50,
            projectile_speed = 50,
            dash_cooldown_reduction = 40,
            phase_chance = 15,
            description =
            "Swift Caster III: +50% cast speed, +50% projectile speed, -40% dash cooldown, 15% phase chance"
        }
    },

    defense = {
        [3] = {
            armor = 10,
            block_chance_pct = 5,
            description = "Stalwart I: +10 armor, +5% block chance"
        },
        [6] = {
            armor = 25,
            block_chance_pct = 15,
            damage_reduction_pct = 10,
            description = "Stalwart II: +25 armor, +15% block chance, +10% damage reduction"
        },
        [9] = {
            armor = 50,
            block_chance_pct = 30,
            damage_reduction_pct = 25,
            reflect_damage_pct = 20,
            description = "Stalwart III: +50 armor, +30% block chance, +25% damage reduction, 20% reflect damage"
        }
    },

    hazard = {
        [3] = {
            dot_damage_pct = 20,
            area_of_effect_pct = 15,
            description = "Hazardous I: +20% DoT damage, +15% area of effect"
        },
        [6] = {
            dot_damage_pct = 50,
            area_of_effect_pct = 30,
            dot_duration_pct = 25,
            description = "Hazardous II: +50% DoT damage, +30% area of effect, +25% DoT duration"
        },
        [9] = {
            dot_damage_pct = 100,
            area_of_effect_pct = 50,
            dot_duration_pct = 50,
            chain_hazards = true,
            description = "Hazardous III: +100% DoT damage, +50% area of effect, +50% DoT duration, hazards chain"
        }
    },

    brute = {
        [3] = {
            all_damage_pct = 15,
            knockback_strength = 10,
            description = "Brute Force I: +15% all damage, +10% knockback"
        },
        [6] = {
            all_damage_pct = 35,
            knockback_strength = 25,
            crit_damage_pct = 20,
            description = "Brute Force II: +35% all damage, +25% knockback, +20% crit damage"
        },
        [9] = {
            all_damage_pct = 75,
            knockback_strength = 50,
            crit_damage_pct = 50,
            stun_chance_pct = 15,
            description = "Brute Force III: +75% all damage, +50% knockback, +50% crit damage, 15% stun chance"
        }
    },

    elemental = {
        [3] = {
            fire_modifier_pct = 15,
            cold_modifier_pct = 15,
            lightning_modifier_pct = 15,
            description = "Elemental I: +15% fire/cold/lightning damage"
        },
        [6] = {
            fire_modifier_pct = 35,
            cold_modifier_pct = 35,
            lightning_modifier_pct = 35,
            elemental_resistance_reduction = 10,
            description = "Elemental II: +35% fire/cold/lightning damage, -10% enemy resistances"
        },
        [9] = {
            fire_modifier_pct = 75,
            cold_modifier_pct = 75,
            lightning_modifier_pct = 75,
            elemental_resistance_reduction = 25,
            elemental_chain_chance = 20,
            description = "Elemental III: +75% fire/cold/lightning damage, -25% enemy resistances, 20% chain chance"
        }
    },

    tactical = {
        [3] = {
            crit_chance_pct = 10,
            accuracy = 15,
            description = "Tactical I: +10% crit chance, +15% accuracy"
        },
        [6] = {
            crit_chance_pct = 25,
            accuracy = 30,
            cooldown_reduction_pct = 15,
            description = "Tactical II: +25% crit chance, +30% accuracy, -15% cooldowns"
        },
        [9] = {
            crit_chance_pct = 50,
            accuracy = 50,
            cooldown_reduction_pct = 30,
            guaranteed_crit_on_first_hit = true,
            description = "Tactical III: +50% crit chance, +50% accuracy, -30% cooldowns, guaranteed crit on first hit"
        }
    }
}

-- ============================================================================
-- CURATED COMBO DEFINITIONS
-- ============================================================================

--- Curated combos: specific card combinations with unique effects
--- Structure: { comboId = { cards = {id1, id2, id3}, bonus = {...}, description = "..." } }
CardSynergy.curatedCombos = {
    -- Example: Flame Trinity (3 specific fire cards)
    flame_trinity = {
        name = "Flame Trinity",
        description = "Projectiles leave burning trails",
        cards = { "ACTION_EXPLOSIVE_FIRE_PROJECTILE", "MOD_EXPLOSIVE", "MOD_BURN_ON_HIT" },
        bonus = {
            burn_trail = true,
            fire_modifier_pct = 50,
            burn_duration_pct = 100
        },
        icon = "icon_flame_trinity"
    },

    -- Example: Ice Fortress (defensive ice combo)
    ice_fortress = {
        name = "Ice Fortress",
        description = "Frozen enemies create ice walls",
        cards = { "ACTION_ICE_SHARD", "MOD_FREEZE_ON_HIT", "MOD_AREA_EFFECT" },
        bonus = {
            freeze_creates_wall = true,
            cold_modifier_pct = 40,
            armor = 30
        },
        icon = "icon_ice_fortress"
    }

    -- Add more curated combos here as needed
}

-- ============================================================================
-- SET DETECTION
-- ============================================================================

--- Detects active tag-based sets from a list of cards
--- @param cardList table Array of card instances (must have .tags field)
--- @return table Map of tagName -> count
function CardSynergy.detectSets(cardList)
    local tagCounts = {}

    for _, card in ipairs(cardList) do
        if card.tags then
            for _, tag in ipairs(card.tags) do
                tagCounts[tag] = (tagCounts[tag] or 0) + 1
            end
        end
    end

    return tagCounts
end

--- Detects active curated combos from a list of cards
--- @param cardList table Array of card instances (must have .id field)
--- @return table Array of active combo IDs
function CardSynergy.detectCuratedCombos(cardList)
    local activeCombos = {}
    local cardIds = {}

    -- Build set of card IDs
    for _, card in ipairs(cardList) do
        if card.id then
            cardIds[card.id] = true
        end
    end

    -- Check each curated combo
    for comboId, comboDef in pairs(CardSynergy.curatedCombos) do
        local hasAllCards = true
        for _, requiredCardId in ipairs(comboDef.cards) do
            if not cardIds[requiredCardId] then
                hasAllCards = false
                break
            end
        end

        if hasAllCards then
            table.insert(activeCombos, comboId)
        end
    end

    return activeCombos
end

-- ============================================================================
-- BONUS CALCULATION
-- ============================================================================

--- Gets the highest active bonus tier for a tag
--- @param tagName string Tag name
--- @param count number Number of cards with this tag
--- @return number|nil Threshold (3, 6, or 9), or nil if no bonus active
function CardSynergy.getActiveTier(tagName, count)
    local bonuses = CardSynergy.setBonuses[tagName]
    if not bonuses then return nil end

    -- Find highest threshold met
    local activeTier = nil
    for threshold, _ in pairs(bonuses) do
        if count >= threshold then
            if not activeTier or threshold > activeTier then
                activeTier = threshold
            end
        end
    end

    return activeTier
end

--- Gets all active set bonuses from tag counts
--- @param tagCounts table Result from detectSets
--- @return table Map of tagName -> { tier = number, bonus = table }
function CardSynergy.getActiveBonuses(tagCounts)
    local activeBonuses = {}

    for tagName, count in pairs(tagCounts) do
        local tier = CardSynergy.getActiveTier(tagName, count)
        if tier then
            local bonus = CardSynergy.setBonuses[tagName][tier]
            activeBonuses[tagName] = {
                tier = tier,
                count = count,
                bonus = bonus
            }
        end
    end

    return activeBonuses
end

--- Gets bonus info for UI display
--- @param tagCounts table Result from detectSets
--- @return table Array of { tagName, tier, count, description, color }
function CardSynergy.getActiveBonusInfo(tagCounts)
    local bonusInfo = {}
    local activeBonuses = CardSynergy.getActiveBonuses(tagCounts)

    for tagName, bonusData in pairs(activeBonuses) do
        local tagDef = CardSynergy.tags[tagName]
        table.insert(bonusInfo, {
            tagName = tagName,
            displayName = tagDef.name,
            tier = bonusData.tier,
            count = bonusData.count,
            description = bonusData.bonus.description,
            color = tagDef.color,
            icon = tagDef.icon
        })
    end

    -- Sort by tier descending
    table.sort(bonusInfo, function(a, b) return a.tier > b.tier end)

    return bonusInfo
end

-- ============================================================================
-- BONUS APPLICATION
-- ============================================================================

--- Applies set bonuses to an entity's stats
--- @param entity table Entity with stats (must have entity.stats)
--- @param tagCounts table Result from detectSets
function CardSynergy.applySetBonuses(entity, tagCounts)
    if not entity.stats then
        error("[CardSynergy] Entity missing stats object")
    end

    local activeBonuses = CardSynergy.getActiveBonuses(tagCounts)

    for tagName, bonusData in pairs(activeBonuses) do
        local bonus = bonusData.bonus

        -- Apply each stat bonus
        for statName, value in pairs(bonus) do
            if statName ~= "description" and type(value) == "number" then
                -- Determine if percentage or flat
                if statName:match("_pct$") or statName:match("_reduction$") then
                    entity.stats:add_add_pct(statName, value)
                else
                    entity.stats:add_base(statName, value)
                end
            end
        end

        print(string.format("[CardSynergy] Applied %s set bonus (tier %d)", tagName, bonusData.tier))
    end
end

--- Applies set bonuses to wand modifiers (alternative to entity stats)
--- @param modifierAggregate table Modifier aggregate from WandModifiers
--- @param tagCounts table Result from detectSets
function CardSynergy.applySetBonusesToModifiers(modifierAggregate, tagCounts)
    local activeBonuses = CardSynergy.getActiveBonuses(tagCounts)

    for tagName, bonusData in pairs(activeBonuses) do
        local bonus = bonusData.bonus

        -- Map set bonuses to modifier aggregate fields
        if bonus.cast_speed then
            modifierAggregate.castSpeedBonus = (modifierAggregate.castSpeedBonus or 0) + bonus.cast_speed
        end
        if bonus.projectile_speed then
            modifierAggregate.speedMultiplier = modifierAggregate.speedMultiplier * (1 + bonus.projectile_speed / 100)
        end
        if bonus.all_damage_pct then
            modifierAggregate.damageMultiplier = modifierAggregate.damageMultiplier * (1 + bonus.all_damage_pct / 100)
        end
        if bonus.area_of_effect_pct then
            modifierAggregate.explosionRadiusMultiplier = (modifierAggregate.explosionRadiusMultiplier or 1.0) *
            (1 + bonus.area_of_effect_pct / 100)
        end

        -- Add special flags
        if bonus.chain_hazards then
            modifierAggregate.chainHazards = true
        end
        if bonus.guaranteed_crit_on_first_hit then
            modifierAggregate.guaranteedFirstCrit = true
        end

        print(string.format("[CardSynergy] Applied %s set bonus to modifiers (tier %d)", tagName, bonusData.tier))
    end
end

--- Applies curated combo bonuses
--- @param entity table Entity with stats
--- @param activeCombos table Array of combo IDs from detectCuratedCombos
function CardSynergy.applyCuratedCombos(entity, activeCombos)
    for _, comboId in ipairs(activeCombos) do
        local comboDef = CardSynergy.curatedCombos[comboId]
        if comboDef then
            local bonus = comboDef.bonus

            -- Apply stat bonuses
            for statName, value in pairs(bonus) do
                if type(value) == "number" then
                    if statName:match("_pct$") then
                        entity.stats:add_add_pct(statName, value)
                    else
                        entity.stats:add_base(statName, value)
                    end
                end
            end

            print(string.format("[CardSynergy] Applied curated combo: %s", comboDef.name))
        end
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Gets progress toward next tier for a tag
--- @param tagName string Tag name
--- @param count number Current count
--- @return number|nil Next threshold, or nil if maxed
--- @return number|nil Cards needed to reach next threshold
function CardSynergy.getProgressToNextTier(tagName, count)
    local bonuses = CardSynergy.setBonuses[tagName]
    if not bonuses then return nil, nil end

    local thresholds = { 3, 6, 9 }
    for _, threshold in ipairs(thresholds) do
        if count < threshold then
            return threshold, threshold - count
        end
    end

    return nil, nil -- Already at max tier
end

--- Lists all available tags (for UI)
--- @return table Array of tag definitions
function CardSynergy.listTags()
    local tags = {}
    for tagName, tagDef in pairs(CardSynergy.tags) do
        table.insert(tags, {
            id = tagName,
            name = tagDef.name,
            description = tagDef.description,
            color = tagDef.color,
            icon = tagDef.icon
        })
    end
    table.sort(tags, function(a, b) return a.name < b.name end)
    return tags
end

--- Lists all curated combos (for UI)
--- @return table Array of combo definitions
function CardSynergy.listCuratedCombos()
    local combos = {}
    for comboId, comboDef in pairs(CardSynergy.curatedCombos) do
        table.insert(combos, {
            id = comboId,
            name = comboDef.name,
            description = comboDef.description,
            cards = comboDef.cards,
            icon = comboDef.icon
        })
    end
    table.sort(combos, function(a, b) return a.name < b.name end)
    return combos
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function CardSynergy.init()
    print("[CardSynergy] Initialized with", #CardSynergy.listTags(), "tags and", #CardSynergy.listCuratedCombos(),
        "curated combos")
end

return CardSynergy
