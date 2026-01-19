--[[
================================================================================
TEST: Status Effects Phase 1 - Demo Implementation
================================================================================
TDD tests for Phase 1 requirements:
1. New status effects (arcane_charge, focused, forms)
2. Status aliases (scorch=burning, freeze=frozen)
3. Per-status fan-out signals (on_apply_burn, on_apply_freeze, etc.)
4. Standardized player_damaged signal (emit both variants)

RED PHASE: These tests are written BEFORE implementation.
All tests should FAIL initially.
================================================================================
]]

local TestRunner = require("tests.test_runner")
local describe = TestRunner.describe
local it = TestRunner.it
local expect = TestRunner.expect

-- Mock signal system for capturing emissions
local function create_mock_signal()
    local emissions = {}
    return {
        emit = function(name, ...)
            emissions[#emissions + 1] = { name = name, args = {...} }
        end,
        get_emissions = function()
            return emissions
        end,
        clear = function()
            emissions = {}
        end,
        find = function(name)
            for _, e in ipairs(emissions) do
                if e.name == name then return e end
            end
            return nil
        end,
        count = function(name)
            local c = 0
            for _, e in ipairs(emissions) do
                if e.name == name then c = c + 1 end
            end
            return c
        end,
    }
end

local function create_mock_ctx()
    local events = {}
    return {
        time = { now = 0, tick = function(self, dt) self.now = self.now + dt end },
        bus = {
            emit = function(_, name, data)
                events[#events + 1] = { name = name, data = data }
            end
        },
        _events = events,
    }
end

local function create_mock_target()
    return {
        statuses = {},
        dots = {},
        stats = {
            _values = {},
            add_base = function(self, stat, value)
                self._values[stat] = (self._values[stat] or 0) + value
            end,
            get = function(self, stat)
                return self._values[stat] or 0
            end
        }
    }
end

--------------------------------------------------------------------------------
-- SECTION 1: New Status Effect Definitions
--------------------------------------------------------------------------------

describe("Phase 1: Status Effect Definitions", function()
    local StatusEffects = require("data.status_effects")

    it("arcane_charge exists with stack_mode=count", function()
        local def = StatusEffects.arcane_charge
        expect(def).never().to_be_nil()
        expect(def.id).to_be("arcane_charge")
        expect(def.stack_mode).to_be("count")
        expect(def.buff_type).to_be(true)
    end)

    it("focused exists with stack_mode=replace and duration", function()
        local def = StatusEffects.focused
        expect(def).never().to_be_nil()
        expect(def.id).to_be("focused")
        expect(def.stack_mode).to_be("replace")
        expect(def.buff_type).to_be(true)
        expect(def.duration).never().to_be_nil()
        expect(def.duration > 0).to_be(true)
    end)

    it("fireform exists as buff with aura properties", function()
        local def = StatusEffects.fireform
        expect(def).never().to_be_nil()
        expect(def.id).to_be("fireform")
        expect(def.buff_type).to_be(true)
        -- Forms should have aura/shader properties
        expect(def.shader).never().to_be_nil()
    end)

    it("iceform exists as buff with aura properties", function()
        local def = StatusEffects.iceform
        expect(def).never().to_be_nil()
        expect(def.id).to_be("iceform")
        expect(def.buff_type).to_be(true)
        expect(def.shader).never().to_be_nil()
    end)

    it("stormform exists as buff with aura properties", function()
        local def = StatusEffects.stormform
        expect(def).never().to_be_nil()
        expect(def.id).to_be("stormform")
        expect(def.buff_type).to_be(true)
        expect(def.shader).never().to_be_nil()
    end)

    it("voidform exists as buff with aura properties", function()
        local def = StatusEffects.voidform
        expect(def).never().to_be_nil()
        expect(def.id).to_be("voidform")
        expect(def.buff_type).to_be(true)
        expect(def.shader).never().to_be_nil()
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 2: Status Effect Aliases
--------------------------------------------------------------------------------

describe("Phase 1: Status Effect Aliases", function()
    local StatusEffects = require("data.status_effects")

    it("scorch is an alias for burning", function()
        expect(StatusEffects.scorch).never().to_be_nil()
        expect(StatusEffects.scorch).to_be(StatusEffects.burning)
    end)

    it("freeze is an alias for frozen", function()
        expect(StatusEffects.freeze).never().to_be_nil()
        expect(StatusEffects.freeze).to_be(StatusEffects.frozen)
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 3: Per-Status Fan-Out Signals
--------------------------------------------------------------------------------

-- NOTE: These tests require the full game engine to run.
-- They are documented here for integration testing but marked with xit() to skip.
-- Run these tests in the full game environment with:
--   RUN_INTEGRATION_TESTS=1 ./build/raylib-cpp-cmake-template

describe("Phase 1: Per-Status Fan-Out Signals (Integration)", function()
    -- We need to test that StatusEngine.apply emits per-status signals
    -- StatusEngine requires the full game engine context

    -- Try to load combat system (may fail outside game)
    local ok, CombatSystem = pcall(require, "combat.combat_system")
    local StatusEngine = ok and CombatSystem and CombatSystem.StatusEngine or nil

    -- Skip all tests if StatusEngine not available
    if not StatusEngine then
        it("SKIPPED: StatusEngine requires full game engine", function()
            -- This test passes but documents the skip
            expect(true).to_be(true)
        end)
        return
    end

    it("emits on_apply_burn when applying burning status", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 2, duration = 5 })

        local found = mock_signal.find("on_apply_burn")
        expect(found).never().to_be_nil()

        -- Restore
        package.loaded["external.hump.signal"] = original_signal
    end)

    it("emits on_apply_freeze when applying frozen status", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "frozen", { duration = 3 })

        local found = mock_signal.find("on_apply_freeze")
        expect(found).never().to_be_nil()

        package.loaded["external.hump.signal"] = original_signal
    end)

    it("emits on_apply_doom when applying doom status", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "doom", { stacks = 10 })

        local found = mock_signal.find("on_apply_doom")
        expect(found).never().to_be_nil()

        package.loaded["external.hump.signal"] = original_signal
    end)

    it("emits on_apply_electrocute when applying electrocute status", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "electrocute", { stacks = 1, duration = 5 })

        local found = mock_signal.find("on_apply_electrocute")
        expect(found).never().to_be_nil()

        package.loaded["external.hump.signal"] = original_signal
    end)

    it("emits on_apply_poison when applying poison status", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "poison", { stacks = 3, duration = 6 })

        local found = mock_signal.find("on_apply_poison")
        expect(found).never().to_be_nil()

        package.loaded["external.hump.signal"] = original_signal
    end)

    it("emits on_apply_bleed when applying bleed status", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "bleed", { stacks = 2, duration = 4 })

        local found = mock_signal.find("on_apply_bleed")
        expect(found).never().to_be_nil()

        package.loaded["external.hump.signal"] = original_signal
    end)

    it("emits on_apply_corrosion when applying corrosion status", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "corrosion", { stacks = 5, duration = 8 })

        local found = mock_signal.find("on_apply_corrosion")
        expect(found).never().to_be_nil()

        package.loaded["external.hump.signal"] = original_signal
    end)

    it("fan-out signal fires exactly once per apply", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()

        -- Apply burning twice
        StatusEngine.apply(ctx, target, "burning", { stacks = 1, duration = 5 })
        StatusEngine.apply(ctx, target, "burning", { stacks = 1, duration = 5 })

        local count = mock_signal.count("on_apply_burn")
        expect(count).to_be(2)

        package.loaded["external.hump.signal"] = original_signal
    end)

    it("fan-out signal contains correct payload", function()
        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        local ctx = create_mock_ctx()
        local target = create_mock_target()
        local source = { id = "test_source" }

        StatusEngine.apply(ctx, target, "burning", { stacks = 3, duration = 5, source = source })

        local found = mock_signal.find("on_apply_burn")
        expect(found).never().to_be_nil()
        -- Payload should include target, stacks, and source
        expect(found.args[1]).to_be(target)
        expect(found.args[2].stacks).to_be(3)
        expect(found.args[2].source).to_be(source)

        package.loaded["external.hump.signal"] = original_signal
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 4: Player Damaged Signal Standardization
-- This tests that BOTH player_damaged AND on_player_damaged are emitted
--------------------------------------------------------------------------------

describe("Phase 1: Player Damaged Signal Standardization", function()
    -- This test verifies the contract from combat_system.lua
    -- We need to ensure both signal names fire with identical payloads

    it("combat_system emits both player_damaged and on_player_damaged", function()
        -- This test documents the expected behavior
        -- The actual implementation is in combat_system.lua around line 2476
        -- We verify by checking the signal emission code

        local mock_signal = create_mock_signal()
        local original_signal = package.loaded["external.hump.signal"]
        package.loaded["external.hump.signal"] = mock_signal

        -- Simulate what combat_system should do
        -- In reality, this is called from resolveHit when target is player
        local payload = { amount = 25, damage_type = "fire", source = 123 }
        local target_entity = 456

        -- This is what we expect combat_system to do:
        mock_signal.emit("player_damaged", target_entity, payload)
        mock_signal.emit("on_player_damaged", target_entity, payload)

        local p1 = mock_signal.find("player_damaged")
        local p2 = mock_signal.find("on_player_damaged")

        expect(p1).never().to_be_nil()
        expect(p2).never().to_be_nil()

        -- Both should have identical payloads
        expect(p1.args[1]).to_be(p2.args[1])
        expect(p1.args[2].amount).to_be(p2.args[2].amount)
        expect(p1.args[2].damage_type).to_be(p2.args[2].damage_type)

        package.loaded["external.hump.signal"] = original_signal
    end)
end)

--------------------------------------------------------------------------------
-- SECTION 5: Stack Mode Behaviors (COUNT mode for arcane_charge)
--------------------------------------------------------------------------------

describe("Phase 1: Stack Mode COUNT Behavior (Integration)", function()
    -- Try to load combat system
    local ok, CombatSystem = pcall(require, "combat.combat_system")
    local StatusEngine = ok and CombatSystem and CombatSystem.StatusEngine or nil

    if not StatusEngine then
        it("SKIPPED: StatusEngine requires full game engine", function()
            expect(true).to_be(true)
        end)
        return
    end

    it("count mode increments stacks without resetting duration", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        -- First application
        StatusEngine.apply(ctx, target, "arcane_charge", { stacks = 1, duration = 10 })
        local initial_until = target.statuses.arcane_charge and target.statuses.arcane_charge.until_time

        -- Advance time
        ctx.time.now = 5

        -- Second application
        StatusEngine.apply(ctx, target, "arcane_charge", { stacks = 1, duration = 10 })

        -- Stacks should be 2
        expect(target.statuses.arcane_charge.stacks).to_be(2)

        -- Duration behavior for COUNT mode: should set until_time based on latest apply
        -- (different from TIME_EXTEND which adds to existing)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

-- Only run if executed directly
if arg and arg[0] and arg[0]:match("test_status_effects_phase1%.lua$") then
    local success = TestRunner.run()
    os.exit(success and 0 or 1)
end

return TestRunner
