# Game Stealing Prevention Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement ownership watermarking and tamper detection to protect itch.io builds from casual theft.

**Architecture:** Compile-time ownership constants in C++, read-only Lua bindings, validation function that detects tampering, and C++ rendered warning overlay. CMake generates build IDs and signatures for traceability.

**Tech Stack:** C++20, Sol2 (Lua bindings), CMake, raylib (rendering), GoogleTest

---

## Task 1: Create Ownership Header

**Files:**
- Create: `src/core/ownership.hpp`

**Step 1: Write the failing test**

Create test file first:

```cpp
// tests/unit/test_ownership.cpp
#include <gtest/gtest.h>
#include "core/ownership.hpp"

TEST(Ownership, ConstantsAreDefined) {
    EXPECT_FALSE(ownership::DISCORD_LINK.empty());
    EXPECT_FALSE(ownership::ITCH_LINK.empty());
    EXPECT_TRUE(ownership::DISCORD_LINK.find("discord.com") != std::string_view::npos);
    EXPECT_TRUE(ownership::ITCH_LINK.find("itch.io") != std::string_view::npos);
}

TEST(Ownership, BuildIdIsDefined) {
    EXPECT_NE(ownership::BUILD_ID, nullptr);
    EXPECT_GT(strlen(ownership::BUILD_ID), 0);
}

TEST(Ownership, BuildSignatureIsDefined) {
    EXPECT_NE(ownership::BUILD_SIGNATURE, nullptr);
    EXPECT_GT(strlen(ownership::BUILD_SIGNATURE), 0);
}
```

**Step 2: Run test to verify it fails**

Run: `just test` or `./build/unit_tests --gtest_filter="Ownership.*"`
Expected: FAIL - `ownership.hpp` not found

**Step 3: Write the header**

```cpp
// src/core/ownership.hpp
#pragma once

#include <string_view>
#include <string>

namespace ownership {

// Compile-time constants - cannot be modified at runtime
inline constexpr std::string_view DISCORD_LINK = "https://discord.com/invite/rp6yXxKu5z";
inline constexpr std::string_view ITCH_LINK = "https://chugget.itch.io/";

// Build ID generated at compile time (CMake injects these via -D flags)
// Defaults provided for builds without CMake injection
#ifndef BUILD_ID_VALUE
#define BUILD_ID_VALUE "dev-local"
#endif
#ifndef BUILD_SIGNATURE_VALUE
#define BUILD_SIGNATURE_VALUE "unsigned"
#endif

inline const char* BUILD_ID = BUILD_ID_VALUE;
inline const char* BUILD_SIGNATURE = BUILD_SIGNATURE_VALUE;

}  // namespace ownership
```

**Step 4: Add test to CMakeLists.txt**

In `tests/CMakeLists.txt`, add to `add_executable(unit_tests ...)`:
```cmake
    unit/test_ownership.cpp
```

**Step 5: Run test to verify it passes**

Run: `just test` or `./build/unit_tests --gtest_filter="Ownership.*"`
Expected: PASS

**Step 6: Commit**

```bash
git add src/core/ownership.hpp tests/unit/test_ownership.cpp tests/CMakeLists.txt
git commit -m "feat(ownership): add compile-time ownership constants header"
```

---

## Task 2: Add CMake Build ID Generation

**Files:**
- Modify: `CMakeLists.txt` (root, around line 60-80)

**Step 1: Write test for build ID format**

Add to `tests/unit/test_ownership.cpp`:

```cpp
TEST(Ownership, BuildIdHasExpectedFormat) {
    // Format: <git-short-hash>-<YYYYMMDD>-<HHMMSS> or "dev-local"
    std::string buildId = ownership::BUILD_ID;
    // Either dev-local or matches pattern like "a3f2b1c-20250609-143052"
    bool isDevLocal = (buildId == "dev-local");
    bool hasTimestamp = (buildId.length() > 15 && buildId.find('-') != std::string::npos);
    EXPECT_TRUE(isDevLocal || hasTimestamp);
}
```

**Step 2: Run test to verify current state**

Run: `./build/unit_tests --gtest_filter="Ownership.BuildIdHasExpectedFormat"`
Expected: PASS (with "dev-local" default)

**Step 3: Add CMake build ID generation**

Add to `CMakeLists.txt` after the options section (around line 148):

