# Lockstep Networking Implementation Plan

## Executive Summary

This document outlines a phased approach to adding lockstep networking support to the C++20 + Lua game engine. The plan prioritizes **determinism first**, ensuring single-player games are bit-reproducible before any networking code is introduced.

**Key Principles:**
- **Non-breaking**: All changes are opt-in via a `LockstepConfig` toggle
- **Determinism-first**: Phases 0-3 focus purely on making simulation reproducible
- **Lua-aware**: Game logic is primarily Lua, so Lua RNG/timing must be determinized
- **Future-proof**: Design for multiplayer without requiring network code immediately

---

## Determinism Contract (New)

Define the deterministic envelope before coding. Suggested tiers:
- Tier A: Same build + same machine/arch (fastest to achieve)
- Tier B: Same OS/arch across machines (requires deterministic RNG distribution + time handling)
- Tier C: Cross-OS/arch (requires strict FP settings or fixed-point)

This plan targets Tier B by default; tighten or relax as needed.

Authoritative state is simulation-only (ECS/physics/AI/combat, timers, RNG, IDs). Rendering, audio, profiling, and editor/debug UI may use real time but must not feed back into simulation.

---

## Current Architecture Summary

### Engine Stack
- **C++20** + **Lua scripting** (Sol2 bindings)
- **Raylib 5.5** (rendering/input)
- **EnTT** (ECS)
- **Chipmunk2D** (physics)
- **effolkronium::random_static** for RNG

### Main Loop (`src/main.cpp`, `src/systems/main_loop_enhancement/`)
```
Fixed timestep: rate = 1.0f / 60.0f (16.67ms per tick)
Accumulator pattern with lag tracking
Physics: 2 substeps per tick via PhysicsManager::stepAll()
Frame tracking: mainLoop.frame (logic ticks), mainLoop.renderFrame
```

### Non-Determinism Sources Identified

| Source | Location | Severity | Phase to Fix |
|--------|----------|----------|--------------|
| RNG uses std::uniform_* distribution (non-portable) | `random.hpp` / effolkronium | **Critical** | Phase 1 |
| Lua `math.random()` + `math.randomseed(os.time())` | `assets/scripts/*` | **Critical** | Phase 1 |
| `rand()` / `std::rand()` usage | `screen_shake.hpp`, `physics/steering.cpp` | **High** | Phase 1 |
| Real-time clocks (`GetTime`, `GetFrameTime`, `os.clock`, `os.time`) in gameplay | Lua + `scripting_functions.cpp` | **High** | Phase 1 |
| Timer system iterates `std::unordered_map` | `timer.hpp` | **High** | Phase 1 |
| Lua table iteration order (`pairs`) | scripts (various) | Medium | Phase 1 |
| Unordered container iteration outside EnTT views | timers, signals, caches | Medium | Phase 1 |
| Physics FP variance + compiler FP flags | Chipmunk2D + build flags | Medium | Phase 0 |
| Input polling bypasses provider | `input_polling.cpp` | Medium | Phase 2 |
| Input values not quantized | `input_polling.hpp` | Medium | Phase 2 |
| No input serialization | N/A | **High** | Phase 2 |

---

## Phase 0: Foundation — Determinism Audit & Preparation

**Goal:** Establish infrastructure for measuring and testing determinism without changing game behavior.

**Estimated Complexity:** Low-Medium  
**Duration:** 1-2 days

### 0.0 Define Determinism Contract & Build Settings (New)

Decide and document:
- Target determinism tier (same machine vs cross-platform).
- Authoritative state list (what is hashed/serialized).
- Fixed tick rate and time scale rules.

Lock build settings:
- Disable fast-math / unsafe math optimizations.
- Disable FP contraction (FMA) where possible.
- Set rounding mode to FE_TONEAREST at startup.

Record a build/config hash in lockstep headers/replays to detect mismatches.

**Implementation Notes:**
- Clang/GCC: `-fno-fast-math -ffp-contract=off -fno-unsafe-math-optimizations`
- MSVC: `/fp:precise` or `/fp:strict`
- Tier C may require fixed-point or a deterministic math library.

### 0.1 Create Lockstep Configuration System

**New File:** `src/systems/lockstep/lockstep_config.hpp`

```cpp
#pragma once
#include <cstdint>

namespace lockstep {

struct LockstepConfig {
    bool enabled = false;                    // Master toggle (set at startup)
    bool deterministic_rng = false;          // Use deterministic RNG
    bool deterministic_timers = false;       // Use tick-based timing
    bool deterministic_time = false;         // Override GetTime/GetFrameTime/os.clock
    bool deterministic_ids = false;          // Deterministic tag/ID generation
    bool input_recording = false;            // Record inputs for replay
    bool checksum_validation = false;        // Generate state checksums
    bool rollback_enabled = false;           // Enable state snapshots/rollback
    uint32_t base_seed = 0;                  // Session seed
    uint32_t tick_rate = 60;                 // Fixed ticks per second
    uint32_t checksum_interval = 60;         // Ticks between checksums
};

extern LockstepConfig g_lockstepConfig;

void initLockstep(const LockstepConfig& config);
bool isLockstepEnabled();

} // namespace lockstep
```

