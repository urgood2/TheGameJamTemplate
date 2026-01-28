cmake_minimum_required(VERSION 3.14)

# Some third-party dependencies still declare very old cmake_minimum_required()
# values. Force CMake to allow configuring them even though compatibility modes
# below 3.5 have been removed in newer CMake releases.
if(NOT DEFINED CMAKE_POLICY_VERSION_MINIMUM)
    set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
endif()

# Ensure ccache has a writable temp directory before the first compiler probe runs.
if(NOT DEFINED ENV{CCACHE_TEMPDIR})
    set(_repo_ccache_tmp "${CMAKE_SOURCE_DIR}/.ccache/tmp")
    file(MAKE_DIRECTORY "${_repo_ccache_tmp}")
    set(ENV{CCACHE_TEMPDIR} "${_repo_ccache_tmp}")
endif()

# set(LUAJIT_DIR "${CMAKE_SOURCE_DIR}/src/third_party/LuaJIT-2.1"
#     CACHE PATH "Path to LuaJIT source directory" FORCE)

project(raylib-cpp-cmake-template CXX C)

# Legacy compatibility: allow old -DPLATFORM=Native/Web to keep working by
# copying it into the new sentinel variable before we override PLATFORM for raylib.
if(DEFINED PLATFORM AND NOT DEFINED GAME_PLATFORM)
    if(PLATFORM STREQUAL "Native" OR PLATFORM STREQUAL "Web")
        set(GAME_PLATFORM "${PLATFORM}")
    endif()
endif()

# Normalize the high-level platform toggle we use throughout the project. We keep
# the choices simple (Native/Web) and later translate to the concrete raylib
# platform strings (Desktop/Web/...).
set(GAME_PLATFORM "${GAME_PLATFORM}" CACHE STRING "Target platform (Native/Web)")
set_property(CACHE GAME_PLATFORM PROPERTY STRINGS "Native" "Web")
if(NOT DEFINED GAME_PLATFORM OR GAME_PLATFORM STREQUAL "")
    if(EMSCRIPTEN)
        set(GAME_PLATFORM "Web" CACHE STRING "Target platform (Native/Web)" FORCE)
    else()
        set(GAME_PLATFORM "Native" CACHE STRING "Target platform (Native/Web)" FORCE)
    endif()
elseif(EMSCRIPTEN AND NOT GAME_PLATFORM STREQUAL "Web")
    # emcmake should always force the Web sentinel
    set(GAME_PLATFORM "Web" CACHE STRING "Target platform (Native/Web)" FORCE)
endif()

# Map to raylib's expected PLATFORM strings so FetchContent builds configure
# cleanly. Desktop is the default native target.
if(GAME_PLATFORM STREQUAL "Web")
    set(_raylib_platform "Web")
else()
    set(_raylib_platform "Desktop")
endif()
set(PLATFORM "${_raylib_platform}" CACHE STRING "Raylib platform selector" FORCE)

if (GAME_PLATFORM STREQUAL "Web")
    add_definitions(-DFMT_USE_CONSTEXPR=0)
    add_definitions(-DFMT_USE_NONTYPE_TEMPLATE_PARAMETERS=0)
endif()

option(TRACY_ENABLE "Enable Tracy profiler instrumentation" ON)
option(PROFILE_LUA_BOUNDARY "Enable Lua/C++ boundary call profiling" OFF)
option(ENABLE_UNITY_BUILD "Enable unity/jumbo build for main target" OFF)
option(ENGINECTX_DEPRECATE_GLOBALS "Emit deprecation warnings for legacy globals accessors to encourage EngineContext usage" ON)
option(ENABLE_POSTHOG "Enable PostHog metrics (requires libcurl)" OFF)

if (PROFILE_LUA_BOUNDARY)
    message(STATUS "Lua boundary profiling ENABLED")
    add_compile_definitions(PROFILE_LUA_BOUNDARY=1)
endif()

option(ENABLE_UNIT_TESTS "Enable unit tests" OFF)
if(ENABLE_UNIT_TESTS)
    set(BUILD_TESTING ON CACHE BOOL "Enable CTest and dependency tests" FORCE)
else()
    set(BUILD_TESTING OFF CACHE BOOL "Enable CTest and dependency tests" FORCE)
endif()

# Prefer compiler cache when available to speed up rebuilds.
find_program(CCACHE_PROGRAM ccache)
if (CCACHE_PROGRAM)
    message(STATUS "ccache detected: enabling compiler launcher")

    # Default to existing env var, otherwise keep cache local to the repo.
    set(_default_ccache_dir "$ENV{CCACHE_DIR}")
    if (NOT _default_ccache_dir)
        set(_default_ccache_dir "${CMAKE_SOURCE_DIR}/.ccache")
    endif()

    set(CCACHE_DIR "${_default_ccache_dir}" CACHE PATH "Optional ccache directory (leave empty to use default)")
    if (CCACHE_DIR)
        file(MAKE_DIRECTORY "${CCACHE_DIR}")
        file(MAKE_DIRECTORY "${CCACHE_DIR}/tmp")
        set(ENV{CCACHE_DIR} "${CCACHE_DIR}")
        set(ENV{CCACHE_TEMPDIR} "${CCACHE_DIR}/tmp")
        message(STATUS "ccache CCACHE_DIR set to '${CCACHE_DIR}'")
    endif()

    # Honor an existing config path if present, otherwise leave empty to use ccache defaults.
    set(_default_ccache_config "$ENV{CCACHE_CONFIGPATH}")
    if (NOT _default_ccache_config AND EXISTS "${CMAKE_SOURCE_DIR}/.ccache/ccache.conf")
        set(_default_ccache_config "${CMAKE_SOURCE_DIR}/.ccache/ccache.conf")
    endif()
    set(CCACHE_CONFIGPATH "${_default_ccache_config}" CACHE FILEPATH "Optional ccache.conf path (leave empty to use default search)")
    if (CCACHE_CONFIGPATH)
        set(ENV{CCACHE_CONFIGPATH} "${CCACHE_CONFIGPATH}")
        message(STATUS "ccache CCACHE_CONFIGPATH set to '${CCACHE_CONFIGPATH}'")
    endif()

    # Wrap launcher with explicit env so builds honor the repo-local cache even
    # when the outer shell doesn't export CCACHE_* variables.
    set(_ccache_env)
    if (CCACHE_DIR)
        list(APPEND _ccache_env "CCACHE_DIR=${CCACHE_DIR}" "CCACHE_TEMPDIR=${CCACHE_DIR}/tmp")
    endif()
    if (CCACHE_CONFIGPATH)
        list(APPEND _ccache_env "CCACHE_CONFIGPATH=${CCACHE_CONFIGPATH}")
    endif()
    if (_ccache_env)
        set(CMAKE_C_COMPILER_LAUNCHER   ${CMAKE_COMMAND} -E env ${_ccache_env} ${CCACHE_PROGRAM})
        set(CMAKE_CXX_COMPILER_LAUNCHER ${CMAKE_COMMAND} -E env ${_ccache_env} ${CCACHE_PROGRAM})
    else()
        set(CMAKE_C_COMPILER_LAUNCHER   ${CCACHE_PROGRAM})
        set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
    endif()

    add_custom_target(ccache_stats
        COMMAND ${CCACHE_PROGRAM} -s
        COMMENT "Show ccache statistics"
    )