```cmake
# =============================================================================
# Build ID Generation for Ownership Tracking
# =============================================================================
execute_process(
    COMMAND git rev-parse --short HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_COMMIT_SHORT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT GIT_COMMIT_SHORT)
    set(GIT_COMMIT_SHORT "nogit")
endif()

execute_process(
    COMMAND git rev-parse --abbrev-ref HEAD
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT GIT_BRANCH)
    set(GIT_BRANCH "unknown")
endif()

string(TIMESTAMP BUILD_TIMESTAMP "%Y%m%d-%H%M%S")
string(TIMESTAMP BUILD_ISO_TIMESTAMP "%Y-%m-%dT%H:%M:%SZ" UTC)

set(OWNERSHIP_BUILD_ID "${GIT_COMMIT_SHORT}-${BUILD_TIMESTAMP}")

# Generate signature (use a secret salt in production - store in env var)
set(OWNERSHIP_SALT "$ENV{OWNERSHIP_SALT}")
if(NOT OWNERSHIP_SALT)
    set(OWNERSHIP_SALT "dev-salt-replace-in-production")
endif()
string(SHA256 OWNERSHIP_BUILD_SIGNATURE "${OWNERSHIP_BUILD_ID}-${OWNERSHIP_SALT}")

message(STATUS "Build ID: ${OWNERSHIP_BUILD_ID}")
message(STATUS "Build Signature: ${OWNERSHIP_BUILD_SIGNATURE}")

add_compile_definitions(
    BUILD_ID_VALUE="${OWNERSHIP_BUILD_ID}"
    BUILD_SIGNATURE_VALUE="${OWNERSHIP_BUILD_SIGNATURE}"
)

# Generate build_info.json for release tracking
file(WRITE "${CMAKE_BINARY_DIR}/build_info.json"
"{
  \"build_id\": \"${OWNERSHIP_BUILD_ID}\",
  \"signature\": \"${OWNERSHIP_BUILD_SIGNATURE}\",
  \"git_commit\": \"${GIT_COMMIT_SHORT}\",
  \"git_branch\": \"${GIT_BRANCH}\",
  \"timestamp\": \"${BUILD_ISO_TIMESTAMP}\"
}")
```

**Step 4: Rebuild and verify**

Run: `just build-debug && ./build/unit_tests --gtest_filter="Ownership.*"`
Expected: All PASS, build ID now has git hash + timestamp format

**Step 5: Commit**

```bash
git add CMakeLists.txt
git commit -m "feat(ownership): add CMake build ID and signature generation"
```

---

## Task 3: Create Tamper Detection State

**Files:**
- Modify: `src/core/ownership.hpp`
- Create: `src/core/ownership.cpp`

**Step 1: Write the failing test**

Add to `tests/unit/test_ownership.cpp`:

```cpp
TEST(Ownership, TamperStateDefaultsToNotDetected) {
    ownership::TamperState state;
    EXPECT_FALSE(state.detected);
    EXPECT_TRUE(state.luaDiscordValue.empty());
    EXPECT_TRUE(state.luaItchValue.empty());
}

TEST(Ownership, ValidateDetectsTampering) {
    ownership::resetTamperState();

    // Validate with correct values - no tampering
    ownership::validate(std::string(ownership::DISCORD_LINK),
                        std::string(ownership::ITCH_LINK));
    EXPECT_FALSE(ownership::isTamperDetected());

    // Validate with wrong Discord link - tampering detected
    ownership::resetTamperState();
    ownership::validate("https://discord.gg/fake", std::string(ownership::ITCH_LINK));
    EXPECT_TRUE(ownership::isTamperDetected());

    // Validate with wrong itch link - tampering detected
    ownership::resetTamperState();
    ownership::validate(std::string(ownership::DISCORD_LINK), "https://fake.itch.io/");
    EXPECT_TRUE(ownership::isTamperDetected());
}
```

**Step 2: Run test to verify it fails**

Run: `./build/unit_tests --gtest_filter="Ownership.ValidateDetectsTampering"`
Expected: FAIL - `TamperState`, `validate`, etc. not found

**Step 3: Update header with tamper detection declarations**

Update `src/core/ownership.hpp`:

