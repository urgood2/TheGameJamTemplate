# LuaJIT Optional Backend - Implementation & Testing Plan

**Generated:** January 18, 2026
**Status:** Planning Complete, Ready for Implementation
**Priority:** HIGH

---

## Executive Summary

This plan details how to add **optional LuaJIT 2.1** support as an alternative to the current **Lua 5.4.4** backend in the Game Jam Template. The goal is to:

1. Enable developers to choose Lua 5.4.4 (current) or LuaJIT 2.1 via CMake option `-DUSE_LUAJIT=ON`
2. Maintain **strict compatibility** - a single Lua codebase runs under both backends
3. Preserve web build support (Emscripten cannot use LuaJIT)
4. Provide comprehensive testing to ensure both configurations work correctly

**Key Decision:** Strict compatibility (single Lua codebase) rather than dual-script approach. All `.lua` files must parse under both Lua 5.4.4 and LuaJIT 2.1.

---

## Success Criteria (Defined Up Front)

| Criteria Type | Description | Pass/Fail |
|--------------|-------------|------------|
| **Functional** | Build can be configured with **either** Lua 5.4.4 or LuaJIT | `cmake … -DUSE_LUAJIT=OFF` builds + `cmake … -DUSE_LUAJIT=ON` builds |
| **Functional** | Runtime executes the same core Lua entry scripts under both backends | Game boots and loads scripts in both configs |
| **Observable** | Engine logs which backend is active | Log line contains `Lua backend: Lua 5.4.4` or `Lua backend: LuaJIT 2.1` |
| **Pass/Fail** | Test suite passes under both configs (web build unaffected) | `just test` passes for OFF and ON; `just build-web` still uses standard Lua |

---

## Current State Analysis

### Existing Infrastructure

| Item | Location | Notes |
|-------|-----------|-------|
| **Lua 5.4.4** | `add_git_dependency(lua "https://github.com/marovira/lua" 5.4.4)` | Currently used, works |
| **Sol2 v4.0.0** | `src/third_party/sol2/` | Already integrated with Lua |
| **LuaJIT 2.1 source** | `src/third_party/LuaJIT-2.1/` | Already vendored in repo |
| **LuaJIT CMake wrapper** | `src/third_party/luajit-cmake-master/` | CMake integration layer |
| **USE_LUAJIT option** | `CMakeLists.txt` line ~142 | Already defined, default OFF |
| **Commented LuaJIT code** | `CMakeLists.txt` lines 974-1048 | Previous attempt, had errors |

### Lua Codebase Audit

Based on grep analysis of 100+ `.lua` files:

| Feature | Count | Compatibility Risk |
|---------|--------|-------------------|
| **goto statements** | 48 matches in 19 files | **LOW** - LuaJIT 2.1 supports goto |
| **Bitwise operators (`& \| ~ << >>`)** | Extensive usage | **HIGH** - LuaJIT 2.1 does NOT support these operators |
| **Floor division (`//`)** | Not found in grep | **N/A** - No usage detected |
| **utf8 library** | Not found | **LOW** - Not used |
| **64-bit constants** | TBD (need audit) | **MEDIUM** - LuaJIT has 53-bit integer precision limit |

**Key Finding:** The primary compatibility blocker is **bitwise operators**. LuaJIT 2.1 expects function calls (`bit.band`, `bit.bor`, etc.) instead of operators.

---

## Implementation Plan - Phased Approach

### Phase 0 — Baseline Establishment
**Goal:** Verify current Lua 5.4.4 build is stable and all tests pass.

**Tasks:**
1. **Baseline Build (Lua 5.4.4)**
   ```bash
   just build-debug
   just test
   ```
   - Record build time, test pass/fail status
   - Capture any warnings

2. **Verify Web Build**
   ```bash
   just build-web
   ```
   - Ensure web build still uses Lua 5.4.4 (LuaJIT not supported on Emscripten)

**Checkpoint:** Baseline established. All tests pass with Lua 5.4.4.