**Files to Modify:**
- `src/core/globals.hpp` — Add `lockstep::LockstepConfig` reference
- `src/main.cpp` — Initialize lockstep config at startup

### 0.2 Deterministic Time + ID Helpers (New)

**New File:** `src/systems/lockstep/deterministic_time.hpp`

```cpp
#pragma once
#include <cstdint>

namespace lockstep {
uint64_t getTick();
double getSimTimeSeconds();   // tick / tick_rate
double getFrameDtSeconds();   // fixed dt
} // namespace lockstep
```

**New File:** `src/systems/lockstep/deterministic_ids.hpp`

```cpp
#pragma once
#include <cstdint>

namespace lockstep {
uint64_t nextId();
void resetIds(uint64_t seed);
} // namespace lockstep
```

**Implementation Notes:**
- Route Lua `GetTime`/`GetFrameTime` to deterministic time when lockstep is enabled.
- Expose `GetRealTime()` (or `lockstep.get_real_time()`) for UI/debug paths.
- Replace `os.time`/`os.clock` tag generation with `nextId()` in lockstep.

### 0.3 Create State Checksum System

**New File:** `src/systems/lockstep/state_checksum.hpp`

```cpp
#pragma once
#include <cstdint>
#include "entt/entt.hpp"

namespace lockstep {

struct ChecksumResult {
    uint64_t frame;
    uint32_t physics_hash;      // Chipmunk body positions/velocities
    uint32_t transform_hash;    // Transform component positions
    uint32_t rng_state_hash;    // Current RNG internal state
    uint32_t combined_hash;     // XOR of all above
};

// Compute deterministic hash of game state
ChecksumResult computeStateChecksum(
    entt::registry& registry,
    uint64_t frame,
    class PhysicsManager* physics
);

// For comparing two clients' states
bool checksumsMatch(const ChecksumResult& a, const ChecksumResult& b);

} // namespace lockstep
```

**Implementation Notes:**
- Hash physics bodies by iterating in deterministic order (sorted by entity ID)
- Use XXHash or CRC32 for speed
- Only hash simulation-relevant state (not rendering)
- Include RNG, timer counters, and deterministic ID state in the checksum
- Quantize floats (or hash bitwise with NaN normalization) to avoid false mismatches

### 0.4 Create Determinism Audit Tool

**New File:** `src/systems/lockstep/determinism_audit.hpp`

```cpp
#pragma once
#include <vector>
#include <string>

namespace lockstep {

struct AuditReport {
    std::vector<std::string> rng_calls;           // Where RNG was called
    std::vector<std::string> time_accesses;       // Real-time accesses
    std::vector<std::string> rand_calls;          // std::rand()/rand() usage
    std::vector<std::string> unordered_iterations; // Potential issues
    std::vector<std::string> lua_table_iterations; // pairs() over tables in sim
};

// Run audit for N frames, report non-deterministic calls
AuditReport runDeterminismAudit(int frames);

} // namespace lockstep
```

**Implementation Notes:**
- Combine runtime hooks with static scans for `os.time`, `os.clock`, `rand()`, and `pairs()` usage.
- Allow auditing to be enabled without affecting release builds.

### 0.5 Lua Audit Bindings

**Modify:** `src/systems/scripting/scripting_functions.cpp`

Add audit hooks to track Lua RNG and timing calls:
```cpp
// Wrap random_utils functions to log calls in audit mode
if (lockstep::g_lockstepConfig.checksum_validation) {
    lockstep::logRngCall(__FILE__, __LINE__);
}
```
Also hook `math.randomseed`, `os.clock`, and `os.time` to log or warn when used in lockstep mode.

### Success Criteria (Phase 0)
- [ ] Determinism tier + authoritative state list are documented
- [ ] `LockstepConfig` is set at startup (mid-run toggling is unsupported)
- [ ] State checksums are computed each frame when enabled
- [ ] Audit tool identifies non-deterministic code paths
- [ ] Deterministic time/ID helpers are available in lockstep mode
- [ ] No gameplay changes when lockstep is disabled

### Testing Strategy
1. Run game normally → verify checksums are NOT computed (no overhead)
2. Enable lockstep → verify checksums ARE computed
3. Run same seed twice → checksums should match (if already deterministic)
4. Run audit → identify remaining non-determinism sources (rng/time/rand/pairs)
5. Verify build/config hash is recorded in logs or replay headers