else()
    message(STATUS "ccache not found; builds will run without a compiler cache")
endif()

if(ENGINECTX_DEPRECATE_GLOBALS)
    add_compile_definitions(ENGINECTX_DEPRECATE_GLOBALS=1)
endif()





option(USE_LUAJIT "Use LuaJIT instead of standard Lua" OFF)

# LuaJIT is NOT supported on Emscripten - force OFF with warning
if (EMSCRIPTEN)
    if (USE_LUAJIT)
        message(WARNING "USE_LUAJIT=ON is not supported for Emscripten builds. Forcing OFF.")
        set(USE_LUAJIT OFF CACHE BOOL "Use LuaJIT instead of standard Lua" FORCE)
    endif()
endif()

# LuaJIT source directory (only used if USE_LUAJIT=ON)
set(LUAJIT_DIR "${CMAKE_SOURCE_DIR}/src/third_party/LuaJIT-2.1" CACHE PATH "Path to LuaJIT source directory")

option(SKIP_ASSET_SCAN "Skip recursive asset scan at startup (can also set env SKIP_ASSET_SCAN=1)" OFF)
option(SKIP_UUID_DUMP "Skip writing auto-generated all_uuids.json (can also set env SKIP_UUID_DUMP=1)" OFF)
option(ENABLE_WEB_HELPER_TARGETS "Expose web helper targets even when the top-level build is native" ON)
option(STRIP_LUA_COMMENTS_FOR_WEB "Strip Lua comments from assets for web/release builds to shrink payloads" ON)

if(STRIP_LUA_COMMENTS_FOR_WEB)
    find_package(Python3 COMPONENTS Interpreter QUIET)
    if(NOT Python3_Interpreter_FOUND)
        message(WARNING "STRIP_LUA_COMMENTS_FOR_WEB is ON but Python3 interpreter not found; Lua assets will be copied without stripping comments.")
    endif()
endif()

# ------------------------------------------------------------------
# Dev ergonomics:
#   - Set environment variable SKIP_ASSET_SCAN=1 to skip recursive asset walk at startup.
#   - Set environment variable SKIP_UUID_DUMP=1 to skip writing all_uuids.json.
# ------------------------------------------------------------------

# propagate CMake options to code defaults (env vars still override at runtime)
if (SKIP_ASSET_SCAN)
    add_compile_definitions(SKIP_ASSET_SCAN_DEFAULT=1)
else()
    add_compile_definitions(SKIP_ASSET_SCAN_DEFAULT=0)
endif()

if (SKIP_UUID_DUMP OR EMSCRIPTEN)
    add_compile_definitions(SKIP_UUID_DUMP_DEFAULT=1)
else()
    add_compile_definitions(SKIP_UUID_DUMP_DEFAULT=0)
endif()

# PostHog compile-time guard (libcurl on native; JS fetch on Web).
if(ENABLE_POSTHOG AND EMSCRIPTEN)
    message(STATUS "ENABLE_POSTHOG is ON for Web builds (JS fetch, no libcurl).")
endif()
if(ENABLE_POSTHOG)
    add_compile_definitions(ENABLE_POSTHOG=1)
else()
    add_compile_definitions(ENABLE_POSTHOG=0)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# Default to a debuggable optimized build unless the user/config presets it
if(NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Build type" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

##########################################################################################
# PERFORMANCE OPTIMIZATION: Link-Time Optimization (LTO)
##########################################################################################
option(ENABLE_LTO "Enable Link-Time Optimization for Release builds" ON)

if(ENABLE_LTO AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    include(CheckIPOSupported)
    check_ipo_supported(RESULT lto_supported OUTPUT lto_output)
    if(lto_supported)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
        # MinGW requires gcc-ar and gcc-ranlib for LTO to work properly
        if(MINGW)
            find_program(GCC_AR gcc-ar)
            find_program(GCC_RANLIB gcc-ranlib)
            if(GCC_AR AND GCC_RANLIB)
                set(CMAKE_AR ${GCC_AR})
                set(CMAKE_RANLIB ${GCC_RANLIB})
                message(STATUS "LTO/IPO ENABLED with gcc-ar/gcc-ranlib for MinGW")
            else()
                message(WARNING "LTO on MinGW requires gcc-ar and gcc-ranlib; falling back to no LTO")
                set(CMAKE_INTERPROCEDURAL_OPTIMIZATION FALSE)
            endif()
        else()
            message(STATUS "LTO/IPO ENABLED - expect 10-20% smaller binaries and potential runtime speedup")
        endif()
    else()
        message(WARNING "LTO requested but not supported: ${lto_output}")
    endif()
endif()

##########################################################################################
# PERFORMANCE OPTIMIZATION: Size reduction for Release/RelWithDebInfo/MinSizeRel
##########################################################################################
option(ENABLE_SIZE_OPTIMIZATION "Enable aggressive size optimization flags" OFF)

# MinSizeRel: Aggressive size reduction (disables RTTI and exceptions)
if(NOT MSVC)
    set(CMAKE_CXX_FLAGS_MINSIZEREL "-Os -DNDEBUG -ffunction-sections -fdata-sections -fno-rtti -fno-exceptions" CACHE STRING "" FORCE)
    set(CMAKE_C_FLAGS_MINSIZEREL "-Os -DNDEBUG -ffunction-sections -fdata-sections" CACHE STRING "" FORCE)
    if(APPLE)
        set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL "-Wl,-dead_strip" CACHE STRING "" FORCE)
    elseif(UNIX OR MINGW)
        set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL "-Wl,--gc-sections -Wl,--strip-all" CACHE STRING "" FORCE)
    endif()
else()
    set(CMAKE_CXX_FLAGS_MINSIZEREL "/O1 /Ob1 /DNDEBUG /GR-" CACHE STRING "" FORCE)
    set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL "/OPT:REF /OPT:ICF" CACHE STRING "" FORCE)
endif()

# Size optimization for Release and RelWithDebInfo when ENABLE_SIZE_OPTIMIZATION is ON
if(ENABLE_SIZE_OPTIMIZATION AND NOT CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "SIZE OPTIMIZATION: Enabling gc-sections and dead code elimination")
    if(NOT MSVC)
        # Enable function and data sections for dead code elimination
        add_compile_options(-ffunction-sections -fdata-sections)
        # Note: -gsplit-dwarf disabled on MinGW due to compatibility issues
        # Linker flags for garbage collection of unused sections
        if(APPLE)
            add_link_options(-Wl,-dead_strip)
        elseif(UNIX OR MINGW)
            add_link_options(-Wl,--gc-sections)
            # For Release, also strip all symbols
            if(CMAKE_BUILD_TYPE STREQUAL "Release")
                add_link_options(-Wl,--strip-all)
            elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
                # Strip debug symbols from binary (can reduce size by 50%+)
                add_link_options(-Wl,--strip-debug)
            endif()
        endif()
    else()
        # MSVC equivalent: /OPT:REF removes unreferenced functions
        add_link_options(/OPT:REF /OPT:ICF)
    endif()