---

### Phase 1 — CMake Configuration
**Goal:** Make `-DUSE_LUAJIT=ON` build successfully (native builds only).

#### 1.1 Enforce LuaJIT Forbidden for Web

**File:** `CMakeLists.txt` (around line ~960, before "Sol2 + Lua / LuaJIT toggle")

**Add:**
```cmake
# LuaJIT is NOT supported on Emscripten
if (EMSCRIPTEN)
    if (USE_LUAJIT)
        message(WARNING "USE_LUAJIT=ON is not supported for Emscripten builds. Forcing OFF.")
        set(USE_LUAJIT OFF CACHE BOOL "Use LuaJIT instead of standard Lua" FORCE)
    endif()
endif()
```

#### 1.2 Centralize LuaJIT Path

**File:** `CMakeLists.txt` (before luajit-cmake-master inclusion)

**Add:**
```cmake
# LuaJIT source directory (only used if USE_LUAJIT=ON)
set(LUAJIT_DIR "${CMAKE_SOURCE_DIR}/src/third_party/LuaJIT-2.1" CACHE PATH "Path to LuaJIT source directory")
```

#### 1.3 Refactor Toggle Block

**File:** `CMakeLists.txt` (replace lines 962-1048)

**Replace entire block with:**
```cmake
# ======================================================================
# Sol2 + Lua / LuaJIT Backend Selection
# ======================================================================
if (USE_LUAJIT AND NOT EMSCRIPTEN)
    message(STATUS ">> Using LuaJIT 2.1 as backend for Sol2")

    # Build LuaJIT via cmake wrapper
    add_subdirectory("src/third_party/luajit-cmake-master")

    # Sol2 is already included via add_subdirectory(src/third_party/sol2)

    target_link_libraries(CommonSettings INTERFACE
        luajit::lib
        luajit::header
        sol2::sol2
    )

    target_include_directories(CommonSettings INTERFACE
        ${LUAJIT_DIR}/src
        ${sol2_SOURCE_DIR}/include
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
        ${sol2_SOURCE_DIR}/include
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
```

#### 1.4 Platform-Specific Notes

| Platform | Known Issues | Required Workarounds |
|----------|----------------|---------------------|
| **macOS ARM64** | LuaJIT assembly quirks | luajit-cmake-master may need Clang flags; see `LuaJIT.cmake` |
| **Windows** | May need explicit library naming | Usually handled by luajit-cmake-master |
| **Linux** | Generally straightforward | No known issues |

**Checkpoint:** Both `USE_LUAJIT=OFF` and `USE_LUAJIT=ON` build successfully.

---

### Phase 2 — Add Lua Backend Smoke Test (C++)
**Goal:** Catch LuaJIT-vs-Lua differences early with a dedicated unit test.

**File:** `tests/unit/test_lua_backend.cpp` (NEW)

**Implementation:**
```cpp
#include <gtest/gtest.h>
#include <sol/sol.hpp>

// Helper to create state with libraries opened
sol::state create_lua_state() {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::math,
                     sol::lib::string, sol::lib::table);
    return lua;
}

TEST(LuaBackend, VersionDetection) {
    auto lua = create_lua_state();

    // Check _VERSION exists
    std::string version = lua["_VERSION"];
    ASSERT_FALSE(version.empty());

    std::cout << "Lua version: " << version << std::endl;

    // Detect LuaJIT
    bool isLuaJIT = lua["jit"].valid();
    if (isLuaJIT) {
        std::string jitVersion = lua["jit"]["version"];
        std::cout << "LuaJIT version: " << jitVersion << std::endl;
    } else {
        std::cout << "Standard Lua (not LuaJIT)" << std::endl;
    }
}

TEST(LuaBackend, GotoSupport) {
    auto lua = create_lua_state();

    // LuaJIT 2.1 supports goto
    std::string code = R"(
        local sum = 0
        for i = 1, 10 do
            if i == 5 then goto skip end
            sum = sum + i
            ::skip::
        end
        return sum
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Lua error: " << result.get<sol::error>().what();
    int sum = result;
    EXPECT_EQ(sum, 1 + 2 + 3 + 4 + 6 + 7 + 8 + 9 + 10);  // Sum without 5
}

TEST(LuaBackend, PcallPropagation) {
    auto lua = create_lua_state();

    std::string code = R"(
        local function safeCall(fn)
            local ok, err = pcall(fn)
            if not ok then
                return "ERROR: " .. err
            end
            return "SUCCESS"
        end

        return safeCall(function() error("test error") end)
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid());
    std::string outcome = result;
    EXPECT_TRUE(outcome.find("ERROR") != std::string::npos);
}

TEST(LuaBackend, BasicArithmetic) {
    auto lua = create_lua_state();

    std::string code = R"(
        local a = 10.5
        local b = 20.3
        return a + b, a * b
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid());

    auto values = result.get<std::tuple<float, float>>();
    float sum, product = values;
    EXPECT_NEAR(sum, 30.8f, 0.01f);
    EXPECT_NEAR(product, 213.15f, 0.01f);
}
```

