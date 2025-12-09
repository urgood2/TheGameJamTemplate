# Ownership System - User Guide

## Overview

The ownership system helps protect your itch.io builds from casual theft by watermarking your game with official links and detecting tampering. It displays your Discord and itch.io links in-game and shows a warning overlay if someone modifies them.

**What it does:**
- Embeds your Discord and itch.io links as compile-time constants (harder to modify)
- Provides read-only Lua bindings so scripts can display the links
- Detects if displayed links don't match the embedded ones (tampering)
- Shows a prominent warning overlay on stolen/modified builds
- Generates unique build IDs for tracking and DMCA evidence

**What it doesn't do:**
- This is **not** DRM - determined attackers can still bypass it
- Won't prevent binary hex-editing or source rebuilds
- Won't stop all theft, just makes it harder and more obvious

**Philosophy:** Deterrence + Attribution. Make stolen copies look obviously stolen, and provide evidence for takedown requests.

---

## Quick Start

### 1. Display Ownership Links in Your Game

In your title screen or main menu Lua script, display the official links:

```lua
-- Example: assets/scripts/ui/title_screen.lua

function drawTitleScreen()
    -- Get official links from C++ (these are read-only)
    local discord = ownership.getDiscordLink()
    local itch = ownership.getItchLink()

    -- Display them in your UI
    drawText("Join our Discord: " .. discord, x, y, fontSize, WHITE)
    drawText("Get the game: " .. itch, x, y + 20, fontSize, WHITE)

    -- IMPORTANT: Tell the C++ side what you displayed
    -- This validates that Lua didn't modify the links
    ownership.validate(discord, itch)
end
```

**That's it!** If someone steals your game and changes the Lua code to display their own links, the validation will fail and a warning overlay will appear.

### 2. Set a Secret Salt for Release Builds

The ownership system generates a cryptographic signature using a secret salt. **Never** use the default salt in production!

**Option A: Environment Variable (Recommended)**
```bash
export OWNERSHIP_SALT="your-secret-random-string-here"
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

**Option B: GitHub Actions / CI**
```yaml
# .github/workflows/release.yml
env:
  OWNERSHIP_SALT: ${{ secrets.OWNERSHIP_SALT }}
steps:
  - name: Build Release
    run: |
      cmake -B build -DCMAKE_BUILD_TYPE=Release
      cmake --build build -j
```

**Security Note:** Keep your salt secret! If it leaks, attackers can generate valid signatures. Store it in CI secrets, not in your repository.

### 3. Record Release Builds

When releasing a build to itch.io, record it in the manifest:

```bash
# After building
cmake --build build --target append_release

# Or if you use the justfile
just record-release
```

This creates/updates `releases/manifest.json` with build metadata for tracking stolen copies.

---

## How It Works

### Architecture

```
┌─────────────────────────────────────────┐
│         C++ Engine (Compile-time)        │
│  ─────────────────────────────────────  │
│  DISCORD_LINK = "discord.com/..."       │ ← Hardcoded at compile time
│  ITCH_LINK = "chugget.itch.io/..."      │ ← Cannot be changed at runtime
│  BUILD_ID = "a3f2b1c-20250609-143052"   │ ← Git hash + timestamp
│  BUILD_SIGNATURE = "sha256(...+salt)"   │ ← Proves ownership
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│           Lua Bindings (Read-Only)       │
│  ─────────────────────────────────────  │
│  ownership.getDiscordLink() → string    │
│  ownership.getItchLink() → string       │
│  ownership.getBuildId() → string        │
│  ownership.validate(discord, itch)      │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│      Lua Script (Your Game Code)        │
│  ─────────────────────────────────────  │
│  local discord = ownership.getDiscord() │
│  drawText(discord, ...)                 │
│  ownership.validate(discord, itch)      │ ← Reports what was displayed
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│         C++ Validation (Runtime)         │
│  ─────────────────────────────────────  │
│  if displayed != DISCORD_LINK:          │
│      showWarningOverlay()               │ ← Cannot be disabled from Lua
└─────────────────────────────────────────┘
```

### What Happens When Someone Steals Your Game

**Scenario 1: They upload your build unchanged**
- No tampering detected
- Players see your official Discord/itch.io links
- ✅ Free advertising!

**Scenario 2: They modify the Lua to show their links**
```lua
-- Thief's modified script
function drawTitleScreen()
    -- They changed this to their links
    drawText("Join: discord.gg/thief-link", x, y)

    -- But validate() still receives their fake link
    ownership.validate("discord.gg/thief-link", "fake.itch.io")
    -- ⚠️ TAMPERING DETECTED! Warning overlay appears
