--[[
================================================================================
TEST: Character Select Screen - TDD Implementation
================================================================================
Tests for character select screen following the spec:
- CS-01: UI scaffold and layout
- CS-02: Selection state and data wiring
- CS-03: Info panel rendering
- CS-04: Buttons and dialog
- CS-05: Input and focus navigation
- CS-06: Persistence
- CS-07: Visual and audio polish

RED PHASE: Tests written BEFORE implementation.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

--------------------------------------------------------------------------------
-- CS-01: UI Scaffold and Layout
--------------------------------------------------------------------------------

describe("CS-01: Character Select Module Structure", function()
    it("module exists and can be required", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect).never().to_be_nil()
    end)

    it("has open() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.open).to_be_type("function")
    end)

    it("has close() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.close).to_be_type("function")
    end)

    it("has toggle() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.toggle).to_be_type("function")
    end)

    it("has isOpen() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.isOpen).to_be_type("function")
    end)

    it("has destroy() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.destroy).to_be_type("function")
    end)
end)

describe("CS-01: Character Select Data Model", function()
    it("has GOD_DATA table with 4 unlocked gods", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.GOD_DATA).never().to_be_nil()

        local unlockedCount = 0
        for id, data in pairs(CharacterSelect.GOD_DATA) do
            if data.unlocked then
                unlockedCount = unlockedCount + 1
            end
        end
        expect(unlockedCount >= 4).to_be(true)
    end)

    it("has CLASS_DATA table with 2 unlocked classes", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.CLASS_DATA).never().to_be_nil()

        local unlockedCount = 0
        for id, data in pairs(CharacterSelect.CLASS_DATA) do
            if data.unlocked then
                unlockedCount = unlockedCount + 1
            end
        end
        expect(unlockedCount >= 2).to_be(true)
    end)

    it("has locked god entries for demo", function()
        local CharacterSelect = require("ui.character_select")
        local lockedCount = 0
        for id, data in pairs(CharacterSelect.GOD_DATA) do
            if not data.unlocked then
                lockedCount = lockedCount + 1
            end
        end
        expect(lockedCount >= 2).to_be(true)
    end)

    it("has locked class entry for demo", function()
        local CharacterSelect = require("ui.character_select")
        local lockedCount = 0
        for id, data in pairs(CharacterSelect.CLASS_DATA) do
            if not data.unlocked then
                lockedCount = lockedCount + 1
            end
        end
        expect(lockedCount >= 1).to_be(true)
    end)

    it("god data has required fields", function()
        local CharacterSelect = require("ui.character_select")
        for id, data in pairs(CharacterSelect.GOD_DATA) do
            if data.unlocked then
                expect(data.name_key).never().to_be_nil()
                expect(data.lore_key).never().to_be_nil()
                expect(data.blessing_key).never().to_be_nil()
                expect(data.passive_key).never().to_be_nil()
                expect(data.portrait).never().to_be_nil()
                expect(data.aura).never().to_be_nil()
            end
        end
    end)

    it("class data has required fields", function()
        local CharacterSelect = require("ui.character_select")
        for id, data in pairs(CharacterSelect.CLASS_DATA) do
            if data.unlocked then
                expect(data.name_key).never().to_be_nil()
                expect(data.lore_key).never().to_be_nil()
                expect(data.passive_key).never().to_be_nil()
                expect(data.triggered_key).never().to_be_nil()
                expect(data.starterWand).never().to_be_nil()
                expect(data.portrait).never().to_be_nil()
            end
        end
    end)
end)

describe("CS-01: Character Select Layout Configuration", function()
    it("has layout constants defined", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.LAYOUT).never().to_be_nil()
    end)

    it("layout has god row configuration", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.LAYOUT.GOD_ROW_SLOTS).to_be(6)
    end)

    it("layout has class row configuration", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.LAYOUT.CLASS_ROW_SLOTS).to_be(3)
    end)

    it("layout has info zone split configuration", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.LAYOUT.INFO_GOD_WIDTH_PCT).to_be(60)
        expect(CharacterSelect.LAYOUT.INFO_CLASS_WIDTH_PCT).to_be(40)
    end)

    it("layout has animation timing", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.LAYOUT.SLIDE_IN_DURATION).never().to_be_nil()
        expect(CharacterSelect.LAYOUT.SLIDE_IN_DURATION > 0).to_be(true)
    end)
