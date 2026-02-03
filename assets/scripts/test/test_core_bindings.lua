-- test_core_bindings.lua
-- Core system bindings coverage tests (Phase 2 A4)

local TestRunner = require("test.test_runner")
local TestUtils = require("test.test_utils")

local function get_registry()
    return _G.registry or registry
end

-- ============================================================================
-- GLOBALS SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.globals_exists.basic",
    name = "globals table exists",
    tags = {"core", "globals", "smoke"},
    doc_ids = {"sol2_usertype_globals"},
    run = function()
        TestUtils.assert_not_nil(_G.globals, "globals table should exist in global namespace")
    end
})

TestRunner.register_test({
    id = "core.globals.screen_width.basic",
    name = "globals.screenWidth accessible",
    tags = {"core", "globals", "smoke"},
    doc_ids = {"sol2_property_globals_screenwidth"},
    run = function()
        if not _G.globals then
            TestUtils.skip("globals not available")
            return
        end
        TestUtils.assert_not_nil(_G.globals.screenWidth, "screenWidth property should exist")
        TestUtils.assert_true(type(_G.globals.screenWidth) == "number", "screenWidth should be a number")
    end
})

TestRunner.register_test({
    id = "core.globals.screen_height.basic",
    name = "globals.screenHeight accessible",
    tags = {"core", "globals", "smoke"},
    doc_ids = {"sol2_property_globals_screenheight"},
    run = function()
        if not _G.globals then
            TestUtils.skip("globals not available")
            return
        end
        TestUtils.assert_not_nil(_G.globals.screenHeight, "screenHeight property should exist")
        TestUtils.assert_true(type(_G.globals.screenHeight) == "number", "screenHeight should be a number")
    end
})

TestRunner.register_test({
    id = "core.globals.is_game_paused.basic",
    name = "globals.isGamePaused accessible",
    tags = {"core", "globals", "smoke"},
    doc_ids = {"sol2_property_globals_isgamepaused"},
    run = function()
        if not _G.globals then
            TestUtils.skip("globals not available")
            return
        end
        TestUtils.assert_not_nil(_G.globals.isGamePaused ~= nil, "isGamePaused property should be defined")
    end
})

TestRunner.register_test({
    id = "core.globals.camera.basic",
    name = "globals.camera accessible",
    tags = {"core", "globals", "smoke"},
    doc_ids = {"sol2_property_globals_camera"},
    run = function()
        if not _G.globals then
            TestUtils.skip("globals not available")
            return
        end
        TestUtils.assert_not_nil(_G.globals.camera, "camera property should exist")
    end
})

TestRunner.register_test({
    id = "core.globals.input_state.basic",
    name = "globals.inputState accessible",
    tags = {"core", "globals", "smoke"},
    doc_ids = {"sol2_property_globals_inputstate"},
    run = function()
        if not _G.globals then
            TestUtils.skip("globals not available")
            return
        end
        TestUtils.assert_not_nil(_G.globals.inputState, "inputState property should exist")
    end
})

-- ============================================================================
-- REGISTRY SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.registry_exists.basic",
    name = "registry exists",
    tags = {"core", "registry", "smoke"},
    doc_ids = {"sol2_usertype_entt_registry"},
    run = function()
        local reg = get_registry()
        TestUtils.assert_not_nil(reg, "registry should exist in global namespace")
    end
})

TestRunner.register_test({
    id = "core.registry.create.basic",
    name = "registry.create accessible",
    tags = {"core", "registry", "smoke"},
    doc_ids = {"sol2_property_entt_registry_create"},
    run = function()
        local reg = get_registry()
        if not reg then
            TestUtils.skip("registry not available")
            return
        end
        TestUtils.assert_not_nil(reg.create, "registry.create should exist")
    end
})

TestRunner.register_test({
    id = "core.registry.destroy.basic",
    name = "registry.destroy accessible",
    tags = {"core", "registry", "smoke"},
    doc_ids = {"sol2_property_entt_registry_destroy"},
    run = function()
        local reg = get_registry()
        if not reg then
            TestUtils.skip("registry not available")
            return
        end
        TestUtils.assert_not_nil(reg.destroy, "registry.destroy should exist")
    end
})

