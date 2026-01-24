# Lockstep Networking Implementation Plan

## Executive Summary

This document outlines a phased approach to adding lockstep networking support to the C++20 + Lua game engine. The plan prioritizes **determinism first**, ensuring single-player games are bit-reproducible before any networking code is introduced.

**Key Principles:**
- **Non-breaking**: All changes are opt-in via a `LockstepConfig` toggle
- **Determinism-first**: Phases 0-3 focus purely on making simulation reproducible
- **Lua-aware**: Game logic is primarily Lua, so Lua RNG/timing must be determinized
- **Future-proof**: Design for multiplayer without requiring network code immediately

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
| Global RNG not frame-seeded | `random.hpp` | **Critical** | Phase 1 |
| Lua `math.random()` usage | ~71 script files | **Critical** | Phase 1 |
| Timer system uses real time | `timer.hpp` | **High** | Phase 1 |
| Physics float precision | Chipmunk2D | Medium | Phase 1 |
| Unordered container iteration | EnTT views | Medium | Phase 1 |
| Input from Raylib directly | `input_polling.hpp` | **High** | Phase 2 |
| No input serialization | N/A | **High** | Phase 2 |

---

## Phase 0: Foundation — Determinism Audit & Preparation

**Goal:** Establish infrastructure for measuring and testing determinism without changing game behavior.

**Estimated Complexity:** Low-Medium  
**Duration:** 1-2 days

### 0.1 Create Lockstep Configuration System

**New File:** `src/systems/lockstep/lockstep_config.hpp`

```cpp
#pragma once
#include <cstdint>

namespace lockstep {

struct LockstepConfig {
    bool enabled = false;                    // Master toggle
    bool deterministic_rng = false;          // Seed RNG per frame
    bool deterministic_timers = false;       // Use tick-based timing
    bool input_recording = false;            // Record inputs for replay
    bool checksum_validation = false;        // Generate state checksums
    uint32_t base_seed = 0;                  // Session seed
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

### 0.2 Create State Checksum System

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

### 0.3 Create Determinism Audit Tool

**New File:** `src/systems/lockstep/determinism_audit.hpp`

```cpp
#pragma once
#include <vector>
#include <string>

namespace lockstep {

struct AuditReport {
    std::vector<std::string> rng_calls;           // Where RNG was called
    std::vector<std::string> time_accesses;       // Real-time accesses
    std::vector<std::string> unordered_iterations; // Potential issues
};

// Run audit for N frames, report non-deterministic calls
AuditReport runDeterminismAudit(int frames);

} // namespace lockstep
```

### 0.4 Lua Audit Bindings

**Modify:** `src/systems/scripting/scripting_functions.cpp`

Add audit hooks to track Lua RNG and timing calls:
```cpp
// Wrap random_utils functions to log calls in audit mode
if (lockstep::g_lockstepConfig.checksum_validation) {
    lockstep::logRngCall(__FILE__, __LINE__);
}
```

### Success Criteria (Phase 0)
- [ ] `LockstepConfig` can be enabled/disabled at runtime
- [ ] State checksums are computed each frame when enabled
- [ ] Audit tool identifies non-deterministic code paths
- [ ] No gameplay changes when lockstep is disabled

### Testing Strategy
1. Run game normally → verify checksums are NOT computed (no overhead)
2. Enable lockstep → verify checksums ARE computed
3. Run same seed twice → checksums should match (if already deterministic)
4. Run audit → identify remaining non-determinism sources

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
    // Initialize with session seed
    void init(uint32_t baseSeed);
    
    // Call at start of each tick to derive per-frame seed
    void advanceFrame(uint64_t frame);
    
    // Getters (replace effolkronium calls in lockstep mode)
    int randomInt(int min, int max);
    float randomFloat(float min, float max);
    bool randomBool(float chance);
    
    // Get current internal state for checksumming
    uint64_t getStateHash() const;

private:
    uint32_t baseSeed_ = 0;
    uint64_t currentSeed_ = 0;
    // Use PCG or xoshiro256** for quality + reproducibility
};

extern DeterministicRNG g_deterministicRng;

} // namespace lockstep
```

**Modify:** `src/systems/random/random.hpp`

```cpp
namespace random_utils {

inline void set_seed(unsigned int seed) {
    if (lockstep::isLockstepEnabled()) {
        lockstep::g_deterministicRng.init(seed);
    } else {
        RandomEngine::seed(seed);
    }
}

inline int random_int(int min, int max) {
    if (lockstep::isLockstepEnabled()) {
        return lockstep::g_deterministicRng.randomInt(min, max);
    }
    return RandomEngine::get(min, max);
}

// ... same pattern for all random functions
}
```

**Modify:** `src/main.cpp` — Seed RNG per frame

```cpp
// In RunGameLoop(), inside fixed update:
if (lockstep::isLockstepEnabled()) {
    lockstep::g_deterministicRng.advanceFrame(mainLoop.frame);
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
                return lockstep::g_deterministicRng.randomFloat(0.0f, 1.0f);
            } else if (va.size() == 1) {
                int max = va[0].as<int>();
                return lockstep::g_deterministicRng.randomInt(1, max);
            } else {
                int min = va[0].as<int>();
                int max = va[1].as<int>();
                return lockstep::g_deterministicRng.randomInt(min, max);
            }
        };
    }
}
```