end)

describe("CS-01: Panel Entity Management", function()
    it("getPanelEntity returns nil when not initialized", function()
        local CharacterSelect = require("ui.character_select")
        -- Destroy first to ensure clean state
        CharacterSelect.destroy()
        expect(CharacterSelect.getPanelEntity()).to_be_nil()
    end)

    it("isOpen returns false when not initialized", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        expect(CharacterSelect.isOpen()).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- CS-02: Selection State and Data Wiring
--------------------------------------------------------------------------------

describe("CS-02: Selection State", function()
    it("has getSelectedGod() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getSelectedGod).to_be_type("function")
    end)

    it("has getSelectedClass() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getSelectedClass).to_be_type("function")
    end)

    it("has selectGod() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.selectGod).to_be_type("function")
    end)

    it("has selectClass() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.selectClass).to_be_type("function")
    end)

    it("has randomize() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.randomize).to_be_type("function")
    end)

    it("has isConfirmEnabled() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.isConfirmEnabled).to_be_type("function")
    end)

    it("confirm is disabled when no selection", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        expect(CharacterSelect.isConfirmEnabled()).to_be(false)
    end)
end)

describe("CS-02: Selection Logic", function()
    local CharacterSelect

    it("selectGod sets selected god", function()
        CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        expect(CharacterSelect.getSelectedGod()).to_be("pyr")
    end)

    it("selectClass sets selected class", function()
        CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectClass("channeler")
        expect(CharacterSelect.getSelectedClass()).to_be("channeler")
    end)

    it("confirm enabled when both selected", function()
        CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectClass("channeler")
        expect(CharacterSelect.isConfirmEnabled()).to_be(true)
    end)

    it("selectGod ignores locked gods", function()
        CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr") -- Valid selection first
        CharacterSelect.selectGod("locked_god_1") -- Attempt locked selection
        -- Should still be pyr, not locked
        expect(CharacterSelect.getSelectedGod()).to_be("pyr")
    end)

    it("switching god changes selection", function()
        CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectGod("glah")
        expect(CharacterSelect.getSelectedGod()).to_be("glah")
    end)

    it("selectGod ignores invalid god IDs", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectGod("nonexistent_god_id")
        expect(CharacterSelect.getSelectedGod()).to_be("pyr")
    end)

    it("selectClass ignores invalid class IDs", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectClass("channeler")
        CharacterSelect.selectClass("nonexistent_class_id")
        expect(CharacterSelect.getSelectedClass()).to_be("channeler")
    end)

    it("randomize selects both god and class", function()
        CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.randomize()
        expect(CharacterSelect.getSelectedGod()).never().to_be_nil()
        expect(CharacterSelect.getSelectedClass()).never().to_be_nil()
    end)

    it("randomize only picks unlocked entries", function()
        CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- Run randomize multiple times to verify
        for i = 1, 10 do
            CharacterSelect.randomize()
            local god = CharacterSelect.getSelectedGod()
            local class = CharacterSelect.getSelectedClass()
            local godData = CharacterSelect.GOD_DATA[god]
            local classData = CharacterSelect.CLASS_DATA[class]
            expect(godData.unlocked).to_be(true)
            expect(classData.unlocked).to_be(true)
        end
    end)
end)

--------------------------------------------------------------------------------
-- CS-03: Info Panel Data
--------------------------------------------------------------------------------

describe("CS-03: Info Panel Helpers", function()
    it("has getGodInfo() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getGodInfo).to_be_type("function")
    end)

    it("has getClassInfo() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getClassInfo).to_be_type("function")
    end)

    it("getGodInfo returns correct data for selected god", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        local info = CharacterSelect.getGodInfo()
        expect(info).never().to_be_nil()
        expect(info.id).to_be("pyr")
        expect(info.name_key).never().to_be_nil()
    end)

    it("getGodInfo returns nil when no god selected", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        local info = CharacterSelect.getGodInfo()
        expect(info).to_be_nil()
    end)

    it("getClassInfo returns correct data for selected class", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectClass("channeler")
        local info = CharacterSelect.getClassInfo()
        expect(info).never().to_be_nil()
        expect(info.id).to_be("channeler")
        expect(info.name_key).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- CS-04: Buttons and Confirmation
--------------------------------------------------------------------------------

describe("CS-04: Button State", function()
    it("has confirm() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.confirm).to_be_type("function")
    end)

    it("confirm includes godAura in selection data", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectClass("channeler")
        local result = CharacterSelect.confirm()
        expect(result.godAura).to_be("fire")
    end)

    it("destroy clears onConfirm callback", function()
        local CharacterSelect = require("ui.character_select")
        local callbackCalled = false
        CharacterSelect.setOnConfirm(function() callbackCalled = true end)
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectClass("channeler")
        CharacterSelect.confirm()
        expect(callbackCalled).to_be(false)
    end)

    it("has setOnConfirm() callback setter", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.setOnConfirm).to_be_type("function")
    end)

    it("confirm() returns nil when not enabled", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        local result = CharacterSelect.confirm()
        expect(result).to_be_nil()
    end)

    it("confirm() returns selection data when enabled", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectClass("channeler")
        local result = CharacterSelect.confirm()
        expect(result).never().to_be_nil()
        expect(result.god).to_be("pyr")
        expect(result.class).to_be("channeler")
    end)

    it("confirm triggers callback with selection data", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()

        local callbackData = nil
        CharacterSelect.setOnConfirm(function(data)
            callbackData = data
        end)

        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectClass("channeler")
        CharacterSelect.confirm()

        expect(callbackData).never().to_be_nil()
        expect(callbackData.god).to_be("pyr")
        expect(callbackData.class).to_be("channeler")
    end)
end)

--------------------------------------------------------------------------------
-- CS-06: Persistence
--------------------------------------------------------------------------------

describe("CS-06: Persistence", function()
    it("has setLastSelection() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.setLastSelection).to_be_type("function")
    end)

    it("has getLastSelection() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getLastSelection).to_be_type("function")
    end)

    it("preselects valid last selection", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setLastSelection("glah", "seer")
        CharacterSelect.applyLastSelection()
        expect(CharacterSelect.getSelectedGod()).to_be("glah")
        expect(CharacterSelect.getSelectedClass()).to_be("seer")
    end)

    it("ignores invalid last selection", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setLastSelection("nonexistent_god", "nonexistent_class")
        CharacterSelect.applyLastSelection()
        expect(CharacterSelect.getSelectedGod()).to_be_nil()
        expect(CharacterSelect.getSelectedClass()).to_be_nil()
    end)

    it("ignores locked entries in last selection", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setLastSelection("locked_god_1", "locked_class_1")
        CharacterSelect.applyLastSelection()
        expect(CharacterSelect.getSelectedGod()).to_be_nil()
        expect(CharacterSelect.getSelectedClass()).to_be_nil()
    end)
end)

describe("CS-06: Save System Integration", function()
    it("has getSaveCollector() method for testing", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getSaveCollector).to_be_type("function")
    end)

    it("collector has collect() function", function()
        local CharacterSelect = require("ui.character_select")
        local collector = CharacterSelect.getSaveCollector()
        expect(collector.collect).to_be_type("function")
    end)

    it("collector has distribute() function", function()
        local CharacterSelect = require("ui.character_select")
        local collector = CharacterSelect.getSaveCollector()
        expect(collector.distribute).to_be_type("function")
    end)

    it("collect() returns lastGod and lastClass", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setLastSelection("pyr", "channeler")
        local collector = CharacterSelect.getSaveCollector()
        local data = collector.collect()
        expect(data.lastGod).to_be("pyr")
        expect(data.lastClass).to_be("channeler")
    end)

    it("collect() returns nil fields when no last selection", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        local collector = CharacterSelect.getSaveCollector()
        local data = collector.collect()
        expect(data.lastGod).to_be_nil()
        expect(data.lastClass).to_be_nil()
    end)

    it("distribute() restores last selection", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        local collector = CharacterSelect.getSaveCollector()
        collector.distribute({ lastGod = "vix", lastClass = "seer" })
        local god, class = CharacterSelect.getLastSelection()
        expect(god).to_be("vix")
        expect(class).to_be("seer")
    end)

    it("distribute() handles nil data gracefully", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        local collector = CharacterSelect.getSaveCollector()
        -- Should not error
        collector.distribute(nil)
        local god, class = CharacterSelect.getLastSelection()
        expect(god).to_be_nil()
        expect(class).to_be_nil()
    end)

    it("distribute() handles empty table gracefully", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        local collector = CharacterSelect.getSaveCollector()
        collector.distribute({})
        local god, class = CharacterSelect.getLastSelection()
        expect(god).to_be_nil()
        expect(class).to_be_nil()
    end)

    it("has registerWithSaveManager() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.registerWithSaveManager).to_be_type("function")
    end)

    it("registerWithSaveManager returns boolean", function()
        local CharacterSelect = require("ui.character_select")
        -- Returns true if SaveManager exists, false otherwise
        local result = CharacterSelect.registerWithSaveManager()
        expect(type(result)).to_be("boolean")
    end)
end)

--------------------------------------------------------------------------------
-- CS-01: UI Scaffold (standalone-compatible tests)
--------------------------------------------------------------------------------

describe("CS-01: UI Scaffold Functions", function()
    it("has hasGameEngine() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.hasGameEngine).to_be_type("function")
    end)

    it("hasGameEngine returns false in standalone mode", function()
        local CharacterSelect = require("ui.character_select")
        -- In standalone Lua without game engine, DSL is not available
        expect(CharacterSelect.hasGameEngine()).to_be(false)
    end)

    it("has spawnPanel() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.spawnPanel).to_be_type("function")
    end)

    it("spawnPanel returns nil without game engine", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.spawnPanel()).to_be_nil()
    end)

    it("has refreshUI() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.refreshUI).to_be_type("function")
    end)

    it("open/close work without game engine", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        expect(CharacterSelect.isOpen()).to_be(false)
        CharacterSelect.open()
        expect(CharacterSelect.isOpen()).to_be(true)
        CharacterSelect.close()
        expect(CharacterSelect.isOpen()).to_be(false)
    end)

    it("toggle works without game engine", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        expect(CharacterSelect.isOpen()).to_be(false)
        CharacterSelect.toggle()
        expect(CharacterSelect.isOpen()).to_be(true)
        CharacterSelect.toggle()
        expect(CharacterSelect.isOpen()).to_be(false)
    end)

    it("GOD_ORDER has correct count", function()
        local CharacterSelect = require("ui.character_select")
        -- The LAYOUT specifies 6 god slots
        expect(CharacterSelect.LAYOUT.GOD_ROW_SLOTS).to_be(6)
    end)

    it("CLASS_ORDER has correct count", function()
        local CharacterSelect = require("ui.character_select")
        -- The LAYOUT specifies 3 class slots
        expect(CharacterSelect.LAYOUT.CLASS_ROW_SLOTS).to_be(3)
    end)
end)

--------------------------------------------------------------------------------
-- CS-05: Focus Management
--------------------------------------------------------------------------------

describe("CS-05: Focus State API", function()
    it("has getFocusSection() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getFocusSection).to_be_type("function")
    end)

    it("has getFocusIndex() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getFocusIndex).to_be_type("function")
    end)

    it("has setFocus() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.setFocus).to_be_type("function")
    end)

    it("has FOCUS_SECTIONS constant", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.FOCUS_SECTIONS).never().to_be_nil()
        expect(CharacterSelect.FOCUS_SECTIONS.GODS).to_be(1)
        expect(CharacterSelect.FOCUS_SECTIONS.CLASSES).to_be(2)
        expect(CharacterSelect.FOCUS_SECTIONS.BUTTONS).to_be(3)
    end)
end)

