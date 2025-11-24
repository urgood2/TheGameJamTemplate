--[[
================================================================================
SHOP SYSTEM - Between-Round Card Shop
================================================================================
Manages shop mechanics including:
- Card offerings (triggers, modifiers, actions with rarity)
- Interest system (1g per 10g, max 5g)
- Lock system (preserve offerings between rerolls)
- Escalating reroll costs (2g, 3g, 4g...)
- Card upgrades and removal

Key Features:
- Weighted random selection based on rarity
- Player level scaling for card pool
- Lock individual offerings
- Interest calculation
- Upgrade and removal services

Usage Example:
  -- Generate shop offerings
  local shop = ShopSystem.generateShop(playerLevel, playerGold)

  -- Purchase a card
  local success, card = ShopSystem.purchaseCard(shop, slotIndex, player)

  -- Lock an offering
  ShopSystem.lockOffering(shop, slotIndex)

  -- Reroll unlocked offerings
  ShopSystem.rerollOfferings(shop, player)

  -- Calculate interest
  local interest = ShopSystem.calculateInterest(playerGold)

================================================================================
]] --

local ShopSystem = {}

-- Dependencies (will be required at runtime)
local CardUpgrade = nil -- Lazy loaded

-- ============================================================================
-- SHOP CONFIGURATION
-- ============================================================================

ShopSystem.config = {
    offerSlots = 5,       -- Number of card offerings
    baseRerollCost = 2,   -- Starting reroll cost
    rerollCostIncrease = 1, -- Cost increase per reroll
    interestRate = 1,     -- 1 gold per 10 gold
    interestThreshold = 10, -- Gold needed for 1 interest
    maxInterest = 5,      -- Maximum interest per round
    interestCap = 50,     -- Max gold that counts for interest

    -- Service costs
    removalCost = 2, -- Cost to remove a card (TBC)

    -- Card type distribution
    typeWeights = {
        trigger = 15, -- 15% triggers
        modifier = 40, -- 40% modifiers
        action = 45 -- 45% actions
    }
}

-- ============================================================================
-- RARITY DEFINITIONS
-- ============================================================================

ShopSystem.rarities = {
    common = {
        name = "Common",
        color = "#CCCCCC", -- Gray
        weight = 60,   -- 60% chance
        baseCost = 3
    },
    uncommon = {
        name = "Uncommon",
        color = "#4A90E2", -- Blue
        weight = 30,   -- 30% chance
        baseCost = 5
    },
    rare = {
        name = "Rare",
        color = "#9B59B6", -- Purple
        weight = 9,    -- 9% chance
        baseCost = 8
    },
    legendary = {
        name = "Legendary",
        color = "#F39C12", -- Gold
        weight = 1,    -- 1% chance
        baseCost = 12
    }
}

-- ============================================================================
-- CARD POOL REGISTRY
-- ============================================================================

--- Card pool organized by type and rarity
--- This will be populated from card definitions
ShopSystem.cardPool = {
    trigger = {
        common = {},
        uncommon = {},
        rare = {},
        legendary = {}
    },
    modifier = {
        common = {},
        uncommon = {},
        rare = {},
        legendary = {}
    },
    action = {
        common = {},
        uncommon = {},
        rare = {},
        legendary = {}
    }
}

-- ============================================================================
-- CARD POOL MANAGEMENT
-- ============================================================================

--- Registers a card in the shop pool
--- @param cardDef table Card definition (must have id, type, rarity)
function ShopSystem.registerCard(cardDef)
    if not cardDef.id or not cardDef.type or not cardDef.rarity then
        print("[ShopSystem] Warning: Card missing id, type, or rarity:", cardDef.id or "unknown")
        return
    end

    local cardType = cardDef.type
    local rarity = cardDef.rarity

    -- Map card types to shop categories
    local shopType = cardType
    if cardType == "trigger" then
        shopType = "trigger"
    elseif cardType == "modifier" or cardType == "multicast" then
        shopType = "modifier"
    elseif cardType == "action" then
        shopType = "action"
    else
        print("[ShopSystem] Warning: Unknown card type:", cardType)
        return
    end

    if not ShopSystem.cardPool[shopType] then
        ShopSystem.cardPool[shopType] = {
            common = {}, uncommon = {}, rare = {}, legendary = {}
        }
    end

    if not ShopSystem.cardPool[shopType][rarity] then
        print("[ShopSystem] Warning: Unknown rarity:", rarity)
        return
    end

    table.insert(ShopSystem.cardPool[shopType][rarity], cardDef)

    -- print(string.format("[ShopSystem] Registered %s %s: %s", rarity, shopType, cardDef.id))
