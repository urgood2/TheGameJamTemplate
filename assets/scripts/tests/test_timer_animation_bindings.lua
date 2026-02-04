--[[
================================================================================
TIMER / ANIMATION BINDING TESTS
================================================================================
Smoke tests for timer and animation bindings exposed to Lua.

Run with:
    lua assets/scripts/tests/test_timer_animation_bindings.lua
================================================================================
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/tests/?.lua"

local standalone = not _G.registry
if standalone then
    pcall(require, "tests.mocks.engine_mock")
end

local t = require("tests.test_runner")

local caps = t.get_capabilities()
caps.timer = type(_G.timer) == "table" and type(_G.timer.after) == "function"
caps.animation = type(_G.animation_system) == "table"
    and type(_G.animation_system.createAnimatedObjectWithTransform) == "function"
    and type(_G.animation_system.play) == "function"

local function register(test_id, doc_id, requires, fn)
    t:register(test_id, "bindings", fn, {
        doc_ids = { doc_id },
        tags = { "bindings", "timer_anim" },
        requires = requires or {},
    })
end

local function step_timer(total_seconds, steps)
    local dt = total_seconds / steps
    for _ = 1, steps do
        _G.timer.update(dt)
    end
end

--------------------------------------------------------------------------------
-- Timer bindings
--------------------------------------------------------------------------------

register("timer.after.basic", "sol2_function_timer_after", { "timer" }, function()
    local fired = false
    _G.timer.after(0.05, function() fired = true end, "test_after")

    step_timer(0.1, 5)

    t.expect(fired).to_be(true)
end)

register("timer.every.basic", "sol2_function_timer_every", { "timer" }, function()
    local count = 0
    _G.timer.every(0.02, function() count = count + 1 end, 3, false, function() end, "test_every")

    step_timer(0.2, 10)

    t.expect(count).to_be(3)
end)

register("timer.cancel.basic", "sol2_function_timer_cancel", { "timer" }, function()
    local count = 0
    _G.timer.every(0.01, function() count = count + 1 end, 0, false, function() end, "test_cancel")
    _G.timer.cancel("test_cancel")

    step_timer(0.1, 5)

    t.expect(count).to_be(0)
end)

register("timer.tween.basic", "sol2_function_timer_tween", { "timer" }, function()
    local value = 0
    local finished = false

    _G.timer.tween(
        0.05,
        function() return value end,
        function(v) value = v end,
        1.0,
        "test_tween",
        "",
        function(t) return t end,
        function() finished = true end
    )

    step_timer(0.2, 10)

    t.expect(value >= 1.0).to_be(true)
    t.expect(finished).to_be(true)
end)

--------------------------------------------------------------------------------
-- Animation bindings
--------------------------------------------------------------------------------

register("animation.create.basic", "sol2_function_animation_system_createanimatedobjectwithtransform", { "animation" }, function()
    local entity = _G.animation_system.createAnimatedObjectWithTransform("test_sprite", true, 0, 0, nil, true)
    t.expect(type(entity)).to_be("number")

    if _G.registry and type(_G.registry.valid) == "function" then
        t.expect(_G.registry:valid(entity)).to_be(true)
    end
end)

register("animation.play.basic", "sol2_function_animation_system_play", { "animation" }, function()
    local entity = _G.animation_system.createAnimatedObjectWithTransform("test_sprite", true, 0, 0, nil, true)
    t.expect(type(entity)).to_be("number")

    local ok_play = pcall(_G.animation_system.play, entity)
    t.expect(ok_play).to_be(true)

    local ok_pause = pcall(_G.animation_system.pause, entity)
    t.expect(ok_pause).to_be(true)

    local ok_stop = pcall(_G.animation_system.stop, entity)
    t.expect(ok_stop).to_be(true)
end)

register("animation.chain.basic", "sol2_function_animation_system_onanimationend", { "animation" }, function()
    local entity = _G.animation_system.createAnimatedObjectWithTransform("test_sprite", true, 0, 0, nil, true)
    t.expect(type(entity)).to_be("number")

    local called = false
    local ok = pcall(_G.animation_system.onAnimationEnd, entity, function() called = true end)
    t.expect(ok).to_be(true)
    t.expect(called).to_be(false)
end)

--------------------------------------------------------------------------------
-- Run
--------------------------------------------------------------------------------

t.run()
