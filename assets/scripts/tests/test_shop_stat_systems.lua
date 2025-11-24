--[[
================================================================================
SHOP AND STAT SYSTEMS - COMPREHENSIVE TEST HARNESS
================================================================================
Pure Lua test harness for all shop and stat systems.
Tests each system in isolation and integrated workflows.

Usage:
  lua assets/scripts/tests/test_shop_stat_systems.lua

Or require and run specific tests:
  local Tests = require("tests.test_shop_stat_systems")
  Tests.runAllTests()
  Tests.testStatSystem()
  Tests.testCardSynergy()
  Tests.testCardUpgrade()
  Tests.testShopSystem()
  Tests.testIntegratedWorkflow()

================================================================================
]] --

local Tests = {}

-- ============================================================================
-- SETUP
-- ============================================================================

-- Mock combat_system Stats for testing
local function createMockStats()
    local stats = {
        values = {},
        recomputeHooks = {}
    }

    function stats:add_base(name, value)
        self.values[name] = (self.values[name] or 0) + value
    end

    function stats:add_add_pct(name, value)
        self.values[name .. "_pct"] = (self.values[name .. "_pct"] or 0) + value
    end

    function stats:derived_add_base(name, value)
        self.values[name] = (self.values[name] or 0) + value
    end

    function stats:derived_add_add_pct(name, value)
        self.values[name .. "_pct"] = (self.values[name .. "_pct"] or 0) + value
    end

    function stats:get(name)
        return self.values[name] or 0
    end

    function stats:get_raw(name)
        return { base = self.values[name] or 0 }
    end

    function stats:on_recompute(func)
        table.insert(self.recomputeHooks, func)
    end

    function stats:recompute()
        for _, hook in ipairs(self.recomputeHooks) do
            hook(self)
        end
    end

    return stats
end

-- ============================================================================
-- TEST 1: STAT SYSTEM
-- ============================================================================

function Tests.testStatSystem()
    print("\n" .. string.rep("=", 60))
    print("TEST 1: STAT SYSTEM")
    print(string.rep("=", 60))

    local StatSystem = require("core.stat_system")
    StatSystem.init()

    -- Test 1.1: Default derivations
    print("\n[1.1] Testing default derivations...")
    local impact = StatSystem.getStatImpact("physique", 10, 1)
    print("Impact of +1 physique from 10:")
    print(StatSystem.formatStatImpact(impact))
    assert(impact.health == 10, "Physique should give +10 health")

    -- Test 1.2: Custom derivation
    print("\n[1.2] Testing custom derivation registration...")
    StatSystem.registerDerivation("physique", "dash_distance", function(value, entity)
        return value * 2
    end)

    local impact2 = StatSystem.getStatImpact("physique", 15, 1)
    print("Impact of +1 physique from 15 (with dash_distance):")
    print(StatSystem.formatStatImpact(impact2))
    assert(impact2.dash_distance == 2, "Physique should give +2 dash_distance")

    -- Test 1.3: Integration with Stats instance
    print("\n[1.3] Testing Stats instance integration...")
    local mockStats = createMockStats()
    StatSystem.attachToStatsInstance(mockStats)

    mockStats:add_base("physique", 20)
    mockStats:add_base("cunning", 15)
    mockStats:add_base("spirit", 10)
    mockStats:recompute()

    print(string.format("Health from 20 physique: %.0f", mockStats:get("health")))
    print(string.format("Energy from 10 spirit: %.0f", mockStats:get("energy")))
    assert(mockStats:get("health") > 0, "Health should be derived from physique")
    assert(mockStats:get("energy") > 0, "Energy should be derived from spirit")

    -- Test 1.4: List derivations
    print("\n[1.4] Listing all derivations...")
    StatSystem.listDerivations()

    print("\n[1.1-1.4] ✓ Stat System tests passed")
end

-- ============================================================================
-- TEST 2: CARD SYNERGY SYSTEM
-- ============================================================================