**Add to CMakeLists.txt (in tests section):**
```cmake
add_executable(test_lua_backend
    tests/unit/test_lua_backend.cpp
)
target_link_libraries(test_lua_backend
    PRIVATE CommonSettings
    PRIVATE GTest::gtest
)
add_test(NAME LuaBackend COMMAND test_lua_backend)
```

**Checkpoint:** `just test` passes new LuaBackend tests in both configurations.

---

### Phase 2.5 — 32-Bit Bitwise Usage Audit
**Goal:** Ensure no Lua code uses 64-bit masks that would break under 32-bit canonical semantics.

#### 2.5.1 Static Scan for 64-Bit Constants

**Commands to run:**
```bash
# Find hex literals wider than 32-bit (≥ 0x100000000)
grep -rn "0x[0-9a-fA-F]\{9,\}" assets/scripts/

# Find decimal constants > 4294967295 (0xFFFFFFFF)
grep -rn "[0-9]\{10,\}" assets/scripts/ | grep -v "0x"

# Find suspicious shift counts (≥ 32)
grep -rnE "<< [0-9]+" assets/scripts/ | grep -E "<< [3-9][0-9]|<< [1-9][0-9]{2,}"
grep -rnE ">> [0-9]+" assets/scripts/ | grep -E ">> [3-9][0-9]|>> [1-9][0-9]{2,}"
```

**Action for each match:**
- If mask is clearly 64-bit (≥ 2^32): Investigate whether it needs 64 bits
  - If yes: Document that this code cannot work with LuaJIT 32-bit bitops
  - If no: Downgrade to 32-bit mask or split into hi/lo parts
- If shift count can exceed 31: Add masking `n % 32` to ensure consistency

**Decision Rule (for unknown cases):**
- If unsure whether 64-bit is intentional → **assume 32-bit is sufficient** and test
- If tests reveal 64-bit dependency → either:
  1. Refactor to use `(hi32, lo32)` pairs
  2. Keep code Lua 5.4-only and document limitation

#### 2.5.2 Runtime Guardrails (Optional, Dev/Test Only)

**Add to bitops module (later in Phase 3):**
```lua
-- Optional strict mode for development
local bitops_strict = false  -- Set true in dev builds

local function assert_32bit(val, context)
    if bitops_strict then
        if val < 0 or val >= 2^32 then
            error(string.format("bitops: value out of 32-bit range in %s: %d", context, val))
        end
    end
    return val
end

-- Wrap all operations with assertions
local safe_band = function(a, b)
    return assert_32bit(bit.band(a, b), "band")
end
```

**Checkpoint:** Audit complete. Either (a) zero 64-bit usage found, or (b) identified and documented all 64-bit cases.

---

### Phase 3 — Lua Bitwise Compatibility Layer
**Goal:** Remove all Lua 5.3+ bitwise operators from `.lua` files and replace with 32-bit function calls.