endif()

##########################################################################################
# MODULE TOGGLES: Compile-time feature flags to reduce binary size
##########################################################################################
option(ENABLE_SPINE "Enable Spine 2D skeletal animation support (40+ source files)" ON)
option(ENABLE_IMGUI_CONSOLE "Enable ImGui developer console" ON)
option(ENABLE_NAVMESH "Enable NavMesh pathfinding system" ON)
option(ENABLE_GOAP "Enable GOAP AI planning system" ON)
option(ENABLE_LDTK "Enable LDtk level loader" ON)
option(ENABLE_TELEMETRY "Enable telemetry/crash reporting" ON)

# Propagate module toggles to compile definitions
if(ENABLE_SPINE)
    add_compile_definitions(ENABLE_SPINE=1)
    message(STATUS "Module SPINE: ENABLED")
else()
    add_compile_definitions(ENABLE_SPINE=0)
    message(STATUS "Module SPINE: DISABLED (saves ~40 source files)")
endif()

if(ENABLE_IMGUI_CONSOLE)
    add_compile_definitions(ENABLE_IMGUI_CONSOLE=1)
    message(STATUS "Module IMGUI_CONSOLE: ENABLED")
else()
    add_compile_definitions(ENABLE_IMGUI_CONSOLE=0)
    message(STATUS "Module IMGUI_CONSOLE: DISABLED")
endif()

if(ENABLE_NAVMESH)
    add_compile_definitions(ENABLE_NAVMESH=1)
    message(STATUS "Module NAVMESH: ENABLED")
else()
    add_compile_definitions(ENABLE_NAVMESH=0)
    message(STATUS "Module NAVMESH: DISABLED")
endif()

if(ENABLE_GOAP)
    add_compile_definitions(ENABLE_GOAP=1)
    message(STATUS "Module GOAP: ENABLED")
else()
    add_compile_definitions(ENABLE_GOAP=0)
    message(STATUS "Module GOAP: DISABLED")
endif()

if(ENABLE_LDTK)
    add_compile_definitions(ENABLE_LDTK=1)
    message(STATUS "Module LDTK: ENABLED")
else()
    add_compile_definitions(ENABLE_LDTK=0)
    message(STATUS "Module LDTK: DISABLED")
endif()

if(ENABLE_TELEMETRY)
    add_compile_definitions(ENABLE_TELEMETRY=1)
    message(STATUS "Module TELEMETRY: ENABLED")
else()
    add_compile_definitions(ENABLE_TELEMETRY=0)
    message(STATUS "Module TELEMETRY: DISABLED")
endif()

# enable tracy (disable for web)

# Force Tracy off on Web builds regardless of the option.
if (EMSCRIPTEN)
    set(TRACY_ENABLE OFF CACHE BOOL "Tracy disabled on Web" FORCE)
endif()

# Force Tracy off on MinGW builds (known compatibility issues with Windows SDK headers)
if (WIN32 AND MINGW)
    set(TRACY_ENABLE OFF CACHE BOOL "Tracy disabled on MinGW" FORCE)
endif()

if (TRACY_ENABLE AND NOT EMSCRIPTEN)
    message(STATUS "Tracy ENABLED for this build")
    add_compile_definitions(
        TRACY_ENABLE
        TRACY_ENABLED=1
        TRACY_NO_CRASH_HANDLER
    )
else()
    message(STATUS "Tracy DISABLED for this build")
    add_compile_definitions(TRACY_ENABLED=0)
endif()


#set opengl version
#enum_option(OPENGL_VERSION "OFF;4.3;3.3;2.1;1.1;ES 2.0;ES 3.0" "Force a specific OpenGL Version?")
if (EMSCRIPTEN)
    set(OPENGL_VERSION "ES 3.0")
    #for chipmunk
    add_definitions(-DSOKOL_GLES3)
    set(BUILD_DEMOS OFF)
    set(INSTALL_DEMOS OFF)
else()
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

# Windows requires big object file support due to large template instantiations
if (WIN32)
    if (MSVC)
        # MSVC native flag for big objects
        add_compile_options(/bigobj)
    else()
        # MinGW/GCC flag (passes through to assembler)
        add_compile_options(-Wa,-mbig-obj)
    endif()
endif()


#spdlog
# set(SPDLOG_FMT_EXTERNAL ON)
# set(SPDLOG_FMT_EXTERNAL OFF CACHE BOOL "" FORCE)

# set(SPDLOG_FMT_EXTERNAL_HO OFF CACHE BOOL "" FORCE)
# set(SPDLOG_FMT_EXTERNAL ON CACHE BOOL "" FORCE)
# set(SPDLOG_FMT_EXTERNAL_HO OFF CACHE BOOL "" FORCE)
# set(SPDLOG_BUILD_FMT OFF CACHE BOOL "" FORCE)
 



#debug
set(CMAKE_VERBOSE_MAKEFILE ON)

# Set project details
set(ITCH_USER "chugget")
set(ITCH_PAGE "testing")
set(PROJECT_VERSION "0.1")

# Build/version identifiers used for crash reporting and itch uploads
set(_default_build_id "$ENV{ITCH_BUILD_ID}")
if(NOT _default_build_id)
    set(_default_build_id "$ENV{TELEMETRY_BUILD_ID}")
endif()
if(NOT _default_build_id)
    set(_default_build_id "$ENV{BUILD_ID}")
endif()
if(NOT _default_build_id)
    find_package(Git QUIET)
    if(GIT_FOUND)
        # Add TIMEOUT to prevent hanging on Windows if Git is waiting for credentials
        execute_process(
            COMMAND ${GIT_EXECUTABLE} describe --tags --always --dirty
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE _git_build_id
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE _git_build_id_result
            TIMEOUT 10
            ERROR_QUIET
        )
        if(_git_build_id_result EQUAL 0 AND NOT _git_build_id STREQUAL "")
            set(_default_build_id "${_git_build_id}")
        endif()
    endif()
endif()
if(NOT _default_build_id)
    set(_default_build_id "${PROJECT_VERSION}")
endif()
set(ITCH_BUILD_ID "${_default_build_id}" CACHE STRING "Version label used for itch.io pushes and crash reports")
if(NOT DEFINED CRASH_REPORT_BUILD_ID OR CRASH_REPORT_BUILD_ID STREQUAL "")
    set(CRASH_REPORT_BUILD_ID "${ITCH_BUILD_ID}")
endif()
set(CRASH_REPORT_BUILD_ID "${CRASH_REPORT_BUILD_ID}" CACHE STRING "Build identifier attached to crash reports" FORCE)

include(FetchContent)