```cpp
#pragma once

#include <string_view>
#include <string>

namespace ownership {

// Compile-time constants - cannot be modified at runtime
inline constexpr std::string_view DISCORD_LINK = "https://discord.com/invite/rp6yXxKu5z";
inline constexpr std::string_view ITCH_LINK = "https://chugget.itch.io/";

// Build ID generated at compile time (CMake injects these via -D flags)
#ifndef BUILD_ID_VALUE
#define BUILD_ID_VALUE "dev-local"
#endif
#ifndef BUILD_SIGNATURE_VALUE
#define BUILD_SIGNATURE_VALUE "unsigned"
#endif

inline const char* BUILD_ID = BUILD_ID_VALUE;
inline const char* BUILD_SIGNATURE = BUILD_SIGNATURE_VALUE;

// Tamper detection state
struct TamperState {
    bool detected = false;
    std::string luaDiscordValue;
    std::string luaItchValue;
};

// Validate displayed links against compile-time constants
// Called from Lua after rendering ownership info
void validate(const std::string& displayedDiscord, const std::string& displayedItch);

// Check if tampering was detected
bool isTamperDetected();

// Get current tamper state (for rendering warning)
const TamperState& getTamperState();

// Reset tamper state (for testing)
void resetTamperState();

}  // namespace ownership
```

**Step 4: Create implementation file**

Create `src/core/ownership.cpp`:

```cpp
#include "ownership.hpp"

namespace ownership {

namespace {
    TamperState g_tamperState;
}

void validate(const std::string& displayedDiscord, const std::string& displayedItch) {
    g_tamperState.luaDiscordValue = displayedDiscord;
    g_tamperState.luaItchValue = displayedItch;

    // Check if displayed values match compile-time constants
    bool discordMatches = (displayedDiscord == DISCORD_LINK);
    bool itchMatches = (displayedItch == ITCH_LINK);

    g_tamperState.detected = !(discordMatches && itchMatches);
}

bool isTamperDetected() {
    return g_tamperState.detected;
}

const TamperState& getTamperState() {
    return g_tamperState;
}

void resetTamperState() {
    g_tamperState = TamperState{};
}

}  // namespace ownership
```

**Step 5: Add to tests CMakeLists.txt**

In `tests/CMakeLists.txt`, add to the source list:
```cmake
    ${CMAKE_SOURCE_DIR}/src/core/ownership.cpp
```

**Step 6: Run test to verify it passes**

Run: `./build/unit_tests --gtest_filter="Ownership.*"`
Expected: All PASS

**Step 7: Commit**

```bash
git add src/core/ownership.hpp src/core/ownership.cpp tests/CMakeLists.txt tests/unit/test_ownership.cpp
git commit -m "feat(ownership): add tamper detection state and validation"
```

---

## Task 4: Add Lua Bindings

**Files:**
- Modify: `src/core/ownership.cpp`
- Modify: `src/systems/scripting/scripting_functions.cpp`

**Step 1: Write the failing test**

Add to `tests/unit/test_ownership.cpp`:

```cpp
#include "sol/sol.hpp"

TEST(Ownership, LuaBindingsExist) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);

    ownership::registerLuaBindings(lua);

    // Check that ownership table exists
    sol::table ownershipTable = lua["ownership"];
    EXPECT_TRUE(ownershipTable.valid());

    // Check getters exist and return correct values
    sol::function getDiscord = ownershipTable["getDiscordLink"];
    sol::function getItch = ownershipTable["getItchLink"];
    sol::function getBuildId = ownershipTable["getBuildId"];
    sol::function validate = ownershipTable["validate"];

    EXPECT_TRUE(getDiscord.valid());
    EXPECT_TRUE(getItch.valid());
    EXPECT_TRUE(getBuildId.valid());
    EXPECT_TRUE(validate.valid());

    // Check getter return values
    std::string discord = getDiscord();
    std::string itch = getItch();

    EXPECT_EQ(discord, ownership::DISCORD_LINK);
    EXPECT_EQ(itch, ownership::ITCH_LINK);
}
```

**Step 2: Run test to verify it fails**

Run: `./build/unit_tests --gtest_filter="Ownership.LuaBindingsExist"`
Expected: FAIL - `registerLuaBindings` not found

**Step 3: Add Lua binding declaration to header**

Add to `src/core/ownership.hpp` before the closing `}`:

```cpp
// Forward declaration for Sol2
namespace sol { class state; }

// Register Lua bindings (read-only getters + validate function)
void registerLuaBindings(sol::state& lua);
```

**Step 4: Implement Lua bindings**

Add to `src/core/ownership.cpp`:

```cpp
#include "sol/sol.hpp"

// ... existing code ...

void registerLuaBindings(sol::state& lua) {
    sol::table ownershipTable = lua.create_named_table("ownership");

    // Read-only getters - Lua cannot modify these
    ownershipTable.set_function("getDiscordLink", []() -> std::string {
        return std::string(DISCORD_LINK);
    });

    ownershipTable.set_function("getItchLink", []() -> std::string {
        return std::string(ITCH_LINK);
    });

    ownershipTable.set_function("getBuildId", []() -> std::string {
        return std::string(BUILD_ID);
    });

    // Validation function - Lua reports what it displayed
    ownershipTable.set_function("validate",
        [](const std::string& displayedDiscord, const std::string& displayedItch) {
            validate(displayedDiscord, displayedItch);
        });
}
```

**Step 5: Run test to verify it passes**

Run: `./build/unit_tests --gtest_filter="Ownership.LuaBindingsExist"`
Expected: PASS

**Step 6: Register bindings in scripting_functions.cpp**

In `src/systems/scripting/scripting_functions.cpp`, add include at top:

```cpp
#include "core/ownership.hpp"
```

In `initLuaMasterState()`, add after the existing binding sections (around line 268):

```cpp
  //---------------------------------------------------------
  // ownership (anti-theft watermarking)
  //---------------------------------------------------------
  ownership::registerLuaBindings(stateToInit);
```

**Step 7: Run full test suite**

Run: `just test`
Expected: All PASS

**Step 8: Commit**

```bash
git add src/core/ownership.hpp src/core/ownership.cpp src/systems/scripting/scripting_functions.cpp tests/unit/test_ownership.cpp
git commit -m "feat(ownership): add Lua bindings for ownership validation"
```

---

## Task 5: Implement Warning Overlay Rendering

**Files:**
- Modify: `src/core/ownership.hpp`
- Modify: `src/core/ownership.cpp`

**Step 1: Write the failing test**

Add to `tests/unit/test_ownership.cpp`:

```cpp
TEST(Ownership, RenderWarningFunctionExists) {
    // Just verify the function exists and is callable
    // Actual rendering requires raylib context which we don't have in unit tests
    ownership::resetTamperState();

    // Should not crash when called with no tampering
    ownership::renderTamperWarningIfNeeded(800, 600);

    // Trigger tampering
    ownership::validate("fake", "fake");
    EXPECT_TRUE(ownership::isTamperDetected());

    // Should not crash when tampering detected (would render in real context)
    ownership::renderTamperWarningIfNeeded(800, 600);
}
```

**Step 2: Run test to verify it fails**

Run: `./build/unit_tests --gtest_filter="Ownership.RenderWarningFunctionExists"`
Expected: FAIL - `renderTamperWarningIfNeeded` not found

**Step 3: Add render function declaration**

Add to `src/core/ownership.hpp`:

```cpp
// Render tamper warning overlay if tampering detected
// Call this at the end of your render loop (before EndDrawing)
// screenWidth/screenHeight used to center the warning
void renderTamperWarningIfNeeded(int screenWidth, int screenHeight);
```

**Step 4: Implement render function**

Add to `src/core/ownership.cpp`:

```cpp
#include "raylib.h"

// ... existing code ...

void renderTamperWarningIfNeeded(int screenWidth, int screenHeight) {
    if (!g_tamperState.detected) {
        return;
    }

    // Warning box dimensions
    const int boxWidth = 500;
    const int boxHeight = 280;
    const int boxX = (screenWidth - boxWidth) / 2;
    const int boxY = (screenHeight - boxHeight) / 2;
    const int padding = 20;
    const int fontSize = 18;
    const int titleFontSize = 24;

    // Semi-transparent dark overlay
    DrawRectangle(0, 0, screenWidth, screenHeight, Fade(BLACK, 0.7f));

    // Warning box background
    DrawRectangle(boxX, boxY, boxWidth, boxHeight, Fade(DARKGRAY, 0.95f));
    DrawRectangleLines(boxX, boxY, boxWidth, boxHeight, RED);
    DrawRectangleLines(boxX + 1, boxY + 1, boxWidth - 2, boxHeight - 2, RED);

    // Warning title
    const char* title = "WARNING: POTENTIALLY STOLEN BUILD";
    int titleWidth = MeasureText(title, titleFontSize);
    DrawText(title, boxX + (boxWidth - titleWidth) / 2, boxY + padding, titleFontSize, RED);

    // Warning message
    int textY = boxY + padding + titleFontSize + 20;
    DrawText("This copy may have been modified and", boxX + padding, textY, fontSize, WHITE);
    textY += fontSize + 5;
    DrawText("redistributed without permission.", boxX + padding, textY, fontSize, WHITE);

    textY += fontSize + 20;
    DrawText("Official sources:", boxX + padding, textY, fontSize, YELLOW);

    textY += fontSize + 10;
    DrawText(TextFormat("Discord: %s", std::string(DISCORD_LINK).c_str()),
             boxX + padding, textY, fontSize, SKYBLUE);

    textY += fontSize + 5;
    DrawText(TextFormat("Itch.io: %s", std::string(ITCH_LINK).c_str()),
             boxX + padding, textY, fontSize, SKYBLUE);

    textY += fontSize + 20;
    DrawText(TextFormat("Build ID: %s", BUILD_ID), boxX + padding, textY, fontSize - 2, GRAY);
}
```

**Step 5: Run test to verify it passes**

Run: `./build/unit_tests --gtest_filter="Ownership.RenderWarningFunctionExists"`
Expected: PASS

**Step 6: Commit**

```bash
git add src/core/ownership.hpp src/core/ownership.cpp tests/unit/test_ownership.cpp
git commit -m "feat(ownership): add tamper warning overlay rendering"
```

---

## Task 6: Integrate Warning Render into Main Loop

**Files:**
- Modify: `src/main.cpp`

**Step 1: Add include**

At top of `src/main.cpp`, add:

```cpp
#include "core/ownership.hpp"
```

**Step 2: Add warning render call**

In `MainLoopRenderAbstraction()` function (around line 181-199), add the warning render as the LAST thing before the function returns:

```cpp
auto MainLoopRenderAbstraction(float dt) -> void {

  switch (globals::getCurrentGameState()) {
  case GameState::MAIN_MENU:
    mainMenuStateGameLoopRender(dt);
    break;
  case GameState::MAIN_GAME:
    mainGameStateGameLoopRender(dt);
    break;
  case GameState::LOADING_SCREEN:
    loadingScreenStateGameLoopRender(dt);
    break;
  case GameState::GAME_OVER:
    gameOverScreenGameLoopRender(dt);
    break;
  default:
    // draw nothing
    break;
  }

  // Render tamper warning overlay (always last, cannot be covered)
  ownership::renderTamperWarningIfNeeded(GetScreenWidth(), GetScreenHeight());
}
```

**Step 3: Build and verify**

Run: `just build-debug`
Expected: Compiles without errors

**Step 4: Commit**

```bash
git add src/main.cpp
git commit -m "feat(ownership): integrate tamper warning into main render loop"
```

---

## Task 7: Add Release Manifest Generation

**Files:**
- Create: `releases/.gitkeep`
- Create: `scripts/append_release.py`
- Modify: `CMakeLists.txt`

**Step 1: Create releases directory**

```bash
mkdir -p releases
touch releases/.gitkeep
```

**Step 2: Create manifest append script**

Create `scripts/append_release.py`:

```python
#!/usr/bin/env python3
"""Append build info to releases/manifest.json"""

import json
import sys
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("Usage: append_release.py <build_info.json>")
        sys.exit(1)

    build_info_path = Path(sys.argv[1])
    manifest_path = Path(__file__).parent.parent / "releases" / "manifest.json"

    # Read build info
    with open(build_info_path) as f:
        build_info = json.load(f)

    # Add notes field
    build_info["notes"] = ""

    # Read or create manifest
    if manifest_path.exists():
        with open(manifest_path) as f:
            manifest = json.load(f)
    else:
        manifest = {"releases": []}

    # Check for duplicate
    for release in manifest["releases"]:
        if release.get("build_id") == build_info.get("build_id"):
            print(f"Build {build_info['build_id']} already in manifest, skipping")
            return

    # Append new release
    manifest["releases"].append(build_info)

    # Write manifest
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Added {build_info['build_id']} to manifest")

if __name__ == "__main__":
    main()
```

