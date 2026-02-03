-- test_timer_anim_bindings.lua
-- Timer and animation bindings coverage tests (Phase 2 A3)

local TestRunner = require("test.test_runner")
local TestUtils = require("test.test_utils")

local function get_timer()
    return _G.timer
end

local function get_animation_system()
    return _G.animation_system
end

local function step_timer(total_seconds, steps)
    local timer = get_timer()
    TestUtils.assert_not_nil(timer, "timer table available")
    TestUtils.assert_true(type(timer.update) == "function", "timer.update available")

    local total = tonumber(total_seconds) or 0
    local count = tonumber(steps) or 1
    if count <= 0 then
        count = 1
    end
    local dt = total / count
    for _ = 1, count do
        timer.update(dt)
    end
end

TestRunner.register("timer.after.basic", "timer", function()
    TestUtils.reset_world()
    local timer = get_timer()
    TestUtils.assert_not_nil(timer, "timer table available")

    local fired = false
    timer.after(0.05, function() fired = true end, "test_after_basic")

    step_timer(0.2, 8)
    TestUtils.assert_true(fired, "timer.after fired")
    TestUtils.reset_world()
end, {
    tags = {"timer"},
    doc_ids = {"sol2_function_timer_after"},
    requires = {"test_scene"},
})

TestRunner.register("timer.every.basic", "timer", function()
    TestUtils.reset_world()
    local timer = get_timer()
    TestUtils.assert_not_nil(timer, "timer table available")

    local count = 0
    timer.every(0.02, function() count = count + 1 end, 3, false, function() end, "test_every_basic")

    step_timer(0.2, 10)
    TestUtils.assert_eq(count, 3, "timer.every count")
    TestUtils.reset_world()
end, {
    tags = {"timer"},
    doc_ids = {"sol2_function_timer_every"},
    requires = {"test_scene"},
})

TestRunner.register("timer.cancel.basic", "timer", function()
    TestUtils.reset_world()
    local timer = get_timer()
    TestUtils.assert_not_nil(timer, "timer table available")

    local count = 0
    timer.every(0.01, function() count = count + 1 end, 0, false, function() end, "test_cancel_basic")
    timer.cancel("test_cancel_basic")

    step_timer(0.1, 5)
    TestUtils.assert_eq(count, 0, "timer.cancel stops callbacks")
    TestUtils.reset_world()
end, {
    tags = {"timer"},
    doc_ids = {"sol2_function_timer_cancel"},
    requires = {"test_scene"},
})

TestRunner.register("timer.tween.basic", "timer", function()
    TestUtils.reset_world()
    local timer = get_timer()
    TestUtils.assert_not_nil(timer, "timer table available")

    local value = 0
    local finished = false

    timer.tween(
        0.05,
        function() return value end,
        function(v) value = v end,
        1.0,
        "test_tween_basic",
        "",
        function(t) return t end,
        function() finished = true end
    )

    step_timer(0.2, 10)
    TestUtils.assert_true(value >= 1.0, "timer.tween reached target")
    TestUtils.assert_true(finished, "timer.tween after callback")
    TestUtils.reset_world()
end, {
    tags = {"timer"},
    doc_ids = {"sol2_function_timer_tween"},
    requires = {"test_scene"},
})

TestRunner.register("animation.create.basic", "animation", function()
    TestUtils.reset_world()
    local anim = get_animation_system()
    TestUtils.assert_not_nil(anim, "animation_system available")

    local entity = anim.createAnimatedObjectWithTransform("test_sprite", true, 0, 0, nil, true)
    TestUtils.assert_not_nil(entity, "animation entity created")

    if _G.registry and type(_G.registry.valid) == "function" then
        TestUtils.assert_true(_G.registry:valid(entity), "entity valid")
    end
    TestUtils.reset_world()
end, {
    tags = {"animation"},
    doc_ids = {"sol2_function_animation_system_createanimatedobjectwithtransform"},
    requires = {"test_scene"},
})

TestRunner.register("animation.play.basic", "animation", function()
    TestUtils.reset_world()
    local anim = get_animation_system()
    TestUtils.assert_not_nil(anim, "animation_system available")

    local entity = anim.createAnimatedObjectWithTransform("test_sprite", true, 0, 0, nil, true)
    TestUtils.assert_not_nil(entity, "animation entity created")

    local ok_play = pcall(anim.play, entity)
    TestUtils.assert_true(ok_play, "animation_system.play")

    local ok_pause = pcall(anim.pause, entity)
    TestUtils.assert_true(ok_pause, "animation_system.pause")

    local ok_stop = pcall(anim.stop, entity)
    TestUtils.assert_true(ok_stop, "animation_system.stop")

    TestUtils.reset_world()
end, {
    tags = {"animation"},
    doc_ids = {"sol2_function_animation_system_play"},
    requires = {"test_scene"},
})

TestRunner.register("animation.chain.basic", "animation", function()
    TestUtils.reset_world()
    local anim = get_animation_system()
    TestUtils.assert_not_nil(anim, "animation_system available")

    local entity = anim.createAnimatedObjectWithTransform("test_sprite", true, 0, 0, nil, true)
    TestUtils.assert_not_nil(entity, "animation entity created")

    local called = false
    local ok = pcall(anim.onAnimationEnd, entity, function() called = true end)
    TestUtils.assert_true(ok, "animation_system.onAnimationEnd")
    TestUtils.assert_false(called, "animation end callback not fired immediately")

    TestUtils.reset_world()
end, {
    tags = {"animation"},
    doc_ids = {"sol2_function_animation_system_onanimationend"},
    requires = {"test_scene"},
})
