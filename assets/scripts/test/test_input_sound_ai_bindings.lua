-- test_input_sound_ai_bindings.lua
-- Input/Sound/AI bindings coverage tests (Phase 2 A5)

local TestRunner = require("test.test_runner")
local TestUtils = require("test.test_utils")

local function get_registry()
    return _G.registry or registry
end

-- ============================================================================
-- INPUT SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "input.module_exists.basic",
    name = "Input module exists",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_function_in_iskeypressed"},
    run = function()
        TestUtils.assert_not_nil(_G["in"], "Input module 'in' should exist in global namespace")
    end
})

TestRunner.register_test({
    id = "input.is_key_pressed.basic",
    name = "Input.isKeyPressed accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_function_in_iskeypressed"},
    run = function()
        local input_module = _G["in"]
        if not input_module then
            TestUtils.skip("Input module not available")
            return
        end
        TestUtils.assert_not_nil(input_module.isKeyPressed, "isKeyPressed function should exist")
    end
})

TestRunner.register_test({
    id = "input.get_mouse_position.basic",
    name = "Input.getMousePos accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_function_in_getmousepos"},
    run = function()
        local input_module = _G["in"]
        if not input_module then
            TestUtils.skip("Input module not available")
            return
        end
        TestUtils.assert_not_nil(input_module.getMousePos, "getMousePos function should exist")
    end
})

TestRunner.register_test({
    id = "input.keyboard_key_enum.basic",
    name = "KeyboardKey enum accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_enum_keyboardkey"},
    run = function()
        TestUtils.assert_not_nil(_G.KeyboardKey, "KeyboardKey enum should exist")
        -- Check for common keys
        if _G.KeyboardKey then
            TestUtils.assert_not_nil(_G.KeyboardKey.KEY_SPACE, "KEY_SPACE should exist")
            TestUtils.assert_not_nil(_G.KeyboardKey.KEY_ENTER, "KEY_ENTER should exist")
        end
    end
})

TestRunner.register_test({
    id = "input.mouse_button_enum.basic",
    name = "MouseButton enum accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_enum_mousebutton"},
    run = function()
        TestUtils.assert_not_nil(_G.MouseButton, "MouseButton enum should exist")
        if _G.MouseButton then
            TestUtils.assert_not_nil(_G.MouseButton.MOUSE_BUTTON_LEFT, "MOUSE_BUTTON_LEFT should exist")
            TestUtils.assert_not_nil(_G.MouseButton.MOUSE_BUTTON_RIGHT, "MOUSE_BUTTON_RIGHT should exist")
        end
    end
})

TestRunner.register_test({
    id = "input.gamepad_button_enum.basic",
    name = "GamepadButton enum accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_enum_gamepadbutton"},
    run = function()
        TestUtils.assert_not_nil(_G.GamepadButton, "GamepadButton enum should exist")
    end
})

TestRunner.register_test({
    id = "input.gamepad_axis_enum.basic",
    name = "GamepadAxis enum accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_enum_gamepadaxis"},
    run = function()
        TestUtils.assert_not_nil(_G.GamepadAxis, "GamepadAxis enum should exist")
    end
})

TestRunner.register_test({
    id = "input.hid_flags.basic",
    name = "HIDFlags type accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_usertype_hidflags"},
    run = function()
        TestUtils.assert_not_nil(_G.HIDFlags, "HIDFlags type should exist")
    end
})

TestRunner.register_test({
    id = "input.input_state.basic",
    name = "InputState type accessible",
    tags = {"input", "smoke"},
    doc_ids = {"sol2_usertype_inputstate"},
    run = function()
        TestUtils.assert_not_nil(_G.InputState, "InputState type should exist")
    end
})

-- ============================================================================
-- SOUND SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "sound.play.basic",
    name = "playSoundEffect function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_playsoundeffect"},
    run = function()
        TestUtils.assert_not_nil(_G.playSoundEffect, "playSoundEffect function should exist")
    end
})

TestRunner.register_test({
    id = "sound.play_music.basic",
    name = "playMusic function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_playmusic"},
    run = function()
        TestUtils.assert_not_nil(_G.playMusic, "playMusic function should exist")
    end
})

TestRunner.register_test({
    id = "sound.stop_all.basic",
    name = "stopAllMusic function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_stopallmusic"},
    run = function()
        TestUtils.assert_not_nil(_G.stopAllMusic, "stopAllMusic function should exist")
    end
})

TestRunner.register_test({
    id = "sound.set_volume.basic",
    name = "setVolume function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_setvolume"},
    run = function()
        TestUtils.assert_not_nil(_G.setVolume, "setVolume function should exist")
    end
})

TestRunner.register_test({
    id = "sound.set_music_volume.basic",
    name = "setMusicVolume function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_setmusicvolume"},
    run = function()
        TestUtils.assert_not_nil(_G.setMusicVolume, "setMusicVolume function should exist")
    end
})

TestRunner.register_test({
    id = "sound.toggle_low_pass.basic",
    name = "toggleLowPassFilter function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_togglelowpassfilter"},
    run = function()
        TestUtils.assert_not_nil(_G.toggleLowPassFilter, "toggleLowPassFilter function should exist")
    end
})

TestRunner.register_test({
    id = "sound.fade_in.basic",
    name = "fadeInMusic function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_fadeinmusic"},
    run = function()
        TestUtils.assert_not_nil(_G.fadeInMusic, "fadeInMusic function should exist")
    end
})

