# Benchmark executables for performance testing
# These are separate from unit tests and use custom timing infrastructure

# Placeholder for benchmark sources - actual benchmark files will be added in later tasks
set(BENCHMARK_SOURCES
    benchmark_lua_boundary.cpp
    # benchmark_physics.cpp - Task 1.4
    # benchmark_layer.cpp - Task 1.5
)

# Only create executable if we have benchmark sources
if(BENCHMARK_SOURCES)
    add_executable(perf_benchmarks
        ${BENCHMARK_SOURCES}
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
        ${CMAKE_CURRENT_SOURCE_DIR}/../helpers/test_stubs.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/../helpers/object_pool_stubs.cpp
        # ImGui sources needed for shader_system.cpp
        ${CMAKE_SOURCE_DIR}/src/third_party/rlImGui/imgui.cpp
        ${CMAKE_SOURCE_DIR}/src/third_party/rlImGui/imgui_draw.cpp
        ${CMAKE_SOURCE_DIR}/src/third_party/rlImGui/imgui_widgets.cpp
        ${CMAKE_SOURCE_DIR}/src/third_party/rlImGui/imgui_tables.cpp
    )

    target_include_directories(perf_benchmarks PRIVATE
        ${CMAKE_SOURCE_DIR}/src
        ${CMAKE_SOURCE_DIR}/include
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/..
    )

    if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.16")
        target_precompile_headers(perf_benchmarks PRIVATE "${CMAKE_SOURCE_DIR}/src/util/common_headers.hpp")
    endif()

    target_compile_definitions(perf_benchmarks PRIVATE
        ASSETS_PATH="${CMAKE_SOURCE_DIR}/assets/"
        UNIT_TESTS
    )

    target_link_libraries(perf_benchmarks PRIVATE
        gtest_main
        CommonSettings
    )

    # Note: We don't use gtest_discover_tests for benchmarks
    # Benchmarks are run manually for performance profiling
endif()