**Step 3: Make script executable**

```bash
chmod +x scripts/append_release.py
```

**Step 4: Add CMake target for release manifest**

Add to `CMakeLists.txt` after the build_info.json generation:

```cmake
# Target to append build info to release manifest (run manually for releases)
find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND)
    add_custom_target(append_release
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/scripts/append_release.py ${CMAKE_BINARY_DIR}/build_info.json
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Appending build to releases/manifest.json"
    )
endif()
```

**Step 5: Update justfile (if exists)**

If there's a `justfile`, add:

```just
# Record this build in the release manifest
record-release:
    cmake --build build --target append_release
```

**Step 6: Commit**

```bash
git add releases/.gitkeep scripts/append_release.py CMakeLists.txt
git commit -m "feat(ownership): add release manifest generation"
```

---

## Task 8: Add Main Target Source File

**Files:**
- Modify: Root `CMakeLists.txt` to include ownership.cpp in main target

**Step 1: Find where source files are listed**

Search for where `src/core/` files are added to the main target.

**Step 2: Add ownership.cpp**

Add `src/core/ownership.cpp` to the main executable source list (alongside other `src/core/*.cpp` files).

**Step 3: Build and verify**

Run: `just build-debug`
Expected: Compiles and links without errors

**Step 4: Commit**

```bash
git add CMakeLists.txt
git commit -m "build: add ownership.cpp to main target"
```

---

## Task 9: Create Example Lua Usage

**Files:**
- Create: `assets/scripts/ui/ownership_display.lua`

**Step 1: Create the Lua module**

```lua
-- assets/scripts/ui/ownership_display.lua
-- Example usage of ownership bindings for title screen

local M = {}

--- Draw ownership links on title screen
--- Call this from your title screen render function
--- @param x number X position for text
--- @param y number Y position for text
function M.draw(x, y)
    -- Get official links from C++ (read-only)
    local discord = ownership.getDiscordLink()
    local itch = ownership.getItchLink()
    local buildId = ownership.getBuildId()

    -- Draw the links (replace with your actual UI system)
    -- This is just an example using hypothetical draw functions
    drawText("Join our Discord: " .. discord, x, y, 16, {255, 255, 255, 255})
    drawText("Get the game: " .. itch, x, y + 20, 16, {255, 255, 255, 255})
    drawText("Build: " .. buildId, x, y + 40, 12, {128, 128, 128, 255})

    -- IMPORTANT: Report what we displayed to C++ for validation
    -- If these don't match compile-time constants, warning overlay appears
    ownership.validate(discord, itch)
end

return M
```

**Step 2: Commit**

```bash
git add assets/scripts/ui/ownership_display.lua
git commit -m "docs: add example Lua ownership display module"
```

---

## Task 10: Final Integration Test

**Files:**
- Create: `tests/integration/test_ownership_integration.cpp` (optional)

**Step 1: Manual integration test**

Build the game and verify:
1. Game starts normally without warning
2. Modify `ownership_display.lua` to pass wrong values to `validate()`
3. Restart game - warning overlay should appear
4. Warning shows correct Discord/itch.io links
5. Warning cannot be dismissed or covered

**Step 2: Verify build info**

```bash
cat build/build_info.json
```

Expected: Contains build_id, signature, git_commit, git_branch, timestamp

**Step 3: Test manifest append**

```bash
cmake --build build --target append_release
cat releases/manifest.json
```

Expected: manifest.json contains the build entry

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(ownership): complete game stealing prevention implementation"
```

---

## Summary

| Task | Component | Purpose |
|------|-----------|---------|
| 1 | ownership.hpp | Compile-time constants |
| 2 | CMakeLists.txt | Build ID generation |
| 3 | ownership.cpp | Tamper detection state |
| 4 | Lua bindings | Read-only getters + validate() |
| 5 | Warning overlay | C++ rendered warning |
| 6 | main.cpp | Integrate into render loop |
| 7 | Manifest | Release tracking |
| 8 | Build config | Add to main target |
| 9 | Example Lua | Usage documentation |
| 10 | Integration test | Verify end-to-end |

**Total estimated tasks:** 10 tasks, ~30-40 bite-sized steps