describe("CS-05: Arrow Key Navigation", function()
    it("has moveFocusLeft() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.moveFocusLeft).to_be_type("function")
    end)

    it("has moveFocusRight() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.moveFocusRight).to_be_type("function")
    end)

    it("moveFocusRight increments index", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 1)
        CharacterSelect.moveFocusRight()
        expect(CharacterSelect.getFocusIndex()).to_be(2)
    end)

    it("moveFocusLeft decrements index", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 3)
        CharacterSelect.moveFocusLeft()
        expect(CharacterSelect.getFocusIndex()).to_be(2)
    end)

    it("moveFocusRight wraps at end of gods row", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- Gods row has 6 slots (index 1-6)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 6)
        CharacterSelect.moveFocusRight()
        expect(CharacterSelect.getFocusIndex()).to_be(1)
    end)

    it("moveFocusLeft wraps at start of gods row", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 1)
        CharacterSelect.moveFocusLeft()
        expect(CharacterSelect.getFocusIndex()).to_be(6)
    end)

    it("moveFocusRight wraps at end of classes row", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- Classes row has 3 slots (index 1-3)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.CLASSES, 3)
        CharacterSelect.moveFocusRight()
        expect(CharacterSelect.getFocusIndex()).to_be(1)
    end)

    it("moveFocusRight wraps at end of buttons row", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- Buttons row has 2 slots (index 1-2)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.BUTTONS, 2)
        CharacterSelect.moveFocusRight()
        expect(CharacterSelect.getFocusIndex()).to_be(1)
    end)