TestRunner.register_test({
    id = "core.registry.valid.basic",
    name = "registry.valid accessible",
    tags = {"core", "registry", "smoke"},
    doc_ids = {"sol2_property_entt_registry_valid"},
    run = function()
        local reg = get_registry()
        if not reg then
            TestUtils.skip("registry not available")
            return
        end
        TestUtils.assert_not_nil(reg.valid, "registry.valid should exist")
    end
})

TestRunner.register_test({
    id = "core.registry.emplace.basic",
    name = "registry.emplace accessible",
    tags = {"core", "registry", "smoke"},
    doc_ids = {"sol2_property_entt_registry_emplace"},
    run = function()
        local reg = get_registry()
        if not reg then
            TestUtils.skip("registry not available")
            return
        end
        TestUtils.assert_not_nil(reg.emplace, "registry.emplace should exist")
    end
})

TestRunner.register_test({
    id = "core.registry.has.basic",
    name = "registry.has accessible",
    tags = {"core", "registry", "smoke"},
    doc_ids = {"sol2_property_entt_registry_has"},
    run = function()
        local reg = get_registry()
        if not reg then
            TestUtils.skip("registry not available")
            return
        end
        TestUtils.assert_not_nil(reg.has, "registry.has should exist")
    end
})

TestRunner.register_test({
    id = "core.registry.remove.basic",
    name = "registry.remove accessible",
    tags = {"core", "registry", "smoke"},
    doc_ids = {"sol2_property_entt_registry_remove"},
    run = function()
        local reg = get_registry()
        if not reg then
            TestUtils.skip("registry not available")
            return
        end
        TestUtils.assert_not_nil(reg.remove, "registry.remove should exist")
    end
})

-- ============================================================================
-- UTILITY FUNCTION SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.get_frame_time.basic",
    name = "GetFrameTime function accessible",
    tags = {"core", "utility", "smoke"},
    doc_ids = {"sol2_function_getframetime"},
    run = function()
        TestUtils.assert_not_nil(_G.GetFrameTime, "GetFrameTime function should exist")
    end
})

TestRunner.register_test({
    id = "core.get_time.basic",
    name = "GetTime function accessible",
    tags = {"core", "utility", "smoke"},
    doc_ids = {"sol2_function_gettime"},
    run = function()
        TestUtils.assert_not_nil(_G.GetTime, "GetTime function should exist")
    end
})

TestRunner.register_test({
    id = "core.get_screen_width.basic",
    name = "GetScreenWidth function accessible",
    tags = {"core", "utility", "smoke"},
    doc_ids = {"sol2_function_getscreenwidth"},
    run = function()
        TestUtils.assert_not_nil(_G.GetScreenWidth, "GetScreenWidth function should exist")
    end
})

TestRunner.register_test({
    id = "core.get_screen_height.basic",
    name = "GetScreenHeight function accessible",
    tags = {"core", "utility", "smoke"},
    doc_ids = {"sol2_function_getscreenheight"},
    run = function()
        TestUtils.assert_not_nil(_G.GetScreenHeight, "GetScreenHeight function should exist")
    end
})

TestRunner.register_test({
    id = "core.vector2.basic",
    name = "Vector2 function accessible",
    tags = {"core", "utility", "smoke"},
    doc_ids = {"sol2_function_vector2"},
    run = function()
        TestUtils.assert_not_nil(_G.Vector2, "Vector2 function should exist")
    end
})

TestRunner.register_test({
    id = "core.vector3.basic",
    name = "Vector3 function accessible",
    tags = {"core", "utility", "smoke"},
    doc_ids = {"sol2_function_vector3"},
    run = function()
        TestUtils.assert_not_nil(_G.Vector3, "Vector3 function should exist")
    end
})

