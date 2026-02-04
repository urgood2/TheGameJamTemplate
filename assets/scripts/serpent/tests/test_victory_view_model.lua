--[[
================================================================================
TEST: Victory View Model
================================================================================
Tests for victory screen view-model functionality.

Run with: lua assets/scripts/serpent/tests/test_victory_view_model.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.ui.victory_view_model"] = nil

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = print

t.describe("victory_view_model - View Model Creation", function()
    t.it("creates basic view model structure", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        local final_game_state = {
            wave = 20,
            gold = 100,
            snake_state = {
                segments = {
                    { def_id = "soldier", level = 1, hp = 100, hp_max_base = 100 },
                    { def_id = "apprentice", level = 2, hp = 150, hp_max_base = 150 }
                }
            }
        }

        local view_model = victory_view_model.build(final_game_state, 600, 12345)

        -- Check basic structure
        t.expect(view_model.title).to_be("ui.serpent_victory_title")
        t.expect(view_model.subtitle).to_be("Victory Achieved!")
        t.expect(view_model.stats).to_be_truthy()
        t.expect(view_model.snake_summary).to_be_truthy()
        t.expect(view_model.buttons).to_be_truthy()
    end)

    t.it("calculates run statistics correctly", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        local final_game_state = {
            wave = 15,
            gold = 250
        }

        local view_model = victory_view_model.build(final_game_state, 847, 54321)

        t.expect(view_model.stats.waves_completed).to_be(15)
        t.expect(view_model.stats.final_gold).to_be(250)
        t.expect(view_model.stats.run_time_sec).to_be(847)
        t.expect(view_model.stats.run_time_display).to_be("14:07")
        t.expect(view_model.stats.seed).to_be(54321)
        t.expect(view_model.stats.seed_display).to_be("Seed: 54321")
    end)

    t.it("builds snake summary correctly", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        local final_game_state = {
            wave = 20,
            gold = 200,
            snake_state = {
                segments = {
                    { def_id = "soldier", level = 1, hp = 100 },
                    { def_id = "knight", level = 2, hp = 160 },
                    { def_id = "apprentice", level = 1, hp = 80 },
                    { def_id = "healer", level = 3, hp = 180 }
                }
            }
        }

        local view_model = victory_view_model.build(final_game_state, 600, 12345)

        t.expect(view_model.snake_summary.total_segments).to_be(4)
        t.expect(view_model.snake_summary.class_counts.Warrior).to_be(2) -- soldier + knight
        t.expect(view_model.snake_summary.class_counts.Mage).to_be(1) -- apprentice
        t.expect(view_model.snake_summary.class_counts.Support).to_be(1) -- healer
        t.expect(view_model.snake_summary.level_counts[1]).to_be(2) -- soldier + apprentice
        t.expect(view_model.snake_summary.level_counts[2]).to_be(1) -- knight
        t.expect(view_model.snake_summary.level_counts[3]).to_be(1) -- healer
    end)

    t.it("includes correct buttons", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        local view_model = victory_view_model.build({}, 0, 0)

        t.expect(#view_model.buttons).to_be(2)

        local retry_button = view_model.buttons[1]
        t.expect(retry_button.id).to_be("retry")
        t.expect(retry_button.label).to_be("Play Again")
        t.expect(retry_button.action).to_be("restart_run")
        t.expect(retry_button.style).to_be("primary")

        local menu_button = view_model.buttons[2]
        t.expect(menu_button.id).to_be("menu")
        t.expect(menu_button.label).to_be("Main Menu")
        t.expect(menu_button.action).to_be("return_to_menu")
        t.expect(menu_button.style).to_be("secondary")
    end)
end)

t.describe("victory_view_model - Utility Functions", function()
    t.it("formats time correctly", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        t.expect(victory_view_model._format_time(0)).to_be("00:00")
        t.expect(victory_view_model._format_time(59)).to_be("00:59")
        t.expect(victory_view_model._format_time(60)).to_be("01:00")
        t.expect(victory_view_model._format_time(125)).to_be("02:05")
        t.expect(victory_view_model._format_time(3661)).to_be("61:01") -- Over an hour
    end)

    t.it("maps unit classes correctly", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        t.expect(victory_view_model._get_unit_class("soldier")).to_be("Warrior")
        t.expect(victory_view_model._get_unit_class("apprentice")).to_be("Mage")
        t.expect(victory_view_model._get_unit_class("scout")).to_be("Ranger")
        t.expect(victory_view_model._get_unit_class("healer")).to_be("Support")
        t.expect(victory_view_model._get_unit_class("unknown_unit")).to_be("Unknown")
    end)

    t.it("generates summary lines", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        local mock_view_model = victory_view_model.get_mock_view_model()
        local summary_lines = victory_view_model.get_summary_lines(mock_view_model)

        t.expect(#summary_lines).to_be_truthy()
        -- Check that the first few lines contain expected content
        local first_line_has_waves = string.find(summary_lines[1], "Waves Completed") ~= nil
        local second_line_has_gold = string.find(summary_lines[2], "Final Gold") ~= nil
        local third_line_has_time = string.find(summary_lines[3], "Run Time") ~= nil

        t.expect(first_line_has_waves).to_be(true)
        t.expect(second_line_has_gold).to_be(true)
        t.expect(third_line_has_time).to_be(true)
    end)

    t.it("passes self-test", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        local test_passed = victory_view_model.test_view_model_generation()
        t.expect(test_passed).to_be(true)
    end)
end)

t.describe("victory_view_model - Mock Data", function()
    t.it("provides working mock view model", function()
        local victory_view_model = require("serpent.ui.victory_view_model")

        local mock_view_model = victory_view_model.get_mock_view_model()

        t.expect(mock_view_model.title).to_be("ui.serpent_victory_title")
        t.expect(mock_view_model.stats.waves_completed).to_be(20)
        t.expect(mock_view_model.snake_summary.total_segments).to_be(4)
        t.expect(#mock_view_model.buttons).to_be(2)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)