---

## Phase 1: Deterministic Simulation

**Goal:** Make game simulation 100% reproducible given same inputs and seed.

**Estimated Complexity:** High  
**Duration:** 3-5 days

### 1.1 Deterministic RNG System

**New File:** `src/systems/lockstep/deterministic_rng.hpp`

```cpp
#pragma once
#include <cstdint>

namespace lockstep {

class DeterministicRNG {
public:
    // Initialize once per session
    void seed(uint64_t baseSeed);

    // Core generator (PCG/xoshiro recommended)
    uint32_t nextU32();

    // Custom distributions (avoid std::uniform_* differences)
    uint32_t uniform(uint32_t min, uint32_t max);
    float uniformFloat01();
    bool randomBool(float chance);

    // Get current internal state for checksumming
    uint64_t getStateHash() const;

private:
    uint64_t state_ = 0;
    uint64_t inc_ = 0;
};

extern DeterministicRNG g_deterministicRng;

} // namespace lockstep
```

**Modify:** `src/systems/random/random.hpp`

```cpp
namespace random_utils {

inline void set_seed(unsigned int seed) {
    if (lockstep::isLockstepEnabled()) {
        lockstep::g_deterministicRng.seed(seed);
    } else {
        RandomEngine::seed(seed);
    }
}

inline int random_int(int min, int max) {
    if (lockstep::isLockstepEnabled()) {
        return static_cast<int>(lockstep::g_deterministicRng.uniform(min, max));
    }
    return RandomEngine::get(min, max);
}

// ... same pattern for all random functions
}
```

**Implementation Notes:**
- Avoid `std::uniform_*` distributions in lockstep mode (libstdc++/libc++ differences).
- Consider named RNG streams (combat/loot/ai/ui) to reduce call-order coupling.
- Route `random_uid` and any `rand()` usage through the deterministic RNG/ID system.

**Modify:** `src/main.cpp` — Seed RNG once per session

```cpp
// In initLockstep():
if (lockstep::isLockstepEnabled()) {
    lockstep::g_deterministicRng.seed(g_lockstepConfig.base_seed);
}
```

### 1.2 Deterministic Lua Random

**Critical:** Many RNG calls in Lua scripts use `math.random()`

**Modify:** `src/systems/scripting/scripting_functions.cpp`

```cpp
// Override Lua's math.random in lockstep mode
void exposeLockstepRng(sol::state& lua) {
    if (lockstep::isLockstepEnabled()) {
        lua["math"]["random"] = [](sol::variadic_args va) -> double {
            if (va.size() == 0) {
                return lockstep::g_deterministicRng.uniformFloat01();
            } else if (va.size() == 1) {
                int max = va[0].as<int>();
                return lockstep::g_deterministicRng.uniform(1, max);
            } else {
                int min = va[0].as<int>();
                int max = va[1].as<int>();
                return lockstep::g_deterministicRng.uniform(min, max);
            }
        };
        lua["math"]["randomseed"] = [](int) {
            // No-op or log in lockstep to prevent mid-run reseeding
        };
    }
}
```

**Priority Script Files to Audit:**
1. `assets/scripts/combat/*.lua` — Combat must be deterministic
2. `assets/scripts/core/*.lua` — Core game logic
3. `assets/scripts/ai/*.lua` — AI decisions

### 1.3 Deterministic Time Sources (New)

**Modify:** `src/systems/scripting/scripting_functions.cpp`, `src/main.cpp`

- When lockstep is enabled, `GetTime` returns `lockstep::getSimTimeSeconds()` and `GetFrameTime` returns `lockstep::getFrameDtSeconds()` (fixed dt).
- Override Lua `os.clock`/`os.time` to return deterministic sim time or warn in lockstep.
- Provide `GetRealTime()` (or `lockstep.get_real_time()`) for UI/debug paths that must use wall time.

### 1.4 Deterministic Timer System

**Modify:** `src/systems/timer/timer.hpp`

Add tick-based timing option:

```cpp
namespace timer {

struct Timer {
    // ... existing fields ...
    
    // NEW: Tick-based timing for lockstep
    uint64_t tickTimer = 0;    // Ticks elapsed (instead of float seconds)
    uint64_t tickDelay = 0;    // Delay in ticks
    bool useTicks = false;     // If true, use tick-based timing
};

namespace TimerSystem {
    // NEW: Update using tick count instead of dt
    void update_timers_tick_based(uint64_t currentTick);
}

}
```

**Modify:** `src/main.cpp`

```cpp
// In fixed update loop:
if (lockstep::isLockstepEnabled()) {
    timer::TimerSystem::update_timers_tick_based(mainLoop.frame);
} else {
    timer::TimerSystem::update_timers(scaledStep);
}
```