TestRunner.register_test({
    id = "sound.fade_out.basic",
    name = "fadeOutMusic function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_fadeoutmusic"},
    run = function()
        TestUtils.assert_not_nil(_G.fadeOutMusic, "fadeOutMusic function should exist")
    end
})

TestRunner.register_test({
    id = "sound.queue.basic",
    name = "queueMusic function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_queuemusic"},
    run = function()
        TestUtils.assert_not_nil(_G.queueMusic, "queueMusic function should exist")
    end
})

TestRunner.register_test({
    id = "sound.set_pitch.basic",
    name = "setSoundPitch function accessible",
    tags = {"sound", "smoke"},
    doc_ids = {"sol2_function_setsoundpitch"},
    run = function()
        TestUtils.assert_not_nil(_G.setSoundPitch, "setSoundPitch function should exist")
    end
})

-- ============================================================================
-- AI SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "ai.module_exists.basic",
    name = "AI module exists",
    tags = {"ai", "smoke"},
    doc_ids = {"sol2_function_ai_list_lua_files"},
    run = function()
        TestUtils.assert_not_nil(_G.ai, "AI module 'ai' should exist in global namespace")
    end
})

TestRunner.register_test({
    id = "ai.list_lua_files.basic",
    name = "ai.list_lua_files accessible",
    tags = {"ai", "smoke"},
    doc_ids = {"sol2_function_ai_list_lua_files"},
    run = function()
        local ai_module = _G.ai
        if not ai_module then
            TestUtils.skip("AI module not available")
            return
        end
        TestUtils.assert_not_nil(ai_module.list_lua_files, "list_lua_files function should exist")
    end
})

TestRunner.register_test({
    id = "ai.create_entity.basic",
    name = "create_ai_entity accessible",
    tags = {"ai", "smoke"},
    doc_ids = {"sol2_function_create_ai_entity"},
    run = function()
        TestUtils.assert_not_nil(_G.create_ai_entity, "create_ai_entity function should exist")
    end
})

TestRunner.register_test({
    id = "ai.blackboard.basic",
    name = "Blackboard type accessible",
    tags = {"ai", "smoke"},
    doc_ids = {"sol2_usertype_blackboard"},
    run = function()
        TestUtils.assert_not_nil(_G.Blackboard, "Blackboard type should exist")
    end
})

TestRunner.register_test({
    id = "ai.dump_blackboard.basic",
    name = "ai.dump_blackboard accessible",
    tags = {"ai", "smoke"},
    doc_ids = {"sol2_function_ai_dump_blackboard"},
    run = function()
        local ai_module = _G.ai
        if not ai_module then
            TestUtils.skip("AI module not available")
            return
        end
        TestUtils.assert_not_nil(ai_module.dump_blackboard, "dump_blackboard function should exist")
    end
})

TestRunner.register_test({
    id = "ai.dump_plan.basic",
    name = "ai.dump_plan accessible",
    tags = {"ai", "smoke"},
    doc_ids = {"sol2_function_ai_dump_plan"},
    run = function()
        local ai_module = _G.ai
        if not ai_module then
            TestUtils.skip("AI module not available")
            return
        end
        TestUtils.assert_not_nil(ai_module.dump_plan, "dump_plan function should exist")
    end
})

TestRunner.register_test({
    id = "ai.clear_trace.basic",
    name = "ai.clear_trace accessible",
    tags = {"ai", "smoke"},
    doc_ids = {"sol2_function_ai_clear_trace"},
    run = function()
        local ai_module = _G.ai
        if not ai_module then
            TestUtils.skip("AI module not available")
            return
        end
        TestUtils.assert_not_nil(ai_module.clear_trace, "clear_trace function should exist")
    end
})

-- ============================================================================
-- FUNCTIONAL TESTS (may require mocking or specific context)
-- ============================================================================

TestRunner.register_test({
    id = "input.is_key_pressed.call",
    name = "Input.isKeyPressed callable without error",
    tags = {"input", "functional"},
    doc_ids = {"sol2_function_in_iskeypressed"},
    run = function()
        local input_module = _G["in"]
        if not input_module or not input_module.isKeyPressed then
            TestUtils.skip("Input module or isKeyPressed not available")
            return
        end
        -- Call with a key enum to verify it doesn't error
        local success, result = pcall(function()
            if _G.KeyboardKey and _G.KeyboardKey.KEY_SPACE then
                return input_module.isKeyPressed(_G.KeyboardKey.KEY_SPACE)
            end
            return nil
        end)
        TestUtils.assert_true(success, "isKeyPressed should be callable without error")
    end
})

TestRunner.register_test({
    id = "input.get_mouse_position.call",
    name = "Input.getMousePos returns position",
    tags = {"input", "functional"},
    doc_ids = {"sol2_function_in_getmousepos"},
    run = function()
        local input_module = _G["in"]
        if not input_module or not input_module.getMousePos then
            TestUtils.skip("Input module or getMousePos not available")
            return
        end
        local success, pos = pcall(function()
            return input_module.getMousePos()
        end)
        TestUtils.assert_true(success, "getMousePos should be callable without error")
        -- Position may be a table or vector
    end
})

-- ============================================================================
-- MODULE RETURN
-- ============================================================================

return {
    name = "Input/Sound/AI Bindings Tests",
    version = "1.0.0",
    description = "Phase 2 A5: Tests for Input, Sound, and AI system bindings",
    run_all = function()
        return TestRunner.run_tagged({"input", "sound", "ai"})
    end,
    run_smoke = function()
        return TestRunner.run_tagged({"smoke"})
    end
}
