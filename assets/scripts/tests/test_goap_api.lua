--[[
================================================================================
GOAP API TESTS - In-Game Lua Test Suite
================================================================================
Comprehensive tests for all GOAP API bindings exposed to Lua.

Run in-game by setting: RUN_GOAP_TESTS=1 ./build/raylib-cpp-cmake-template

Coverage:
- 11 ai.* methods (set_worldstate, get_worldstate, set_goal, patch_worldstate, 
  patch_goal, get_blackboard, get_entity_ai_def, pause_ai_system, resume_ai_system,
  force_interrupt, list_lua_files)
- 2 global functions (create_ai_entity, create_ai_entity_with_overrides)
- 5 utility bindings (dump_worldstate, dump_plan, get_all_atoms, has_plan, dump_blackboard)
- Blackboard usertype methods (set_*/get_* for bool/int/double/float/string, contains, clear, size, isEmpty)
- Edge cases (nil entity, invalid entity, empty states)
]]

local t = require("tests.test_runner")

local M = {}

--------------------------------------------------------------------------------
-- Test Fixtures & Helpers
--------------------------------------------------------------------------------

--- Create a test entity and return it, ensuring cleanup can happen
local function create_test_entity()
    local ok, entity = pcall(create_ai_entity, "kobold")
    if not ok then
        error("Failed to create test entity: " .. tostring(entity))
    end
    if not entity then
        error("Failed to create test entity: entity is nil")
    end
    return entity
end

--- Destroy a test entity safely
local function destroy_test_entity(entity)
    if entity and registry and registry.valid then
        local ok = pcall(function()
            if registry:valid(entity) then
                registry:destroy(entity)
            end
        end)
    end
end

--- Check if a value is userdata (for blackboard)
local function is_userdata(val)
    return type(val) == "userdata"
end

--------------------------------------------------------------------------------
-- ai.set_worldstate / ai.get_worldstate
--------------------------------------------------------------------------------