**Implementation Notes:**
- `TimerSystem::timers` currently iterates `std::unordered_map`; switch to a stable update order (insertion-order vector or sorted keys).
- Route random delay resolution to the deterministic RNG.
- Reset timer UID counters on lockstep init; avoid tags derived from `os.time`/`os.clock`.

### 1.5 Deterministic Physics

**Modify:** `src/systems/physics/physics_world.cpp`

Chipmunk2D is generally deterministic, but ensure:
```cpp
void PhysicsWorld::Update(float deltaTime) {
    // Always use fixed dt in lockstep mode
    float dt = lockstep::isLockstepEnabled() 
        ? (1.0f / 60.0f / 2.0f)  // Fixed substep
        : deltaTime;
    
    cpSpaceStep(space, dt);
}
```

**Implementation Notes:**
- Replace `rand()` usage in physics and screen shake paths with deterministic RNG (or move to render-only).
- Keep body/constraint insertion and removal order deterministic.

### 1.6 Deterministic Entity Iteration

**Modify:** `src/core/game.cpp` and other systems

When iterating ECS views, sort by entity ID for determinism:

```cpp
// Instead of:
auto view = registry.view<ComponentA, ComponentB>();
for (auto entity : view) { ... }

// Use:
auto view = registry.view<ComponentA, ComponentB>();
std::vector<entt::entity> sorted(view.begin(), view.end());
std::sort(sorted.begin(), sorted.end());
for (auto entity : sorted) { ... }
```

**New Helper:** `src/util/deterministic_iteration.hpp`

```cpp
template<typename... Components>
auto sortedView(entt::registry& reg) {
    auto view = reg.view<Components...>();
    std::vector<entt::entity> sorted(view.begin(), view.end());
    std::sort(sorted.begin(), sorted.end());
    return sorted;
}
```

**Implementation Notes:**
- Prefer `registry.sort<Component>(...)` + `view.use<Component>()` for stable ordering without per-frame sorts.
- Avoid iterating Lua tables with `pairs` in simulation code; use arrays or sort keys.

### 1.7 Deterministic IDs and Tags (New)

**Modify:** Lua scripts that build tags/IDs from `os.time`, `os.clock`, or `math.random`

- Provide `lockstep.next_id()` in Lua for stable tag/ID generation.
- Replace time-based tags in simulation-critical systems (timers, signal groups, tweens, combat state).
- Example files: `assets/scripts/core/timer_chain.lua`, `assets/scripts/core/signal_group.lua`, `assets/scripts/core/tween.lua`

### Success Criteria (Phase 1)
- [ ] Same seed + same inputs = identical frame checksums
- [ ] Lua `math.random()` uses deterministic RNG; `math.randomseed` is blocked/logged
- [ ] `GetTime`/`GetFrameTime`/`os.clock` return deterministic sim time in lockstep
- [ ] Timer system works in tick-based mode with stable update order
- [ ] No `rand()` usage in simulation paths
- [ ] Time-based IDs/tags replaced with deterministic IDs in simulation
- [ ] Physics produces identical results across runs
- [ ] Entity iteration order is deterministic

### Testing Strategy
1. **Replay Test:** Record inputs, play back twice, compare checksums
2. **Cross-Platform Test:** Same seed on different machines → same checksums
3. **Lua Audit:** Run game with RNG/time logging, verify all calls go through deterministic system
4. **Static Scan:** Flag `os.time`, `os.clock`, `math.randomseed`, `rand()`, `pairs()` in sim-critical paths

---

## Phase 2: Input Abstraction

**Goal:** Decouple input from direct Raylib calls, enable serialization.

**Estimated Complexity:** Medium  
**Duration:** 2-3 days

### 2.1 Input Snapshot Structure

**New File:** `src/systems/lockstep/input_snapshot.hpp`

```cpp
#pragma once
#include <cstdint>
#include <vector>
#include <bitset>
#include "raylib.h"

namespace lockstep {

// Compact input representation for one player, one frame
struct InputSnapshot {
    uint64_t frame = 0;
    uint8_t playerId = 0;
    
    // Keyboard (match input_polling key range)
    static constexpr size_t kKeyCount = KEY_KP_EQUAL + 1;
    std::bitset<kKeyCount> keysDown;
    std::bitset<kKeyCount> keysPressed;   // optional, can be derived
    std::bitset<kKeyCount> keysReleased;
    
    // Mouse (quantized to avoid float drift)
    int16_t mouseX = 0;
    int16_t mouseY = 0;
    int16_t mouseDeltaX = 0;
    int16_t mouseDeltaY = 0;
    int16_t mouseWheel = 0;   // scaled (e.g. wheel * 120)
    uint8_t mouseButtonsDown = 0;     // Bitfield: LMB=1, RMB=2, MMB=4
    uint8_t mouseButtonsPressed = 0;  // Optional edge data
    
    // Gamepad (quantized to int16)
    uint16_t gamepadButtons = 0;
    int16_t leftStickX = 0, leftStickY = 0;
    int16_t rightStickX = 0, rightStickY = 0;
    int16_t leftTrigger = 0, rightTrigger = 0;

    // Text input (optional)
    uint16_t charPressed = 0;  // 0 if none
    
    // Serialization
    std::vector<uint8_t> serialize() const;
    static InputSnapshot deserialize(const uint8_t* data, size_t len);
    
    // Checksum for validation
    uint32_t computeHash() const;
};

// Collection of inputs from all players for one frame
struct FrameInputs {
    uint64_t frame = 0;
    std::vector<InputSnapshot> players;
};

} // namespace lockstep
```

