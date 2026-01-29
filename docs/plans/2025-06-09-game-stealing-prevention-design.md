# Game Stealing Prevention Design

## Goals

1. **Watermarking/Attribution** - Display ownership links (Discord + itch.io) on title screen so players can identify legitimate source
2. **Detection** - Unique build IDs and signatures for DMCA evidence

## Official Links

- Discord: `https://discord.com/invite/rp6yXxKu5z`
- Itch.io: `https://chugget.itch.io/`

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      C++ Engine                          │
├─────────────────────────────────────────────────────────┤
│  OwnershipInfo (compile-time constants)                  │
│  ├── discordLink                                         │
│  ├── itchLink                                            │
│  ├── buildId = git_commit + timestamp                    │
│  └── signature = SHA256(buildId + links + salt)          │
├─────────────────────────────────────────────────────────┤
│  Lua Bindings (read-only)                                │
│  ├── ownership.getDiscordLink() → string                 │
│  ├── ownership.getItchLink() → string                    │
│  └── ownership.getBuildId() → string                     │
├─────────────────────────────────────────────────────────┤
│  TamperDetection                                         │
│  ├── ownership.validate(displayedDiscord, displayedItch) │
│  └── renderTamperWarning() [if mismatch detected]        │
└─────────────────────────────────────────────────────────┘
```

## Implementation Components

### 1. C++ Ownership Header (`src/core/ownership.hpp`)

```cpp
#pragma once
#include <string_view>

namespace ownership {

// Compile-time constants - cannot be modified at runtime
inline constexpr std::string_view DISCORD_LINK = "https://discord.com/invite/rp6yXxKu5z";
inline constexpr std::string_view ITCH_LINK = "https://chugget.itch.io/";

// Build ID generated at compile time (CMake injects these)
extern const char* BUILD_ID;        // e.g., "a3f2b1c-20250609-143052"
extern const char* BUILD_SIGNATURE; // SHA256 for binary identification

// Tamper detection state
struct TamperState {
    bool detected = false;
    std::string luaDiscordValue;
    std::string luaItchValue;
};

// Called each frame during title screen rendering
void validateAndRender(const TamperState& state);

// Lua bindings (read-only getters)
void registerLuaBindings(sol::state& lua);

} // namespace ownership
```

### 2. CMake Build Integration

```cmake
# Get git info
execute_process(
    COMMAND git rev-parse --short HEAD
    OUTPUT_VARIABLE GIT_COMMIT
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
execute_process(
    COMMAND git rev-parse --abbrev-ref HEAD
    OUTPUT_VARIABLE GIT_BRANCH
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)

# Generate timestamp
string(TIMESTAMP BUILD_TIMESTAMP "%Y%m%d-%H%M%S")
string(TIMESTAMP BUILD_ISO_TIMESTAMP "%Y-%m-%dT%H:%M:%SZ")

# Create build ID
set(BUILD_ID "${GIT_COMMIT}-${BUILD_TIMESTAMP}")

# Generate signature (SHA256 of build info + secret salt)
# Note: Keep the salt secret - don't commit it to public repos
string(SHA256 BUILD_SIGNATURE "${BUILD_ID}-discord.com/invite/rp6yXxKu5z-chugget.itch.io/-YOUR_SECRET_SALT")

# Pass to compiler
add_compile_definitions(
    BUILD_ID="${BUILD_ID}"
    BUILD_SIGNATURE="${BUILD_SIGNATURE}"
    GIT_COMMIT="${GIT_COMMIT}"
    GIT_BRANCH="${GIT_BRANCH}"
)

# Generate build_info.json
file(WRITE "${CMAKE_BINARY_DIR}/build_info.json"
"{
  \"build_id\": \"${BUILD_ID}\",
  \"signature\": \"${BUILD_SIGNATURE}\",
  \"git_commit\": \"${GIT_COMMIT}\",
  \"git_branch\": \"${GIT_BRANCH}\",
  \"timestamp\": \"${BUILD_ISO_TIMESTAMP}\"
}")
```

### 3. Tamper Warning Overlay

When `ownership.validate()` receives values that don't match compile-time constants, C++ renders a warning overlay:

```
┌─────────────────────────────────────────────────────────┐
│  ⚠ WARNING: THIS MAY BE A STOLEN BUILD ⚠               │
│                                                         │
│  This copy may have been modified and redistributed     │
│  without permission.                                    │
│                                                         │
│  Official sources:                                      │
│  Discord: https://discord.com/invite/rp6yXxKu5z        │
│  Itch.io: https://chugget.itch.io/                     │
│                                                         │
│  Build ID: a3f2b1c-20250609-143052                     │
└─────────────────────────────────────────────────────────┘
```

Rendering details:
- Drawn in C++ using raylib `DrawRectangle` + `DrawText`
- Rendered last before `EndDrawing()` so it cannot be covered
- Semi-transparent dark background overlay
- Cannot be disabled from Lua

### 4. Lua Integration

```lua
-- In title_screen.lua or main_menu.lua

function drawTitleScreen()
    -- Get official links from C++ (read-only)
    local discord = ownership.getDiscordLink()
    local itch = ownership.getItchLink()

    -- Draw them using your UI code
    drawText("Join us: " .. discord, x, y)
    drawText("Get the game: " .. itch, x, y2)

    -- Report what we displayed - C++ validates this
    ownership.validate(discord, itch)
end
```

### 5. Release Manifest (`releases/manifest.json`)

Tracks all release builds for traceability:

```json
{
  "releases": [
    {
      "build_id": "a3f2b1c-20250609-143052",
      "signature": "8f4a2b3c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a",
      "git_commit": "a3f2b1c",
      "git_branch": "master",
      "timestamp": "2025-06-09T14:30:52Z",
      "notes": ""
    }
  ]
}
```

## Investigating Stolen Builds

1. Get build ID from stolen copy:
   - Run `strings game.exe | grep discord` to find embedded links
   - Or look at the warning overlay screenshot if someone reports it

2. Find matching release:
   ```bash
   grep "a3f2b1c" releases/manifest.json
   ```

3. Verify with git:
   ```bash
   git show a3f2b1c
   ```

4. For DMCA: Signature proves ownership (you know the secret salt used to generate it)

## Threat Model

### Protected Against
- Casual theft (re-uploading unchanged builds)
- Basic Lua modifications (changing Discord link in scripts)
- Players unable to identify real source

### Not Protected Against (Determined Attackers)
- Hex-editing binary to change hardcoded strings
- Patching out validate() call in binary
- Rebuilding from source if leaked

### Design Philosophy
This is **deterrence + attribution**, not DRM. The warning makes stolen copies look obviously stolen, and build signatures provide DMCA evidence. Most game thieves are lazy and won't bother with binary patching.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
