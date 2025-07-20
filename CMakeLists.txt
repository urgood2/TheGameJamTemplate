cmake_minimum_required(VERSION 3.14)
project(raylib-cpp-cmake-template CXX C)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_BUILD_TYPE Debug)

# enable tracy (disable for web)
option( TRACY_ENABLE "" OFF)
add_definitions(-DTRACY_NO_CRASH_HANDLER)

#set opengl version
#enum_option(OPENGL_VERSION "OFF;4.3;3.3;2.1;1.1;ES 2.0;ES 3.0" "Force a specific OpenGL Version?")
if (EMSCRIPTEN)
    set(OPENGL_VERSION "ES 3.0")
    #for chipmunk
    add_definitions(-DSOKOL_GLES3)
    set(BUILD_DEMOS OFF)
    set(INSTALL_DEMOS OFF)
elseif()
    set(OPENGL_VERSION "3.3") #apple uses 4.1, which is not supported 
endif()

#set gzip for window
if (WIN32)
    set(GZIP_EXE "E:/gzip-1.3.12-1-bin/bin/gzip.exe")  # Adjust to where gzip.exe lives
endif()

#stack size adjustment for web
if (EMSCRIPTEN)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -s TOTAL_STACK=128MB") # 5MB stack size
endif() 

if (WIN32) 
    add_compile_options("-Wa,-mbig-obj")
endif()


#spdlog
set(SPDLOG_FMT_EXTERNAL ON)
#debug
set(CMAKE_VERBOSE_MAKEFILE ON)

# Set project details
set(ITCH_USER "chugget")
set(ITCH_PAGE "weather-or-not")
set(PROJECT_VERSION "0.1")

include(FetchContent)

##########################################################################################
# Add dependencies with FetchContent
##########################################################################################

function(add_git_dependency libName gitURL gitTag)
    FetchContent_Declare(${libName}
        GIT_REPOSITORY ${gitURL}
        GIT_TAG        ${gitTag}
        GIT_SHALLOW    TRUE
        GIT_PROGRESS   TRUE
    )
    FetchContent_MakeAvailable(${libName})
    
    if(TARGET ${libName})
        get_target_property(type ${libName} TYPE)
        if(NOT "${type}" STREQUAL "INTERFACE_LIBRARY")
            target_compile_options(${libName} PRIVATE "-w")
        endif()
    else()
        # For header-only libraries, manually set the include directory
        set(${libName}_SOURCE_DIR ${${libName}_SOURCE_DIR} PARENT_SCOPE)
    endif()
endfunction()

# Add Raylib
set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE) # don't build the supplied examples
set(BUILD_GAMES    OFF CACHE BOOL "" FORCE) # don't build the supplied example games
add_git_dependency(
    raylib
    https://github.com/raysan5/raylib.git
    5.5
)

# Add LDtkLoader
# add_git_dependency(
#     LDtkLoader
#     https://github.com/Madour/LDtkLoader.git
#     1.5.3.1
# )

# Add Box2d
# set(BOX2D_BUILD_UNIT_TESTS OFF CACHE BOOL "" FORCE)
# set(BOX2D_BUILD_TESTBED OFF CACHE BOOL "" FORCE)
# add_git_dependency(
#     box2d
#     https://github.com/erincatto/box2d.git
#     v2.4.1
# )

# Add {fmt} library
add_git_dependency(
    fmt
    https://github.com/fmtlib/fmt.git
    10.2.1
)

# Add {nlohmann/json} library
add_git_dependency(
    json
    https://github.com/nlohmann/json.git
    v3.11.3
)

# Add {spdlog} library
add_git_dependency(
    spdlog
    https://github.com/gabime/spdlog.git
    v1.14.1
)

# # Add {taskflow} library
# # set(TF_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
# # set(TF_BUILD_TESTS OFF CACHE BOOL "" FORCE)
# # set(TF_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
# # add_git_dependency(
# #     taskflow
# #     https://github.com/taskflow/taskflow.git
# #     v3.7.0
# # )

# Add {tweeny} library
# add_git_dependency(
#     tweeny
#     https://github.com/mobius3/tweeny.git
#     v3.2.0
# )

# # {HFSM2} library was removed from the template because source directory was not being set correctly