end)

describe("CS-05: Tab Navigation", function()
    it("has nextFocusSection() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.nextFocusSection).to_be_type("function")
    end)

    it("has prevFocusSection() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.prevFocusSection).to_be_type("function")
    end)

    it("nextFocusSection cycles Gods -> Classes -> Buttons -> Gods", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 1)
        expect(CharacterSelect.getFocusSection()).to_be(CharacterSelect.FOCUS_SECTIONS.GODS)

        CharacterSelect.nextFocusSection()
        expect(CharacterSelect.getFocusSection()).to_be(CharacterSelect.FOCUS_SECTIONS.CLASSES)

        CharacterSelect.nextFocusSection()
        expect(CharacterSelect.getFocusSection()).to_be(CharacterSelect.FOCUS_SECTIONS.BUTTONS)

        CharacterSelect.nextFocusSection()
        expect(CharacterSelect.getFocusSection()).to_be(CharacterSelect.FOCUS_SECTIONS.GODS)
    end)

    it("prevFocusSection cycles backwards", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 1)

        CharacterSelect.prevFocusSection()
        expect(CharacterSelect.getFocusSection()).to_be(CharacterSelect.FOCUS_SECTIONS.BUTTONS)
    end)

    it("section change resets index to 1", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 4)
        CharacterSelect.nextFocusSection()
        expect(CharacterSelect.getFocusIndex()).to_be(1)
    end)