**Implementation Notes:**
- Quantize analog inputs to fixed-point (e.g., scale [-1,1] to int16).
- Ensure `input_polling.cpp` stops calling Raylib directly (use provider for ctrl/cmd and mouse position).
- Store previous snapshot in the provider to derive pressed/released edges deterministically.
- Optionally define a compact key map if you do not want to store all `KEY_KP_EQUAL` keys.
- Treat text input as UI-only or record it explicitly (keyboard layouts vary across machines).
- Decide on raw vs scaled mouse coordinates and keep it consistent for capture/playback.
- Serialize in a fixed endianness and version the input schema.

### 2.2 Input Provider Abstraction

**Modify:** `src/systems/input/input_polling.hpp`

The existing `IInputProvider` interface is sufficient. Implement a lockstep-aware provider:

```cpp
namespace input::polling {

// NEW: Lockstep-aware input provider
class LockstepInputProvider : public IInputProvider {
public:
    // Update current/previous snapshots (for replay/network)
    void advanceFrame(const lockstep::InputSnapshot& snapshot);
    
    // Override all methods to read from snapshot
    bool is_key_down(int key) const override;
    bool is_key_released(int key) const override;
    int get_char_pressed() const override;
    bool is_mouse_button_down(int button) const override;
    bool is_mouse_button_pressed(int button) const override;
    Vector2 get_mouse_delta() const override;
    float get_mouse_wheel_move() const override;
    // ... etc
    
private:
    lockstep::InputSnapshot currentSnapshot_;
    lockstep::InputSnapshot previousSnapshot_;
};

// Capture current Raylib state into a snapshot
lockstep::InputSnapshot captureCurrentInput(uint64_t frame, uint8_t playerId);

} // namespace input::polling
```

### 2.3 Input Buffer

**New File:** `src/systems/lockstep/input_buffer.hpp`

```cpp
#pragma once
#include "input_snapshot.hpp"
#include <map>

namespace lockstep {

// Buffers inputs for input delay / rollback
class InputBuffer {
public:
    // Add local input
    void addLocalInput(const InputSnapshot& input);
    
    // Add remote input (from network)
    void addRemoteInput(const InputSnapshot& input);
    
    // Get inputs for a specific frame (returns nullopt if not ready)
    std::optional<FrameInputs> getInputsForFrame(uint64_t frame);
    
    // Check if we have all inputs needed for frame
    bool isFrameReady(uint64_t frame) const;
    
    // Input delay (frames) for local smoothing
    void setInputDelay(int frames);
    
    // Cleanup old frames
    void pruneOldFrames(uint64_t olderThan);

private:
    std::map<uint64_t, FrameInputs> buffer_;
    int inputDelay_ = 3;  // Default 3 frame delay (~50ms at 60fps)
    int playerCount_ = 1;
};

} // namespace lockstep
```

**Implementation Notes:**
- Keep the buffer ordered by frame (map or ring buffer with sorted indices).
- Quantize inputs before buffering to avoid cross-platform drift.

### 2.4 Integrate with Main Loop

**Modify:** `src/main.cpp`

```cpp
// At start of fixed update:
if (lockstep::isLockstepEnabled()) {
    // Capture local input
    auto localInput = input::polling::captureCurrentInput(
        mainLoop.frame, 
        0 // playerId
    );
    g_inputBuffer.addLocalInput(localInput);
    
    // Get this frame's inputs (may include delay)
    auto frameInputs = g_inputBuffer.getInputsForFrame(mainLoop.frame);
    if (!frameInputs) {
        // Wait for inputs (network sync point)
        return; // Skip this tick
    }
    
    // Apply inputs via LockstepInputProvider
    g_lockstepInputProvider.advanceFrame(frameInputs->players[0]);
}
```

Also set the input provider to `LockstepInputProvider` when lockstep is enabled.