t.describe("ai.set_worldstate / ai.get_worldstate", function()
    t.it("should set and get a worldstate atom", function()
        local entity = create_test_entity()
        
        -- Set a worldstate value
        ai.set_worldstate(entity, "hungry", true)
        local value = ai.get_worldstate(entity, "hungry")
        t.expect(value).to_be(true)
        
        -- Set it to false
        ai.set_worldstate(entity, "hungry", false)
        value = ai.get_worldstate(entity, "hungry")
        t.expect(value).to_be(false)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should handle multiple atoms", function()
        local entity = create_test_entity()
        
        ai.set_worldstate(entity, "hungry", true)
        ai.set_worldstate(entity, "enemyvisible", false)
        ai.set_worldstate(entity, "underAttack", true)
        
        t.expect(ai.get_worldstate(entity, "hungry")).to_be(true)
        t.expect(ai.get_worldstate(entity, "enemyvisible")).to_be(false)
        t.expect(ai.get_worldstate(entity, "underAttack")).to_be(true)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.set_goal
--------------------------------------------------------------------------------

t.describe("ai.set_goal", function()
    t.it("should set goal without error", function()
        local entity = create_test_entity()
        
        local ok, err = pcall(function()
            ai.set_goal(entity, { hungry = false })
        end)
        t.expect(ok).to_be(true)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should handle multiple goal atoms", function()
        local entity = create_test_entity()
        
        local ok, err = pcall(function()
            ai.set_goal(entity, { hungry = false, enemyvisible = false })
        end)
        t.expect(ok).to_be(true)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.patch_worldstate
--------------------------------------------------------------------------------

t.describe("ai.patch_worldstate", function()
    t.it("should patch individual worldstate atoms", function()
        local entity = create_test_entity()
        
        ai.patch_worldstate(entity, "hungry", true)
        ai.patch_worldstate(entity, "enemyvisible", true)
        ai.patch_worldstate(entity, "underAttack", false)
        
        t.expect(ai.get_worldstate(entity, "hungry")).to_be(true)
        t.expect(ai.get_worldstate(entity, "enemyvisible")).to_be(true)
        t.expect(ai.get_worldstate(entity, "underAttack")).to_be(false)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should not affect other atoms when patching one", function()
        local entity = create_test_entity()
        
        local initial_hungry = ai.get_worldstate(entity, "hungry")
        ai.patch_worldstate(entity, "enemyvisible", true)
        t.expect(ai.get_worldstate(entity, "hungry")).to_be(initial_hungry)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.patch_goal
--------------------------------------------------------------------------------

t.describe("ai.patch_goal", function()
    t.it("should patch multiple goal atoms without error", function()
        local entity = create_test_entity()
        
        local ok = pcall(function()
            ai.patch_goal(entity, {
                hungry = false,
                enemyvisible = false
            })
        end)
        t.expect(ok).to_be(true)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.get_blackboard
--------------------------------------------------------------------------------

t.describe("ai.get_blackboard", function()
    t.it("should return a blackboard userdata", function()
        local entity = create_test_entity()
        
        local bb = ai.get_blackboard(entity)
        t.expect(bb).to_be_truthy()
        t.expect(is_userdata(bb)).to_be(true)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.get_entity_ai_def
--------------------------------------------------------------------------------

t.describe("ai.get_entity_ai_def", function()
    t.it("should return the AI definition table", function()
        local entity = create_test_entity()
        
        local def = ai.get_entity_ai_def(entity)
        t.expect(def).to_be_truthy()
        t.expect(type(def)).to_be("table")
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.pause_ai_system / ai.resume_ai_system
--------------------------------------------------------------------------------

t.describe("ai.pause_ai_system / ai.resume_ai_system", function()
    t.it("should pause and resume without error", function()
        local ok1 = pcall(ai.pause_ai_system)
        t.expect(ok1).to_be(true)
        
        local ok2 = pcall(ai.resume_ai_system)
        t.expect(ok2).to_be(true)
    end)
    
    t.it("should handle multiple pauses gracefully", function()
        local ok = pcall(function()
            ai.pause_ai_system()
            ai.pause_ai_system()
            ai.resume_ai_system()
            ai.resume_ai_system()
        end)
        t.expect(ok).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- ai.force_interrupt
--------------------------------------------------------------------------------

t.describe("ai.force_interrupt", function()
    t.it("should force interrupt without error", function()
        local entity = create_test_entity()
        
        local ok = pcall(function()
            ai.force_interrupt(entity)
        end)
        t.expect(ok).to_be(true)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.list_lua_files
--------------------------------------------------------------------------------

t.describe("ai.list_lua_files", function()
    t.it("should return a table of AI definition files", function()
        local files = ai.list_lua_files()
        t.expect(files).to_be_truthy()
        t.expect(type(files)).to_be("table")
    end)
    
    t.it("should include kobold in the list", function()
        local files = ai.list_lua_files()
        local has_kobold = false
        for _, file in ipairs(files) do
            if file == "kobold" or file:find("kobold") then
                has_kobold = true
                break
            end
        end
        t.expect(has_kobold).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- create_ai_entity (global function)
--------------------------------------------------------------------------------

t.describe("create_ai_entity", function()
    t.it("should create an AI entity by definition name", function()
        local entity = create_ai_entity("kobold")
        t.expect(entity).to_be_truthy()
        t.expect(registry:valid(entity)).to_be(true)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should return nil for invalid definition name", function()
        local entity = create_ai_entity("nonexistent_ai_type_xyz")
        t.expect(entity).to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- create_ai_entity_with_overrides (global function)
--------------------------------------------------------------------------------

t.describe("create_ai_entity_with_overrides", function()
    t.it("should create entity with initial worldstate overrides", function()
        local entity = create_ai_entity_with_overrides("kobold", {
            hungry = false,
            enemyvisible = true
        }, nil)
        t.expect(entity).to_be_truthy()
        
        -- Verify overrides were applied
        t.expect(ai.get_worldstate(entity, "hungry")).to_be(false)
        t.expect(ai.get_worldstate(entity, "enemyvisible")).to_be(true)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should create entity with goal overrides", function()
        local entity = create_ai_entity_with_overrides("kobold", nil, {
            hungry = false
        })
        t.expect(entity).to_be_truthy()
        
        -- Goals don't have getters, just verify creation succeeded
        destroy_test_entity(entity)
    end)
    
    t.it("should return nil for invalid definition", function()
        local entity = create_ai_entity_with_overrides("invalid_def_xyz", {}, {})
        t.expect(entity).to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- ai.dump_worldstate (utility binding)
--------------------------------------------------------------------------------

t.describe("ai.dump_worldstate", function()
    t.it("should return a table of atom names to boolean values", function()
        local entity = create_test_entity()
        
        ai.set_worldstate(entity, "hungry", true)
        ai.set_worldstate(entity, "enemyvisible", false)
        
        local ws = ai.dump_worldstate(entity)
        t.expect(ws).to_be_truthy()
        t.expect(type(ws)).to_be("table")
        t.expect(ws.hungry).to_be(true)
        t.expect(ws.enemyvisible).to_be(false)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.dump_plan (utility binding)
--------------------------------------------------------------------------------

t.describe("ai.dump_plan", function()
    t.it("should return a table (possibly empty for new entity)", function()
        local entity = create_test_entity()
        
        local plan = ai.dump_plan(entity)
        t.expect(plan).to_be_truthy()
        t.expect(type(plan)).to_be("table")
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.get_all_atoms (utility binding)
--------------------------------------------------------------------------------

t.describe("ai.get_all_atoms", function()
    t.it("should return a 1-based array of atom names", function()
        local entity = create_test_entity()
        
        local atoms = ai.get_all_atoms(entity)
        t.expect(atoms).to_be_truthy()
        t.expect(type(atoms)).to_be("table")
        t.expect(#atoms > 0).to_be(true)
        
        local has_hungry = false
        for _, name in ipairs(atoms) do
            if name == "hungry" then
                has_hungry = true
                break
            end
        end
        t.expect(has_hungry).to_be(true)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.has_plan (utility binding)
--------------------------------------------------------------------------------

t.describe("ai.has_plan", function()
    t.it("should return a boolean", function()
        local entity = create_test_entity()
        
        local has = ai.has_plan(entity)
        t.expect(type(has)).to_be("boolean")
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- ai.dump_blackboard (utility binding)
--------------------------------------------------------------------------------

t.describe("ai.dump_blackboard", function()
    t.it("should return a table of blackboard contents", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        -- Set some values first
        bb:set_bool("test_flag", true)
        bb:set_int("test_count", 42)
        bb:set_string("test_name", "kobold_01")
        
        local dump = ai.dump_blackboard(entity)
        t.expect(dump).to_be_truthy()
        t.expect(type(dump)).to_be("table")
        
        -- Check that our values are in the dump
        t.expect(dump.test_flag).to_be_truthy()
        t.expect(dump.test_flag.type).to_be("bool")
        t.expect(dump.test_flag.value).to_be(true)
        
        t.expect(dump.test_count).to_be_truthy()
        t.expect(dump.test_count.type).to_be("int")
        t.expect(dump.test_count.value).to_be(42)
        
        t.expect(dump.test_name).to_be_truthy()
        t.expect(dump.test_name.type).to_be("string")
        t.expect(dump.test_name.value).to_be("kobold_01")
        
        destroy_test_entity(entity)
    end)
    
    t.it("should return empty table for empty blackboard", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        bb:clear() -- Ensure empty
        
        local dump = ai.dump_blackboard(entity)
        t.expect(dump).to_be_truthy()
        t.expect(type(dump)).to_be("table")
        
        -- Should be empty or have no entries
        local count = 0
        for _ in pairs(dump) do count = count + 1 end
        t.expect(count).to_be(0)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- Blackboard Usertype Methods
--------------------------------------------------------------------------------

t.describe("Blackboard set_*/get_* methods", function()
    t.it("should set and get bool values", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        bb:set_bool("flag1", true)
        bb:set_bool("flag2", false)
        
        t.expect(bb:get_bool("flag1")).to_be(true)
        t.expect(bb:get_bool("flag2")).to_be(false)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should set and get int values", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        bb:set_int("count", 42)
        bb:set_int("negative", -10)
        bb:set_int("zero", 0)
        
        t.expect(bb:get_int("count")).to_be(42)
        t.expect(bb:get_int("negative")).to_be(-10)
        t.expect(bb:get_int("zero")).to_be(0)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should set and get double values", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        bb:set_double("pi", 3.14159265359)
        bb:set_double("neg", -2.5)
        
        local pi = bb:get_double("pi")
        t.expect(pi > 3.14 and pi < 3.15).to_be(true)
        t.expect(bb:get_double("neg")).to_be(-2.5)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should set and get float values", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        bb:set_float("speed", 1.5)
        bb:set_float("gravity", 9.8)
        
        local speed = bb:get_float("speed")
        t.expect(speed > 1.4 and speed < 1.6).to_be(true)
        
        local gravity = bb:get_float("gravity")
        t.expect(gravity > 9.7 and gravity < 9.9).to_be(true)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should set and get string values", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        bb:set_string("name", "TestKobold")
        bb:set_string("empty", "")
        bb:set_string("special", "hello world! @#$%")
        
        t.expect(bb:get_string("name")).to_be("TestKobold")
        t.expect(bb:get_string("empty")).to_be("")
        t.expect(bb:get_string("special")).to_be("hello world! @#$%")
        
        destroy_test_entity(entity)
    end)
end)

t.describe("Blackboard contains", function()
    t.it("should return true for existing keys", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        bb:set_bool("exists", true)
        t.expect(bb:contains("exists")).to_be(true)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should return false for non-existing keys", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        t.expect(bb:contains("nonexistent_key_xyz")).to_be(false)
        
        destroy_test_entity(entity)
    end)
end)

t.describe("Blackboard clear", function()
    t.it("should remove all entries", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        
        bb:set_bool("a", true)
        bb:set_int("b", 1)
        bb:set_string("c", "test")
        
        t.expect(bb:size() >= 3).to_be(true)
        
        bb:clear()
        t.expect(bb:size()).to_be(0)
        t.expect(bb:isEmpty()).to_be(true)
        
        destroy_test_entity(entity)
    end)
end)

t.describe("Blackboard size", function()
    t.it("should return correct count of entries", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        bb:clear()
        
        t.expect(bb:size()).to_be(0)
        
        bb:set_bool("a", true)
        t.expect(bb:size()).to_be(1)
        
        bb:set_int("b", 42)
        t.expect(bb:size()).to_be(2)
        
        bb:set_string("c", "test")
        t.expect(bb:size()).to_be(3)
        
        destroy_test_entity(entity)
    end)
end)

t.describe("Blackboard isEmpty", function()
    t.it("should return true for empty blackboard", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        bb:clear()
        
        t.expect(bb:isEmpty()).to_be(true)
        
        destroy_test_entity(entity)
    end)
    
    t.it("should return false for non-empty blackboard", function()
        local entity = create_test_entity()
        local bb = ai.get_blackboard(entity)
        bb:clear()
        
        bb:set_bool("test", true)
        t.expect(bb:isEmpty()).to_be(false)
        
        destroy_test_entity(entity)
    end)
end)

--------------------------------------------------------------------------------
-- Edge Cases: nil entity (Sol2 type checking)
--------------------------------------------------------------------------------

t.describe("Edge case: nil entity", function()
    t.it("ai.get_worldstate with nil should error (Sol2 type check)", function()
        local ok, err = pcall(function()
            ai.get_worldstate(nil, "hungry")
        end)
        t.expect(ok).to_be(false)
    end)
    
    t.it("ai.set_worldstate with nil should error (Sol2 type check)", function()
        local ok, err = pcall(function()
            ai.set_worldstate(nil, "hungry", true)
        end)
        t.expect(ok).to_be(false)
    end)
    
    t.it("ai.get_blackboard with nil should error (Sol2 type check)", function()
        local ok, err = pcall(function()
            ai.get_blackboard(nil)
        end)
        t.expect(ok).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function M.run()
    print("\n================================================================================")
    print("GOAP API TESTS")
    print("================================================================================\n")
    
    local success = t.run()
    
    print("\n================================================================================")
    if success then
        print("ALL GOAP TESTS PASSED!")
    else
        print("SOME GOAP TESTS FAILED - see output above")
    end
    print("================================================================================\n")
    
    return success
end

return M