end)

describe("CS-05: Activate Focus", function()
    it("has activateFocus() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.activateFocus).to_be_type("function")
    end)

    it("activateFocus on god selects that god", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- Focus on first god (pyr is index 1 in GOD_ORDER)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 1)
        CharacterSelect.activateFocus()
        expect(CharacterSelect.getSelectedGod()).to_be("pyr")
    end)

    it("activateFocus on class selects that class", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- Focus on first class (channeler is index 1 in CLASS_ORDER)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.CLASSES, 1)
        CharacterSelect.activateFocus()
        expect(CharacterSelect.getSelectedClass()).to_be("channeler")
    end)

    it("activateFocus on locked god does nothing", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        -- Focus on locked god (index 5 = locked_god_1)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 5)
        CharacterSelect.activateFocus()
        -- Should still be pyr
        expect(CharacterSelect.getSelectedGod()).to_be("pyr")
    end)

    it("activateFocus on Random button triggers randomize", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- Focus on Random button (index 1 in buttons)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.BUTTONS, 1)
        CharacterSelect.activateFocus()
        -- Should have selected both
        expect(CharacterSelect.getSelectedGod()).never().to_be_nil()
        expect(CharacterSelect.getSelectedClass()).never().to_be_nil()
    end)

    it("activateFocus on Confirm button triggers confirm when enabled", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("pyr")
        CharacterSelect.selectClass("channeler")

        local confirmed = false
        CharacterSelect.setOnConfirm(function() confirmed = true end)

        -- Focus on Confirm button (index 2 in buttons)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.BUTTONS, 2)
        CharacterSelect.activateFocus()

        expect(confirmed).to_be(true)
    end)

    it("activateFocus on Confirm button does nothing when disabled", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        -- No selection made

        local confirmed = false
        CharacterSelect.setOnConfirm(function() confirmed = true end)

        -- Focus on Confirm button (index 2 in buttons)
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.BUTTONS, 2)
        CharacterSelect.activateFocus()

        expect(confirmed).to_be(false)
    end)
