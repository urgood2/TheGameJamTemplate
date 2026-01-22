--[[
================================================================================
TEST: GOAP Debug Overlay Module
================================================================================
Tests for the GOAP debug overlay system.

TDD Approach:
- RED: Tests fail before implementation
- GREEN: Implement, tests pass

Run with: lua assets/scripts/tests/test_goap_debug.lua
]]

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Clear cached module
package.loaded["core.goap_debug"] = nil
_G.goap_debug = nil

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Tests: Module existence and basic API
--------------------------------------------------------------------------------

t.describe("goap_debug - Module API", function()

    t.it("can be required", function()
        local goap_debug = require("core.goap_debug")
        t.expect(goap_debug).to_be_truthy()
    end)

    t.it("has enable/disable functions", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.enable)).to_be("function")
        t.expect(type(goap_debug.disable)).to_be("function")
        t.expect(type(goap_debug.is_enabled)).to_be("function")
    end)

    t.it("has set_current_goal function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.set_current_goal)).to_be("function")
    end)

    t.it("has set_plan function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.set_plan)).to_be("function")
    end)

    t.it("has set_plan_index function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.set_plan_index)).to_be("function")
    end)

    t.it("has set_world_state function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.set_world_state)).to_be("function")
    end)

    t.it("has add_rejected_action function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.add_rejected_action)).to_be("function")
    end)

    t.it("has get_entity_debug_info function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.get_entity_debug_info)).to_be("function")
    end)

    t.it("has clear_entity function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.clear_entity)).to_be("function")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: No-op when disabled
--------------------------------------------------------------------------------

t.describe("goap_debug - No-op when disabled", function()

    t.it("is disabled by default", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        t.expect(goap_debug.is_enabled()).to_be(false)
    end)

    t.it("does not store data when disabled", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")

        -- Ensure disabled
        goap_debug.disable()

        -- Try to set data
        goap_debug.set_current_goal(1, "KillPlayer", 0.9)
        goap_debug.set_plan(1, { "FindWeapon", "Attack" })
        goap_debug.set_plan_index(1, 1)

        -- Should return nil/empty when disabled
        local info = goap_debug.get_entity_debug_info(1)
        t.expect(info).to_be_falsy()
    end)

    t.it("calls are safe when disabled (no errors)", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.disable()

        -- These should not error
        goap_debug.set_current_goal(1, "Test", 1.0)
        goap_debug.set_plan(1, {})
        goap_debug.set_plan_index(1, 0)
        goap_debug.set_world_state(1, {})
        goap_debug.add_rejected_action(1, "Flee", "reason")
        goap_debug.clear_entity(1)

        t.expect(true).to_be(true)  -- If we got here, no errors
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Data storage when enabled
--------------------------------------------------------------------------------

t.describe("goap_debug - Data storage when enabled", function()

    t.it("stores goal information", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_current_goal(42, "KillPlayer", 0.9)

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info).to_be_truthy()
        t.expect(info.goal_name).to_be("KillPlayer")
        t.expect(info.goal_priority).to_be(0.9)

        goap_debug.disable()
    end)

    t.it("stores plan list", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        local plan = { "FindWeapon", "ApproachTarget", "AttackMelee", "Retreat" }
        goap_debug.set_plan(42, plan)

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info).to_be_truthy()
        t.expect(info.plan).to_be_truthy()
        t.expect(#info.plan).to_be(4)
        t.expect(info.plan[1]).to_be("FindWeapon")
        t.expect(info.plan[3]).to_be("AttackMelee")

        goap_debug.disable()
    end)

    t.it("stores plan index (current step)", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_plan(42, { "A", "B", "C" })
        goap_debug.set_plan_index(42, 2)

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info.plan_index).to_be(2)

        goap_debug.disable()
    end)

    t.it("stores world state", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        local world_state = {
            has_weapon = true,
            target_in_range = false,
            health = 45,
            ammo = 0
        }
        goap_debug.set_world_state(42, world_state)

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info.world_state).to_be_truthy()
        t.expect(info.world_state.has_weapon).to_be(true)
        t.expect(info.world_state.ammo).to_be(0)

        goap_debug.disable()
    end)

    t.it("clears entity data", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_current_goal(42, "Test", 1.0)
        goap_debug.clear_entity(42)

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info).to_be_falsy()

        goap_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Rejected actions with bounded ring buffer
--------------------------------------------------------------------------------

t.describe("goap_debug - Rejected actions (bounded)", function()

    t.it("stores rejected actions", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.add_rejected_action(42, "RangedAttack", "ammo = 0 (need > 0)")
        goap_debug.add_rejected_action(42, "Flee", "health > 30")

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info.rejected_actions).to_be_truthy()
        t.expect(#info.rejected_actions).to_be(2)
        t.expect(info.rejected_actions[1].action).to_be("RangedAttack")
        t.expect(info.rejected_actions[1].reason).to_be("ammo = 0 (need > 0)")

        goap_debug.disable()
    end)

    t.it("limits rejected actions to MAX_REJECTED (ring buffer)", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        -- Default max is 10, add 15 items
        for i = 1, 15 do
            goap_debug.add_rejected_action(42, "Action" .. i, "reason" .. i)
        end

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(#info.rejected_actions <= 10).to_be(true)

        -- Should contain the most recent entries
        local has_action15 = false
        for _, entry in ipairs(info.rejected_actions) do
            if entry.action == "Action15" then has_action15 = true end
        end
        t.expect(has_action15).to_be(true)

        goap_debug.disable()
    end)

    t.it("can configure max rejected actions", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()
        goap_debug.set_max_rejected_actions(5)

        for i = 1, 10 do
            goap_debug.add_rejected_action(42, "Action" .. i, "reason")
        end

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(#info.rejected_actions <= 5).to_be(true)

        goap_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Multiple entities
--------------------------------------------------------------------------------

t.describe("goap_debug - Multiple entities", function()

    t.it("tracks data separately per entity", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_current_goal(1, "AttackPlayer", 0.9)
        goap_debug.set_current_goal(2, "Patrol", 0.5)
        goap_debug.set_current_goal(3, "Flee", 1.0)

        local info1 = goap_debug.get_entity_debug_info(1)
        local info2 = goap_debug.get_entity_debug_info(2)
        local info3 = goap_debug.get_entity_debug_info(3)

        t.expect(info1.goal_name).to_be("AttackPlayer")
        t.expect(info2.goal_name).to_be("Patrol")
        t.expect(info3.goal_name).to_be("Flee")

        goap_debug.disable()
    end)

    t.it("can list all tracked entities", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_current_goal(100, "A", 1)
        goap_debug.set_current_goal(200, "B", 1)
        goap_debug.set_current_goal(300, "C", 1)

        local entities = goap_debug.get_tracked_entities()
        t.expect(#entities).to_be(3)

        goap_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Selected entity for detailed view
--------------------------------------------------------------------------------

t.describe("goap_debug - Entity selection", function()

    t.it("can select an entity for detailed view", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        t.expect(type(goap_debug.select_entity)).to_be("function")
        t.expect(type(goap_debug.get_selected_entity)).to_be("function")

        goap_debug.select_entity(42)
        t.expect(goap_debug.get_selected_entity()).to_be(42)

        goap_debug.disable()
    end)

    t.it("can deselect entity", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.select_entity(42)
        goap_debug.select_entity(nil)
        t.expect(goap_debug.get_selected_entity()).to_be_falsy()

        goap_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Action Selection Breakdown
--------------------------------------------------------------------------------

t.describe("goap_debug - Action selection breakdown", function()

    t.it("has set_current_action function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.set_current_action)).to_be("function")
    end)

    t.it("has set_action_preconditions function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.set_action_preconditions)).to_be("function")
    end)

    t.it("has set_action_cost function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.set_action_cost)).to_be("function")
    end)

    t.it("has add_competing_action function", function()
        local goap_debug = require("core.goap_debug")
        t.expect(type(goap_debug.add_competing_action)).to_be("function")
    end)

    t.it("stores current action info", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_current_action(42, "AttackMelee")

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info.current_action).to_be("AttackMelee")

        goap_debug.disable()
    end)

    t.it("stores action preconditions with met/unmet status", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        local preconditions = {
            { name = "has_weapon", met = true, required = true, actual = true },
            { name = "target_in_range", met = true, required = true, actual = true },
            { name = "has_ammo", met = false, required = true, actual = false }
        }
        goap_debug.set_action_preconditions(42, "RangedAttack", preconditions)

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info.action_preconditions).to_be_truthy()
        t.expect(info.action_preconditions.action).to_be("RangedAttack")
        t.expect(#info.action_preconditions.conditions).to_be(3)
        t.expect(info.action_preconditions.conditions[1].name).to_be("has_weapon")
        t.expect(info.action_preconditions.conditions[1].met).to_be(true)
        t.expect(info.action_preconditions.conditions[3].met).to_be(false)

        goap_debug.disable()
    end)

    t.it("stores action cost calculation", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_action_cost(42, "AttackMelee", 1.5, {
            { name = "base_cost", value = 1.0 },
            { name = "distance_penalty", value = 0.5 }
        })

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info.action_cost).to_be_truthy()
        t.expect(info.action_cost.action).to_be("AttackMelee")
        t.expect(info.action_cost.total).to_be(1.5)
        t.expect(#info.action_cost.breakdown).to_be(2)
        t.expect(info.action_cost.breakdown[1].name).to_be("base_cost")

        goap_debug.disable()
    end)

    t.it("stores competing actions with why they lost", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.add_competing_action(42, "RangedAttack", 2.0, "Higher cost (2.0 vs 1.5)")
        goap_debug.add_competing_action(42, "Flee", nil, "Precondition failed: health <= 30")

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info.competing_actions).to_be_truthy()
        t.expect(#info.competing_actions).to_be(2)
        t.expect(info.competing_actions[1].action).to_be("RangedAttack")
        t.expect(info.competing_actions[1].cost).to_be(2.0)
        t.expect(info.competing_actions[1].reason).to_be("Higher cost (2.0 vs 1.5)")
        t.expect(info.competing_actions[2].action).to_be("Flee")
        t.expect(info.competing_actions[2].reason:match("Precondition")).to_be_truthy()

        goap_debug.disable()
    end)

    t.it("limits competing actions (bounded)", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()
        goap_debug.set_max_competing_actions(5)

        for i = 1, 10 do
            goap_debug.add_competing_action(42, "Action" .. i, i, "reason")
        end

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(#info.competing_actions <= 5).to_be(true)

        goap_debug.disable()
    end)

    t.it("clears action selection info when clearing entity", function()
        package.loaded["core.goap_debug"] = nil
        local goap_debug = require("core.goap_debug")
        goap_debug.enable()

        goap_debug.set_current_action(42, "Test")
        goap_debug.set_action_cost(42, "Test", 1.0, {})
        goap_debug.add_competing_action(42, "Other", 2.0, "reason")
        goap_debug.clear_entity(42)

        local info = goap_debug.get_entity_debug_info(42)
        t.expect(info).to_be_falsy()

        goap_debug.disable()
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