TestRunner.register_test({
    id = "core.vector4.basic",
    name = "Vector4 function accessible",
    tags = {"core", "utility", "smoke"},
    doc_ids = {"sol2_function_vector4"},
    run = function()
        TestUtils.assert_not_nil(_G.Vector4, "Vector4 function should exist")
    end
})

-- ============================================================================
-- LOGGING FUNCTION SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.log_debug.basic",
    name = "log_debug function accessible",
    tags = {"core", "logging", "smoke"},
    doc_ids = {"sol2_function_log_debug"},
    run = function()
        TestUtils.assert_not_nil(_G.log_debug, "log_debug function should exist")
    end
})

TestRunner.register_test({
    id = "core.log_info.basic",
    name = "log_info function accessible",
    tags = {"core", "logging", "smoke"},
    doc_ids = {"sol2_function_log_info"},
    run = function()
        TestUtils.assert_not_nil(_G.log_info, "log_info function should exist")
    end
})

TestRunner.register_test({
    id = "core.log_warn.basic",
    name = "log_warn function accessible",
    tags = {"core", "logging", "smoke"},
    doc_ids = {"sol2_function_log_warn"},
    run = function()
        TestUtils.assert_not_nil(_G.log_warn, "log_warn function should exist")
    end
})

TestRunner.register_test({
    id = "core.log_error.basic",
    name = "log_error function accessible",
    tags = {"core", "logging", "smoke"},
    doc_ids = {"sol2_function_log_error"},
    run = function()
        TestUtils.assert_not_nil(_G.log_error, "log_error function should exist")
    end
})

-- ============================================================================
-- GAME STATE SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.pause_game.basic",
    name = "pauseGame function accessible",
    tags = {"core", "gamestate", "smoke"},
    doc_ids = {"sol2_function_pausegame"},
    run = function()
        TestUtils.assert_not_nil(_G.pauseGame, "pauseGame function should exist")
    end
})

TestRunner.register_test({
    id = "core.unpause_game.basic",
    name = "unpauseGame function accessible",
    tags = {"core", "gamestate", "smoke"},
    doc_ids = {"sol2_function_unpausegame"},
    run = function()
        TestUtils.assert_not_nil(_G.unpauseGame, "unpauseGame function should exist")
    end
})

-- ============================================================================
-- ENTITY ALIAS SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.get_entity_by_alias.basic",
    name = "getEntityByAlias function accessible",
    tags = {"core", "entity", "smoke"},
    doc_ids = {"sol2_function_getentitybyalias"},
    run = function()
        TestUtils.assert_not_nil(_G.getEntityByAlias, "getEntityByAlias function should exist")
    end
})

TestRunner.register_test({
    id = "core.set_entity_alias.basic",
    name = "setEntityAlias function accessible",
    tags = {"core", "entity", "smoke"},
    doc_ids = {"sol2_function_setentityalias"},
    run = function()
        TestUtils.assert_not_nil(_G.setEntityAlias, "setEntityAlias function should exist")
    end
})

-- ============================================================================
-- CAMERA SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.camera2d.basic",
    name = "Camera2D type accessible",
    tags = {"core", "camera", "smoke"},
    doc_ids = {"sol2_usertype_camera2d"},
    run = function()
        TestUtils.assert_not_nil(_G.Camera2D, "Camera2D type should exist")
    end
})

TestRunner.register_test({
    id = "core.get_world_to_screen.basic",
    name = "GetWorldToScreen2D function accessible",
    tags = {"core", "camera", "smoke"},
    doc_ids = {"sol2_function_getworldtoscreen2d"},
    run = function()
        TestUtils.assert_not_nil(_G.GetWorldToScreen2D, "GetWorldToScreen2D function should exist")
    end
})

TestRunner.register_test({
    id = "core.get_screen_to_world.basic",
    name = "GetScreenToWorld2D function accessible",
    tags = {"core", "camera", "smoke"},
    doc_ids = {"sol2_function_getscreentoworld2d"},
    run = function()
        TestUtils.assert_not_nil(_G.GetScreenToWorld2D, "GetScreenToWorld2D function should exist")
    end
})