if(ENABLE_POSTHOG AND NOT EMSCRIPTEN)
    find_package(CURL QUIET)
    if(NOT CURL_FOUND)
        message(STATUS "[FetchContent] CURL not found; fetching from GitHub...")
        message(STATUS "               If this hangs on Windows, Git may be waiting for credentials.")
        set(BUILD_CURL_EXE OFF CACHE BOOL "" FORCE)
        set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
        # Enable HTTPS support so PostHog can be reached over TLS.
        set(HTTP_ONLY OFF CACHE BOOL "" FORCE)
        set(CURL_ENABLE_SSL ON CACHE BOOL "" FORCE)
        set(CURL_USE_SCHANNEL ON CACHE BOOL "" FORCE)
        set(CURL_ZLIB OFF CACHE BOOL "" FORCE)
        FetchContent_Declare(curl
            GIT_REPOSITORY https://github.com/curl/curl.git
            GIT_TAG curl-8_10_1
            GIT_SHALLOW TRUE
            GIT_PROGRESS TRUE
        )
        FetchContent_MakeAvailable(curl)
        message(STATUS "[FetchContent] CURL ready.")
        if(NOT TARGET CURL::libcurl)
            if(TARGET libcurl)
                get_target_property(_curl_aliased libcurl ALIASED_TARGET)
                if(_curl_aliased)
                    add_library(CURL::libcurl ALIAS ${_curl_aliased})
                else()
                    add_library(CURL::libcurl ALIAS libcurl)
                endif()
            endif()
        endif()
    endif()
    if(NOT CURL_FOUND AND NOT TARGET CURL::libcurl)
        message(FATAL_ERROR "ENABLE_POSTHOG is ON but libcurl is unavailable.")
    endif()
endif()

##########################################################################################
# Add dependencies with FetchContent
##########################################################################################

# NOTE (Windows users): If CMake appears to hang here, it's likely Git is waiting for
# credentials. To fix: run 'git config --global credential.helper manager' and ensure
# your GitHub credentials are cached, or use SSH keys.
function(add_git_dependency libName gitURL gitTag)
    message(STATUS "[FetchContent] Fetching ${libName} from ${gitURL} (${gitTag})...")
    message(STATUS "               If this hangs on Windows, Git may be waiting for credentials.")

    FetchContent_Declare(${libName}
        GIT_REPOSITORY ${gitURL}
        GIT_TAG        ${gitTag}
        GIT_SHALLOW    TRUE
        GIT_PROGRESS   TRUE
    )
    FetchContent_MakeAvailable(${libName})

    message(STATUS "[FetchContent] ${libName} ready.")

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

# if (EMSCRIPTEN)
#     message(WARNING "Forcing clean of cached fmt for Web build")
#     file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/_deps/fmt-src")
#     file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/_deps/fmt-build")
# endif()


# # Add {fmt} library
# if (EMSCRIPTEN)
#     # Use older fmt for Web compatibility
#     set(FMT_VERSION 9.1.0)
# else()
#     # Use normal modern version for desktop
#     set(FMT_VERSION 10.2.1)
# endif()

# if (EMSCRIPTEN)
#     message(STATUS ">>> Cleaning cached fmt before re-fetching...")
#     file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/_deps/fmt-src")
#     file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/_deps/fmt-build")
# endif()

# # Force fmt to be header-only for Emscripten
# if (EMSCRIPTEN)
#     # set(FMT_HEADER_ONLY ON CACHE BOOL "" FORCE)
#     # set(FMT_DOC OFF CACHE BOOL "" FORCE)
#     # set(FMT_INSTALL OFF CACHE BOOL "" FORCE)
#     # set(FMT_OS OFF CACHE BOOL "" FORCE)
# endif()

# add_git_dependency(
#     fmt
#     https://github.com/fmtlib/fmt.git
#     9.1.0
# )

# --- DEBUG: print fmt version ---
# if (TARGET fmt)
#     get_target_property(FMT_SOURCE_DIR fmt SOURCE_DIR)
#     message(STATUS ">>> fmt SOURCE DIR = ${FMT_SOURCE_DIR}")

#     file(READ "${FMT_SOURCE_DIR}/include/fmt/core.h" FMT_CORE)
#     string(REGEX MATCH "FMT_VERSION [0-9]+" FMT_VERSION_LINE "${FMT_CORE}")
#     message(STATUS ">>> Detected fmt version: ${FMT_VERSION_LINE}")
# endif()



# --- Force fmt to be header-only for Emscripten ---
# if (EMSCRIPTEN)
#     # # fmt tries to add its library target—stop it
#     # set(FMT_ENABLE_TEST OFF CACHE BOOL "" FORCE)
#     # set(FMT_DOC OFF CACHE BOOL "" FORCE)
#     # set(FMT_INSTALL OFF CACHE BOOL "" FORCE)
#     # set(FMT_OS OFF CACHE BOOL "" FORCE)

#     # set(FMT_HEADER_ONLY ON CACHE BOOL "" FORCE)
#     # add_compile_definitions(FMT_HEADER_ONLY=1)
#     # target_compile_definitions(fmt PRIVATE
#     #     FMT_USE_CONSTEXPR=0
#     #     FMT_USE_CONSTEVAL=0
#     #     FMT_ENFORCE_COMPILE_STRING=0
#     # )
#     # add_definitions(-DFMT_CONSTEVAL=constexpr)
#     # add_definitions(-DFMT_USE_NONTYPE_TEMPLATE_ARGS=0)

#     set(FMT_HEADER_ONLY ON CACHE BOOL "" FORCE)
#     target_compile_definitions(fmt PRIVATE
#         FMT_USE_CONSTEXPR=0
#         FMT_USE_CONSTEVAL=0
#         FMT_CONSTEVAL=constexpr
#         FMT_ENFORCE_COMPILE_STRING=0
#         FMT_USE_NONTYPE_TEMPLATE_ARGS=0
#     )
# endif()

# --------------------------------------------------------------------
# Local fmt (header-only recommended for Web)
# --------------------------------------------------------------------
# ============================================================
# Local fmt (full repo)
# ============================================================
set(FMT_OS OFF CACHE BOOL "" FORCE)
set(FMT_DOC OFF CACHE BOOL "" FORCE)
set(FMT_TEST OFF CACHE BOOL "" FORCE)
set(FMT_INSTALL OFF CACHE BOOL "" FORCE)

# For Emscripten we MUST force header-only + disable constexpr
# if(EMSCRIPTEN)
# Force spdlog to use external fmt (header-only)
set(SPDLOG_FMT_EXTERNAL      OFF CACHE BOOL "" FORCE)
set(SPDLOG_FMT_EXTERNAL_HO   ON  CACHE BOOL "" FORCE)
# endif()

if(EMSCRIPTEN)
    set(FMT_HEADER_ONLY ON CACHE BOOL "" FORCE)
endif()

# ─────────────────────────────────────────────────────────────
# Force vendored fmt into safe header-only mode for Emscripten
# ─────────────────────────────────────────────────────────────
# if(EMSCRIPTEN)
#     add_compile_definitions(
#         FMT_HEADER_ONLY=1
#         FMT_USE_CONSTEXPR=0
#         FMT_USE_CONSTEVAL=0
#         FMT_CONSTEVAL=constexpr
#         FMT_ENFORCE_COMPILE_STRING=0
#         FMT_USE_NONTYPE_TEMPLATE_ARGS=0
#     )
# endif()

