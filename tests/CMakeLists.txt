add_executable(unit_tests
    unit/test_engine_context.cpp
    unit/test_color_utils.cpp
    unit/test_component_cache.cpp
    unit/test_uuid.cpp
    unit/test_utilities.cpp
    unit/test_input_state.cpp
    unit/test_transform_hooks.cpp
    unit/test_physics_manager.cpp
    unit/test_shader_system.cpp
    unit/test_shader_presets.cpp
    unit/test_binding_recorder.cpp
    unit/test_crash_reporter.cpp
    unit/test_event_bus.cpp
    unit/test_collision_log.cpp
    unit/test_error_handling.cpp
    unit/test_config_validation.cpp
    unit/test_sound_system.cpp
    unit/test_scripting_bindings.cpp
    unit/test_scripting_lifecycle.cpp
    unit/test_globals_caches.cpp
    unit/test_telemetry.cpp
    unit/test_controller_nav.cpp
    unit/test_input_events.cpp
    unit/test_physics_events.cpp
    unit/test_localization.cpp
    unit/test_globals_bridge.cpp
    unit/test_text_waiters.cpp
    unit/test_asset_validation.cpp
    unit/test_memory_safety.cpp
    unit/test_ownership.cpp
    unit/test_ui_layout.cpp
    unit/test_ui_components.cpp
    unit/test_draw_call_counter.cpp
    unit/test_layer_sorted_flag.cpp
    helpers/test_stubs.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/shaders/shader_system.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/shaders/shader_presets.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/sound/sound_system.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/localization/localization.cpp
    ${CMAKE_SOURCE_DIR}/src/core/engine_context.cpp
    ${CMAKE_SOURCE_DIR}/src/core/globals.cpp
    ${CMAKE_SOURCE_DIR}/src/core/ownership.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/telemetry/telemetry.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/telemetry/posthog_client.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/scripting/scripting_system.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/scripting/registry_bond.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/uuid/uuid.cpp
    ${CMAKE_SOURCE_DIR}/src/util/crash_reporter.cpp
    ${CMAKE_SOURCE_DIR}/src/util/utilities.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_actions.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_functions.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_lua_bindings.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_function_data.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_keyboard.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_gamepad.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_hid.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_cursor.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_cursor_events.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_focus.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_polling.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/entity_gamestate_management/entity_gamestate_management.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/physics/physics_world.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/controller_nav.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/ui/ui_data.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/ui/core/ui_components.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/layer/layer_command_buffer.cpp
)

target_include_directories(unit_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.16")
    target_precompile_headers(unit_tests PRIVATE "${CMAKE_SOURCE_DIR}/src/util/common_headers.hpp")
endif()

target_compile_definitions(unit_tests PRIVATE
    ASSETS_PATH="${CMAKE_SOURCE_DIR}/assets/"
)

target_link_libraries(unit_tests PRIVATE
    gtest_main
    CommonSettings
)

gtest_discover_tests(unit_tests)
