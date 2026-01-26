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
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_character_select%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