### Success Criteria (Phase 2)
- [ ] `InputSnapshot` can serialize/deserialize round-trip
- [ ] Game plays identically using `LockstepInputProvider` vs direct Raylib
- [ ] Input delay works correctly (3-frame default)
- [ ] Input checksums match between capture and replay
- [ ] No direct Raylib input calls in lockstep path

### Testing Strategy
1. Capture inputs for 60 seconds of gameplay
2. Replay using `LockstepInputProvider`
3. Verify frame checksums match
4. Verify quantized inputs replay identically across machines

---

## Phase 3: Replay System

**Goal:** Record and playback games for determinism testing.

**Estimated Complexity:** Medium  
**Duration:** 2-3 days

### 3.1 Recording System

**New File:** `src/systems/lockstep/replay_recorder.hpp`

```cpp
#pragma once
#include "input_snapshot.hpp"
#include <vector>
#include <string>
#include <fstream>

namespace lockstep {

struct ReplayHeader {
    char magic[4] = {'R', 'P', 'L', 'Y'};
    uint32_t version = 2;
    uint32_t baseSeed = 0;
    uint32_t tickRate = 60;
    uint64_t frameCount = 0;
    uint8_t playerCount = 1;
    uint32_t configHash = 0;        // LockstepConfig hash
    uint32_t buildHash = 0;         // Build/compiler hash
    uint64_t contentHash = 0;       // Scripts/assets hash
    uint32_t inputSchemaVersion = 1;
};

struct ReplayFrame {
    uint64_t frame;
    FrameInputs inputs;
    uint32_t checksum;  // For validation
};

class ReplayRecorder {
public:
    void startRecording(uint32_t seed, const std::string& filename);
    void recordFrame(uint64_t frame, const FrameInputs& inputs, uint32_t checksum);
    void stopRecording();
    
    bool isRecording() const { return recording_; }
    
private:
    std::ofstream file_;
    bool recording_ = false;
    ReplayHeader header_;
};

} // namespace lockstep
```

### 3.2 Playback System

**New File:** `src/systems/lockstep/replay_player.hpp`

```cpp
#pragma once
#include "input_snapshot.hpp"
#include "replay_recorder.hpp"
#include <fstream>

namespace lockstep {

enum class ReplayResult {
    InProgress,
    Completed,
    Desync,  // Checksum mismatch
    Error
};

class ReplayPlayer {
public:
    bool loadReplay(const std::string& filename);
    
    // Get inputs for next frame
    std::optional<FrameInputs> getNextFrameInputs();
    
    // Verify checksum matches
    ReplayResult validateFrame(uint64_t frame, uint32_t actualChecksum);
    
    // Playback position
    uint64_t getCurrentFrame() const;
    uint64_t getTotalFrames() const;
    
    const ReplayHeader& getHeader() const { return header_; }
    
private:
    std::ifstream file_;
    ReplayHeader header_;
    uint64_t currentFrame_ = 0;
    std::vector<ReplayFrame> frames_;
};

} // namespace lockstep
```

**Implementation Notes:**
- Validate header hashes before playback.
- Stream frames from disk to avoid loading large replays into memory.

### 3.3 Lua Bindings

**Modify:** `src/systems/scripting/scripting_functions.cpp`

```lua
-- Start recording
lockstep.start_recording("my_replay.rpl")

-- Stop recording
lockstep.stop_recording()

-- Load and play replay
lockstep.play_replay("my_replay.rpl")

-- Check replay status
if lockstep.replay_status() == "desync" then
    print("Desync at frame " .. lockstep.replay_desync_frame())
end
```

### Success Criteria (Phase 3)
- [ ] Record 5 minutes of gameplay to file
- [ ] Playback produces identical checksums
- [ ] Desync detection identifies divergence frame
- [ ] Replay files are portable (same result on different machines)
- [ ] Replay header validates build/config/content hash before playback

### Testing Strategy
1. Record gameplay session A
2. Play back on same machine → verify match
3. Transfer replay file to different machine → verify match
4. Intentionally corrupt one RNG call → verify desync detection
5. Change build/config hash → verify replay rejects or warns

---

## Phase 4: Lockstep Core

**Goal:** Implement synchronization primitives for multiplayer (without network code).

**Estimated Complexity:** High  
**Duration:** 3-5 days

### 4.1 Lockstep Simulation Controller

**New File:** `src/systems/lockstep/lockstep_controller.hpp`