end

--- Counts cards in the pool
--- @return table Counts by type and rarity
function ShopSystem.getPoolCounts()
    local counts = {}
    for shopType, rarities in pairs(ShopSystem.cardPool) do
        counts[shopType] = {}
        for rarity, cards in pairs(rarities) do
            counts[shopType][rarity] = #cards
        end
    end
    return counts
end

-- ============================================================================
-- WEIGHTED RANDOM SELECTION
-- ============================================================================

--- Selects a rarity based on weights
--- @param playerLevel number Player level (can modify weights)
--- @return string Rarity name
function ShopSystem.selectRarity(playerLevel)
    playerLevel = playerLevel or 1

    -- Build weighted list
    local entries = {}
    for rarity, def in pairs(ShopSystem.rarities) do
        table.insert(entries, {
            item = rarity,
            w = def.weight
        })
    end

    -- Use weighted choice (from combat_system.lua util)
    local sum = 0
    for _, e in ipairs(entries) do
        sum = sum + e.w
    end

    local r = math.random() * sum
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + e.w
        if r <= acc then
            return e.item
        end
    end

    return entries[#entries].item
end

--- Selects a card type based on weights
--- @return string Card type (trigger, modifier, action)
function ShopSystem.selectCardType()
    local entries = {}
    for cardType, weight in pairs(ShopSystem.config.typeWeights) do
        table.insert(entries, { item = cardType, w = weight })
    end

    local sum = 0
    for _, e in ipairs(entries) do
        sum = sum + e.w
    end

    local r = math.random() * sum
    local acc = 0
    for _, e in ipairs(entries) do
        acc = acc + e.w
        if r <= acc then
            return e.item
        end
    end

    return entries[#entries].item
end

--- Selects a random card from the pool
--- @param cardType string Card type (trigger, modifier, action)
--- @param rarity string Rarity
--- @return table|nil Card definition
function ShopSystem.selectCard(cardType, rarity)
    local pool = ShopSystem.cardPool[cardType][rarity]
    if not pool or #pool == 0 then
        return nil
    end

    local index = math.random(1, #pool)
    return pool[index]
end

-- ============================================================================
-- SHOP GENERATION
-- ============================================================================

--- Generates a shop instance
--- @param playerLevel number Player level
--- @param playerGold number Player's current gold
--- @return table Shop instance
function ShopSystem.generateShop(playerLevel, playerGold)
    playerLevel = playerLevel or 1
    playerGold = playerGold or 0

    local shop = {
        playerLevel = playerLevel,
        offerings = {},
        locks = {}, -- Track locked slots
        rerollCount = 0,
        rerollCost = ShopSystem.config.baseRerollCost,
        interest = ShopSystem.calculateInterest(playerGold)
    }

    -- Generate offerings
    for i = 1, ShopSystem.config.offerSlots do
        local offering = ShopSystem.generateOffering(playerLevel)
        table.insert(shop.offerings, offering)
        shop.locks[i] = false -- Initially unlocked
    end

    return shop
end

--- Generates a single offering
--- @param playerLevel number Player level
--- @return table Offering { cardDef, rarity, cost, type }
function ShopSystem.generateOffering(playerLevel)
    local rarity = ShopSystem.selectRarity(playerLevel)
    local cardType = ShopSystem.selectCardType()
    local cardDef = ShopSystem.selectCard(cardType, rarity)

    if not cardDef then
        -- Fallback if pool is empty
        print(string.format("[ShopSystem] Warning: No cards in pool for %s %s", rarity, cardType))
        return {
            cardDef = nil,
            rarity = rarity,
            cardType = cardType,
            cost = 0,
            isEmpty = true
        }
    end

    local rarityDef = ShopSystem.rarities[rarity]
    local cost = rarityDef.baseCost

    return {
        cardDef = cardDef,
        rarity = rarity,
        cardType = cardType,
        cost = cost,
        isEmpty = false
    }
end

-- ============================================================================
-- SHOP ACTIONS
-- ============================================================================

--- Purchases a card from the shop
--- @param shop table Shop instance
--- @param slotIndex number Slot index (1-based)
--- @param player table Player object (must have .gold and .cards)
--- @return boolean Success
--- @return table|nil Card instance
function ShopSystem.purchaseCard(shop, slotIndex, player)
    local offering = shop.offerings[slotIndex]
    if not offering or offering.isEmpty then
        return false, nil
    end

    if player.gold < offering.cost then
        print("[ShopSystem] Not enough gold")
        return false, nil
    end

    -- Deduct gold
    player.gold = player.gold - offering.cost

    -- Create card instance from definition
    local cardInstance = ShopSystem.createCardInstance(offering.cardDef)

    -- Add to player's collection
    if not player.cards then
        player.cards = {}
    end
    table.insert(player.cards, cardInstance)

    -- Mark offering as sold
    offering.isEmpty = true
    offering.sold = true

    print(string.format("[ShopSystem] Purchased %s for %dg", offering.cardDef.id, offering.cost))

    return true, cardInstance
end

--- Locks an offering (prevents reroll)
--- @param shop table Shop instance
--- @param slotIndex number Slot index (1-based)
function ShopSystem.lockOffering(shop, slotIndex)
    shop.locks[slotIndex] = true
    print(string.format("[ShopSystem] Locked slot %d", slotIndex))
end

--- Unlocks an offering
--- @param shop table Shop instance
--- @param slotIndex number Slot index (1-based)
function ShopSystem.unlockOffering(shop, slotIndex)
    shop.locks[slotIndex] = false
    print(string.format("[ShopSystem] Unlocked slot %d", slotIndex))
end

--- Rerolls unlocked offerings
--- @param shop table Shop instance
--- @param player table Player object (must have .gold)
--- @return boolean Success
function ShopSystem.rerollOfferings(shop, player)
    if player.gold < shop.rerollCost then
        print("[ShopSystem] Not enough gold to reroll")
        return false
    end

    -- Deduct gold
    player.gold = player.gold - shop.rerollCost

    -- Reroll unlocked slots
    for i = 1, #shop.offerings do
        if not shop.locks[i] and not shop.offerings[i].sold then
            shop.offerings[i] = ShopSystem.generateOffering(shop.playerLevel)
        end
    end

    -- Increase reroll count and cost
    shop.rerollCount = shop.rerollCount + 1
    shop.rerollCost = ShopSystem.config.baseRerollCost + (shop.rerollCount * ShopSystem.config.rerollCostIncrease)

    print(string.format("[ShopSystem] Rerolled (count: %d, next cost: %dg)", shop.rerollCount, shop.rerollCost))

    return true
end

-- ============================================================================
-- UPGRADE AND REMOVAL SERVICES
-- ============================================================================

--- Upgrades a card (uses CardUpgrade system)
--- @param card table Card instance
--- @param player table Player object (must have .gold)
--- @return boolean Success
--- @return table|nil Upgraded card
function ShopSystem.upgradeCard(card, player)
    -- Lazy load CardUpgrade
    if not CardUpgrade then
        CardUpgrade = require("wand.card_upgrade_system")
    end

    local cost = CardUpgrade.getUpgradeCost(card)
    if not cost then
        print("[ShopSystem] Card cannot be upgraded")
        return false, nil
    end

    if player.gold < cost then
        print("[ShopSystem] Not enough gold to upgrade")
        return false, nil
    end

    -- Deduct gold
    player.gold = player.gold - cost

    -- Upgrade card
    local success, upgradedCard = CardUpgrade.upgradeCard(card)

    if success then
        print(string.format("[ShopSystem] Upgraded card for %dg", cost))
    end

    return success, upgradedCard
end

--- Removes a card from player's collection
--- @param card table Card instance
--- @param player table Player object (must have .gold and .cards)
--- @return boolean Success
function ShopSystem.removeCard(card, player)
    local cost = ShopSystem.config.removalCost

    if player.gold < cost then
        print("[ShopSystem] Not enough gold to remove card")
        return false
    end

    -- Find and remove card
    local found = false
    for i, c in ipairs(player.cards) do
        if c == card then
            table.remove(player.cards, i)
            found = true
            break
        end
    end

    if not found then
        print("[ShopSystem] Card not found in player's collection")
        return false
    end

    -- Deduct gold
    player.gold = player.gold - cost

    print(string.format("[ShopSystem] Removed card for %dg", cost))

    return true
end

-- ============================================================================
-- INTEREST SYSTEM
-- ============================================================================

--- Calculates interest based on player's gold
--- @param playerGold number Player's current gold
--- @return number Interest amount
function ShopSystem.calculateInterest(playerGold)
    local config = ShopSystem.config

    -- Cap gold for interest calculation
    local cappedGold = math.min(playerGold, config.interestCap)

    -- Calculate interest: 1g per 10g
    local interest = math.floor(cappedGold / config.interestThreshold) * config.interestRate

    -- Cap interest
    interest = math.min(interest, config.maxInterest)

    return interest
end

--- Applies interest to player's gold
--- @param player table Player object (must have .gold)
--- @return number Interest amount added
function ShopSystem.applyInterest(player)
    local interest = ShopSystem.calculateInterest(player.gold)
    player.gold = player.gold + interest

    print(string.format("[ShopSystem] Applied %dg interest (total: %dg)", interest, player.gold))

    return interest
end

-- ============================================================================
-- CARD INSTANCE CREATION
-- ============================================================================

--- Creates a card instance from a definition
--- @param cardDef table Card definition
--- @return table Card instance
function ShopSystem.createCardInstance(cardDef)
    -- Deep copy card definition
    local instance = {}
    for k, v in pairs(cardDef) do
        if type(v) == "table" then
            instance[k] = {}
            for k2, v2 in pairs(v) do
                instance[k][k2] = v2
            end
        else
            instance[k] = v
        end
    end

    -- Initialize upgrade tracking
    if not CardUpgrade then
        CardUpgrade = require("wand.card_upgrade_system")
    end
    CardUpgrade.initializeCard(instance)

    return instance
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Formats shop for display
--- @param shop table Shop instance
--- @return string Formatted text
function ShopSystem.formatShop(shop)
    local lines = {}
    table.insert(lines, "=== SHOP ===")
    table.insert(lines, string.format("Reroll Cost: %dg | Interest: %dg", shop.rerollCost, shop.interest))
    table.insert(lines, "")

    for i, offering in ipairs(shop.offerings) do
        local lockStatus = shop.locks[i] and "[LOCKED]" or ""
        if offering.isEmpty then
            if offering.sold then
                table.insert(lines, string.format("%d. [SOLD] %s", i, lockStatus))
            else
                table.insert(lines, string.format("%d. [EMPTY] %s", i, lockStatus))
            end
        else
            local rarityDef = ShopSystem.rarities[offering.rarity]
            table.insert(lines, string.format("%d. [%s] %s - %dg %s",
                i, rarityDef.name, offering.cardDef.id, offering.cost, lockStatus))
        end
    end

    return table.concat(lines, "\n")
end

--- Gets shop statistics
--- @param shop table Shop instance
--- @return table Stats { totalOfferings, sold, locked, rerollCount }
function ShopSystem.getShopStats(shop)
    local stats = {
        totalOfferings = #shop.offerings,
        sold = 0,
        locked = 0,
        rerollCount = shop.rerollCount
    }

    for i, offering in ipairs(shop.offerings) do
        if offering.sold then
            stats.sold = stats.sold + 1
        end
        if shop.locks[i] then
            stats.locked = stats.locked + 1
        end
    end

    return stats
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ShopSystem.init()
    print("[ShopSystem] Initialized")

    -- Print pool counts
    local counts = ShopSystem.getPoolCounts()
    local total = 0
    for shopType, rarities in pairs(counts) do
        for rarity, count in pairs(rarities) do
            total = total + count
        end
    end

    print(string.format("[ShopSystem] Card pool: %d cards", total))
end

return ShopSystem