**CRITICAL CONSTRAINT:** The loader module must NOT contain `& | ~ << >> //` tokens, or LuaJIT will fail to parse it even if unused code path.

#### 3.1 Create Compatibility Module Structure

**File:** `assets/scripts/compat/bitops.lua` (NEW)

```lua
-- Bitwise operations compatibility layer
-- Standardizes to 32-bit unsigned operations across Lua 5.4.4 and LuaJIT 2.1
--
-- NEVER uses Lua operators & | ~ << >> // (would break LuaJIT parsing)

local bitops = {}

-- Backend detection (safe for LuaJIT)
local is_luajit = (type(jit) == "table") and (type(jit.version) == "string")

-- Load backend implementation
if is_luajit then
    -- LuaJIT 2.1: use built-in bit library
    local bit = require("bit")

    -- LuaJIT bit.* returns signed 32-bit; normalize to unsigned 0..2^32-1
    local function to_unsigned(x)
        return bit.band(x, 0xFFFFFFFF)
    end

    bitops.band = function(a, b) return to_unsigned(bit.band(a, b)) end
    bitops.bor = function(a, b) return to_unsigned(bit.bor(a, b)) end
    bitops.bxor = function(a, b) return to_unsigned(bit.bxor(a, b)) end
    bitops.bnot = function(x) return to_unsigned(bit.bnot(x)) end

    -- Logical right shift (LuaJIT's >> is arithmetic)
    bitops.rshift = function(a, n)
        n = n % 32  -- Mask shift count
        local x = to_unsigned(a)
        -- Emulate logical shift for unsigned
        return math.floor(x / (2^n)) % 2^32
    end

    bitops.lshift = function(a, n)
        n = n % 32
        return to_unsigned(bit.tobit(bit.lshift(to_unsigned(a), n)))
    end

else
    -- Lua 5.4: use native operators (only loaded by Lua 5.4)
    local function norm(x)
        -- Normalize to unsigned 0..2^32-1
        x = x % 2^32
        if x < 0 then x = x + 2^32 end
        return x
    end

    bitops.band = function(a, b) return norm(norm(a) & norm(b)) end
    bitops.bor = function(a, b) return norm(norm(a) | norm(b)) end
    bitops.bxor = function(a, b) return norm(norm(a) ~ norm(b)) end
    bitops.bnot = function(x) return norm(~norm(x)) end

    -- Logical right shift (>> is arithmetic on signed integers)
    bitops.rshift = function(a, n)
        n = n % 32
        local x = norm(a)
        -- Logical shift: use division for unsigned behavior
        return math.floor(x / (2^n))
    end

    bitops.lshift = function(a, n)
        n = n % 32
        return norm(norm(a) << n)
    end
end

-- 32-bit mask constants (common values)
bitops.MASK_8BIT  = 0x000000FF
bitops.MASK_16BIT = 0x0000FFFF
bitops.MASK_24BIT = 0x00FFFFFF
bitops.MASK_32BIT = 0xFFFFFFFF

-- Helper: extract byte from 32-bit value
function bitops.byte32(value, index)
    -- index: 0=LSB, 3=MSB
    local shift = index * 8
    return bitops.rshift(bitops.band(value, bitops.lshift(0xFF, shift)), shift)
end

-- Helper: pack bytes into 32-bit value
function bitops.pack32(b0, b1, b2, b3)
    return bitops.bor(
        bitops.band(b0, 0xFF),
        bitops.lshift(bitops.band(b1, 0xFF), 8),
        bitops.lshift(bitops.band(b2, 0xFF), 16),
        bitops.lshift(bitops.band(b3, 0xFF), 24)
    )
end

return bitops
```

#### 3.2 Floor Division Compatibility (if `//` found in audit)

**File:** `assets/scripts/compat/math_compat.lua` (NEW, ONLY if needed)