add_subdirectory(src/third_party/fmt)

if(EMSCRIPTEN)
    # Remove fmt .cc sources
    # set_target_properties(fmt PROPERTIES SOURCES "")
endif()


# Emscripten fixes (fmt 10+ constexpr bug)
# if(EMSCRIPTEN)
#     target_compile_definitions(fmt PUBLIC
#         FMT_HEADER_ONLY=1
#         FMT_USE_CONSTEXPR=0
#         FMT_USE_CONSTEVAL=0
#         FMT_CONSTEVAL=constexpr
#         FMT_ENFORCE_COMPILE_STRING=0
#         FMT_USE_NONTYPE_TEMPLATE_ARGS=0
#     )
# endif()


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

if(ENABLE_UNIT_TESTS)
    # Add {Catch2} library
    add_git_dependency(
        Catch2
        https://github.com/catchorg/Catch2.git
        v3.6.0
    )
endif()

#add ldtk loader
# add_git_dependency(
#     LDtkLoader
#     https://github.com/Madour/LDtkLoader.git
#     1.5.3.1
# )

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

# if (WIN32 OR EMSCRIPTEN)
# set(Boost_INCLUDE_DIR "D:/boost_1_81_0")
# set(Boost_LIBRARY_DIR "D:/boost_1_81_0/lib")
# find_package(Boost)
# # find_package(Boost REQUIRED regex) # header only libraries must not be added here
# elseif (APPLE)
#     # Adjust the paths if you have installed Boost in a different location
#     set(Boost_INCLUDE_DIR "/opt/homebrew/Cellar/boost/1.83.0/include")
#     set(Boost_LIBRARY_DIR "/opt/homebrew/Cellar/boost/1.83.0/lib")
#     find_package(Boost)
# else ()
#     # Adjust the paths if you have installed Boost in a different location
#     set(Boost_DEBUG 1)
#     find_package(Boost REQUIRED)
#     message(STATUS "BOOST DIR AND LIBS FOUND?:${Boost_FOUND}")
# endif()


##########################################################################################
# add subdirectories for dependencies
##########################################################################################
# Add the src subdirectory
add_subdirectory("src/third_party/GPGOAP")
add_subdirectory("src/third_party/chipmunk")
if(NOT EMSCRIPTEN AND TRACY_ENABLE)
    add_subdirectory("src/third_party/tracy-master")
endif()
add_subdirectory("src/third_party/objectpool-master")
# add_subdirectory("src/third_party/ldtk_loader")

##########################################################################################
# Project executable setup
##########################################################################################

