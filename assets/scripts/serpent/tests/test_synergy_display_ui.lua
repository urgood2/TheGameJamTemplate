--[[
================================================================================
TEST: Synergy Display UI
================================================================================
Tests for synergy display view-model functionality.

Run with: lua assets/scripts/serpent/tests/test_synergy_display_ui.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.ui.synergy_display_ui"] = nil
package.loaded["serpent.synergy_system"] = nil

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = print

t.describe("synergy_display_ui - View Model", function()
    t.it("provides basic view model structure", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local segments = {}
        local unit_defs = {}

        local view_model = synergy_display_ui.get_view_model(segments, unit_defs)

        -- Check basic structure
        t.expect(view_model.class_counts).to_be_truthy()
        t.expect(view_model.active_synergies).to_be_truthy()
        t.expect(view_model.has_synergies).to_be(false)
        t.expect(view_model.total_units).to_be(0)
        t.expect(view_model.global_regen).to_be(0.0)
    end)

    t.it("calculates class counts correctly", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local segments = {
            { instance_id = 1, def_id = "soldier", hp = 100 },
            { instance_id = 2, def_id = "mage", hp = 80 },
            { instance_id = 3, def_id = "soldier", hp = 100 },
            { instance_id = 4, def_id = "ranger", hp = 70 }
        }

        local unit_defs = {
            soldier = { class = "Warrior", name = "Soldier" },
            mage = { class = "Mage", name = "Mage" },
            ranger = { class = "Ranger", name = "Ranger" }
        }

        local view_model = synergy_display_ui.get_view_model(segments, unit_defs)

        t.expect(view_model.class_counts.Warrior).to_be(2)
        t.expect(view_model.class_counts.Mage).to_be(1)
        t.expect(view_model.class_counts.Ranger).to_be(1)
        t.expect(view_model.class_counts.Support).to_be(0)
        t.expect(view_model.total_units).to_be(4)
    end)

    t.it("detects active synergies", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local segments = {
            { instance_id = 1, def_id = "warrior", hp = 100 },
            { instance_id = 2, def_id = "warrior", hp = 100 }
        }

        local unit_defs = {
            warrior = { class = "Warrior", name = "Warrior" }
        }

        local view_model = synergy_display_ui.get_view_model(segments, unit_defs)

        t.expect(view_model.has_synergies).to_be(true)
        t.expect(#view_model.active_synergies).to_be(1)

        local warrior_synergy = view_model.active_synergies[1]
        t.expect(warrior_synergy.class).to_be("Warrior")
        t.expect(warrior_synergy.count).to_be(2)
        t.expect(warrior_synergy.threshold).to_be(2)
    end)

    t.it("handles Support global regen", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local segments = {
            { instance_id = 1, def_id = "healer", hp = 60 },
            { instance_id = 2, def_id = "healer", hp = 60 }
        }

        local unit_defs = {
            healer = { class = "Support", name = "Healer" }
        }

        local view_model = synergy_display_ui.get_view_model(segments, unit_defs)

        t.expect(view_model.global_regen).to_be(5) -- 2 Support units = 5 HP/sec
        t.expect(view_model.has_synergies).to_be(true)
    end)
end)

t.describe("synergy_display_ui - Display Functions", function()
    t.it("provides class counts display", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local segments = {
            { instance_id = 1, def_id = "warrior", hp = 100 },
            { instance_id = 2, def_id = "mage", hp = 80 }
        }

        local unit_defs = {
            warrior = { class = "Warrior", name = "Warrior" },
            mage = { class = "Mage", name = "Mage" }
        }

        local display_counts = synergy_display_ui.get_class_counts_display(segments, unit_defs)

        t.expect(#display_counts).to_be(4) -- 4 classes

        -- Check Warrior entry
        local warrior_entry = display_counts[1]
        t.expect(warrior_entry.class).to_be("Warrior")
        t.expect(warrior_entry.count).to_be(1)
        t.expect(warrior_entry.status).to_be("partial")
        t.expect(warrior_entry.next_threshold).to_be(2)
        t.expect(warrior_entry.progress_text).to_be("1/2")
    end)

    t.it("generates summary text correctly", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local segments = {
            { instance_id = 1, def_id = "warrior", hp = 100 },
            { instance_id = 2, def_id = "warrior", hp = 100 }
        }

        local unit_defs = {
            warrior = { class = "Warrior", name = "Warrior" }
        }

        local summary_text = synergy_display_ui.get_summary_text(segments, unit_defs)

        t.expect(type(summary_text)).to_be("string")
        t.expect(string.find(summary_text, "Warrior")).to_be_truthy()
        t.expect(string.find(summary_text, "attack damage")).to_be_truthy()
    end)

    t.it("handles no synergies case", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local segments = {
            { instance_id = 1, def_id = "warrior", hp = 100 } -- Only 1 unit, no synergy
        }

        local unit_defs = {
            warrior = { class = "Warrior", name = "Warrior" }
        }

        local summary_text = synergy_display_ui.get_summary_text(segments, unit_defs)
        t.expect(summary_text).to_be("No active synergies")
    end)

    t.it("provides synergy requirements info", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        local requirements = synergy_display_ui.get_synergy_requirements()

        t.expect(requirements.Warrior).to_be_truthy()
        t.expect(requirements.Mage).to_be_truthy()
        t.expect(requirements.Ranger).to_be_truthy()
        t.expect(requirements.Support).to_be_truthy()

        t.expect(requirements.Warrior[2]).to_be_truthy()
        t.expect(requirements.Warrior[4]).to_be_truthy()
    end)

    t.it("determines visibility correctly", function()
        local synergy_display_ui = require("serpent.ui.synergy_display_ui")

        -- Should show with units
        local segments_with_units = {
            { instance_id = 1, def_id = "warrior", hp = 100 }
        }
        local unit_defs = {
            warrior = { class = "Warrior", name = "Warrior" }
        }

        t.expect(synergy_display_ui.should_show(segments_with_units, unit_defs)).to_be(true)

        -- Should not show with no units
        t.expect(synergy_display_ui.should_show({}, unit_defs)).to_be(false)
        t.expect(synergy_display_ui.should_show(nil, unit_defs)).to_be(false)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)