```lua
-- Math compatibility layer for LuaJIT

local math_compat = {}

-- Floor division (LuaJIT 2.1 does not have // operator)
function math_compat.idiv(a, b)
    -- Lua 5.4: a // b
    -- LuaJIT: math.floor(a / b)
    if b == 0 then
        error("Division by zero in idiv")
    end
    return math.floor(a / b)
end

return math_compat
```

**If no `//` found in audit:** Skip this file. Not needed if code doesn't use floor division.

#### 3.3 Replace Bitwise Operators in Lua Files

**Mechanical replacement strategy:**

| Lua 5.4 syntax | Replace with (32-bit canonical) |
|------------------|----------------------------------|
| `a & b` | `bitops.band(a, b)` |
| `a | b` | `bitops.bor(a, b)` |
| `a ~ b` | `bitops.bxor(a, b)` |
| `~a` | `bitops.bnot(a)` |
| `a << n` | `bitops.lshift(a, n)` |
| `a >> n` | `bitops.rshift(a, n)` |

**Important:** Operator precedence changes. Always parenthesize subexpressions:

**Example conversion:**
```lua
-- BEFORE (Lua 5.4 only):
local mask = (value & 0xFF00) >> 8

-- AFTER (compatible):
local bitops = require("compat.bitops")
local mask = bitops.rshift(bitops.band(value, 0xFF00), 8)
```

**Batch replacement workflow:**

1. **Add bitops import to each file using bitwise ops:**
   ```lua
   -- Add at top of file:
   local bitops = require("compat.bitops")
   ```

2. **Replace operators file-by-file:**
   - Use find-replace with careful parentheses
   - Run `just test` after each file to catch errors

3. **Prioritize high-traffic files:**
   - Collision detection scripts
   - UI layer management
   - Physics queries

**Checkpoint:** No `.lua` files (except `bitops_lua54.lua`) contain `& | ~ << >>` tokens.

---

### Phase 4 — End-to-End Testing
**Goal:** Prove real game scripts run under both backends.

#### 4.1 Run Existing Lua Test Suite

```bash
# Test with Lua 5.4.4
cmake -B build -DUSE_LUAJIT=OFF -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
./build/raylib-cpp-cmake-template 2>&1 | grep -E "(PASS|FAIL|error|Error)" | head -50

# Test with LuaJIT
cmake -B build-luajit -DUSE_LUAJIT=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build build-luajit -j
./build-luajit/raylib-cpp-cmake-template 2>&1 | grep -E "(PASS|FAIL|error|Error)" | head -50
```

**Expected:** Same test pass/fail pattern for both builds.

#### 4.2 Bitops Integration Test

**File:** `tests/lua/test_bitops.lua` (NEW)

```lua
-- Bitwise operations compatibility test
-- Must pass under both Lua 5.4.4 and LuaJIT

local bitops = require("compat.bitops")

print("Testing bitops module...")

-- Identity tests
assert(bitops.band(0xF0, 0x0F) == 0x00, "band identity failed")
assert(bitops.bor(0xF0, 0x0F) == 0xFF, "bor identity failed")
assert(bitops.bxor(0xFF00FF00, 0x00FF00FF) == 0xFFFFFFFF, "bxor identity failed")
assert(bitops.bnot(0x00000000) == 0xFFFFFFFF, "bnot identity failed")

-- Mask constants
assert(bitops.MASK_8BIT == 0x000000FF, "MASK_8BIT wrong")
assert(bitops.MASK_16BIT == 0x0000FFFF, "MASK_16BIT wrong")
assert(bitops.MASK_24BIT == 0x00FFFFFF, "MASK_24BIT wrong")
assert(bitops.MASK_32BIT == 0xFFFFFFFF, "MASK_32BIT wrong")

-- Shift tests (logical right shift)
assert(bitops.rshift(0x80000000, 1) == 0x40000000, "rshift MSB failed")
assert(bitops.rshift(0x80000000, 31) == 1, "rshift to bit 0 failed")
assert(bitops.lshift(1, 31) == 0x80000000, "lshift to MSB failed")

-- Shift count masking (should wrap modulo 32)
assert(bitops.lshift(1, 32) == 1, "shift 32 should wrap to 0")
assert(bitops.lshift(1, 64) == 1, "shift 64 should wrap to 0")

-- Unsigned normalization (negative input)
assert(bitops.band(-1, 0xFF) == 0xFF, "negative band failed")

-- Byte packing/unpacking
local packed = bitops.pack32(0xAA, 0xBB, 0xCC, 0xDD)
assert(packed == 0xDDCCBBAA, "pack32 failed")
assert(bitops.byte32(packed, 0) == 0xAA, "byte32[0] failed")
assert(bitops.byte32(packed, 3) == 0xDD, "byte32[3] failed")

print("✓ All bitops tests passed!")
```

