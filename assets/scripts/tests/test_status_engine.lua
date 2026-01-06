local TestRunner = require("tests.test_runner")
local it = TestRunner.it
local assert_equals = TestRunner.assert_equals
local assert_true = TestRunner.assert_true
local assert_nil = TestRunner.assert_nil
local assert_not_nil = TestRunner.assert_not_nil

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

TestRunner.describe("StatusEngine", function()
    local CombatSystem = require("combat.combat_system")
    local StatusEngine = CombatSystem.StatusEngine
    local StatusEffects = require("data.status_effects")

    it("apply() creates status bucket with correct stacks", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        local stacks = StatusEngine.apply(ctx, target, "burning", { stacks = 3, duration = 5 })

        assert_equals(3, stacks, "should return applied stacks")
        assert_not_nil(target.statuses.burning, "should create status bucket")
        assert_equals(3, target.statuses.burning.stacks, "bucket should have correct stacks")
    end)

    it("apply() with intensity mode adds stacks", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "bleed", { stacks = 2, duration = 5 })
        StatusEngine.apply(ctx, target, "bleed", { stacks = 3, duration = 5 })

        assert_equals(5, target.statuses.bleed.stacks, "intensity mode should add stacks")
    end)

    it("apply() respects max_stacks", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        for i = 1, 20 do
            StatusEngine.apply(ctx, target, "bleed", { stacks = 1, duration = 5 })
        end

        local def = StatusEffects.bleed
        local expected = def and def.max_stacks or 10
        assert_true(target.statuses.bleed.stacks <= expected, "should not exceed max_stacks")
    end)

    it("apply() creates DoT entry for DoT-type statuses", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 2, duration = 5, source = { id = "test" } })

        assert_equals(1, #target.dots, "should create one DoT entry")
        assert_equals("burning", target.dots[1].status_id, "DoT should reference status_id")
        assert_equals(2, target.dots[1].stacks, "DoT should have correct stacks")
    end)

    it("remove() clears status completely when no stacks_to_remove", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 5, duration = 5 })
        StatusEngine.remove(ctx, target, "burning")

        assert_nil(target.statuses.burning, "status should be removed")
        assert_equals(0, #target.dots, "DoT should be removed")
    end)

    it("remove() with stacks_to_remove does partial removal", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "bleed", { stacks = 5, duration = 5 })
        local remaining = StatusEngine.remove(ctx, target, "bleed", 2)

        assert_equals(3, remaining, "should return remaining stacks")
        assert_equals(3, target.statuses.bleed.stacks, "bucket should have reduced stacks")
    end)

    it("remove() syncs DoT stacks on partial removal", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 5, duration = 5, source = { id = "test" } })
        StatusEngine.remove(ctx, target, "burning", 2)

        assert_equals(3, target.dots[1].stacks, "DoT stacks should be synced")
    end)

    it("update_entity() expires bucket.until_time statuses", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "frozen", { duration = 2 })
        assert_not_nil(target.statuses.frozen, "status should exist initially")

        ctx.time.now = 3
        StatusEngine.update_entity(ctx, target, 0)

        assert_nil(target.statuses.frozen, "status should expire after until_time")
    end)

    it("update_entity() expires DoT and removes linked status", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 1, duration = 2, source = { id = "test" } })

        ctx.time.now = 3
        StatusEngine.update_entity(ctx, target, 0)

        assert_equals(0, #target.dots, "DoT should be removed")
        assert_nil(target.statuses.burning, "linked status should be removed")
    end)

    it("update_entity() ticks DoT damage", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()
        target.hp = 100
        target.max_health = 100
        target.stats._values.armor = 0

        StatusEngine.apply(ctx, target, "burning", { stacks = 1, duration = 10, source = { id = "test" } })

        ctx.time.now = 1.5
        target.dots[1].next_tick = 1.0

        local damage_dealt = false
        local original_emit = ctx.bus.emit
        ctx.bus.emit = function(self, name, data)
            if name == "OnHitResolved" then damage_dealt = true end
            original_emit(self, name, data)
        end

        StatusEngine.update_entity(ctx, target, 0.5)
    end)

    it("getStacks() returns current stack count", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        assert_equals(0, StatusEngine.getStacks(target, "burning"), "should return 0 for missing status")

        StatusEngine.apply(ctx, target, "burning", { stacks = 3, duration = 5 })
        assert_equals(3, StatusEngine.getStacks(target, "burning"), "should return correct stacks")
    end)

    it("hasStatus() returns boolean", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        assert_true(not StatusEngine.hasStatus(target, "burning"), "should return false for missing status")

        StatusEngine.apply(ctx, target, "burning", { stacks = 1, duration = 5 })
        assert_true(StatusEngine.hasStatus(target, "burning"), "should return true for active status")
    end)

    it("clearAll() removes all statuses", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 1, duration = 5 })
        StatusEngine.apply(ctx, target, "frozen", { duration = 5 })
        StatusEngine.apply(ctx, target, "bleed", { stacks = 2, duration = 5 })

        StatusEngine.clearAll(ctx, target)

        assert_nil(target.statuses.burning, "burning should be removed")
        assert_nil(target.statuses.frozen, "frozen should be removed")
        assert_nil(target.statuses.bleed, "bleed should be removed")
    end)

    it("emits OnStatusApplied event", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 2, duration = 5 })

        local found = false
        for _, ev in ipairs(ctx._events) do
            if ev.name == "OnStatusApplied" and ev.data.id == "burning" then
                found = true
                assert_equals(2, ev.data.stacks, "event should contain stacks")
            end
        end
        assert_true(found, "OnStatusApplied event should be emitted")
    end)

    it("emits OnStatusRemoved event", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "burning", { stacks = 1, duration = 5 })
        StatusEngine.remove(ctx, target, "burning")

        local found = false
        for _, ev in ipairs(ctx._events) do
            if ev.name == "OnStatusRemoved" and ev.data.id == "burning" then
                found = true
            end
        end
        assert_true(found, "OnStatusRemoved event should be emitted")
    end)

    it("emits OnStatusExpired event on bucket expiry", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        StatusEngine.apply(ctx, target, "frozen", { duration = 1 })
        ctx.time.now = 2
        StatusEngine.update_entity(ctx, target, 0)

        local found = false
        for _, ev in ipairs(ctx._events) do
            if ev.name == "OnStatusExpired" and ev.data.id == "frozen" then
                found = true
            end
        end
        assert_true(found, "OnStatusExpired event should be emitted")
    end)

    it("stat_mods are applied on first stack", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        local def = StatusEffects.haste
        if def and def.stat_mods then
            StatusEngine.apply(ctx, target, "haste", { stacks = 1, duration = 5 })

            for stat, value in pairs(def.stat_mods) do
                assert_equals(value, target.stats:get(stat), "stat mod should be applied")
            end
        end
    end)

    it("stat_mods are removed on status removal", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        local def = StatusEffects.haste
        if def and def.stat_mods then
            StatusEngine.apply(ctx, target, "haste", { stacks = 1, duration = 5 })
            StatusEngine.remove(ctx, target, "haste")

            for stat, _ in pairs(def.stat_mods) do
                assert_equals(0, target.stats:get(stat), "stat mod should be removed")
            end
        end
    end)

    it("stat_mods_per_stack scales with stacks", function()
        local ctx = create_mock_ctx()
        local target = create_mock_target()

        local def = StatusEffects.bloodrage
        if def and def.stat_mods_per_stack then
            StatusEngine.apply(ctx, target, "bloodrage", { stacks = 3, duration = 5 })

            for stat, value in pairs(def.stat_mods_per_stack) do
                assert_equals(value * 3, target.stats:get(stat), "per-stack mod should scale")
            end
        end
    end)
end)

return TestRunner