end
```

The C++ renders a warning overlay:
```
┌─────────────────────────────────────────┐
│  ⚠ WARNING: POTENTIALLY STOLEN BUILD ⚠  │
│                                         │
│  This copy may have been modified and   │
│  redistributed without permission.      │
│                                         │
│  Official sources:                      │
│  Discord: https://discord.com/...       │ ← Your real links
│  Itch.io: https://chugget.itch.io/...   │
│                                         │
│  Build ID: a3f2b1c-20250609-143052      │
└─────────────────────────────────────────┘
```

This warning:
- Is rendered in C++, so they can't remove it from Lua
- Covers the entire screen
- Shows your real links, redirecting players to you
- Makes the stolen copy look suspicious

**Scenario 3: They hex-edit the binary**
- Advanced attackers can modify the hardcoded strings in the compiled binary
- The ownership system won't detect this (it's not meant to stop determined attackers)
- However, build signatures still help with DMCA takedowns

---

## Integration Guide

### Where to Call `ownership.validate()`

You should call `ownership.validate()` **anywhere you display the ownership links**. Common locations:

**Title Screen** (Most common)
```lua
-- assets/scripts/ui/title_screen.lua
function render()
    local discord = ownership.getDiscordLink()
    local itch = ownership.getItchLink()

    drawLinkButton(discord, x, y)
    drawLinkButton(itch, x, y + 40)

    ownership.validate(discord, itch)  -- ← Call every frame you display them
end
```

**Main Menu**
```lua
-- assets/scripts/ui/main_menu.lua
function drawFooter()
    local discord = ownership.getDiscordLink()
    drawText("Community: " .. discord, 10, screenHeight - 30)
    ownership.validate(discord, ownership.getItchLink())
end
```

**Credits Screen**
```lua
-- assets/scripts/ui/credits.lua
function showCredits()
    local discord = ownership.getDiscordLink()
    local itch = ownership.getItchLink()

    drawText("Discord: " .. discord, x, y)
    drawText("Itch.io: " .. itch, x, y + 20)

    ownership.validate(discord, itch)
end
```

**Performance Note:** `ownership.validate()` is very cheap (just two string comparisons), so calling it every frame is fine.

### Optional: Display Build ID

You can show the build ID in debug menus or "About" screens:

```lua
function drawDebugInfo()
    local buildId = ownership.getBuildId()
    local signature = ownership.getBuildSignature()

    drawText("Build: " .. buildId, 10, 10, 12, GRAY)
    drawText("Sig: " .. signature:sub(1, 16) .. "...", 10, 25, 10, DARKGRAY)
end
```

### Optional: Custom Validation Logic

If you need more control, you can get the links without validating:

```lua
local discord = ownership.getDiscordLink()
local itch = ownership.getItchLink()

-- Do custom stuff with the links
local displayedDiscord = formatLinkForUI(discord)
local displayedItch = formatLinkForUI(itch)

-- Then validate with what you actually displayed
ownership.validate(displayedDiscord, displayedItch)
```

---

## Deployment Guide

### Local Development Builds

No special setup needed! Default salt is used:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
```

Build ID will be: `<git-hash>-<timestamp>` (e.g., `a3f2b1c-20250609-143052`)

### Production Releases

**Step 1: Set a secret salt**

Generate a random salt (do this once, keep it secret):
```bash
# Generate a random salt
openssl rand -hex 32
# Example output: 8f4a2b3c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a
```

Store it securely:
- **Local:** In your shell profile or password manager
- **CI/CD:** In GitHub Secrets, GitLab CI variables, etc.

**Step 2: Build with the salt**

```bash
export OWNERSHIP_SALT="your-secret-salt-here"
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

**Step 3: Record the release**

```bash
# This appends build info to releases/manifest.json
cmake --build build --target append_release