**Run test:**
```bash
# Lua 5.4.4
./build/raylib-cpp-cmake-template tests/lua/test_bitops.lua

# LuaJIT
./build-luajit/raylib-cpp-cmake-template tests/lua/test_bitops.lua
```

**Expected:** Identical output, all tests pass.

#### 4.3 Game Launch Smoke Test

```bash
# Lua 5.4.4
AUTO_START_MAIN_GAME=1 AUTO_EXIT_AFTER_TEST=1 ./build/raylib-cpp-cmake-template 2>&1 | grep -i "lua"

# LuaJIT
AUTO_START_MAIN_GAME=1 AUTO_EXIT_AFTER_TEST=1 ./build-luajit/raylib-cpp-cmake-template 2>&1 | grep -i "lua"
```

**Expected:**
- Lua 5.4.4: Log shows `Lua 5.4.4` or no JIT mention
- LuaJIT: Log shows `LuaJIT 2.1` or similar
- Both: Game boots successfully, no parse errors

#### 4.4 Web Build Verification

```bash
just build-web
```

**Expected:** Web build still uses Lua 5.4.4, unaffected by LuaJIT changes.

---

## Test Plan (MANDATORY)

### Objective
Verify the engine runs with either Lua 5.4.4 or LuaJIT 2.1, and the Lua codebase is compatible.

### Prerequisites
- Clean build directories (`build/`, `build-luajit/`)
- Same assets available

### Test Cases

| # | Test | Command | Expected Result |
|---|-------|-----------------|----------------|
| 1 | **Native build (Lua 5.4.4)** | `cmake -B build -DUSE_LUAJIT=ON && cmake --build build -j` | Configures with Lua 5.4.4, builds without errors |
| 2 | **Native build (LuaJIT)** | `cmake -B build-luajit -DUSE_LUAJIT=ON && cmake --build build-luajit -j` | Configures with LuaJIT, builds without errors |
| 3 | **Unit tests (Lua 5.4.4)** | `cd build && just test` | All tests pass |
| 4 | **Unit tests (LuaJIT)** | `cd build-luajit && just test` | All tests pass |
| 5 | **Lua backend smoke test** | `./build/test_lua_backend` | Passes version, goto, pcall, arithmetic tests |
| 6 | **Bitops compatibility test** | `./build/raylib-cpp-cmake-template tests/lua/test_bitops.lua` | All bitops tests pass |
| 7 | **Game launch (Lua 5.4.4)** | `AUTO_START_MAIN_GAME=1 AUTO_EXIT_AFTER_TEST=1 ./build/raylib-cpp-cmake-template` | Boots, loads scripts, no parse errors |
| 8 | **Game launch (LuaJIT)** | `AUTO_START_MAIN_GAME=1 AUTO_EXIT_AFTER_TEST=1 ./build-luajit/raylib-cpp-cmake-template` | Boots, loads scripts, no parse errors, log shows LuaJIT |
| 9 | **Web build** | `just build-web` | Builds, still uses standard Lua |
| 10 | **Lua test runner scripts** | Run existing `assets/scripts/tests/test_runner.lua` | Same results under both backends |

### Success Criteria
ALL test cases pass.

### How to Execute

