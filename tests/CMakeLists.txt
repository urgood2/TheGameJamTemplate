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
    unit/test_binding_recorder.cpp
    helpers/test_stubs.cpp
    ${CMAKE_SOURCE_DIR}/src/core/engine_context.cpp
    ${CMAKE_SOURCE_DIR}/src/core/globals.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/uuid/uuid.cpp
    ${CMAKE_SOURCE_DIR}/src/util/utilities.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_functions.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/input/input_function_data.cpp
    ${CMAKE_SOURCE_DIR}/src/systems/physics/physics_world.cpp
)

target_include_directories(unit_tests PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_definitions(unit_tests PRIVATE
    ASSETS_PATH="${CMAKE_SOURCE_DIR}/assets/"
)

target_link_libraries(unit_tests PRIVATE
    gtest_main
    CommonSettings
)

gtest_discover_tests(unit_tests)