end)

describe("CS-05: Focused Item Helpers", function()
    it("has getFocusedItemId() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.getFocusedItemId).to_be_type("function")
    end)

    it("getFocusedItemId returns god id when focused on gods", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 2)
        expect(CharacterSelect.getFocusedItemId()).to_be("glah")
    end)

    it("getFocusedItemId returns class id when focused on classes", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.CLASSES, 2)
        expect(CharacterSelect.getFocusedItemId()).to_be("seer")
    end)

    it("getFocusedItemId returns button name when focused on buttons", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.BUTTONS, 1)
        expect(CharacterSelect.getFocusedItemId()).to_be("random")

        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.BUTTONS, 2)
        expect(CharacterSelect.getFocusedItemId()).to_be("confirm")
    end)
end)

--------------------------------------------------------------------------------
-- CS-07: Visual Polish Configuration
--------------------------------------------------------------------------------

describe("CS-07: Aura Particle Configuration", function()
    it("has AURA_PARTICLES constant", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.AURA_PARTICLES).never().to_be_nil()
    end)

    it("AURA_PARTICLES has config for each unlocked god", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.AURA_PARTICLES.pyr).never().to_be_nil()
        expect(CharacterSelect.AURA_PARTICLES.glah).never().to_be_nil()
        expect(CharacterSelect.AURA_PARTICLES.vix).never().to_be_nil()
        expect(CharacterSelect.AURA_PARTICLES["nil"]).never().to_be_nil()
    end)

    it("aura config has sprite and color", function()
        local CharacterSelect = require("ui.character_select")
        local pyrAura = CharacterSelect.AURA_PARTICLES.pyr
        expect(pyrAura.sprite).never().to_be_nil()
        expect(pyrAura.color).never().to_be_nil()
    end)
end)

describe("CS-07: Sound Effect Keys", function()
    it("has SOUNDS constant", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.SOUNDS).never().to_be_nil()
    end)

    it("SOUNDS has hover key", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.SOUNDS.HOVER).never().to_be_nil()
    end)

    it("SOUNDS has select key", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.SOUNDS.SELECT).never().to_be_nil()
    end)

    it("SOUNDS has confirm_enabled key", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.SOUNDS.CONFIRM_ENABLED).never().to_be_nil()
    end)

    it("SOUNDS has confirm_pressed key", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.SOUNDS.CONFIRM_PRESSED).never().to_be_nil()
    end)

    it("SOUNDS has random key", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.SOUNDS.RANDOM).never().to_be_nil()
    end)
end)

describe("CS-07: Visual State Helpers", function()
    it("has isItemFocused() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.isItemFocused).to_be_type("function")
    end)

    it("isItemFocused returns true for focused god", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.GODS, 2)
        expect(CharacterSelect.isItemFocused("glah", "god")).to_be(true)
        expect(CharacterSelect.isItemFocused("pyr", "god")).to_be(false)
    end)

    it("isItemFocused returns true for focused class", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.CLASSES, 1)
        expect(CharacterSelect.isItemFocused("channeler", "class")).to_be(true)
        expect(CharacterSelect.isItemFocused("seer", "class")).to_be(false)
    end)

    it("isItemFocused returns true for focused button", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.setFocus(CharacterSelect.FOCUS_SECTIONS.BUTTONS, 2)
        expect(CharacterSelect.isItemFocused("confirm", "button")).to_be(true)
        expect(CharacterSelect.isItemFocused("random", "button")).to_be(false)
    end)

    it("has isItemSelected() method", function()
        local CharacterSelect = require("ui.character_select")
        expect(CharacterSelect.isItemSelected).to_be_type("function")
    end)

    it("isItemSelected returns true for selected god", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectGod("vix")
        expect(CharacterSelect.isItemSelected("vix", "god")).to_be(true)
        expect(CharacterSelect.isItemSelected("pyr", "god")).to_be(false)
    end)

    it("isItemSelected returns true for selected class", function()
        local CharacterSelect = require("ui.character_select")
        CharacterSelect.destroy()
        CharacterSelect.selectClass("seer")
        expect(CharacterSelect.isItemSelected("seer", "class")).to_be(true)
        expect(CharacterSelect.isItemSelected("channeler", "class")).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_character_select%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
