set(TESTING_STUB_SOURCES
    ${CMAKE_SOURCE_DIR}/src/testing/artifact_index.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/artifact_store.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/baseline_manager.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/determinism_audit.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/determinism_guard.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/log_capture.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/lua_sandbox.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/lua_state_query.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/path_sandbox.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/perf_tracker.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/schema_validator.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/screenshot_capture.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/screenshot_compare.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/schema_validator.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_api_dump.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_api_registry.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_forensics.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_harness_lua.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_input_provider.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_mode.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_runtime.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/timeline_writer.cpp
)

add_executable(unit_tests
    unit/test_animation_playback.cpp
    unit/test_engine_context.cpp
    unit/test_registry_consolidation.cpp
    unit/test_blackboard.cpp
    unit/test_ai_bb_bindings.cpp
    unit/test_ai_sense_bindings.cpp
    unit/test_goap_utils.cpp
    unit/test_color_utils.cpp
    unit/test_component_cache.cpp
    unit/test_bulk_component_access.cpp
    unit/test_uuid.cpp
    unit/test_utilities.cpp
    unit/test_input_state.cpp
    unit/test_transform_hooks.cpp
    unit/test_physics_manager.cpp
    unit/test_shader_system.cpp
    unit/test_shader_presets.cpp
    unit/test_ui_shader_isolation.cpp
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
    unit/test_layer_state_batching.cpp
    unit/test_layer_batching.cpp
    unit/test_batched_local_commands.cpp
    unit/test_startup_timer.cpp
    unit/test_render_stack_safety.cpp
    unit/test_save_file_io.cpp
    unit/test_replace_children.cpp
    unit/test_mode_config.cpp
    unit/test_forensics.cpp
    unit/test_stubs_compile.cpp
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
    ${CMAKE_SOURCE_DIR}/src/util/startup_timer.cpp
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
    ${CMAKE_SOURCE_DIR}/src/testing/test_mode_config.cpp
    ${TESTING_STUB_SOURCES}
    ${CMAKE_SOURCE_DIR}/src/systems/entity_gamestate_management/entity_gamestate_management.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/ai/ai_system.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/scripting/scripting_functions.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/event/event_system.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/physics/physics_world.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/controller_nav.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/ui/ui_data.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/ui/core/ui_components.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/ui/box.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/ui/sizing_pass.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/layer/layer_command_buffer.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/save/save_file_io.cpp
    helpers/object_pool_stubs.cpp
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
    UNIT_TESTS
)

target_link_libraries(unit_tests PRIVATE
    gtest_main
    CommonSettings
)

# ======================================================================
# E2E Supervisor Stub (helper binary for tests)
# ======================================================================
add_executable(e2e_supervisor_stub
    helpers/e2e_supervisor_stub.cpp
)

# ======================================================================
# E2E Supervisor Unit Tests (lightweight target)
# ======================================================================
add_executable(e2e_supervisor_tests
    unit/test_e2e_supervisor.cpp
    ${CMAKE_SOURCE_DIR}/tools/e2e_supervisor_lib.cpp
)

target_include_directories(e2e_supervisor_tests PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(e2e_supervisor_tests PRIVATE
    gtest_main
)

add_dependencies(e2e_supervisor_tests e2e_supervisor_stub)

gtest_discover_tests(e2e_supervisor_tests)

# Link Tracy if enabled (needed by shader_system, physics_world, layer_command_buffer)
if(TRACY_ENABLE AND NOT EMSCRIPTEN)
    target_link_libraries(unit_tests PRIVATE Tracy::TracyClient)
endif()

gtest_discover_tests(unit_tests)

# ======================================================================
# Test Mode Config CLI Driver (for E2E scripts)
# ======================================================================
add_executable(test_mode_config_cli
    helpers/test_mode_config_cli.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_mode_config.cpp
)

target_include_directories(test_mode_config_cli PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(test_mode_config_cli PRIVATE
    CommonSettings
)

# ======================================================================
# Test Mode Config Unit Tests (lightweight target)
# ======================================================================
add_executable(test_mode_config_tests
    unit/test_mode_config.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_mode_config.cpp
)

target_include_directories(test_mode_config_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(test_mode_config_tests PRIVATE
    gtest_main
    CommonSettings
)

gtest_discover_tests(test_mode_config_tests)

# ======================================================================
# Test API Registry Unit Tests
# ======================================================================
add_executable(test_api_registry_tests
    unit/test_api_registry.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_api_registry.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/test_api_dump.cpp
    ${CMAKE_SOURCE_DIR}/src/testing/schema_validator.cpp
)

target_include_directories(test_api_registry_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(test_api_registry_tests PRIVATE
    gtest_main
    CommonSettings
)

gtest_discover_tests(test_api_registry_tests)

# ======================================================================
# Test Runtime Unit Tests
# ======================================================================
add_executable(test_runtime_tests
    unit/test_runtime.cpp
    unit/test_artifact_store.cpp
    unit/test_determinism_audit.cpp
    unit/test_determinism_guard.cpp
    unit/test_harness_lua.cpp
    unit/test_log_harness_lua.cpp
    unit/test_log_capture.cpp
    unit/test_lua_sandbox.cpp
    unit/test_path_sandbox.cpp
    unit/test_baseline_manager.cpp
    unit/test_perf_tracker.cpp
    unit/test_schema_validation.cpp
    unit/test_forensics.cpp
    unit/test_tap_reporter.cpp
    ${TESTING_STUB_SOURCES}
)

target_include_directories(test_runtime_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(test_runtime_tests PRIVATE
    gtest_main
    CommonSettings
)

target_compile_definitions(test_runtime_tests PRIVATE
    UNIT_TESTS
    ASSETS_PATH="${CMAKE_SOURCE_DIR}/assets/"
)

gtest_discover_tests(test_runtime_tests)

# ======================================================================
# Test Mode Stub Compile Tests (headers + stub .cpp files)
# ======================================================================
add_executable(test_stubs_compile
    unit/test_stubs_compile.cpp
    ${TESTING_STUB_SOURCES}
)

target_include_directories(test_stubs_compile PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(test_stubs_compile PRIVATE
    gtest_main
    CommonSettings
)

gtest_discover_tests(test_stubs_compile)

# ======================================================================
# Lua Backend Smoke Tests (minimal dependencies - just Sol2/Lua)
# ======================================================================
add_executable(lua_backend_tests
    unit/test_lua_backend.cpp
)

target_include_directories(lua_backend_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
)

target_compile_definitions(lua_backend_tests PRIVATE
    ASSETS_PATH="${CMAKE_SOURCE_DIR}/assets/"
)

target_link_libraries(lua_backend_tests PRIVATE
    gtest_main
    CommonSettings
)

gtest_discover_tests(lua_backend_tests)
# ======================================================================

# Add benchmark subdirectory
add_subdirectory(benchmark)