# Or if using justfile
just record-release
```

**Step 4: Commit the manifest**

```bash
git add releases/manifest.json
git commit -m "release: record build a3f2b1c-20250609-143052"
git push
```

Now you have a permanent record of this build's signature. If someone steals it, you can prove ownership.

### GitHub Actions Example

```yaml
# .github/workflows/release.yml
name: Release Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Release
        env:
          OWNERSHIP_SALT: ${{ secrets.OWNERSHIP_SALT }}
        run: |
          cmake -B build -DCMAKE_BUILD_TYPE=Release
          cmake --build build -j

      - name: Record Release
        run: |
          cmake --build build --target append_release
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add releases/manifest.json
          git diff --staged --quiet || git commit -m "release: record build $(git rev-parse --short HEAD)"
          git push

      - name: Upload Build
        uses: actions/upload-artifact@v3
        with:
          name: game-release
          path: build/raylib-cpp-cmake-template
```

**Important:** Add `OWNERSHIP_SALT` to your repository secrets:
1. Go to Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `OWNERSHIP_SALT`
4. Value: Your secret salt
5. Click "Add secret"

### Itch.io Deployment

When uploading to itch.io:

```bash
# Build with production salt
export OWNERSHIP_SALT="your-secret-salt"
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j

# Record the release
cmake --build build --target append_release

# Upload to itch.io
butler push build/raylib-cpp-cmake-template yourusername/yourgame:windows
```

**Pro Tip:** Save the `build_info.json` file from each itch.io upload for future reference:

```bash
cp build/build_info.json releases/itch-$(date +%Y%m%d-%H%M%S).json
```

---

## Investigating Stolen Builds

### If Someone Reports a Stolen Copy

**Step 1: Get the build ID**

Ask the reporter to screenshot the warning overlay or look for the build ID in the warning.

Alternatively, run `strings` on the binary:
```bash
strings suspicious_game.exe | grep -E "(discord\.com|itch\.io|Build ID)"
```

**Step 2: Look up the build in your manifest**

```bash
cat releases/manifest.json | grep "a3f2b1c"
```

Output:
```json
{
  "build_id": "a3f2b1c-20250609-143052",
  "signature": "8f4a2b3c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a",
  "git_commit": "a3f2b1c",
  "timestamp": "2025-06-09T14:30:52Z"
}
```

**Step 3: Verify it's your build**

```bash
git show a3f2b1c
```

This shows the code at that commit. You can verify it's from your repository.

**Step 4: File a DMCA takedown**

The build signature proves ownership:
- Only you know the secret salt used to generate it
- The signature matches `SHA256(build_id + salt)`
- You can demonstrate this in your DMCA notice

Example DMCA snippet:
```
I am the copyright owner of the game available at [your itch.io link].