```cpp
#pragma once
#include "input_buffer.hpp"
#include "state_checksum.hpp"
#include <functional>

namespace lockstep {

enum class SyncState {
    WaitingForInputs,    // Blocked, waiting for remote inputs
    Running,             // Normal execution
    Rollback,            // Rolling back to earlier state
    Desynced             // Fatal desync detected
};

struct LockstepCallbacks {
    std::function<void(uint64_t frame)> onWaitForInputs;
    std::function<void(uint64_t frame, uint32_t local, uint32_t remote)> onDesync;
    std::function<std::vector<uint8_t>()> serializeState;
    std::function<void(const std::vector<uint8_t>&)> deserializeState;
};

class LockstepController {
public:
    void initialize(const LockstepConfig& config, const LockstepCallbacks& callbacks);
    
    // Called each frame before simulation
    // Returns false if we should skip this frame (waiting for inputs)
    bool beginFrame(uint64_t frame);
    
    // Called after simulation
    void endFrame(uint64_t frame);
    
    // Add input (local or remote)
    void addInput(const InputSnapshot& input);
    
    // Check sync state
    SyncState getSyncState() const;
    
    // For debugging
    int getInputLag() const;
    int getBufferedFrames() const;

private:
    InputBuffer inputBuffer_;
    std::vector<ChecksumResult> checksumHistory_;
    LockstepCallbacks callbacks_;
    SyncState syncState_ = SyncState::Running;
    
    std::unordered_map<uint64_t, std::vector<uint8_t>> stateSnapshots_;
    
    void checkForDesync(uint64_t frame);
    void performRollback(uint64_t toFrame);
};

} // namespace lockstep
```

**Implementation Notes:**
- Start with wait-for-input lockstep; enable rollback only when needed for latency.
- State snapshots must include RNG/timer/ID counters and any global sim clocks.

### 4.2 State Serialization

**New File:** `src/systems/lockstep/state_serialization.hpp`

```cpp
#pragma once
#include "entt/entt.hpp"
#include <vector>

namespace lockstep {

// Serialize full game state for rollback
std::vector<uint8_t> serializeGameState(
    entt::registry& registry,
    class PhysicsManager* physics,
    uint64_t frame
);

// Restore game state from snapshot
void deserializeGameState(
    entt::registry& registry,
    class PhysicsManager* physics,
    const std::vector<uint8_t>& data
);

} // namespace lockstep
```

**Implementation Notes:**
- Include RNG, timer, and deterministic ID state in snapshots.
- Use stable component ordering and versioned schemas for serialization.

### 4.3 Local Multiplayer Test Mode

**New File:** `src/systems/lockstep/local_multiplayer.hpp`

```cpp
namespace lockstep {

// Simulate network delay locally for testing
class LocalNetworkSimulator {
public:
    void setLatency(int minMs, int maxMs);
    void setPacketLoss(float percentage);
    
    void sendInput(uint8_t fromPlayer, const InputSnapshot& input);
    std::vector<InputSnapshot> receiveInputs(uint8_t forPlayer);
};

} // namespace lockstep
```

### Success Criteria (Phase 4)
- [ ] `LockstepController` correctly blocks when inputs missing
- [ ] Two simulated players stay in sync locally
- [ ] Intentional desync is detected within 1 frame
- [ ] Rollback restores state correctly (if implemented)
- [ ] RNG/timer/ID state restored on rollback (if enabled)

### Testing Strategy
1. Run 2-player local test with simulated 100ms latency
2. Verify both players' checksums match every frame
3. Simulate packet loss → verify recovery
4. Test input delay values (0, 3, 6 frames)

---

## Phase 5: Network Integration (High-Level Overview)

**Goal:** Add actual network transport (future work).

**Estimated Complexity:** Very High  
**Duration:** 2-4 weeks

### 5.1 Network Protocol

```
┌─────────────────────────────────────────┐
│           Message Types                  │
├─────────────────────────────────────────┤
│ HELLO_MESSAGE                            │
│   - buildHash: u32                       │
│   - contentHash: u64                     │
│   - configHash: u32                      │
│   - tickRate: u32                        │
├─────────────────────────────────────────┤
│ INPUT_MESSAGE                            │
│   - frame: u64                          │
│   - playerId: u8                        │
│   - inputSnapshot: bytes                │
├─────────────────────────────────────────┤
│ CHECKSUM_MESSAGE                         │
│   - frame: u64                          │
│   - checksum: u32                       │
├─────────────────────────────────────────┤
│ SYNC_REQUEST                            │
│   - requestedFrame: u64                 │
├─────────────────────────────────────────┤
│ STATE_SNAPSHOT (for joining players)    │
│   - frame: u64                          │
│   - fullState: bytes                    │
└─────────────────────────────────────────┘
```

Handshake must reject mismatched build/config/content hashes to prevent silent desyncs.

### 5.2 Recommended Libraries

- **ENet** — Reliable UDP, simple API
- **GameNetworkingSockets** (Valve) — Production-ready
- **WebRTC DataChannels** — For web builds

### 5.3 Future Considerations

- Rollback netcode (GGPO-style) for fighting games
- Server-authoritative model for competitive games
- Spectator mode
- Match replay sharing

---

## File Structure Summary