**Priority Script Files to Audit:**
1. `assets/scripts/combat/*.lua` — Combat must be deterministic
2. `assets/scripts/core/*.lua` — Core game logic
3. `assets/scripts/ai/*.lua` — AI decisions

### 1.3 Deterministic Timer System

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

### 1.4 Deterministic Physics

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

### 1.5 Deterministic Entity Iteration

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

### Success Criteria (Phase 1)
- [ ] Same seed + same inputs = identical frame checksums
- [ ] Lua `math.random()` uses deterministic RNG in lockstep mode
- [ ] Timer system works in tick-based mode
- [ ] Physics produces identical results across runs
- [ ] Entity iteration order is deterministic

### Testing Strategy
1. **Replay Test:** Record inputs, play back twice, compare checksums
2. **Cross-Platform Test:** Same seed on different machines → same checksums
3. **Lua Audit:** Run game with RNG logging, verify all calls go through deterministic system

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
    
    // Keyboard (compact bitset for common keys)
    std::bitset<128> keysDown;
    std::bitset<128> keysPressed;
    std::bitset<128> keysReleased;
    
    // Mouse
    Vector2 mousePosition = {0, 0};
    Vector2 mouseDelta = {0, 0};
    float mouseWheelDelta = 0.0f;
    uint8_t mouseButtons = 0;  // Bitfield: LMB=1, RMB=2, MMB=4
    
    // Gamepad (simplified)
    uint16_t gamepadButtons = 0;
    float leftStickX = 0.0f, leftStickY = 0.0f;
    float rightStickX = 0.0f, rightStickY = 0.0f;
    float leftTrigger = 0.0f, rightTrigger = 0.0f;
    
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

### 2.2 Input Provider Abstraction

**Modify:** `src/systems/input/input_polling.hpp`

The existing `IInputProvider` interface is a good foundation. Extend it:

```cpp
namespace input::polling {

// NEW: Lockstep-aware input provider
class LockstepInputProvider : public IInputProvider {
public:
    // Set the snapshot to read from (for replay/network)
    void setSnapshot(const lockstep::InputSnapshot& snapshot);
    
    // Override all methods to read from snapshot
    bool is_key_down(int key) const override;
    bool is_key_pressed(int key) const override;
    // ... etc
    
private:
    lockstep::InputSnapshot currentSnapshot_;
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
#include <deque>
#include <unordered_map>

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
    std::deque<FrameInputs> buffer_;
    int inputDelay_ = 3;  // Default 3 frame delay (~50ms at 60fps)
    int playerCount_ = 1;
};

} // namespace lockstep
```

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
    g_lockstepInputProvider.setSnapshot(frameInputs->players[0]);
}
```

### Success Criteria (Phase 2)
- [ ] `InputSnapshot` can serialize/deserialize round-trip
- [ ] Game plays identically using `LockstepInputProvider` vs direct Raylib
- [ ] Input delay works correctly (3-frame default)
- [ ] Input checksums match between capture and replay

### Testing Strategy
1. Capture inputs for 60 seconds of gameplay
2. Replay using `LockstepInputProvider`
3. Verify frame checksums match

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
    uint32_t version = 1;
    uint32_t baseSeed = 0;
    uint64_t frameCount = 0;
    uint8_t playerCount = 1;
    uint32_t configHash = 0;  // For validation
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

### Testing Strategy
1. Record gameplay session A
2. Play back on same machine → verify match
3. Transfer replay file to different machine → verify match
4. Intentionally corrupt one RNG call → verify desync detection

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
| `src/systems/input/input_polling.cpp` | 2 | Implement snapshot capture |
| `src/systems/scripting/scripting_functions.cpp` | 1, 3 | Lua bindings for RNG, replay |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hidden non-determinism sources | High | High | Extensive audit in Phase 0 |
| Lua `math.random()` not all captured | Medium | High | Global override + audit |
| Physics floating-point variance | Low | High | Use fixed timestep always |
| Performance overhead from checksums | Medium | Medium | Only compute every N frames |
| State serialization too slow | Medium | Medium | Optimize critical path, delta compression |

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

1. **Input delay tolerance:** Is 3 frames (~50ms) acceptable for local play feel?
2. **Rollback support:** Do you need GGPO-style rollback, or is simple wait-for-input lockstep sufficient?
3. **Replay file size:** ~50KB/minute expected. Acceptable?
4. **Priority scripts:** Should combat scripts be audited first, or core gameplay?

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
- [ ] RNG seeded per-frame with frame number
- [ ] All timers use tick-based counting
- [ ] Physics uses fixed timestep
- [ ] Entity iteration sorted by ID
- [ ] No `std::unordered_*` in simulation logic
- [ ] Lua `math.random()` overridden
- [ ] No real-time access during simulation

### Desync Debugging
When checksums diverge:
1. Binary search to find first divergent frame
2. Compare component-by-component checksums
3. Log RNG call sequences on both sides
4. Check for missing input or timing drift