```bash
# 1. Build both configurations
cmake -B build -DUSE_LUAJIT=OFF -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j

cmake -B build-luajit -DUSE_LUAJIT=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build build-luajit -j

# 2. Run unit tests
cd build && just test
cd ../build-luajit && just test

# 3. Run Lua backend test
./build/test_lua_backend
./build-luajit/test_lua_backend

# 4. Run bitops test
./build/raylib-cpp-cmake-template tests/lua/test_bitops.lua
./build-luajit/raylib-cpp-cmake-template tests/lua/test_bitops.lua

# 5. Smoke test game launch
(AUTO_START_MAIN_GAME=1 AUTO_EXIT_AFTER_TEST=1 ./build/raylib-cpp-cmake-template 2>&1 &)
(AUTO_START_MAIN_GAME=1 AUTO_EXIT_AFTER_TEST=1 ./build-luajit/raylib-cpp-cmake-template 2>&1 &)

# 6. Verify web build
just build-web
```

---

## Rollback Plan

**If LuaJIT causes problems:**

1. **Quick Revert:** Set `USE_LUAJIT=OFF` (default)
   ```bash
   cmake -DUSE_LUAJIT=OFF ...
   ```
   - This restores Lua 5.4.4 behavior immediately
   - No code changes needed

2. **Disable LuaJIT CI Job:**
   - Comment out or mark LuaJIT job as non-blocking in CI configuration
   - Lua 5.4.4 job remains functional

3. **Revert Lua Code Changes:**
   - If bitwise operator changes cause issues, revert `.lua` files to pre-rewrite state
   - Keep `USE_LUAJIT=OFF` to avoid LuaJIT-specific issues

**Why Rollback is Safe:**
- Lua 5.4.4 path is completely unchanged
- LuaJIT changes are additive only
- No breaking changes to existing Lua code

---

## CI/CD Integration (Optional but Recommended)

### GitHub Actions / GitLab CI Example

```yaml
jobs:
  # Job A: Standard Lua (default, always run)
  test-lua54:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Lua 5.4.4
        run: |
          cmake -B build -DUSE_LUAJIT=OFF -DCMAKE_BUILD_TYPE=Debug
          cmake --build build -j
      - name: Test
        run: cd build && just test

  # Job B: LuaJIT (native only)
  test-luajit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build LuaJIT
        run: |
          cmake -B build -DUSE_LUAJIT=ON -DCMAKE_BUILD_TYPE=Debug
          cmake --build build -j
      - name: Test
        run: cd build && just test

  # Job C: Web build (always uses Lua 5.4.4)
  build-web:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Web
        run: just build-web
```

**Key Points:**
- LuaJIT job is **non-blocking** initially (optional in CI config)
- Web build never uses LuaJIT
- Lua 5.4.4 job ensures baseline stability

---

## Decision Log (Key Decisions Made)