```
src/systems/lockstep/
├── lockstep_config.hpp          # Phase 0
├── lockstep_config.cpp
├── deterministic_time.hpp       # Phase 0
├── deterministic_time.cpp
├── deterministic_ids.hpp        # Phase 0
├── deterministic_ids.cpp
├── state_checksum.hpp           # Phase 0
├── state_checksum.cpp
├── determinism_audit.hpp        # Phase 0
├── determinism_audit.cpp
├── deterministic_rng.hpp        # Phase 1
├── deterministic_rng.cpp
├── input_snapshot.hpp           # Phase 2
├── input_snapshot.cpp
├── input_buffer.hpp             # Phase 2
├── input_buffer.cpp
├── replay_recorder.hpp          # Phase 3
├── replay_recorder.cpp
├── replay_player.hpp            # Phase 3
├── replay_player.cpp
├── lockstep_controller.hpp      # Phase 4
├── lockstep_controller.cpp
├── state_serialization.hpp      # Phase 4
├── state_serialization.cpp
└── local_multiplayer.hpp        # Phase 4
```

## Modified Files Summary

| File | Phase | Changes |
|------|-------|---------|
| `src/core/globals.hpp` | 0 | Add lockstep config reference |
| `src/main.cpp` | 0-4 | Integrate lockstep into main loop |
| `src/systems/random/random.hpp` | 1 | Route to deterministic RNG |
| `src/systems/timer/timer.hpp` | 1 | Add tick-based timing |
| `src/systems/timer/timer.cpp` | 1 | Implement tick-based update |
| `src/systems/physics/physics_world.cpp` | 1 | Ensure fixed dt in lockstep |
| `src/systems/input/input_polling.hpp` | 2 | Add LockstepInputProvider |
| `src/systems/input/input_polling.cpp` | 2 | Implement snapshot capture + remove direct Raylib calls |
| `src/systems/scripting/scripting_functions.cpp` | 1, 3 | Lua bindings for RNG, time, replay |
| `assets/scripts/*` | 1 | Replace time-based IDs/tags in sim-critical scripts |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hidden non-determinism sources | High | High | Extensive audit in Phase 0 |
| Lua `math.random()` not all captured | Medium | High | Global override + audit |
| STL RNG distribution differences | Medium | High | Custom RNG + custom distributions |
| Physics floating-point variance | Medium | High | Fixed timestep + strict FP flags |
| Performance overhead from checksums | Medium | Medium | Only compute every N frames |
| State serialization too slow | Medium | Medium | Optimize critical path, delta compression |
| Input quantization changes feel | Medium | Medium | Tune scaling, clamp, and deadzones |

---

## Recommended Implementation Order

1. **Phase 0** first — establishes measurement before making changes
2. **Phase 1** is critical — without determinism, nothing else works
3. **Phase 2** can start in parallel with Phase 1 (input abstraction is independent)
4. **Phase 3** validates Phases 1-2 worked
5. **Phase 4** only after 3 passes all tests

**Estimated Total Duration:** 2-3 weeks for Phases 0-4

---

## Questions Before Implementation

1. **Determinism tier:** Same machine, same OS/arch, or cross-platform?
2. **Input delay tolerance:** Is 3 frames (~50ms) acceptable for local play feel?
3. **Rollback support:** Do you need GGPO-style rollback, or is wait-for-input sufficient?
4. **Replay file size:** ~50KB/minute expected. Acceptable?
5. **Text input:** Should text entry be lockstep-replayed or treated as UI-only?
6. **Priority scripts:** Should combat scripts be audited first, or core gameplay?

---

## Appendix: Lockstep Algorithm Reference

### Core Lockstep Flow
```
For each simulation tick:
1. Collect inputs from all players for tick N
2. Wait at synchronization barrier until all inputs arrive
3. Execute tick with deterministic simulation
4. Broadcast state checksum for verification
5. Repeat
```

### Determinism Checklist
- [ ] RNG seeded once per session with custom distributions
- [ ] All timers use tick-based counting with stable update order
- [ ] Physics uses fixed timestep
- [ ] Entity iteration sorted by ID
- [ ] No `std::unordered_*` iteration in simulation logic
- [ ] Lua `math.random()` overridden; `math.randomseed` blocked
- [ ] `GetTime`/`GetFrameTime`/`os.clock` deterministic in simulation
- [ ] No `rand()` usage in simulation paths
- [ ] No `pairs()` over unordered Lua tables in simulation
- [ ] Inputs are quantized + serialized
- [ ] Real-time access only in render/debug paths

### Desync Debugging
When checksums diverge:
1. Binary search to find first divergent frame
2. Compare component-by-component checksums
3. Log RNG call sequences on both sides
4. Check for missing input or timing drift
5. Dump input snapshots and RNG/timer state around the divergence

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
