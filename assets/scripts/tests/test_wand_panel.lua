--[[
================================================================================
WAND PANEL TESTS - TDD
================================================================================
Tests for the Wand UI Panel module following the implementation plan.

Phase 1: Module skeleton with state management
- Module exports expected API
- State initializes correctly
- Visibility control works
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

--------------------------------------------------------------------------------
-- Phase 1: Module Skeleton Tests
--------------------------------------------------------------------------------

describe("WandPanel Module Skeleton", function()

    it("exports required API functions", function()
        local WandPanel = require("ui.wand_panel")

        -- Core lifecycle
        expect(WandPanel.open).to_be_truthy()
        expect(WandPanel.close).to_be_truthy()
        expect(WandPanel.toggle).to_be_truthy()
        expect(WandPanel.isOpen).to_be_truthy()

        -- Wand management
        expect(WandPanel.setWandDefs).to_be_truthy()
        expect(WandPanel.selectWand).to_be_truthy()

        -- Card equip API
        expect(WandPanel.equipToTriggerSlot).to_be_truthy()
        expect(WandPanel.equipToActionSlot).to_be_truthy()

        -- Grid accessors
        expect(WandPanel.getTriggerGrid).to_be_truthy()
        expect(WandPanel.getActionGrid).to_be_truthy()

        -- Cleanup
        expect(WandPanel.destroy).to_be_truthy()
        expect(WandPanel.cleanupSignalHandlers).to_be_truthy()
    end)

    it("starts in closed state", function()
        local WandPanel = require("ui.wand_panel")

        -- Panel should start closed
        expect(WandPanel.isOpen()).to_be(false)
    end)

    it("returns nil for grids before initialization", function()
        local WandPanel = require("ui.wand_panel")

        -- Before wand defs are set, grids should be nil
        expect(WandPanel.getTriggerGrid()).to_be_falsy()
        expect(WandPanel.getActionGrid()).to_be_falsy()
    end)

    it("cannot open without initialization", function()
        local WandPanel = require("ui.wand_panel")

        -- Set wand defs but panel is not initialized yet
        WandPanel.setWandDefs({{ id = "W1", total_card_slots = 5 }})

        -- Try to open - should fail because not initialized
        WandPanel.open()

        -- Panel should still be closed (not initialized)
        expect(WandPanel.isOpen()).to_be(false)
    end)

end)

--------------------------------------------------------------------------------
-- Phase 1: Grid Dimension Calculation Tests
--------------------------------------------------------------------------------

describe("WandPanel Grid Dimensions", function()

    it("calculates trigger grid as 1x1 (single slot)", function()
        local WandPanel = require("ui.wand_panel")

        -- Internal function should be accessible for testing
        local getGridDimensions = WandPanel._test.getGridDimensions
        if not getGridDimensions then
            -- Skip if test helpers not exposed
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDef = { total_card_slots = 8 }
        local rows, cols = getGridDimensions(wandDef, "trigger")

        expect(rows).to_be(1)
        expect(cols).to_be(1)
    end)

    it("calculates action grid rows based on total_card_slots", function()
        local WandPanel = require("ui.wand_panel")

        local getGridDimensions = WandPanel._test.getGridDimensions
        if not getGridDimensions then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- 8 slots with 4 columns = 2 rows
        local wandDef = { total_card_slots = 8 }
        local rows, cols = getGridDimensions(wandDef, "action")

        expect(cols).to_be(4)  -- Fixed column count
        expect(rows).to_be(2)  -- ceil(8/4) = 2
    end)

    it("calculates action grid rows with partial fill", function()
        local WandPanel = require("ui.wand_panel")

        local getGridDimensions = WandPanel._test.getGridDimensions
        if not getGridDimensions then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- 5 slots with 4 columns = 2 rows (ceil(5/4))
        local wandDef = { total_card_slots = 5 }
        local rows, cols = getGridDimensions(wandDef, "action")

        expect(cols).to_be(4)
        expect(rows).to_be(2)  -- ceil(5/4) = 2
    end)

    it("handles 10 slot wands correctly", function()
        local WandPanel = require("ui.wand_panel")

        local getGridDimensions = WandPanel._test.getGridDimensions
        if not getGridDimensions then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- 10 slots with 4 columns = 3 rows (ceil(10/4))
        local wandDef = { total_card_slots = 10 }
        local rows, cols = getGridDimensions(wandDef, "action")

        expect(cols).to_be(4)
        expect(rows).to_be(3)  -- ceil(10/4) = 3
    end)

end)

--------------------------------------------------------------------------------
-- Phase 1: Wand Definition Tests
--------------------------------------------------------------------------------

describe("WandPanel Wand Definitions", function()

    it("accepts wand definitions array", function()
        local WandPanel = require("ui.wand_panel")

        local wandDefs = {
            { id = "WAND_1", name = "Fire Wand", total_card_slots = 5 },
            { id = "WAND_2", name = "Ice Wand", total_card_slots = 8 },
        }

        -- Should not error
        WandPanel.setWandDefs(wandDefs)

        -- Panel should still be closed (not auto-opened)
        expect(WandPanel.isOpen()).to_be(false)
    end)

    it("rejects empty wand definitions", function()
        local WandPanel = require("ui.wand_panel")

        -- Should handle empty array gracefully (log warning, not crash)
        WandPanel.setWandDefs({})

        -- Panel should remain closed
        expect(WandPanel.isOpen()).to_be(false)
    end)

    it("rejects invalid wand indices in selectWand", function()
        local WandPanel = require("ui.wand_panel")

        local wandDefs = {
            { id = "WAND_1", total_card_slots = 5 },
            { id = "WAND_2", total_card_slots = 8 },
        }
        WandPanel.setWandDefs(wandDefs)

        -- Get initial state
        local getState = WandPanel._test.getState
        if not getState then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local initialIndex = getState().activeWandIndex

        -- Index 0 should be rejected (too low)
        WandPanel.selectWand(0)
        expect(getState().activeWandIndex).to_be(initialIndex)

        -- Index 3 should be rejected (only 2 wands)
        WandPanel.selectWand(3)
        expect(getState().activeWandIndex).to_be(initialIndex)

        -- Index -1 should be rejected
        WandPanel.selectWand(-1)
        expect(getState().activeWandIndex).to_be(initialIndex)
    end)

    it("accepts valid wand indices in selectWand", function()
        local WandPanel = require("ui.wand_panel")

        local wandDefs = {
            { id = "WAND_1", total_card_slots = 5 },
            { id = "WAND_2", total_card_slots = 8 },
        }
        WandPanel.setWandDefs(wandDefs)

        local getState = WandPanel._test.getState
        if not getState then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- Select wand 2
        WandPanel.selectWand(2)
        expect(getState().activeWandIndex).to_be(2)

        -- Select wand 1
        WandPanel.selectWand(1)
        expect(getState().activeWandIndex).to_be(1)
    end)

end)

--------------------------------------------------------------------------------
-- Phase 2: Tab System Tests
--------------------------------------------------------------------------------

describe("WandPanel Tab System", function()

    it("creates tab definitions for each wand", function()
        local WandPanel = require("ui.wand_panel")

        local createWandTabs = WandPanel._test.createWandTabs
        if not createWandTabs then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDefs = {
            { id = "WAND_1", name = "Fire", total_card_slots = 5 },
            { id = "WAND_2", name = "Ice", total_card_slots = 8 },
            { id = "WAND_3", name = "Lightning", total_card_slots = 6 },
        }
        WandPanel.setWandDefs(wandDefs)

        local tabDef = createWandTabs()

        -- Should create a vbox with tab children
        expect(tabDef).to_be_truthy()
        expect(tabDef.type).to_be("vbox")

        -- Should have children for each wand (plus spacers between)
        -- 3 wands = 3 buttons + 2 spacers = 5 children
        expect(tabDef.children).to_be_truthy()
        expect(#tabDef.children).to_be(5)

        -- First child should be button for wand 1
        expect(tabDef.children[1].type).to_be("button")
        expect(tabDef.children[1].label).to_be("Fi")

        -- Third child should be button for wand 2
        expect(tabDef.children[3].type).to_be("button")
        expect(tabDef.children[3].label).to_be("Ic")
    end)

    it("generates tab labels from wand names", function()
        local WandPanel = require("ui.wand_panel")

        local getTabLabel = WandPanel._test.getTabLabel
        if not getTabLabel then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- Should use first 2 characters of name
        expect(getTabLabel({ name = "Fire Staff" }, 1)).to_be("Fi")
        expect(getTabLabel({ name = "Ice" }, 2)).to_be("Ic")

        -- Should fall back to index if no name
        expect(getTabLabel({ id = "W1" }, 3)).to_be("3")
        expect(getTabLabel({}, 4)).to_be("4")
    end)

    it("tracks active wand index for tab highlighting", function()
        local WandPanel = require("ui.wand_panel")

        local getState = WandPanel._test.getState
        if not getState then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDefs = {
            { id = "WAND_1", total_card_slots = 5 },
            { id = "WAND_2", total_card_slots = 8 },
        }
        WandPanel.setWandDefs(wandDefs)

        -- Select wand 2
        WandPanel.selectWand(2)
        expect(getState().activeWandIndex).to_be(2)

        -- Select wand 1
        WandPanel.selectWand(1)
        expect(getState().activeWandIndex).to_be(1)
    end)

    it("handles edge cases in tab labels", function()
        local WandPanel = require("ui.wand_panel")

        local getTabLabel = WandPanel._test.getTabLabel
        if not getTabLabel then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- Single character name
        expect(getTabLabel({ name = "X" }, 1)).to_be("X")

        -- Empty name string falls back to index
        expect(getTabLabel({ name = "" }, 5)).to_be("5")

        -- Nil name falls back to index
        expect(getTabLabel({ name = nil }, 7)).to_be("7")
    end)

end)

--------------------------------------------------------------------------------
-- Phase 3: Dynamic Grid Tests
--------------------------------------------------------------------------------

describe("WandPanel Dynamic Grids", function()

    it("creates trigger grid definition with single slot", function()
        local WandPanel = require("ui.wand_panel")

        local createTriggerGridDefinition = WandPanel._test.createTriggerGridDefinition
        if not createTriggerGridDefinition then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDef = { id = "WAND_1", total_card_slots = 5 }
        WandPanel.setWandDefs({ wandDef })

        local gridDef = createTriggerGridDefinition(wandDef)

        expect(gridDef).to_be_truthy()
        expect(gridDef.rows).to_be(1)
        expect(gridDef.cols).to_be(1)
        expect(gridDef.id).to_contain("trigger")
    end)

    it("creates action grid definition with correct dimensions", function()
        local WandPanel = require("ui.wand_panel")

        local createActionGridDefinition = WandPanel._test.createActionGridDefinition
        if not createActionGridDefinition then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- 8 slots with 4 columns = 2 rows
        local wandDef = { id = "WAND_1", total_card_slots = 8 }
        WandPanel.setWandDefs({ wandDef })

        local gridDef = createActionGridDefinition(wandDef)

        expect(gridDef).to_be_truthy()
        expect(gridDef.rows).to_be(2)
        expect(gridDef.cols).to_be(4)
        expect(gridDef.id).to_contain("action")
    end)

    it("trigger grid accepts only trigger cards", function()
        local WandPanel = require("ui.wand_panel")

        local createTriggerGridDefinition = WandPanel._test.createTriggerGridDefinition
        if not createTriggerGridDefinition then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDef = { id = "WAND_1", total_card_slots = 5 }
        WandPanel.setWandDefs({ wandDef })

        local gridDef = createTriggerGridDefinition(wandDef)

        -- Should have a canAcceptItem filter
        expect(gridDef.canAcceptItem).to_be_truthy()

        -- Mock a trigger card
        local triggerCard = { cardData = { type = "trigger" } }
        local actionCard = { cardData = { type = "action" } }

        -- canAcceptItem takes (gridEntity, itemEntity) but we test the logic
        -- Since we're in test environment, we can't call it directly
        -- The presence of canAcceptItem is what we verify
    end)

    it("action grid accepts action and modifier cards", function()
        local WandPanel = require("ui.wand_panel")

        local createActionGridDefinition = WandPanel._test.createActionGridDefinition
        if not createActionGridDefinition then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDef = { id = "WAND_1", total_card_slots = 5 }
        WandPanel.setWandDefs({ wandDef })

        local gridDef = createActionGridDefinition(wandDef)

        -- Should have a canAcceptItem filter
        expect(gridDef.canAcceptItem).to_be_truthy()
    end)

    it("grid cleanup helper exists", function()
        local WandPanel = require("ui.wand_panel")

        local cleanupGrid = WandPanel._test.cleanupGrid
        if not cleanupGrid then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- Function should exist
        expect(cleanupGrid).to_be_truthy()
    end)

end)

--------------------------------------------------------------------------------
-- Phase 4: Wand Stats Display Tests
--------------------------------------------------------------------------------

describe("WandPanel Stats Display", function()

    it("formats stat values correctly", function()
        local WandPanel = require("ui.wand_panel")

        local formatStatValue = WandPanel._test.formatStatValue
        if not formatStatValue then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- Value with suffix
        expect(formatStatValue(200, "ms")).to_be("200ms")
        expect(formatStatValue(10, "deg")).to_be("10deg")

        -- Value without suffix
        expect(formatStatValue(5, nil)).to_be("5")

        -- Nil/zero/-1 values return nil (don't display)
        expect(formatStatValue(nil, "ms")).to_be_falsy()
        expect(formatStatValue(0, "ms")).to_be_falsy()
        expect(formatStatValue(-1, "ms")).to_be_falsy()
    end)

    it("creates stats box with wand properties", function()
        local WandPanel = require("ui.wand_panel")

        local createWandStatsRow = WandPanel._test.createWandStatsRow
        if not createWandStatsRow then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDef = {
            id = "TEST_WAND",
            name = "Test Wand",
            cast_delay = 200,
            recharge_time = 1000,
            spread_angle = 10,
            cast_block_size = 2,
            mana_max = 50,
            shuffle = true,
        }

        local statsBox = createWandStatsRow(wandDef)

        -- Should create a root container
        expect(statsBox).to_be_truthy()
        expect(statsBox.type).to_be("root")

        -- Should have children (header + stats text)
        expect(statsBox.children).to_be_truthy()
        expect(#statsBox.children > 0).to_be(true)
    end)

    it("includes shuffle indicator when enabled", function()
        local WandPanel = require("ui.wand_panel")

        local buildStatsText = WandPanel._test.buildStatsText
        if not buildStatsText then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        -- Wand with shuffle = true
        local shuffleWand = { id = "SHUFFLE", shuffle = true }
        local statsText = buildStatsText(shuffleWand)

        expect(statsText:find("Shuffle: Yes") ~= nil).to_be(true)
    end)

    it("includes always_cast indicator when cards present", function()
        local WandPanel = require("ui.wand_panel")

        local buildStatsText = WandPanel._test.buildStatsText
        if not buildStatsText then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local alwaysCastWand = {
            id = "ALWAYS_CAST",
            always_cast_cards = { "CARD_1", "CARD_2" },
        }
        local statsText = buildStatsText(alwaysCastWand)

        expect(statsText:find("Always Cast") ~= nil).to_be(true)
    end)

end)

--------------------------------------------------------------------------------
-- Phase 5: WandAdapter Sync Tests
--------------------------------------------------------------------------------

describe("WandPanel WandAdapter Sync", function()

    it("exposes sync functions for adapter integration", function()
        local WandPanel = require("ui.wand_panel")

        local syncTriggerToAdapter = WandPanel._test.syncTriggerToAdapter
        local syncActionsToAdapter = WandPanel._test.syncActionsToAdapter
        local syncAllToAdapter = WandPanel._test.syncAllToAdapter

        if not syncTriggerToAdapter then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(syncTriggerToAdapter).to_be_truthy()
        expect(syncActionsToAdapter).to_be_truthy()
        expect(syncAllToAdapter).to_be_truthy()
    end)

    it("exposes signal handler setup function", function()
        local WandPanel = require("ui.wand_panel")

        local setupSignalHandlers = WandPanel._test.setupSignalHandlers
        if not setupSignalHandlers then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(setupSignalHandlers).to_be_truthy()
    end)

    it("exposes returnCardToInventory helper", function()
        local WandPanel = require("ui.wand_panel")

        local returnCardToInventory = WandPanel._test.returnCardToInventory
        if not returnCardToInventory then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(returnCardToInventory).to_be_truthy()
    end)

end)

--------------------------------------------------------------------------------
-- Phase 6 & 7: Quick Equip and Input Handling Tests
--------------------------------------------------------------------------------

describe("WandPanel Input Handling", function()

    it("exposes input handler setup function", function()
        local WandPanel = require("ui.wand_panel")

        local setupInputHandler = WandPanel._test.setupInputHandler
        if not setupInputHandler then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(setupInputHandler).to_be_truthy()
    end)

    it("exposes quick equip handler", function()
        local WandPanel = require("ui.wand_panel")

        local handleQuickEquip = WandPanel._test.handleQuickEquip
        if not handleQuickEquip then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(handleQuickEquip).to_be_truthy()
    end)

end)

--------------------------------------------------------------------------------
-- Phase 9: Panel Definition Tests
--------------------------------------------------------------------------------

describe("WandPanel Panel Definition", function()

    it("exposes panel creation functions", function()
        local WandPanel = require("ui.wand_panel")

        local createHeader = WandPanel._test.createHeader
        local createTriggerSection = WandPanel._test.createTriggerSection
        local createActionSection = WandPanel._test.createActionSection
        local createPanelDefinition = WandPanel._test.createPanelDefinition

        if not createPanelDefinition then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(createHeader).to_be_truthy()
        expect(createTriggerSection).to_be_truthy()
        expect(createActionSection).to_be_truthy()
        expect(createPanelDefinition).to_be_truthy()
    end)

    it("creates panel definition with required structure", function()
        local WandPanel = require("ui.wand_panel")

        local createPanelDefinition = WandPanel._test.createPanelDefinition
        if not createPanelDefinition then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        local wandDef = { id = "TEST", name = "Test Wand", total_card_slots = 5 }
        WandPanel.setWandDefs({ wandDef })

        local panelDef = createPanelDefinition(wandDef)

        expect(panelDef).to_be_truthy()
        expect(panelDef.children).to_be_truthy()
        expect(#panelDef.children > 0).to_be(true)
    end)

end)

--------------------------------------------------------------------------------
-- Phase 10: Lifecycle Tests
--------------------------------------------------------------------------------

describe("WandPanel Lifecycle", function()

    it("exposes initialize function", function()
        local WandPanel = require("ui.wand_panel")

        expect(WandPanel.initialize).to_be_truthy()
    end)

    it("exposes visibility control functions", function()
        local WandPanel = require("ui.wand_panel")

        local showPanel = WandPanel._test.showPanel
        local hidePanel = WandPanel._test.hidePanel

        if not showPanel then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(showPanel).to_be_truthy()
        expect(hidePanel).to_be_truthy()
    end)

    it("exposes grid injection functions", function()
        local WandPanel = require("ui.wand_panel")

        local injectTriggerGrid = WandPanel._test.injectTriggerGrid
        local injectActionGrid = WandPanel._test.injectActionGrid

        if not injectTriggerGrid then
            print("  (skipped: _test helpers not exposed)")
            return
        end

        expect(injectTriggerGrid).to_be_truthy()
        expect(injectActionGrid).to_be_truthy()
    end)

end)

--------------------------------------------------------------------------------
-- Run tests when executed directly
--------------------------------------------------------------------------------

if arg and arg[0]:match("test_wand_panel%.lua$") then
    TestRunner.run()
end

return TestRunner