# Add {random} library
set(Random_BuildTests OFF CACHE BOOL "" FORCE)
add_git_dependency(
    random
    https://github.com/ilqvya/random.git
    v1.5.0
)
message(STATUS "random_SOURCE_DIR: ${random_SOURCE_DIR}")

# Add {entt} library
add_git_dependency(
    entt
    https://github.com/skypjack/entt.git
    v3.13.2
)

# Add {Catch2} library
set(BUILD_TESTING ON CACHE BOOL "" FORCE)
add_git_dependency(
    Catch2
    https://github.com/catchorg/Catch2.git
    v3.6.0
)

#add ldtk loader
add_git_dependency(
    LDtkLoader
    https://github.com/Madour/LDtkLoader.git
    1.5.3.1
)

# Add {magic_enum} library
set(MAGIC_ENUM_OPT_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(MAGIC_ENUM_OPT_BUILD_TESTS  OFF CACHE BOOL "" FORCE)
# set(MAGIC_ENUM_OPT_INSTALL     OFF CACHE BOOL "" FORCE)
# set(MAGIC_ENUM_OPT_INSTALL_PACKAGE_XML OFF CACHE BOOL "" FORCE)
add_git_dependency(
    magic_enum
    https://github.com/Neargye/magic_enum.git
    v0.9.5
)

# Add {poisson-disk-generator} library
# add_git_dependency(
#     poisson-disk-generator
#     https://github.com/corporateshark/poisson-disk-generator.git
#     release-1.6.0
# )
# message(STATUS "poisson-disk-generator_SOURCE_DIR: ${poisson-disk-generator_SOURCE_DIR}")

add_git_dependency(
    glm
    https://github.com/g-truc/glm.git
    1.0.1
)
message(STATUS "glm_SOURCE_DIR: ${glm_SOURCE_DIR}")


# Add {sol3} library
add_git_dependency(
    sol2
    https://github.com/ThePhD/sol2.git
    v3.3.0
)
message(STATUS "sol2_SOURCE_DIR: ${sol2_SOURCE_DIR}")

#include lua
add_git_dependency(
    lua
    "https://github.com/marovira/lua"
    5.4.4
)

# add uuid
# add_git_dependency(
#     uuid_v4
#     https://github.com/crashoz/uuid_v4.git
#     v1.0.0
# )

# Add stduuid instead
add_git_dependency(
    stduuid
    https://github.com/mariusbancila/stduuid.git
    v1.2.3
)

#include snowhouse (assertion library)

add_git_dependency(
    snowhouse
    "https://github.com/banditcpp/snowhouse.git"
    v5.0.0
)

if (WIN32 OR EMSCRIPTEN)
set(Boost_INCLUDE_DIR "D:/boost_1_81_0")
set(Boost_LIBRARY_DIR "D:/boost_1_81_0/lib")
find_package(Boost)
# find_package(Boost REQUIRED regex) # header only libraries must not be added here
elseif (APPLE)
    # Adjust the paths if you have installed Boost in a different location
    set(Boost_INCLUDE_DIR "/opt/homebrew/Cellar/boost/1.83.0/include")
    set(Boost_LIBRARY_DIR "/opt/homebrew/Cellar/boost/1.83.0/lib")
    find_package(Boost)
else ()
    # Adjust the paths if you have installed Boost in a different location
    set(Boost_DEBUG 1)
    find_package(Boost REQUIRED)
    message(STATUS "BOOST DIR AND LIBS FOUND?:${Boost_FOUND}")
endif()


##########################################################################################
# add subdirectories for dependencies
##########################################################################################
# Add the src subdirectory
add_subdirectory("src/third_party/GPGOAP")
add_subdirectory("src/third_party/chipmunk")
if(NOT EMSCRIPTEN)
    add_subdirectory("src/third_party/tracy-master")
endif()
add_subdirectory("src/third_party/objectpool-master")

##########################################################################################
# Project executable setup
##########################################################################################

# Adding our source files
# Define PROJECT_SOURCES as a list of all source files
file(GLOB_RECURSE PROJECT_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_LIST_DIR}/src/*.cpp")

# Exclude files in src/third_party/tracy-master
foreach(file ${PROJECT_SOURCES})
    if(file MATCHES "/src/third_party/tracy-master")
        list(REMOVE_ITEM PROJECT_SOURCES ${file})
    endif()
endforeach()
list(APPEND PROJECT_SOURCES "${CMAKE_CURRENT_LIST_DIR}/src/third_party/tracy-master/public/TracyClient.cpp")


# Define PROJECT_INCLUDE to be the path to the include directory of the project
set(PROJECT_INCLUDE "${CMAKE_CURRENT_LIST_DIR}/include/")
set(PROJECT_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/src/")

# Common target settings
add_library(CommonSettings INTERFACE)
target_include_directories(CommonSettings INTERFACE
    ${PROJECT_INCLUDE}
    ${PROJECT_SOURCE_DIR}
    "${PROJECT_INCLUDE}/fudge_pathfinding"
    "${PROJECT_INCLUDE}/fudge_pathfinding/util"
    "${PROJECT_INCLUDE}/GPGOAP",
    "${random_SOURCE_DIR}/include"
    "${entt_SOURCE_DIR}/single_include"
    "${magic_enum_SOURCE_DIR}/include"
    "${CMAKE_CURRENT_LIST_DIR}/include/taskflow-master/taskflow"
    "${poisson-disk-generator_SOURCE_DIR}"
    "${glm_SOURCE_DIR}"    
    "${sol2_SOURCE_DIR}/include"
    "${sol2_SOURCE_DIR}/include/sol"
    # "${tweeny_SOURCE_DIR}"
    "${raygui_SOURCE_DIR}/src"
    "${PROJECT_INCLUDE}/spine"
    "${stduuid_SOURCE_DIR}/include"
    "${snowhouse_SOURCE_DIR}/include"
    "third_party/objectpool-master/src"
    "${LDtkLoader_SOURCE_DIR}/include"
)

target_link_libraries(CommonSettings INTERFACE
    raylib
    fmt
    nlohmann_json::nlohmann_json
    spdlog
    # tweeny
    effolkronium_random
    EnTT::EnTT
    lua::lua
    sol2::sol2
    gpgoap
    chipmunk_static
    stduuid
    snowhouse
    LDtkLoader::LDtkLoader
)

if(NOT EMSCRIPTEN)
    target_include_directories(CommonSettings INTERFACE
        "third_party/tracy-master/public"
    )
    target_link_libraries(CommonSettings INTERFACE
        Tracy::TracyClient
    )    
endif()

# Declaring our executable
add_executable(${PROJECT_NAME})
target_sources(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCES})
target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_INCLUDE})
target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCES})
target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCE_DIR})
# target_include_directories(${PROJECT_NAME} PRIVATE "${PROJECT_INCLUDE}/spine") #removed for now - not sure if needed
# target_include_directories(${PROJECT_NAME} PUBLIC "${PROJECT_INCLUDE}/fudge_pathfinding")
# target_include_directories(${PROJECT_NAME} PUBLIC "${PROJECT_INCLUDE}/fudge_pathfinding/util")
# target_include_directories(${PROJECT_NAME} PUBLIC "${PROJECT_INCLUDE}/GPGOAP")


# Add include directories for single-header dependencies
# target_include_directories(${PROJECT_NAME} PUBLIC "${random_SOURCE_DIR}/include")
# target_include_directories(${PROJECT_NAME} PUBLIC "${entt_SOURCE_DIR}/single_include")
# target_include_directories(${PROJECT_NAME} PUBLIC "${magic_enum_SOURCE_DIR}/include")
# # target_include_directories(${PROJECT_NAME} PUBLIC "${CMAKE_CURRENT_LIST_DIR}/include/taskflow-master/taskflow")
# # target_include_directories(${PROJECT_NAME} PUBLIC "${poisson-disk-generator_SOURCE_DIR}")
# target_include_directories(${PROJECT_NAME} PUBLIC "${glm_SOURCE_DIR}")
# target_include_directories(${PROJECT_NAME} PUBLIC "${sol2_SOURCE_DIR}/include")
# target_include_directories(${PROJECT_NAME} PUBLIC "${sol2_SOURCE_DIR}/include/sol")

##########################################################################################
# Add custom commands for web build, zipping, and publishing with Butler
##########################################################################################

# Set project and output paths 
set(EMSDK_PATH "D:/emsdk")  # Replace with your emsdk installation path
set(EMSCRIPTEN_PATH "${EMSDK_PATH}/upstream/emscripten")
set(BUILD_DIR "${CMAKE_SOURCE_DIR}/build-emc")
set(WEB_OUT "${BUILD_DIR}/index.html")
set(WEB_ZIP "${CMAKE_SOURCE_DIR}/${PROJECT_NAME}_web.zip")

# Target to activate emsdk
add_custom_target(activate_emsdk
    COMMAND ${CMAKE_COMMAND} -E echo "Activating emsdk latest..."
    COMMAND emsdk activate latest --permanent
    COMMENT "Activating latest emsdk"
)

add_custom_target(copy_assets ALL
    COMMENT "Copying asset files to build directory"
)

if(EMSCRIPTEN)
    # Only add copy logic when EMSCRIPTEN is true
    set(EXCLUDED_DIR ${CMAKE_SOURCE_DIR}/assets/graphics/pre-packing-files_globbed)
    file(GLOB_RECURSE ASSET_FILES RELATIVE ${CMAKE_SOURCE_DIR}/assets ${CMAKE_SOURCE_DIR}/assets/*)

    foreach(ASSET_FILE ${ASSET_FILES})
        # Skip macOS junk files
        string(FIND "${ASSET_FILE}" ".DS_Store" IS_DS_STORE)
        if(IS_DS_STORE GREATER -1)
            continue()
        endif()

        # Skip the excluded directory
        string(FIND "${ASSET_FILE}" "graphics/pre-packing-files_globbed" FOUND)
        if(FOUND EQUAL -1)
            # Create the destination directory first
            get_filename_component(DEST_DIR "${BUILD_DIR}/assets/${ASSET_FILE}" DIRECTORY)
            add_custom_command(
                TARGET copy_assets POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E make_directory "${DEST_DIR}"
                COMMAND ${CMAKE_COMMAND} -E copy
                        "${CMAKE_SOURCE_DIR}/assets/${ASSET_FILE}"
                        "${BUILD_DIR}/assets/${ASSET_FILE}"
            )
        endif()
    endforeach()
endif()


# Target to configure CMake with Emscripten
add_custom_target(configure_web_build
    DEPENDS activate_emsdk copy_assets
    COMMAND call ${EMSDK_PATH}/emsdk_env.bat && ${EMSCRIPTEN_PATH}/emcmake.bat cmake .. 
        -DPLATFORM=Web 
        -DCMAKE_BUILD_TYPE=RelWithDebInfo 
        -DCMAKE_EXE_LINKER_FLAGS="-sUSE_GLFW=3 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -Oz -sALLOW_MEMORY_GROWTH=1 -gsource-map -sASSERTIONS=1 -sNO_DISABLE_EXCEPTION_CATCHING=0 -DNDEBUG -s WASM=1 -s SIDE_MODULE=0 -s EXIT_RUNTIME=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 --closure 1"
        -DCMAKE_EXECUTABLE_SUFFIX=\".html\" 
    WORKING_DIRECTORY ${BUILD_DIR}
    COMMENT "Configuring CMake with Emscripten for web build (debug enabled)"
)

# COMMAND call ${EMSDK_PATH}/emsdk_env.bat && ${EMSCRIPTEN_PATH}/emcmake.bat cmake .. -DPLATFORM=Web -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXE_LINKER_FLAGS="-s USE_GLFW=3 -s -sFULL_ES3 -s MIN_WEBGL_VERSION=2 -sNO_DISABLE_EXCEPTION_CATCHING=1" -DCMAKE_EXECUTABLE_SUFFIX=".html"

# Target to compile the web build
add_custom_target(compile_web_build
    DEPENDS configure_web_build
    COMMAND call ${EMSDK_PATH}/emsdk_env.bat && ${EMSCRIPTEN_PATH}/emmake.bat make
    WORKING_DIRECTORY ${BUILD_DIR}
    COMMENT "Compiling web build with Emscripten"
)

# Target to rename the output HTML to index.html
add_custom_target(rename_to_index
    DEPENDS compile_web_build
    COMMAND ${CMAKE_COMMAND} -E copy ${BUILD_DIR}/${PROJECT_NAME}.html ${WEB_OUT}
    COMMENT "Renaming output HTML file to index.html"
)

# Inject snippet into <head> of index.html
set(INJECT_SNIPPET_PATH "${CMAKE_SOURCE_DIR}/cmake/inject_snippet.html")
set(INJECT_SCRIPT_PATH "${CMAKE_SOURCE_DIR}/cmake/inject_snippet.ps1")

add_custom_target(inject_web_patch
    DEPENDS rename_to_index
    COMMAND ${CMAKE_COMMAND} -E echo "Injecting custom HTML snippet into <head>..."
    COMMAND powershell -ExecutionPolicy Bypass -NoProfile -File "${INJECT_SCRIPT_PATH}" `
        -HtmlPath "${WEB_OUT}" `
        -SnippetPath "${INJECT_SNIPPET_PATH}"
    COMMENT "Patch index.html with custom <script> logic"
)

set(WASM_FILE "${BUILD_DIR}/${PROJECT_NAME}.wasm")
set(DATA_FILE "${BUILD_DIR}/${PROJECT_NAME}.data")
set(JS_FILE "${BUILD_DIR}/${PROJECT_NAME}.js")

add_custom_target(gzip_assets
    DEPENDS inject_web_patch
    COMMAND ${CMAKE_COMMAND} -E echo "Gzipping WASM and DATA files..."
    COMMAND ${CMAKE_COMMAND} -E copy ${WASM_FILE} ${WASM_FILE}.orig
    COMMAND ${CMAKE_COMMAND} -E copy ${DATA_FILE} ${DATA_FILE}.orig
    COMMAND ${CMAKE_COMMAND} -E echo "Trying: ${GZIP_EXE} -kf ${WASM_FILE}"
    COMMAND ${GZIP_EXE} -kf ${WASM_FILE}
    COMMAND ${GZIP_EXE} -kf ${DATA_FILE}
    COMMENT "Gzipping .wasm and .data files"
) 

# Set up the target to zip without the parent folder
add_custom_target(zip_web_build
    DEPENDS gzip_assets
    COMMAND ${CMAKE_COMMAND} -E tar "cf" ${WEB_ZIP} --format=zip index.html ${WASM_FILE}.gz ${DATA_FILE}.gz ${JS_FILE} assets
    # COMMAND ${CMAKE_COMMAND} -E tar "cf" ${WEB_ZIP} --format=zip index.html ${WASM_FILE} ${DATA_FILE} ${JS_FILE} assets
    WORKING_DIRECTORY ${BUILD_DIR}
    COMMENT "Zipping web build for distribution"
)

set(BUTLER_PATH "D:/butler-windows-amd64")  

# Publish directly to itch.io (you will need to install and login to butler)
add_custom_target(push_web_build
    DEPENDS clean_web_build  zip_web_build
    COMMAND ${BUTLER_PATH}/butler push ${WEB_ZIP} ${ITCH_USER}/${ITCH_PAGE}:web --userversion ${PROJECT_VERSION}
    COMMENT "Publishing web build to Itch.io with Butler"
)

# Custom target to clean only web-specific output files
add_custom_target(clean_web_build
    COMMAND ${CMAKE_COMMAND} -E remove
        ${BUILD_DIR}/index.html
        ${BUILD_DIR}/${PROJECT_NAME}.html
        ${BUILD_DIR}/${PROJECT_NAME}.js
        ${BUILD_DIR}/${PROJECT_NAME}.wasm
        ${BUILD_DIR}/${PROJECT_NAME}.data
    COMMENT "Cleaning web-specific output files (HTML, JS, WASM, etc.)"
)

# Add clean_web_build as a dependency of the standard clean target
add_custom_target(clean_all
    DEPENDS clean_web_build
    COMMENT "Cleaning all build files, including web-specific files"
)

##########################################################################################
# Testing : delete later
##########################################################################################

# target_link_libraries(${PROJECT_NAME} PUBLIC raylib)
# # target_link_libraries(${PROJECT_NAME} PUBLIC LDtkLoader::LDtkLoader)
# # target_link_libraries(${PROJECT_NAME} PUBLIC box2d)
# target_link_libraries(${PROJECT_NAME} PUBLIC fmt)
# target_link_libraries(${PROJECT_NAME} PUBLIC nlohmann_json::nlohmann_json)
# target_link_libraries(${PROJECT_NAME} PUBLIC spdlog)
# target_link_libraries(${PROJECT_NAME} PUBLIC tweeny)
# target_link_libraries(${PROJECT_NAME} PUBLIC effolkronium_random)
# target_link_libraries(${PROJECT_NAME} PUBLIC EnTT::EnTT)
# target_link_libraries(${PROJECT_NAME} PUBLIC lua::lua)
# target_link_libraries(${PROJECT_NAME} PUBLIC sol2::sol2)
# target_link_libraries(${PROJECT_NAME} PUBLIC gpgoap)
# target_link_libraries(${PROJECT_NAME} PUBLIC chipmunk)

# now link the included prebuilt libraries
# target_link_libraries(CommonSettings INTERFACE goap)
# target_link_libraries(CommonSettings INTERFACE gpgoap)
target_include_directories(CommonSettings INTERFACE ${Boost_INCLUDE_DIRS})
target_link_directories(${PROJECT_NAME} PUBLIC ${Boost_LIBRARY_DIRS})

target_link_libraries(${PROJECT_NAME} PRIVATE CommonSettings)

# TODO: what about enscripten?
# Platform-specific settings for prebuilt libraries included with project

# boost
target_include_directories(${PROJECT_NAME} PUBLIC ${Boost_INCLUDE_DIRS})
target_link_directories(${PROJECT_NAME} PUBLIC ${Boost_LIBRARY_DIRS})


##########################################################################################
# Add tests
##########################################################################################

# Enable testing
enable_testing()

# # Option to enable/disable tests
option(ENABLE_UNIT_TESTS "Enable unit tests" OFF)

if(ENABLE_UNIT_TESTS AND NOT CMAKE_BUILD_TYPE STREQUAL "Release")
    # Create a function to add unit tests
    function(add_unit_test test_name)
        add_executable(${test_name} ${ARGN})
        target_link_libraries(${test_name} PRIVATE Catch2::Catch2WithMain CommonSettings)
        target_compile_definitions(${test_name} PRIVATE ASSETS_PATH="${CMAKE_CURRENT_SOURCE_DIR}/assets/")
        add_test(NAME ${test_name} COMMAND ${test_name} -s -a)
    endfunction()

    file(GLOB_RECURSE TEST_SOURCES CONFIGURE_DEPENDS "src/*.cpp")

    # Exclude src/main.cpp
    list(REMOVE_ITEM TEST_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp")

    # Add unit tests
    # add_unit_test(unit-tests tests/TestInputSystem.cpp ${TEST_SOURCES})
    # add_unit_test(unit-test-timer tests/TestTimer.cpp ${TEST_SOURCES})

    # You can add more unit tests by calling the function
    # add_unit_test(another-test tests/another_test.cpp)
endif()



##########################################################################################
# Project build settings
##########################################################################################

add_definitions( -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} )

target_compile_definitions(${PROJECT_NAME} PUBLIC SOL_STD_OPTIONAL) # Enable std::optional support in sol2 to prevent errors

# at the top of CMakeLists.txt
if(${PLATFORM} STREQUAL "Web")
    message(STATUS "Detected Emscripten; forcing ASSETS_PATH=\"/assets/\"")
    target_compile_definitions(${PROJECT_NAME} PUBLIC
        ASSETS_PATH=\"/assets/\")
else()
    # your existing Debug / Release logic
    if(CMAKE_BUILD_TYPE MATCHES "Debug")
        target_compile_definitions(${PROJECT_NAME} PUBLIC
            ASSETS_PATH="${CMAKE_CURRENT_SOURCE_DIR}/assets/")
    else()
        target_compile_definitions(${PROJECT_NAME} PUBLIC
            ASSETS_PATH=\"/assets/\")
    endif()
endif()

# Set common compiler flags
# SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Wall -Wswitch")
SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Wall")

if (${PLATFORM} STREQUAL "Web")
    # Tell Emscripten to build an .html file.
    set(CMAKE_EXECUTABLE_SUFFIX ".html")
    SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Os")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -s USE_GLFW=3 -s ASSERTIONS=1 -s WASM=1 -Os -Wall -s TOTAL_MEMORY=512MB -s FORCE_FILESYSTEM=1 --preload-file assets/ --shell-file ../src/minshell.html")
    set(CMAKE_EXECUTABLE_SUFFIX ".html") # This line is used to set your executable to build with the emscripten html template so that you can directly open it.
    set_target_properties(${PROJECT_NAME} PROPERTIES SUFFIX ".html")
    target_compile_definitions(${PROJECT_NAME} PUBLIC ASSETS_PATH="/assets/") # Set the asset path macro in release mode to a relative path that assumes the assets folder is in the same directory as the game executable
endif()


# Ensure that hot-reload is enabled for VS
if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /ZI")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /SAFESEH:NO")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")
endif()