| Decision | Rationale |
|----------|-----------|
| **Strict compatibility (single codebase)** | Simpler maintenance, no script duplication, less risk of drift |
| **32-bit canonical bitwise ops** | Aligns with LuaJIT `bit.*` behavior, predictable semantics |
| **Logical right shift** | Consistent with unsigned 32-bit expectations (unlike Lua 5.4's arithmetic `>>`) |
| **Phase 2.5 audit before Phase 3 rewrite** | Avoids wasted effort if 64-bit usage requires different approach |
| **Keep USE_LUAJIT default OFF** | Existing users unaffected, opt-in for LuaJIT |
| **Ban LuaJIT on Emscripten** | LuaJIT doesn't compile for Emscripten, forced fallback to Lua 5.4.4 |

---

## Appendix: Common Issues & Solutions

### Issue: "too many local variables (limit is 200)"
**Cause:** LuaJIT has 200 local variable limit per function scope. File-scope `local` declarations accumulate.
**Solution:** Group related locals into tables (already documented in `docs/skills/check-luajit-limits.md`)

### Issue: "syntax error near '&'" on LuaJIT build
**Cause:** LuaJIT 2.1 doesn't support `& | ~ << >>` operators
**Solution:** Replace with `bitops.band/bor/bxor/bnot/lshift/rshift` (Phase 3)

### Issue: Platform-specific LuaJIT build failure (macOS ARM64, etc.)
**Cause:** LuaJIT assembly quirks, Clang compatibility
**Solution:** Check `src/third_party/luajit-cmake-master/LuaJIT.cmake` for platform flags; may need toolchain adjustments

### Issue: Web build tries to use LuaJIT
**Cause:** `USE_LUAJIT=ON` not guarded against `EMSCRIPTEN`
**Solution:** Phase 1.1 enforces LuaJIT=OFF for Emscripten with warning message

### Issue: Bitwise test passes on Lua 5.4 but fails on LuaJIT
**Cause:** Subtle semantic difference (arithmetic vs logical shift, signed vs unsigned)
**Solution:** Ensure bitops.lua normalizes to unsigned 32-bit in both backends

---

## Implementation Checklist

### Phase 0: Baseline
- [ ] Verify `just build-debug` works with Lua 5.4.4
- [ ] Verify `just test` passes
- [ ] Verify `just build-web` works

### Phase 1: CMake Configuration
- [ ] Add Emscripten guard (LuaJIT forbidden for web)
- [ ] Set `LUAJIT_DIR` before including luajit-cmake-master
- [ ] Refactor toggle block with proper Sol2/LuaJIT linking
- [ ] Test `cmake -DUSE_LUAJIT=OFF && cmake --build build -j`
- [ ] Test `cmake -DUSE_LUAJIT=ON && cmake --build build-luajit -j`

### Phase 2: C++ Smoke Test
- [ ] Create `tests/unit/test_lua_backend.cpp`
- [ ] Implement version detection, goto, pcall, arithmetic tests
- [ ] Add test to CMakeLists.txt
- [ ] Run tests in both configurations

### Phase 2.5: 32-Bit Audit
- [ ] Run grep for 64-bit hex constants
- [ ] Run grep for large decimal constants
- [ ] Run grep for large shift counts
- [ ] Document findings or refactor to 32-bit

### Phase 3: Lua Bitwise Compatibility
- [ ] Create `assets/scripts/compat/bitops.lua`
- [ ] Create `assets/scripts/compat/bitops_lua54.lua` (operators allowed)
- [ ] Add `require("compat.bitops")` to files using bitwise ops
- [ ] Replace `&` with `bitops.band()`
- [ ] Replace `|` with `bitops.bor()`
- [ ] Replace `~` (binary) with `bitops.bxor()`
- [ ] Replace `~` (unary) with `bitops.bnot()`
- [ ] Replace `<<` with `bitops.lshift()`
- [ ] Replace `>>` with `bitops.rshift()`
- [ ] Run `just test` after each file change

### Phase 4: E2E Testing
- [ ] Run existing Lua test suite (Lua 5.4.4)
- [ ] Run existing Lua test suite (LuaJIT)
- [ ] Run bitops compatibility test (both)
- [ ] Run game launch smoke test (both)
- [ ] Verify web build still works

### Documentation
- [ ] Update `CLAUDE.md` with LuaJIT backend notes
- [ ] Document `USE_LUAJIT` CMake option in README
- [ ] Add LuaJIT troubleshooting section

### CI/CD
- [ ] Add Lua 5.4.4 CI job
- [ ] Add LuaJIT CI job (optional, non-blocking)
- [ ] Ensure web job ignores LuaJIT

---

## References

- **LuaJIT Extensions Documentation:** https://luajit.org/extensions.html
- **Lua Version Compatibility:** https://www.lua.org/manual/5.4/manual.html#8
- **Sol2 LuaJIT Integration:** https://sol2.readthedocs.io/en/latest/tutorial/lua-jit.html
- **Game Jam Template Context:** See `CLAUDE.md` for existing Lua patterns

---

**Last Updated:** 2026-01-18

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