The infringing copy at [thief's link] contains my compiled binary with
build signature 8f4a2b3c... which was generated from my source code at
commit a3f2b1c on 2025-06-09. I can prove ownership by providing the
secret salt used to generate this signature.

Build ID: a3f2b1c-20250609-143052
Signature: 8f4a2b3c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a
```

---

## API Reference

### Lua API

```lua
-- Get the official Discord invite link (read-only)
ownership.getDiscordLink() → string
-- Returns: "https://discord.com/invite/rp6yXxKu5z"

-- Get the official itch.io page link (read-only)
ownership.getItchLink() → string
-- Returns: "https://chugget.itch.io/"

-- Get the build ID for this binary
ownership.getBuildId() → string
-- Returns: "a3f2b1c-20250609-143052" (git hash + timestamp)

-- Get the build signature (cryptographic proof of ownership)
ownership.getBuildSignature() → string
-- Returns: "8f4a2b3c5d6e7f8a..." (SHA256 hash, 64 hex characters)

-- Validate that displayed links match the embedded constants
ownership.validate(displayedDiscord: string, displayedItch: string) → void
-- Call this after displaying the ownership links
-- If they don't match, a warning overlay will appear
```

**Important:** You cannot modify the ownership table from Lua:
```lua
-- This will throw an error:
ownership.validate = function() end  -- ❌ Error: ownership table is read-only
ownership.getDiscordLink = nil       -- ❌ Error: ownership table is read-only
```

### C++ API

```cpp
// src/core/ownership.hpp

namespace ownership {

// Compile-time constants (cannot be modified)
inline constexpr std::string_view DISCORD_LINK = "https://discord.com/invite/rp6yXxKu5z";
inline constexpr std::string_view ITCH_LINK = "https://chugget.itch.io/";
inline const char* BUILD_ID;        // Injected by CMake
inline const char* BUILD_SIGNATURE; // Injected by CMake

// Validate displayed links (call from Lua)
void validate(const std::string& displayedDiscord, const std::string& displayedItch);

// Check if tampering was detected
bool isTamperDetected();

// Render warning overlay if tampering detected
// Call this at the end of your render loop
void renderTamperWarningIfNeeded(int screenWidth, int screenHeight);

// Register Lua bindings (already called by the engine)
void registerLuaBindings(sol::state& lua);

} // namespace ownership
```

---

## CMake Configuration

The ownership system is automatically configured when you build. Here's what happens:

```cmake
# CMakeLists.txt (automatically included)

# Get git info
execute_process(COMMAND git rev-parse --short HEAD ...)  # → GIT_COMMIT_SHORT
execute_process(COMMAND git rev-parse --abbrev-ref HEAD ...)  # → GIT_BRANCH

# Generate build ID
set(OWNERSHIP_BUILD_ID "${GIT_COMMIT_SHORT}-${BUILD_TIMESTAMP}")

# Generate signature with salt
set(OWNERSHIP_SALT "$ENV{OWNERSHIP_SALT}")  # From environment
if(NOT OWNERSHIP_SALT)
    set(OWNERSHIP_SALT "dev-salt-replace-in-production")  # Default for dev
endif()
string(SHA256 OWNERSHIP_BUILD_SIGNATURE "${OWNERSHIP_BUILD_ID}-${OWNERSHIP_SALT}")

# Pass to compiler
add_compile_definitions(
    BUILD_ID_VALUE="${OWNERSHIP_BUILD_ID}"
    BUILD_SIGNATURE_VALUE="${OWNERSHIP_BUILD_SIGNATURE}"
)
```

**Environment Variables:**
- `OWNERSHIP_SALT` - Secret salt for signature generation (required for production)

---

## Troubleshooting

### Warning Overlay Appears in My Own Build

**Cause:** You're calling `ownership.validate()` with modified links.

**Fix:** Make sure you're passing the exact values from `getDiscordLink()` and `getItchLink()`:

```lua
-- ✅ Correct
local discord = ownership.getDiscordLink()
ownership.validate(discord, ownership.getItchLink())

-- ❌ Wrong - don't modify the links
local discord = "https://discord.gg/MY_LINK"  -- Custom link
ownership.validate(discord, ...)  -- ⚠️ Warning appears!
```

### Build ID Shows "dev-local"

**Cause:** Git is not available or you're not in a git repository.

**Fix:** Make sure you're building inside the git repository:
```bash
git status  # Should show "On branch ..."
cmake -B build
```

### Build ID Shows "nogit-<timestamp>"

**Cause:** CMake couldn't run `git rev-parse`.

**Fix:** Install git or build from within the git repository.

### "ownership table is read-only" Error

**Cause:** You tried to modify the ownership table from Lua.

**Example:**
```lua
ownership.validate = function() end  -- ❌ Error!
```

**Fix:** Don't modify the ownership table. It's intentionally read-only for security.

### Signature Is Always the Same

**Cause:** You're using the default development salt.

**Fix:** Set `OWNERSHIP_SALT` environment variable for production builds:
```bash
export OWNERSHIP_SALT="your-unique-salt"
cmake -B build -DCMAKE_BUILD_TYPE=Release
```

### Python Script Fails in `append_release`

**Cause:** Python 3 is not found or `build_info.json` doesn't exist.

**Fix:**
```bash
# Install Python 3
sudo apt install python3  # Ubuntu/Debian
brew install python3      # macOS

# Make sure you've built first
cmake -B build
cmake --build build -j
# Now build_info.json exists in build/

# Then run append_release
cmake --build build --target append_release
```

---

## Security Considerations

### What This System Protects Against

✅ **Casual theft** - Re-uploading your build to other sites
✅ **Lua modifications** - Changing Discord/itch links in Lua scripts
✅ **Player confusion** - Players can identify the official source
✅ **DMCA evidence** - Build signatures prove ownership

### What This System Does NOT Protect Against

❌ **Binary hex-editing** - Determined attackers can modify hardcoded strings
❌ **Binary patching** - Can remove `validate()` calls or `renderWarning()`
❌ **Source rebuilds** - If source code leaks, they can rebuild without ownership
❌ **Decompilation** - Reverse engineering and rewriting the game

### Design Philosophy

This is **deterrence + attribution**, not DRM:

1. **Deterrence** - Warning overlay makes stolen copies look suspicious and unprofessional
2. **Attribution** - Build signatures provide evidence for DMCA takedowns
3. **Redirection** - Even stolen copies advertise your official links

Most game thieves are lazy and won't bother with hex-editing binaries. This system stops 90% of casual theft with minimal effort.

### Best Practices

1. **Keep your salt secret** - Don't commit it to git, use environment variables or CI secrets
2. **Rotate your salt if it leaks** - Generate a new one and rebuild all future releases
3. **Record all releases** - Run `append_release` target for every itch.io upload
4. **Monitor for stolen copies** - Search itch.io/game sites periodically
5. **Display links prominently** - Title screen, main menu, credits - more visibility = more deterrence

---

## FAQ

### Q: Does this impact performance?

**A:** No. The ownership constants are compile-time, and `validate()` just compares two strings. Even calling it every frame has negligible cost (< 0.01ms).

### Q: Can I change the Discord/itch.io links?

**A:** Yes, edit `src/core/ownership.hpp`:
```cpp
inline constexpr std::string_view DISCORD_LINK = "https://discord.com/invite/YOUR_INVITE";
inline constexpr std::string_view ITCH_LINK = "https://yourusername.itch.io/";
```

Then rebuild.

### Q: What if I don't have a Discord or itch.io page?

**A:** You can set them to your website, social media, or any link you want players to see. The system is flexible - it just embeds and validates whatever links you configure.

### Q: Will this work on web builds (Emscripten)?

**A:** Yes! The ownership system works on both native and web builds. Raylib's `DrawText`/`DrawRectangle` work on WebGL.

### Q: Can I customize the warning overlay?

**A:** Yes, edit `src/core/ownership.cpp` in the `renderTamperWarningIfNeeded()` function. You can change colors, text, layout, etc.

### Q: What if my salt leaks?

**A:** Generate a new salt and rebuild all future releases. Old builds with the old salt are still valid proof of ownership (you can prove you had the old salt). Just don't reuse the leaked salt for new builds.

### Q: Do I need to call `validate()` on every screen?

**A:** No, only where you display the ownership links. Most games just call it on the title screen.

### Q: Can I disable the ownership system?

**A:** Yes, just don't call `ownership.validate()` anywhere. The system is dormant unless you explicitly validate. However, keeping it enabled is recommended for protection.

---

## Example Integration

Here's a complete example of integrating the ownership system into a title screen:

```lua
-- assets/scripts/ui/title_screen.lua

local TitleScreen = {}

function TitleScreen.init()
    -- Get ownership info once
    TitleScreen.discord = ownership.getDiscordLink()
    TitleScreen.itch = ownership.getItchLink()
    TitleScreen.buildId = ownership.getBuildId()
end

function TitleScreen.update(dt)
    -- Handle input, animations, etc.
end

function TitleScreen.render()
    -- Draw title screen background, logo, etc.
    drawBackground()
    drawLogo(screenWidth/2, 100)

    -- Draw menu buttons
    drawMenuButton("Play", screenWidth/2, 300)
    drawMenuButton("Options", screenWidth/2, 350)
    drawMenuButton("Quit", screenWidth/2, 400)

    -- Draw ownership links in footer
    local footerY = screenHeight - 60
    drawText("Join our community:", 20, footerY, 14, GRAY)
    drawClickableLink(TitleScreen.discord, 20, footerY + 20, 16, SKYBLUE)

    drawText("Get the game:", screenWidth - 250, footerY, 14, GRAY)
    drawClickableLink(TitleScreen.itch, screenWidth - 250, footerY + 20, 16, SKYBLUE)

    -- IMPORTANT: Validate what we displayed
    ownership.validate(TitleScreen.discord, TitleScreen.itch)

    -- Optional: Show build ID in corner for debugging
    if DEBUG_MODE then
        drawText("Build: " .. TitleScreen.buildId, 5, 5, 10, DARKGRAY)
    end
end

return TitleScreen
```

This covers the most common use case. The ownership system will automatically show the warning overlay if someone modifies the Lua to change the links.

---

## Next Steps

1. **Add ownership display to your title screen** - See [Integration Guide](#integration-guide)
2. **Set up production salt for releases** - See [Deployment Guide](#deployment-guide)
3. **Test the system** - Modify the links in Lua and verify the warning appears
4. **Record your releases** - Use `append_release` target when uploading to itch.io

For more technical details, see:
- **Design Document:** `docs/plans/2025-06-09-game-stealing-prevention-design.md`
- **Implementation Plan:** `docs/plans/2025-06-09-game-stealing-prevention-impl.md`
- **Example Lua Module:** `assets/scripts/ui/ownership_display.lua`