# Adding our source files
# Define PROJECT_SOURCES as a list of all source files. Keep globbing automatic while
# skipping vendor/build trees that generate huge glob checks (e.g. tracy profiler cache).
file(GLOB PROJECT_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_LIST_DIR}/src/*.cpp")
set(_project_glob_excludes
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/chipmunk"
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/fmt"
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/GPGOAP"
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/luajit-cmake-master"
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/LuaJIT-2.1"
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/objectpool-master"
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/sol2"
    "${CMAKE_CURRENT_LIST_DIR}/src/third_party/tracy-master"
)
file(GLOB _src_subdirs LIST_DIRECTORIES true "${CMAKE_CURRENT_LIST_DIR}/src/*")
foreach(_src_dir IN LISTS _src_subdirs)
    if(NOT IS_DIRECTORY "${_src_dir}")
        continue()
    endif()
    list(FIND _project_glob_excludes "${_src_dir}" _excluded_idx)
    if(_excluded_idx EQUAL -1)
        file(GLOB_RECURSE _globbed CONFIGURE_DEPENDS "${_src_dir}/*.cpp")
        list(APPEND PROJECT_SOURCES ${_globbed})
    endif()
endforeach()
list(REMOVE_DUPLICATES PROJECT_SOURCES)

# Exclude third_party code that is built as separate libraries
list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/third_party/(tracy-master|chipmunk|GPGOAP|objectpool-master|fmt|sol2|luajit-cmake-master|LuaJIT-2.1)/")
if(NOT EMSCRIPTEN AND TRACY_ENABLE)
    list(APPEND PROJECT_SOURCES "${CMAKE_CURRENT_LIST_DIR}/src/third_party/tracy-master/public/TracyClient.cpp")
endif()
# Pull in objectpool implementation directly (the bundled CMake project doesn't produce a library target).
set(OBJECTPOOL_SOURCES "${CMAKE_CURRENT_LIST_DIR}/src/third_party/objectpool-master/src/object_pool.cpp")
list(APPEND PROJECT_SOURCES ${OBJECTPOOL_SOURCES})

##########################################################################################
# MODULE-BASED SOURCE FILTERING: Exclude sources when modules are disabled
##########################################################################################

# SPINE: 68 source files - significant compile time and binary size impact
if(NOT ENABLE_SPINE)
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/third_party/spine_impl/")
    message(STATUS "  -> Excluding Spine sources (68 files)")
endif()

# IMGUI_CONSOLE: Developer console - not needed in release builds
if(NOT ENABLE_IMGUI_CONSOLE)
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/third_party/imgui_console/")
    message(STATUS "  -> Excluding ImGui console sources (2 files)")
endif()

# NAVMESH: Pathfinding system - may not be needed for all game types
if(NOT ENABLE_NAVMESH)
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/third_party/navmesh/")
    message(STATUS "  -> Excluding NavMesh sources (5 files)")
endif()

# LDTK: Level loader - only needed if using LDtk levels
if(NOT ENABLE_LDTK)
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/third_party/ldtk_loader/")
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/third_party/ldtkimport/")
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/systems/ldtk_loader/")
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/systems/ldtk_rule_import/")
    message(STATUS "  -> Excluding LDtk sources (20 files)")
endif()

# GOAP: AI planning system - only needed for complex AI
if(NOT ENABLE_GOAP)
    # GOAP is built as a separate library (gpgoap), but we may have wrapper code
    list(FILTER PROJECT_SOURCES EXCLUDE REGEX "/src/systems/ai/goap")
    message(STATUS "  -> Excluding GOAP wrapper sources")
endif()

# Avoid pulling heavy precompiled headers into the Spine runtime sources; they don't
# benefit much and can introduce name clashes with raylib types (e.g. Color/BlendMode).
file(GLOB_RECURSE SPINE_IMPL_SOURCES CONFIGURE_DEPENDS "${CMAKE_CURRENT_LIST_DIR}/src/third_party/spine_impl/*.cpp")
if(SPINE_IMPL_SOURCES)
    set_source_files_properties(${SPINE_IMPL_SOURCES} PROPERTIES SKIP_PRECOMPILE_HEADERS ON)
    if(ENABLE_UNITY_BUILD)
        set_source_files_properties(${SPINE_IMPL_SOURCES} PROPERTIES SKIP_UNITY_BUILD_INCLUSION ON)
    endif()
endif()
if(OBJECTPOOL_SOURCES)
    set_source_files_properties(${OBJECTPOOL_SOURCES} PROPERTIES SKIP_PRECOMPILE_HEADERS ON)
    if(ENABLE_UNITY_BUILD)
        set_source_files_properties(${OBJECTPOOL_SOURCES} PROPERTIES SKIP_UNITY_BUILD_INCLUSION ON)
    endif()
endif()


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
    "${PROJECT_INCLUDE}/GPGOAP"
    "${random_SOURCE_DIR}/include"
    "${entt_SOURCE_DIR}/single_include"
    "${magic_enum_SOURCE_DIR}/include"
    "${CMAKE_CURRENT_LIST_DIR}/include/taskflow-master/taskflow"
    "${poisson-disk-generator_SOURCE_DIR}"
    "${glm_SOURCE_DIR}"    
    # "${sol2_SOURCE_DIR}/include"
    # "${sol2_SOURCE_DIR}/include/sol"
    # "${tweeny_SOURCE_DIR}"
    "${raygui_SOURCE_DIR}/src"
    "${PROJECT_INCLUDE}/spine"
    "${stduuid_SOURCE_DIR}/include"
    "${snowhouse_SOURCE_DIR}/include"
    "third_party/objectpool-master/src"
    # "third_party/ldtk_loader/include"
)

target_link_libraries(CommonSettings INTERFACE
    raylib
    fmt
    nlohmann_json::nlohmann_json
    spdlog
    # tweeny
    effolkronium_random
    EnTT::EnTT
    gpgoap
    chipmunk_static
    stduuid
    snowhouse
    # LDtkLoader
)
if(ENABLE_POSTHOG AND NOT EMSCRIPTEN)
    target_link_libraries(CommonSettings INTERFACE CURL::libcurl)
endif()
target_compile_definitions(CommonSettings INTERFACE
    IMGUI_DEFINE_MATH_OPERATORS
)

if(NOT EMSCRIPTEN AND TRACY_ENABLE)
    target_include_directories(CommonSettings INTERFACE
        "third_party/tracy-master/public"
    )
    target_link_libraries(CommonSettings INTERFACE
        Tracy::TracyClient
    )    
endif()


# ======================================================================
# Sol2 + Lua / LuaJIT Backend Selection
# ======================================================================
add_subdirectory(src/third_party/sol2)
set(SOL2_SOURCE_DIR "${CMAKE_SOURCE_DIR}/src/third_party/sol2/include/" CACHE PATH "Path to sol2 source directory")

if (USE_LUAJIT AND NOT EMSCRIPTEN)
    message(STATUS ">> Using LuaJIT 2.1 as backend for Sol2")

    # Build LuaJIT via cmake wrapper
    add_subdirectory("src/third_party/luajit-cmake-master")

    # Generated headers (e.g., luajit.h) are placed in the build directory
    set(LUAJIT_GENERATED_DIR "${CMAKE_BINARY_DIR}/src/third_party/luajit-cmake-master")

    target_link_libraries(CommonSettings INTERFACE
        luajit::lib
        luajit::header
        sol2::sol2
    )

    target_include_directories(CommonSettings INTERFACE
        ${LUAJIT_DIR}/src
        ${LUAJIT_GENERATED_DIR}
        ${SOL2_SOURCE_DIR}
    )

    target_compile_definitions(CommonSettings INTERFACE
        SOL_LUAJIT=1
        LUAJIT_VERSION="2.1.0-beta3"
    )

else()
    message(STATUS ">> Using standard Lua 5.4.4 as backend for Sol2")

    # Use vendored Lua 5.4.4
    add_git_dependency(
        lua
        "https://github.com/marovira/lua"
        5.4.4
    )

    target_include_directories(CommonSettings INTERFACE
        ${SOL2_SOURCE_DIR}
    )

    target_link_libraries(CommonSettings INTERFACE
        lua::lua
        sol2::sol2
    )

    target_compile_definitions(CommonSettings INTERFACE
        SOL_STD_OPTIONAL
        LUA_VERSION="5.4.4"
    )
endif()
# ======================================================================

# Declaring our executable
add_executable(${PROJECT_NAME})
target_sources(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCES})
target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_INCLUDE})
target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCES})
target_include_directories(${PROJECT_NAME} PUBLIC ${PROJECT_SOURCE_DIR})
if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.16" AND NOT EMSCRIPTEN)
    # Speed up compiles by precompiling our shared heavy header.
    target_precompile_headers(${PROJECT_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/src/util/common_headers.hpp")
endif()
if (ENABLE_UNITY_BUILD AND CMAKE_VERSION VERSION_GREATER_EQUAL "3.16")
    set_property(TARGET ${PROJECT_NAME} PROPERTY UNITY_BUILD ON)
    message(STATUS "Unity build ENABLED for target ${PROJECT_NAME}")
elseif(ENABLE_UNITY_BUILD)
    message(WARNING "Unity build requested but requires CMake >= 3.16; ignoring.")
endif()
# target_include_directories(${PROJECT_NAME} PRIVATE "${PROJECT_INCLUDE}/spine") #removed for now - not sure if needed
# target_include_directories(${PROJECT_NAME} PUBLIC "${PROJECT_INCLUDE}/fudge_pathfinding")
# target_include_directories(${PROJECT_NAME} PUBLIC "${PROJECT_INCLUDE}/fudge_pathfinding/util")
# target_include_directories(${PROJECT_NAME} PUBLIC "${PROJECT_INCLUDE}/GPGOAP")


# ------------------------------------------------------------
# Web build helpers (shared)
# ------------------------------------------------------------
if(EMSCRIPTEN OR ENABLE_WEB_HELPER_TARGETS)
    # Keep a configurable output dir for emscripten builds.
    set(WEB_BUILD_DIR "${WEB_BUILD_DIR}" CACHE PATH "Output directory for Emscripten builds")
    if(NOT WEB_BUILD_DIR)
        set(WEB_BUILD_DIR "${CMAKE_SOURCE_DIR}/build-emc" CACHE PATH "Output directory for Emscripten builds" FORCE)
    endif()

    # Copy assets into the web output tree to match expected /assets layout.
    # Uses shared Python script for parity with justfile.
    if(Python3_Interpreter_FOUND)
        set(_strip_lua_flag "")
        if(STRIP_LUA_COMMENTS_FOR_WEB)
            set(_is_release_like FALSE)
            if(CMAKE_BUILD_TYPE MATCHES "Rel" OR CMAKE_BUILD_TYPE MATCHES "MinSizeRel" OR CMAKE_BUILD_TYPE MATCHES "Release")
                set(_is_release_like TRUE)
            endif()
            if(_is_release_like)
                set(_strip_lua_flag "--strip-lua")
            endif()
        endif()

        add_custom_target(copy_assets
            COMMAND ${Python3_EXECUTABLE} "${CMAKE_SOURCE_DIR}/scripts/copy_assets.py"
                    "${CMAKE_SOURCE_DIR}/assets"
                    "${WEB_BUILD_DIR}/assets"
                    ${_strip_lua_flag}
            COMMENT "Copying assets to web build directory (exclusions + optional Lua stripping)"
        )
    else()
        message(WARNING "Python3 not found - copy_assets target unavailable. Web builds require Python3.")
    endif()
endif()

##########################################################################################
# Add custom commands for web build, zipping, and publishing with Butler (cross-platform)
##########################################################################################
if(EMSCRIPTEN OR ENABLE_WEB_HELPER_TARGETS)
    # Allow overriding the emsdk root; pick sensible defaults per platform.
    if(NOT EMSDK_PATH)
        if(DEFINED ENV{EMSDK} AND NOT "$ENV{EMSDK}" STREQUAL "")
            set(EMSDK_PATH "$ENV{EMSDK}" CACHE PATH "Path to your emsdk installation" FORCE)
        elseif(WIN32)
            set(EMSDK_PATH "D:/emsdk" CACHE PATH "Path to your emsdk installation" FORCE)
        else()
            set(EMSDK_PATH "$ENV{HOME}/emsdk" CACHE PATH "Path to your emsdk installation" FORCE)
        endif()
    endif()

    set(EMSCRIPTEN_PATH "${EMSDK_PATH}/upstream/emscripten")
    set(WEB_OUTPUT_HTML "${WEB_BUILD_DIR}/index.html")
    set(WEB_ZIP "${CMAKE_SOURCE_DIR}/${PROJECT_NAME}_web.zip")

    # OS-specific helpers
    if(CMAKE_HOST_WIN32)
        find_program(GIT_BASH_EXE bash
            PATHS "C:/Program Files/Git/bin" "D:/Program Files/Git/bin" "C:/msys64/usr/bin"
            NO_DEFAULT_PATH
        )
        if(NOT GIT_BASH_EXE)
            find_program(GIT_BASH_EXE bash)
        endif()
        if(GIT_BASH_EXE)
            set(_shell_prefix "${GIT_BASH_EXE}")
        else()
            set(_shell_prefix bash)
        endif()
        set(_emsdk_env_cmd "source \"${EMSDK_PATH}/emsdk_env.sh\" &&")
        set(_emcmake_cmd "\"${EMSCRIPTEN_PATH}/emcmake\"")
        set(_emmake_cmd "\"${EMSCRIPTEN_PATH}/emmake\"")
        set(_inject_cmd
            powershell -ExecutionPolicy Bypass -NoProfile -File "${CMAKE_SOURCE_DIR}/cmake/inject_snippet.ps1" `
                -HtmlPath "${WEB_OUTPUT_HTML}" `
                -SnippetPath "${CMAKE_SOURCE_DIR}/cmake/inject_snippet.html"
        )
    else()
        set(_emsdk_env_cmd "source \"${EMSDK_PATH}/emsdk_env.sh\" &&")
        set(_emcmake_cmd "\"${EMSCRIPTEN_PATH}/emcmake\"")
        set(_emmake_cmd "\"${EMSCRIPTEN_PATH}/emmake\"")
        set(_inject_cmd
            ${CMAKE_COMMAND} -DHTML_PATH="${WEB_OUTPUT_HTML}" -DSNIPPET_PATH="${CMAKE_SOURCE_DIR}/cmake/inject_snippet.html" -P "${CMAKE_SOURCE_DIR}/cmake/inject_snippet.cmake"
        )
        set(_shell_prefix bash)
    endif()

    # NOTE: -sFULL_ES2=1 required for raylib's client-side vertex arrays (fixes "cb is undefined" WebGL error)
    # NOTE: --closure removed because miniaudio/telemetry JS isn't closure-compatible (matches justfile)
    # NOTE: EXPORTED_RUNTIME_METHODS needed for audio (HEAPF32) and telemetry (stringToUTF8OnStack)
    set(_emscripten_link_flags "-sUSE_GLFW=3 -sFULL_ES2=1 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -Oz -sALLOW_MEMORY_GROWTH=1 -gsource-map -sASSERTIONS=1 -sDISABLE_EXCEPTION_CATCHING=0 -DNDEBUG -s WASM=1 -s SIDE_MODULE=0 -s EXIT_RUNTIME=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -sEXPORTED_RUNTIME_METHODS=HEAPF32,HEAPF64,HEAP8,HEAP16,HEAP32,HEAPU8,HEAPU16,HEAPU32,stringToUTF8OnStack,UTF8ToString,stringToUTF8,lengthBytesUTF8")
    set(_configure_args "-DPLATFORM=Web -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_EXE_LINKER_FLAGS=\"${_emscripten_link_flags}\" -DCMAKE_EXECUTABLE_SUFFIX=.html -DCCACHE_PROGRAM= -DCMAKE_C_COMPILER_LAUNCHER= -DCMAKE_CXX_COMPILER_LAUNCHER=")

    # Target to activate emsdk
    add_custom_target(activate_emsdk
        COMMAND ${CMAKE_COMMAND} -E echo "Activating emsdk latest..."
        COMMAND ${_shell_prefix} -lc "'${_emsdk_env_cmd} emsdk activate latest --permanent'"
        COMMENT "Activating latest emsdk"
    )

    # Target to configure CMake with Emscripten
    add_custom_target(configure_web_build
        DEPENDS activate_emsdk copy_assets
        COMMAND ${CMAKE_COMMAND} -E make_directory "${WEB_BUILD_DIR}"
        COMMAND ${_shell_prefix} -lc "'${_emsdk_env_cmd} ${_emcmake_cmd} cmake .. ${_configure_args}'"
        WORKING_DIRECTORY ${WEB_BUILD_DIR}
        COMMENT "Configuring CMake with Emscripten for web build (debug enabled)"
    )

    # Target to compile the web build
    add_custom_target(compile_web_build
        DEPENDS configure_web_build
        COMMAND ${_shell_prefix} -lc "'${_emsdk_env_cmd} cmake --build .'"
        WORKING_DIRECTORY ${WEB_BUILD_DIR}
        COMMENT "Compiling web build with Emscripten"
    )

    # Target to rename the output HTML to index.html
    add_custom_target(rename_to_index
        DEPENDS compile_web_build
        COMMAND ${CMAKE_COMMAND} -E copy ${WEB_BUILD_DIR}/${PROJECT_NAME}.html ${WEB_OUTPUT_HTML}
        COMMENT "Renaming output HTML file to index.html"
    )

    # Inject snippet into <head> of index.html
    add_custom_target(inject_web_patch
        DEPENDS rename_to_index
        COMMAND ${CMAKE_COMMAND} -E echo "Injecting custom HTML snippet into <head>..."
        COMMAND ${_inject_cmd}
        COMMENT "Patch index.html with custom <script> logic"
    )

    set(WASM_FILE "${WEB_BUILD_DIR}/${PROJECT_NAME}.wasm")
    set(DATA_FILE "${WEB_BUILD_DIR}/${PROJECT_NAME}.data")
    set(JS_FILE "${WEB_BUILD_DIR}/${PROJECT_NAME}.js")

    # Custom target to clean only web-specific output files
    add_custom_target(clean_web_build
        COMMAND ${CMAKE_COMMAND} -E remove
            ${WEB_BUILD_DIR}/index.html
            ${WEB_BUILD_DIR}/${PROJECT_NAME}.html
            ${WEB_BUILD_DIR}/${PROJECT_NAME}.js
            ${WEB_BUILD_DIR}/${PROJECT_NAME}.wasm
            ${WEB_BUILD_DIR}/${PROJECT_NAME}.data
        COMMENT "Cleaning web-specific output files (HTML, JS, WASM, etc.)"
    )

    if(NOT GZIP_EXE)
        find_program(GZIP_EXE gzip)
    endif()

    if(GZIP_EXE)
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
            WORKING_DIRECTORY ${WEB_BUILD_DIR}
            COMMENT "Zipping web build for distribution"
        )

        set(BUTLER_PATH "D:/butler-windows-amd64" CACHE STRING "Path to itch.io butler executable or directory")
        if(IS_DIRECTORY "${BUTLER_PATH}")
            set(_BUTLER_EXE "${BUTLER_PATH}/butler")
        elseif(BUTLER_PATH)
            set(_BUTLER_EXE "${BUTLER_PATH}")
        else()
            set(_BUTLER_EXE "butler")
        endif()

        # Publish directly to itch.io (you will need to install and login to butler)
        add_custom_target(push_web_build
            DEPENDS clean_web_build zip_web_build
            COMMAND ${_BUTLER_EXE} push ${WEB_ZIP} ${ITCH_USER}/${ITCH_PAGE}:web --userversion ${CRASH_REPORT_BUILD_ID}
            COMMENT "Publishing web build to Itch.io with Butler"
        )
    else()
        message(WARNING "GZIP_EXE not found; gzip_assets and zip_web_build helper targets will be skipped.")
    endif()

    # Add clean_web_build as a dependency of the standard clean target
    add_custom_target(clean_all
        DEPENDS clean_web_build
        COMMENT "Cleaning all build files, including web-specific files"
    )
endif()

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
# target_include_directories(CommonSettings INTERFACE ${Boost_INCLUDE_DIRS})
# target_link_directories(${PROJECT_NAME} PUBLIC ${Boost_LIBRARY_DIRS})

target_link_libraries(${PROJECT_NAME} PRIVATE CommonSettings)

# TODO: what about enscripten?
# Platform-specific settings for prebuilt libraries included with project

# boost
# target_include_directories(${PROJECT_NAME} PUBLIC ${Boost_INCLUDE_DIRS})
# target_link_directories(${PROJECT_NAME} PUBLIC ${Boost_LIBRARY_DIRS})


##########################################################################################
# Add tests
##########################################################################################

option(ENABLE_ASAN "Enable AddressSanitizer" OFF)

if(ENABLE_UNIT_TESTS)
    enable_testing()
    include(GoogleTest)

    message(STATUS "[FetchContent] Fetching GoogleTest...")
    message(STATUS "               If this hangs on Windows, Git may be waiting for credentials.")

    set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG release-1.12.1
        GIT_SHALLOW TRUE
        GIT_PROGRESS TRUE
    )
    FetchContent_MakeAvailable(googletest)
    message(STATUS "[FetchContent] GoogleTest ready.")

    add_subdirectory(tests)

    # Convenience target to run tests (useful for ASAN builds)
    add_custom_target(run-tests
        COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        DEPENDS unit_tests
        COMMENT "Running unit test suite")
endif()

if(ENABLE_ASAN)
    add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address)
endif()


##########################################################################################
# Project build settings
##########################################################################################

add_definitions( -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} )
add_definitions(-DCRASH_REPORT_BUILD_ID="${CRASH_REPORT_BUILD_ID}")

target_compile_definitions(${PROJECT_NAME} PUBLIC SOL_STD_OPTIONAL) # Enable std::optional support in sol2 to prevent errors

if(EMSCRIPTEN)
    message(STATUS "Detected Emscripten; forcing ASSETS_PATH=\"/assets/\"")
    target_compile_definitions(${PROJECT_NAME} PUBLIC
        ASSETS_PATH=\"/assets/\")
else()
    # your existing Debug / Release logic
    if(CMAKE_BUILD_TYPE MATCHES "Debug")
        target_compile_definitions(${PROJECT_NAME} PUBLIC
            ASSETS_PATH="${CMAKE_CURRENT_SOURCE_DIR}/assets/")
    elseif(CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
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

if (EMSCRIPTEN)
    # Tell Emscripten to build an .html file.
    set(CMAKE_EXECUTABLE_SUFFIX ".html")
    # Use -Oz for size optimization (matches link flags below)
    SET(CMAKE_CXX_FLAGS  "${CMAKE_CXX_FLAGS} -Oz")

    # Files/directories to exclude from web build
    set(WEB_EXCLUDE_FILES
        # Source/editor files
        "assets/auto_export_assets.aseprite"
        "assets/graphics/atlas/"
        "assets/graphics/ascii_tilesets/"
        "assets/graphics/auto-exported-sprites-from-aseprite/"
        # Localization source files
        "assets/localization/localization.babel"
        # Test/example files
        "assets/scripts/AI_TABLE_CONTENT_EXAMPLE.lua"
        "assets/shaders/archived/"
        "assets/test_features.ldtk"
        "assets/test_translation_project.babel"
        "assets/test.png"
        "assets/Title.png"
        "assets/Typical_2D_platformer_example.ldtk"
        "assets/Typical_TopDown_example.ldtk"
        # Note: all_uuids.json excluded via copy_assets.py (UUID dump disabled for Emscripten anyway)
    )

    # Build exclude flags
    set(EXCLUDE_FLAGS "")
    foreach(EXCLUDE_PATH ${WEB_EXCLUDE_FILES})
        set(EXCLUDE_FLAGS "${EXCLUDE_FLAGS} --exclude-file ${EXCLUDE_PATH}")
    endforeach()

    # NOTE: -sFULL_ES2=1 required for raylib's client-side vertex arrays (fixes "cb is undefined" WebGL error)
    # NOTE: Updated to match justfile build flags for consistency
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -sUSE_GLFW=3 -sFULL_ES2=1 -sFULL_ES3=1 -sMIN_WEBGL_VERSION=2 -sMAX_WEBGL_VERSION=2 -sASSERTIONS=1 -sWASM=1 -Oz -Wall -sALLOW_MEMORY_GROWTH=1 -sFORCE_FILESYSTEM=1 -sDISABLE_EXCEPTION_CATCHING=0 -sEXPORTED_RUNTIME_METHODS=HEAPF32,HEAPF64,HEAP8,HEAP16,HEAP32,HEAPU8,HEAPU16,HEAPU32,stringToUTF8OnStack,UTF8ToString,stringToUTF8,lengthBytesUTF8 --preload-file assets/${EXCLUDE_FLAGS} --shell-file ${CMAKE_SOURCE_DIR}/src/minshell.html")
    set_target_properties(${PROJECT_NAME} PROPERTIES SUFFIX ".html")
endif()


# Ensure that hot-reload is enabled for VS
if(CMAKE_CXX_COMPILER_ID MATCHES "MSVC")
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /ZI")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /SAFESEH:NO")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO")
endif()