-- ============================================================================
-- COMPONENT CACHE SMOKE TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.component_cache.basic",
    name = "component_cache module accessible",
    tags = {"core", "component_cache", "smoke"},
    doc_ids = {"lua_module_component_cache"},
    run = function()
        TestUtils.assert_not_nil(_G.component_cache, "component_cache should exist in global namespace")
    end
})

TestRunner.register_test({
    id = "core.component_cache.get.basic",
    name = "component_cache.get accessible",
    tags = {"core", "component_cache", "smoke"},
    doc_ids = {"lua_module_component_cache_get"},
    run = function()
        if not _G.component_cache then
            TestUtils.skip("component_cache not available")
            return
        end
        TestUtils.assert_not_nil(_G.component_cache.get, "component_cache.get should exist")
    end
})

-- ============================================================================
-- GLOBAL SHADER UNIFORMS SMOKE TEST
-- ============================================================================

TestRunner.register_test({
    id = "core.global_shader_uniforms.basic",
    name = "globalShaderUniforms accessible",
    tags = {"core", "shaders", "smoke"},
    doc_ids = {"sol2_property_globalshaderuniforms"},
    run = function()
        TestUtils.assert_not_nil(_G.globalShaderUniforms, "globalShaderUniforms should exist")
    end
})

-- ============================================================================
-- FUNCTIONAL TESTS
-- ============================================================================

TestRunner.register_test({
    id = "core.registry.create_entity.functional",
    name = "Registry can create and destroy entity",
    tags = {"core", "registry", "functional"},
    doc_ids = {"sol2_property_entt_registry_create", "sol2_property_entt_registry_destroy", "sol2_property_entt_registry_valid"},
    run = function()
        local reg = get_registry()
        if not reg or not reg.create or not reg.destroy or not reg.valid then
            TestUtils.skip("registry methods not available")
            return
        end

        -- Create entity
        local success, entity = pcall(function()
            return reg:create()
        end)
        TestUtils.assert_true(success, "registry:create should not error")
        TestUtils.assert_not_nil(entity, "created entity should not be nil")

        -- Verify valid
        local valid_check, is_valid = pcall(function()
            return reg:valid(entity)
        end)
        TestUtils.assert_true(valid_check and is_valid, "created entity should be valid")

        -- Destroy entity
        local destroy_success = pcall(function()
            reg:destroy(entity)
        end)
        TestUtils.assert_true(destroy_success, "registry:destroy should not error")
    end
})

TestRunner.register_test({
    id = "core.vector2.creation.functional",
    name = "Vector2 creates vectors",
    tags = {"core", "utility", "functional"},
    doc_ids = {"sol2_function_vector2"},
    run = function()
        if not _G.Vector2 then
            TestUtils.skip("Vector2 not available")
            return
        end

        local success, vec = pcall(function()
            return Vector2(10, 20)
        end)
        TestUtils.assert_true(success, "Vector2 should be callable")
        TestUtils.assert_not_nil(vec, "Vector2 should return a value")
    end
})

TestRunner.register_test({
    id = "core.get_time.returns_number.functional",
    name = "GetTime returns a number",
    tags = {"core", "utility", "functional"},
    doc_ids = {"sol2_function_gettime"},
    run = function()
        if not _G.GetTime then
            TestUtils.skip("GetTime not available")
            return
        end

        local success, time = pcall(GetTime)
        TestUtils.assert_true(success, "GetTime should be callable")
        TestUtils.assert_true(type(time) == "number", "GetTime should return a number")
        TestUtils.assert_true(time >= 0, "GetTime should return non-negative value")
    end
})

-- ============================================================================
-- MODULE RETURN
-- ============================================================================

return {
    name = "Core Bindings Tests",
    version = "1.0.0",
    description = "Phase 2 A4: Tests for Core system bindings (globals, registry, utilities)",
    run_all = function()
        return TestRunner.run_tagged({"core"})
    end,
    run_smoke = function()
        return TestRunner.run_tagged({"smoke"})
    end
}