function Tests.testCardSynergy()
    print("\n" .. string.rep("=", 60))
    print("TEST 2: CARD SYNERGY SYSTEM")
    print(string.rep("=", 60))

    local CardSynergy = require("wand.card_synergy_system")
    CardSynergy.init()

    -- Test 2.1: Tag detection
    print("\n[2.1] Testing tag detection...")
    local cards = {
        { id = "card1", tags = { "mobility", "tactical" } },
        { id = "card2", tags = { "mobility" } },
        { id = "card3", tags = { "mobility" } },
        { id = "card4", tags = { "defense" } },
        { id = "card5", tags = { "defense" } },
        { id = "card6", tags = { "defense" } }
    }

    local tagCounts = CardSynergy.detectSets(cards)
    print("Tag counts:")
    for tag, count in pairs(tagCounts) do
        print(string.format("  %s: %d", tag, count))
    end
    assert(tagCounts.mobility == 3, "Should have 3 mobility cards")
    assert(tagCounts.defense == 3, "Should have 3 defense cards")

    -- Test 2.2: Active bonuses
    print("\n[2.2] Testing active bonuses...")
    local activeBonuses = CardSynergy.getActiveBonuses(tagCounts)
    for tag, bonusData in pairs(activeBonuses) do
        print(string.format("  %s (tier %d): %s", tag, bonusData.tier, bonusData.bonus.description))
    end
    assert(activeBonuses.mobility.tier == 3, "Mobility should be tier 3")
    assert(activeBonuses.defense.tier == 3, "Defense should be tier 3")

    -- Test 2.3: Bonus info for UI
    print("\n[2.3] Testing bonus info formatting...")
    local bonusInfo = CardSynergy.getActiveBonusInfo(tagCounts)
    for _, info in ipairs(bonusInfo) do
        print(string.format("  [%s] %s - %s", info.tier, info.displayName, info.description))
    end

    -- Test 2.4: Progress to next tier
    print("\n[2.4] Testing progress to next tier...")
    local nextTier, needed = CardSynergy.getProgressToNextTier("mobility", 5)
    print(string.format("  Mobility (5 cards): Next tier at %d, need %d more", nextTier or 0, needed or 0))
    assert(nextTier == 6, "Next tier should be 6")
    assert(needed == 1, "Should need 1 more card")

    -- Test 2.5: Curated combos
    print("\n[2.5] Testing curated combo detection...")
    local comboCards = {
        { id = "ACTION_EXPLOSIVE_FIRE_PROJECTILE" },
        { id = "MOD_EXPLOSIVE" },
        { id = "MOD_BURN_ON_HIT" }
    }
    local activeCombos = CardSynergy.detectCuratedCombos(comboCards)
    print(string.format("  Active combos: %d", #activeCombos))
    for _, comboId in ipairs(activeCombos) do
        local comboDef = CardSynergy.curatedCombos[comboId]
        print(string.format("    - %s: %s", comboDef.name, comboDef.description))
    end

    print("\n[2.1-2.5] ✓ Card Synergy tests passed")
end

-- ============================================================================
-- TEST 3: CARD UPGRADE SYSTEM
-- ============================================================================

function Tests.testCardUpgrade()
    print("\n" .. string.rep("=", 60))
    print("TEST 3: CARD UPGRADE SYSTEM")
    print(string.rep("=", 60))

    local CardUpgrade = require("wand.card_upgrade_system")
    CardUpgrade.init()

    -- Test 3.1: Card initialization
    print("\n[3.1] Testing card initialization...")
    local card = { id = "ACTION_BASIC_PROJECTILE", damage = 10 }
    CardUpgrade.initializeCard(card)
    print(string.format("  Level: %d, Max Level: %d", card.level, card.max_level))
    assert(card.level == 1, "Initial level should be 1")
    assert(card.max_level == 3, "Max level should be 3")

    -- Test 3.2: Upgrade preview
    print("\n[3.2] Testing upgrade preview...")
    local preview = CardUpgrade.getUpgradePreview(card)
    print(CardUpgrade.formatUpgradePreview(preview))
    assert(preview.newLevel == 2, "Preview should show level 2")
    assert(preview.cost == 3, "Upgrade cost should be 3g")

    -- Test 3.3: Upgrade execution
    print("\n[3.3] Testing upgrade execution...")
    local success, upgradedCard = CardUpgrade.upgradeCard(card)
    assert(success, "Upgrade should succeed")
    assert(card.level == 2, "Card should be level 2")
    assert(card.damage == 15, "Damage should be 15 at level 2")
    print(string.format("  Upgraded to level %d, damage: %d", card.level, card.damage))

    -- Test 3.4: Second upgrade
    print("\n[3.4] Testing second upgrade...")
    local preview2 = CardUpgrade.getUpgradePreview(card)
    print(CardUpgrade.formatUpgradePreview(preview2))

    local success2, _ = CardUpgrade.upgradeCard(card)
    assert(success2, "Second upgrade should succeed")
    assert(card.level == 3, "Card should be level 3")
    assert(card.damage == 22, "Damage should be 22 at level 3")
    print(string.format("  Upgraded to level %d, damage: %d", card.level, card.damage))

    -- Test 3.5: Custom behaviors
    print("\n[3.5] Testing custom behaviors...")
    local hasExplosion, params = CardUpgrade.hasCustomBehavior(card, "on_hit_explosion")
    if hasExplosion then
        print(string.format("  Has on_hit_explosion: radius=%d, damage_mult=%.1f",
            params.radius, params.damage_mult))
    end

    -- Test 3.6: Visual indicators
    print("\n[3.6] Testing visual indicators...")
    print(string.format("  Level indicator: %s", CardUpgrade.getLevelIndicator(card)))
    print(string.format("  Level color: %s", CardUpgrade.getLevelColor(card)))

    print("\n[3.1-3.6] ✓ Card Upgrade tests passed")
end

-- ============================================================================
-- TEST 4: SHOP SYSTEM
-- ============================================================================

function Tests.testShopSystem()
    print("\n" .. string.rep("=", 60))
    print("TEST 4: SHOP SYSTEM")
    print(string.rep("=", 60))

    local ShopSystem = require("core.shop_system")

    -- Register some test cards
    print("\n[4.1] Registering test cards...")
    local testCards = {
        { id = "TEST_COMMON_ACTION", type = "action",   rarity = "common" },
        { id = "TEST_UNCOMMON_MOD",  type = "modifier", rarity = "uncommon" },
        { id = "TEST_RARE_TRIGGER",  type = "trigger",  rarity = "rare" }
    }

    for _, card in ipairs(testCards) do
        ShopSystem.registerCard(card)
    end

    ShopSystem.init()

    -- Test 4.2: Interest calculation
    print("\n[4.2] Testing interest calculation...")
    local interest1 = ShopSystem.calculateInterest(25)
    local interest2 = ShopSystem.calculateInterest(50)
    local interest3 = ShopSystem.calculateInterest(100)
    print(string.format("  25g -> %dg interest", interest1))
    print(string.format("  50g -> %dg interest", interest2))
    print(string.format("  100g -> %dg interest (capped)", interest3))
    assert(interest1 == 2, "25g should give 2g interest")
    assert(interest2 == 5, "50g should give 5g interest (max)")
    assert(interest3 == 5, "100g should give 5g interest (capped)")

    -- Test 4.3: Shop generation
    print("\n[4.3] Testing shop generation...")
    local player = { gold = 30, cards = {} }
    local shop = ShopSystem.generateShop(1, player.gold)
    print(ShopSystem.formatShop(shop))
    assert(#shop.offerings == 5, "Should have 5 offerings")

    -- Test 4.4: Lock system
    print("\n[4.4] Testing lock system...")
    ShopSystem.lockOffering(shop, 1)
    ShopSystem.lockOffering(shop, 3)
    print("  Locked slots 1 and 3")

    -- Test 4.5: Reroll
    print("\n[4.5] Testing reroll...")
    local initialCost = shop.rerollCost
    print(string.format("  Initial reroll cost: %dg", initialCost))

    local success = ShopSystem.rerollOfferings(shop, player)
    assert(success, "Reroll should succeed")
    print(string.format("  After reroll: cost=%dg, player gold=%dg", shop.rerollCost, player.gold))
    assert(shop.rerollCost == initialCost + 1, "Reroll cost should increase by 1")

    -- Test 4.6: Purchase
    print("\n[4.6] Testing card purchase...")
    local offering = shop.offerings[2] -- Buy unlocked slot
    if not offering.isEmpty then
        local initialGold = player.gold
        local cost = offering.cost
        local success2, card = ShopSystem.purchaseCard(shop, 2, player)
        if success2 then
            print(string.format("  Purchased %s for %dg", card.id, cost))
            print(string.format("  Player gold: %dg -> %dg", initialGold, player.gold))
            assert(player.gold == initialGold - cost, "Gold should be deducted")
            assert(#player.cards == 1, "Player should have 1 card")
        end
    end

    -- Test 4.7: Shop stats
    print("\n[4.7] Testing shop stats...")
    local stats = ShopSystem.getShopStats(shop)
    print(string.format("  Total: %d, Sold: %d, Locked: %d, Rerolls: %d",
        stats.totalOfferings, stats.sold, stats.locked, stats.rerollCount))

    print("\n[4.1-4.7] ✓ Shop System tests passed")
end

-- ============================================================================
-- TEST 5: INTEGRATED WORKFLOW
-- ============================================================================

function Tests.testIntegratedWorkflow()
    print("\n" .. string.rep("=", 60))
    print("TEST 5: INTEGRATED WORKFLOW")
    print(string.rep("=", 60))

    local StatSystem = require("core.stat_system")
    local CardSynergy = require("wand.card_synergy_system")
    local CardUpgrade = require("wand.card_upgrade_system")
    local ShopSystem = require("core.shop_system")

    -- Initialize systems
    StatSystem.init()
    CardSynergy.init()
    CardUpgrade.init()
    ShopSystem.init()

    print("\n[5.1] Simulating player progression...")

    -- Create player
    local player = {
        name = "TestHero",
        level = 1,
        gold = 50,
        cards = {},
        stats = createMockStats()
    }

    -- Set up stats
    StatSystem.attachToStatsInstance(player.stats)
    player.stats:add_base("physique", 10)
    player.stats:add_base("cunning", 12)
    player.stats:add_base("spirit", 8)
    player.stats:recompute()

    print(string.format("  Player: %s (Level %d, %dg)", player.name, player.level, player.gold))
    print(string.format("  Stats: Physique=%d, Cunning=%d, Spirit=%d",
        player.stats:get("physique"), player.stats:get("cunning"), player.stats:get("spirit")))

    -- Round 1: Enter shop
    print("\n[5.2] Round 1: Entering shop...")
    local interest = ShopSystem.calculateInterest(player.gold)
    print(string.format("  Interest earned: %dg", interest))
    player.gold = player.gold + interest

    -- Add some test cards to player's deck
    print("\n[5.3] Building initial deck...")
    player.cards = {
        { id = "ACTION_BASIC_PROJECTILE",         tags = { "brute" },  rarity = "common",   level = 1 },
        { id = "ACTION_FAST_ACCURATE_PROJECTILE", tags = { "tactical" }, rarity = "common", level = 1 },
        { id = "MOD_HOMING",                      tags = { "tactical" }, rarity = "uncommon", level = 1 }
    }

    for _, card in ipairs(player.cards) do
        CardUpgrade.initializeCard(card)
    end

    print(string.format("  Deck size: %d cards", #player.cards))

    -- Check synergies
    print("\n[5.4] Checking card synergies...")
    local tagCounts = CardSynergy.detectSets(player.cards)
    local bonusInfo = CardSynergy.getActiveBonusInfo(tagCounts)
    if #bonusInfo > 0 then
        for _, info in ipairs(bonusInfo) do
            print(string.format("  [Tier %d] %s: %s", info.tier, info.displayName, info.description))
        end
    else
        print("  No active set bonuses yet")
    end

    -- Upgrade a card
    print("\n[5.5] Upgrading a card...")
    local cardToUpgrade = player.cards[1]
    local upgradeCost = CardUpgrade.getUpgradeCost(cardToUpgrade)
    if upgradeCost and player.gold >= upgradeCost then
        local success, _ = ShopSystem.upgradeCard(cardToUpgrade, player)
        if success then
            print(string.format("  Upgraded %s to level %d (%s)",
                cardToUpgrade.id, cardToUpgrade.level, CardUpgrade.getLevelIndicator(cardToUpgrade)))
        end
    end

    -- Level up
    print("\n[5.6] Leveling up...")
    player.level = player.level + 1
    StatSystem.applyLevelUp(player, "cunning", 1)
    player.stats:recompute()
    print(string.format("  Level %d! Allocated +1 cunning", player.level))
    print(string.format("  New stats: Cunning=%d, OA=%d",
        player.stats:get("cunning"), player.stats:get("offensive_ability")))

    print("\n[5.1-5.6] ✓ Integrated Workflow tests passed")
end

-- ============================================================================
-- TEST RUNNER
-- ============================================================================

function Tests.runAllTests()
    print("\n" .. string.rep("=", 60))
    print("SHOP AND STAT SYSTEMS - COMPREHENSIVE TEST SUITE")
    print(string.rep("=", 60))

    local success, err = pcall(function()
        Tests.testStatSystem()
        Tests.testCardSynergy()
        Tests.testCardUpgrade()
        Tests.testShopSystem()
        Tests.testIntegratedWorkflow()
    end)

    if success then
        print("\n" .. string.rep("=", 60))
        print("✓ ALL TESTS PASSED")
        print(string.rep("=", 60))
    else
        print("\n" .. string.rep("=", 60))
        print("✗ TEST FAILED")
        print(string.rep("=", 60))
        print("Error:", err)
    end
end

-- Auto-run if executed directly
if not pcall(debug.getlocal, 4, 1) then
    Tests.runAllTests()
end

return Tests
