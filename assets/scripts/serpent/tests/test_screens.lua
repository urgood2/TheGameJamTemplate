--[[
================================================================================
TEST: Screen Components Verification
================================================================================
Verifies that screen UI components correctly implement:
- Required labels present
- Buttons configured properly
- Localization keys used where appropriate

Tests game_over_screen.lua and victory_screen.lua as specified in task bd-14ft.

Run with: lua assets/scripts/serpent/tests/test_screens.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock dependencies BEFORE requiring modules
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end
_G.globals = {
    screenWidth = function() return 800 end,
    screenHeight = function() return 600 end
}

-- Mock Text system - must be injected into package.loaded before require
local MockText = {
    define = function()
        return {
            content = function(self, content) self._content = content; return self end,
            size = function(self, size) self._size = size; return self end,
            anchor = function(self, anchor) self._anchor = anchor; return self end,
            space = function(self, space) self._space = space; return self end,
            z = function(self, z) self._z = z; return self end,
            pop = function(self, pop) self._pop = pop; return self end,
            spawn = function(self)
                return {
                    at = function(self, x, y)
                        return {
                            stop = function() end,
                            _x = x,
                            _y = y
                        }
                    end
                }
            end
        }
    end
}

-- Mock signal system (emit defined after table to avoid self-reference issue)
local MockSignal = {
    last_emitted = nil,
    last_args = {},
}
function MockSignal.emit(signal_name, ...)
    MockSignal.last_emitted = signal_name
    MockSignal.last_args = {...}
end
_G.signal = MockSignal

-- Inject mocks into package.loaded BEFORE requiring test modules
package.loaded["core.text"] = MockText
package.loaded["external.hump.signal"] = MockSignal

local t = require("tests.test_runner")

t.describe("game_over_screen.lua - Screen Requirements", function()
    t.it("has required labels present", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        -- Test view-model contains required labels
        local test_stats = {
            final_wave = 10,
            gold_earned = 250,
            units_purchased = 8
        }

        local view_model = game_over_screen.get_view_model(test_stats)

        -- Check title label
        t.expect(view_model.title).to_be("GAME OVER")

        -- Check button labels
        t.expect(view_model.buttons).to_be_truthy()
        t.expect(view_model.buttons.retry).to_be_truthy()
        t.expect(view_model.buttons.retry.label).to_be("Retry")
        t.expect(view_model.buttons.main_menu).to_be_truthy()
        t.expect(view_model.buttons.main_menu.label).to_be("Main Menu")
    end)

    t.it("has buttons configured correctly", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        local test_stats = { final_wave = 5 }
        local view_model = game_over_screen.get_view_model(test_stats)

        -- Check retry button configuration
        t.expect(view_model.buttons.retry.enabled).to_be(true)
        t.expect(view_model.buttons.retry.label).to_be("Retry")

        -- Check main menu button configuration
        t.expect(view_model.buttons.main_menu.enabled).to_be(true)
        t.expect(view_model.buttons.main_menu.label).to_be("Main Menu")

        -- Test button functionality by checking localization keys
        t.expect(view_model.localization_keys).to_be_truthy()
        t.expect(view_model.localization_keys.retry).to_be("ui.serpent_retry")
        t.expect(view_model.localization_keys.main_menu).to_be("ui.serpent_main_menu")
    end)

    t.it("uses correct localization keys", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        local view_model = game_over_screen.get_view_model({})

        -- Check all required localization keys
        t.expect(view_model.localization_keys).to_be_truthy()
        t.expect(view_model.localization_keys.title).to_be("ui.serpent_game_over_title")
        t.expect(view_model.localization_keys.retry).to_be("ui.serpent_retry")
        t.expect(view_model.localization_keys.main_menu).to_be("ui.serpent_main_menu")

        -- Check button localization keys
        t.expect(view_model.buttons.retry.localization_key).to_be("ui.serpent_retry")
        t.expect(view_model.buttons.main_menu.localization_key).to_be("ui.serpent_main_menu")
    end)

    t.it("provides view-model with complete data structure", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        local test_stats = {
            final_wave = 15,
            gold_earned = 500,
            units_purchased = 20,
            enemies_defeated = 150
        }

        local view_model = game_over_screen.get_view_model(test_stats)

        -- Check required structure
        t.expect(view_model.isVisible).never().to_be_nil()
        t.expect(view_model.title).never().to_be_nil()
        t.expect(view_model.stats).never().to_be_nil()
        t.expect(view_model.buttons).never().to_be_nil()
        t.expect(view_model.localization_keys).never().to_be_nil()

        -- Check stats structure
        t.expect(view_model.stats.final_wave).to_be(15)
        t.expect(view_model.stats.gold_earned).to_be(500)
        t.expect(view_model.stats.units_purchased).to_be(20)
        t.expect(view_model.stats.enemies_defeated).to_be(150)
    end)

    t.it("detects game over conditions correctly", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        -- Test game over with empty snake
        local empty_snake = { segments = {} }
        t.expect(game_over_screen.should_show_game_over(empty_snake)).to_be(true)

        -- Test game over with nil snake
        t.expect(game_over_screen.should_show_game_over(nil)).to_be(true)

        -- Test not game over with segments
        local living_snake = {
            segments = {
                { instance_id = 1 },
                { instance_id = 2 }
            }
        }
        t.expect(game_over_screen.should_show_game_over(living_snake)).to_be(false)
    end)

    t.it("calculates final stats correctly", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        local snake_state = {
            segments = { { instance_id = 1 }, { instance_id = 2 } }
        }
        local wave_num = 8
        local gold = 200
        local tracked_stats = {
            total_gold_earned = 250,
            units_purchased = 12,
            enemies_defeated = 75
        }

        local final_stats = game_over_screen.calculate_final_stats(
            snake_state, wave_num, gold, tracked_stats
        )

        t.expect(final_stats.final_wave).to_be(8)
        t.expect(final_stats.waves_cleared).to_be(7) -- wave - 1
        t.expect(final_stats.gold_earned).to_be(250)
        t.expect(final_stats.units_purchased).to_be(12)
        t.expect(final_stats.final_snake_length).to_be(2)
        t.expect(final_stats.enemies_defeated).to_be(75)
    end)
end)

t.describe("victory_screen.lua - Screen Requirements", function()
    t.it("has required labels present", function()
        -- Clear cached victory_screen to allow fresh require with capturing mock
        package.loaded["serpent.ui.victory_screen"] = nil

        -- Create a capturing mock for Text
        local captured_content = {}
        local CapturingMockText = {
            define = function()
                return {
                    content = function(self, content)
                        table.insert(captured_content, content)
                        return self
                    end,
                    size = function(self, size) return self end,
                    anchor = function(self, anchor) return self end,
                    space = function(self, space) return self end,
                    z = function(self, z) return self end,
                    pop = function(self, pop) return self end,
                    spawn = function(self)
                        return {
                            at = function(self, x, y)
                                return { stop = function() end }
                            end
                        }
                    end
                }
            end
        }
        package.loaded["core.text"] = CapturingMockText

        -- Fresh require with capturing mock
        local victory_screen = require("serpent.ui.victory_screen")

        -- Show victory screen to capture labels
        victory_screen.show()

        -- Check that victory title is present
        local has_victory_title = false
        local has_continue_button = false
        for _, content in ipairs(captured_content) do
            if content:match("VICTORY") then
                has_victory_title = true
            end
            if content:match("Continue") then
                has_continue_button = true
            end
        end

        t.expect(has_victory_title).to_be(true)
        t.expect(has_continue_button).to_be(true)

        victory_screen.hide()

        -- Restore standard mock
        package.loaded["core.text"] = MockText
    end)

    t.it("has button configured correctly", function()
        local victory_screen = require("serpent.ui.victory_screen")

        -- Show victory screen
        victory_screen.show()

        -- Check that button bounds are configured
        t.expect(victory_screen._buttonBounds).to_be_truthy()
        t.expect(victory_screen._buttonBounds.x).never().to_be_nil()
        t.expect(victory_screen._buttonBounds.y).never().to_be_nil()
        t.expect(victory_screen._buttonBounds.w).never().to_be_nil()
        t.expect(victory_screen._buttonBounds.h).never().to_be_nil()

        victory_screen.hide()
    end)

    t.it("handles click interactions correctly", function()
        local victory_screen = require("serpent.ui.victory_screen")

        -- Reset signal tracking
        MockSignal.last_emitted = nil

        victory_screen.show()

        -- Test button click detection
        local bounds = victory_screen._buttonBounds
        local click_x = bounds.x + bounds.w / 2
        local click_y = bounds.y + bounds.h / 2

        victory_screen.checkClick(click_x, click_y, true)

        -- Check that continue signal was emitted
        t.expect(MockSignal.last_emitted).to_be("continue_game")

        -- Test any click functionality
        MockSignal.last_emitted = nil
        victory_screen.show() -- Show again since checkClick hides it

        victory_screen.handleAnyClick()
        t.expect(MockSignal.last_emitted).to_be("continue_game")
    end)

    t.it("manages visibility state correctly", function()
        local victory_screen = require("serpent.ui.victory_screen")

        -- Initially not visible
        t.expect(victory_screen.isVisible).to_be(false)

        -- Show makes it visible
        victory_screen.show()
        t.expect(victory_screen.isVisible).to_be(true)

        -- Hide makes it not visible
        victory_screen.hide()
        t.expect(victory_screen.isVisible).to_be(false)

        -- Double show doesn't break anything
        victory_screen.show()
        victory_screen.show()
        t.expect(victory_screen.isVisible).to_be(true)

        victory_screen.hide()
    end)

    t.it("ignores clicks when not visible", function()
        local victory_screen = require("serpent.ui.victory_screen")

        MockSignal.last_emitted = nil

        -- Ensure screen is hidden
        victory_screen.hide()

        -- Try to click
        victory_screen.checkClick(400, 300, true)
        victory_screen.handleAnyClick()

        -- Should not emit signal
        t.expect(MockSignal.last_emitted).to_be_nil()
    end)
end)

t.describe("screens.lua - Cross-Screen Consistency", function()
    t.it("screens follow consistent visibility patterns", function()
        local game_over_screen = require("serpent.ui.game_over_screen")
        local victory_screen = require("serpent.ui.victory_screen")

        -- Both screens should have isVisible property
        t.expect(game_over_screen.isVisible ~= nil).to_be(true)
        t.expect(victory_screen.isVisible ~= nil).to_be(true)

        -- Both screens should start not visible
        t.expect(game_over_screen.isVisible).to_be(false)
        t.expect(victory_screen.isVisible).to_be(false)
    end)

    t.it("screens provide proper cleanup", function()
        local game_over_screen = require("serpent.ui.game_over_screen")
        local victory_screen = require("serpent.ui.victory_screen")

        -- Both screens should have show/hide methods
        t.expect(type(game_over_screen.show)).to_be("function")
        t.expect(type(game_over_screen.hide)).to_be("function")
        t.expect(type(victory_screen.show)).to_be("function")
        t.expect(type(victory_screen.hide)).to_be("function")

        -- Show and hide should work without errors
        game_over_screen.show({})
        game_over_screen.hide()

        victory_screen.show()
        victory_screen.hide()

        -- Screens should be properly hidden after hide()
        t.expect(game_over_screen.isVisible).to_be(false)
        t.expect(victory_screen.isVisible).to_be(false)
    end)

    t.it("screens handle signal emission properly", function()
        local game_over_screen = require("serpent.ui.game_over_screen")
        local victory_screen = require("serpent.ui.victory_screen")

        MockSignal.last_emitted = nil

        -- Game over screen should emit appropriate signals
        -- Note: game_over_screen uses signal emission in its internal functions
        -- We test the victory screen since it's simpler and more predictable
        victory_screen.show()
        victory_screen.handleAnyClick()
        t.expect(MockSignal.last_emitted).to_be("continue_game")

        victory_screen.hide()
    end)
end)

t.describe("screens.lua - Localization Compliance", function()
    t.it("game over screen uses proper localization structure", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        local view_model = game_over_screen.get_view_model({})

        -- Check localization keys follow proper naming convention
        local loc_keys = view_model.localization_keys
        t.expect(loc_keys.title:match("^ui%.serpent_")).to_be_truthy()
        t.expect(loc_keys.retry:match("^ui%.serpent_")).to_be_truthy()
        t.expect(loc_keys.main_menu:match("^ui%.serpent_")).to_be_truthy()

        -- Check buttons reference their localization keys
        t.expect(view_model.buttons.retry.localization_key).to_be(loc_keys.retry)
        t.expect(view_model.buttons.main_menu.localization_key).to_be(loc_keys.main_menu)
    end)

    t.it("victory screen could benefit from localization", function()
        local victory_screen = require("serpent.ui.victory_screen")

        -- Note: Victory screen currently uses hardcoded strings
        -- This test documents the current state and could guide future improvements

        -- The victory screen should be enhanced to support localization
        -- For now, we test that it at least has the basic functionality
        victory_screen.show()
        t.expect(victory_screen.isVisible).to_be(true)
        victory_screen.hide()

        -- This is a documentation test - victory_screen could use localization keys
        -- like "ui.serpent_victory_title" and "ui.serpent_continue"
    end)
end)

t.describe("screens.lua - Built-in Testing", function()
    t.it("game over screen passes its built-in tests", function()
        local game_over_screen = require("serpent.ui.game_over_screen")

        -- Run the built-in tests
        local all_tests_passed = game_over_screen.run_all_tests()
        t.expect(all_tests_passed).to_be(true)

        local view_model_test = game_over_screen.test_view_model_generation()
        t.expect(view_model_test).to_be(true)

        local game_over_detection_test = game_over_screen.test_game_over_detection()
        t.expect(game_over_detection_test).to_be(true)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)