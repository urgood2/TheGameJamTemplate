--[[
================================================================================
TEST: Timer Dual-Signature API
================================================================================
Tests that timer functions accept BOTH positional AND options-table signatures.

TDD Approach:
- RED: These tests should FAIL before dual-signature is implemented
- GREEN: Implement dual-signature, tests pass
- REFACTOR: Clean up if needed

Run with: lua assets/scripts/tests/test_timer_dual_signature.lua
]]

--------------------------------------------------------------------------------
-- Setup: Load real timer module
--------------------------------------------------------------------------------

-- Adjust package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock dependencies that timer.lua needs
_G.physicsTickCounter = 0
_G.log_debug = function() end
_G.log_error = function(...) print("[ERROR]", ...) end

-- Clear cached timer module to get fresh instance
package.loaded["core.timer"] = nil
_G.__GLOBAL_TIMER__ = nil

local timer = require("core.timer")
local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Utility: Track created timers
--------------------------------------------------------------------------------

local function get_timer_count()
    local count = 0
    for _ in pairs(timer.timers) do
        count = count + 1
    end
    return count
end

local function clear_timers()
    timer.clear_all()
end

--------------------------------------------------------------------------------
-- Tests: timer.after dual signature
--------------------------------------------------------------------------------

t.describe("timer.after dual signature", function()

    t.it("accepts positional arguments (backwards compatible)", function()
        clear_timers()
        local called = false
        local callback = function() called = true end

        local tag = timer.after(0.5, callback, "pos_tag", "pos_group")

        t.expect(tag).to_be("pos_tag")
        t.expect(get_timer_count()).to_be(1)
        t.expect(timer.timers["pos_tag"]).to_be_truthy()
        t.expect(timer.timers["pos_tag"].delay).to_be(0.5)
    end)

    t.it("accepts options table with all fields", function()
        clear_timers()
        local callback = function() end

        local tag = timer.after({
            delay = 1.5,
            action = callback,
            tag = "opts_tag",
            group = "opts_group"
        })

        t.expect(tag).to_be("opts_tag")
        t.expect(get_timer_count()).to_be(1)
        t.expect(timer.timers["opts_tag"]).to_be_truthy()
        t.expect(timer.timers["opts_tag"].delay).to_be(1.5)
        t.expect(timer.timers["opts_tag"].group).to_be("opts_group")
    end)

    t.it("accepts options table with only required fields", function()
        clear_timers()
        local callback = function() end

        local tag = timer.after({
            delay = 2.0,
            action = callback
        })

        t.expect(tag).to_be_truthy()  -- Auto-generated tag
        t.expect(get_timer_count()).to_be(1)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: timer.every dual signature
--------------------------------------------------------------------------------

t.describe("timer.every dual signature", function()

    t.it("accepts positional arguments (backwards compatible)", function()
        clear_timers()
        local callback = function() end

        local tag = timer.every(0.5, callback, 10, false, nil, "every_pos", "grp")

        t.expect(tag).to_be("every_pos")
        t.expect(timer.timers["every_pos"]).to_be_truthy()
        t.expect(timer.timers["every_pos"].delay).to_be(0.5)
        t.expect(timer.timers["every_pos"].times).to_be(10)
    end)

    t.it("accepts options table with all fields", function()
        clear_timers()
        local callback = function() end
        local after_cb = function() end

        local tag = timer.every({
            delay = 1.0,
            action = callback,
            times = 5,
            immediate = false,
            after = after_cb,
            tag = "every_opts",
            group = "opts_group"
        })

        t.expect(tag).to_be("every_opts")
        t.expect(timer.timers["every_opts"]).to_be_truthy()
        t.expect(timer.timers["every_opts"].delay).to_be(1.0)
        t.expect(timer.timers["every_opts"].times).to_be(5)
    end)

    t.it("defaults times to 0 (infinite) when not specified", function()
        clear_timers()

        local tag = timer.every({
            delay = 0.5,
            action = function() end,
            tag = "every_default"
        })

        t.expect(timer.timers["every_default"].times).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: timer.cooldown dual signature
--------------------------------------------------------------------------------

t.describe("timer.cooldown dual signature", function()

    t.it("accepts positional arguments (backwards compatible)", function()
        clear_timers()
        local condition = function() return true end
        local action = function() end

        local tag = timer.cooldown(1.0, condition, action, 3, nil, "cd_pos", "grp")

        t.expect(tag).to_be("cd_pos")
        t.expect(timer.timers["cd_pos"]).to_be_truthy()
        t.expect(timer.timers["cd_pos"].delay).to_be(1.0)
    end)

    t.it("accepts options table", function()
        clear_timers()
        local condition = function() return true end
        local action = function() end

        local tag = timer.cooldown({
            delay = 2.0,
            condition = condition,
            action = action,
            times = 5,
            tag = "cd_opts"
        })

        t.expect(tag).to_be("cd_opts")
        t.expect(timer.timers["cd_opts"]).to_be_truthy()
        t.expect(timer.timers["cd_opts"].delay).to_be(2.0)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: timer.for_time dual signature
--------------------------------------------------------------------------------

t.describe("timer.for_time dual signature", function()

    t.it("accepts positional arguments (backwards compatible)", function()
        clear_timers()
        local action = function(dt) end

        local tag = timer.for_time(3.0, action, nil, "ft_pos", "grp")

        t.expect(tag).to_be("ft_pos")
        t.expect(timer.timers["ft_pos"]).to_be_truthy()
        t.expect(timer.timers["ft_pos"].delay).to_be(3.0)
    end)

    t.it("accepts options table with delay field", function()
        clear_timers()
        local action = function(dt) end

        local tag = timer.for_time({
            delay = 5.0,
            action = action,
            tag = "ft_opts"
        })

        t.expect(tag).to_be("ft_opts")
        t.expect(timer.timers["ft_opts"]).to_be_truthy()
        t.expect(timer.timers["ft_opts"].delay).to_be(5.0)
    end)

    t.it("accepts options table with duration field (alias)", function()
        clear_timers()
        local action = function(dt) end

        local tag = timer.for_time({
            duration = 4.0,
            action = action,
            tag = "ft_duration"
        })

        t.expect(tag).to_be("ft_duration")
        t.expect(timer.timers["ft_duration"]).to_be_truthy()
        t.expect(timer.timers["ft_duration"].delay).to_be(4.0)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Existing _opts variants still work
--------------------------------------------------------------------------------

t.describe("timer.*_opts variants (backwards compatibility)", function()

    t.it("timer.after_opts still works", function()
        clear_timers()

        local tag = timer.after_opts({
            delay = 1.0,
            action = function() end,
            tag = "after_opts_test"
        })

        t.expect(tag).to_be("after_opts_test")
        t.expect(timer.timers["after_opts_test"]).to_be_truthy()
    end)

    t.it("timer.every_opts still works", function()
        clear_timers()

        local tag = timer.every_opts({
            delay = 1.0,
            action = function() end,
            tag = "every_opts_test"
        })

        t.expect(tag).to_be("every_opts_test")
        t.expect(timer.timers["every_opts_test"]).to_be_truthy()
    end)

    t.it("timer.delay dual signature still works", function()
        clear_timers()

        -- Table signature
        local tag1 = timer.delay({
            delay = 0.5,
            action = function() end,
            tag = "delay_opts"
        })
        t.expect(tag1).to_be("delay_opts")

        -- Positional signature
        local tag2 = timer.delay(0.5, function() end, { tag = "delay_pos" })
        t.expect(tag2).to_be("delay_pos")
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
