# TheGameJamTemplate — Feature Gap Implementation Plan (Updated)

This plan resolves the identified feature gaps in priority order with concrete file targets, acceptance criteria, test plans, and rollback strategies.

**User decisions applied**:
1. **Resource Manager wraps** textures + fonts + **sounds + shaders** (yes, wrap)
2. **Coverage threshold** enforced in CI: **minimum 60%**
3. UI animation is **explicit opt-in** (no auto-attach)
4. Gamepad rumble has a **global enable/disable toggle**

---

## 0) Success Criteria (global)

| Criteria Type | Description | Pass/Fail |
|---|---|---|
| Functional | All features behave as specified | Pass if each task’s acceptance criteria met |
| Observable | Logs/CI artifacts/visual behavior demonstrate correctness | Pass if evidence captured (CI output, logs, report path) |
| Regression | Existing tests still pass | Pass if `just test` and CI tests are green |

---

## Phase 1 — Quick Wins (< 4 hours each)

### 1.1 CRITICAL: Fix silent error handling in text effects

**Problem**: `src/systems/text/text_effects.cpp` contains **11** `catch(...)` blocks that swallow parse errors.

**Target file**:
- `src/systems/text/text_effects.cpp`

**Known empty catch locations**:
- `catch (...)` at lines: **208, 242, 331, 383, 409, 449, 493, 550, 586, 631, 688**

**Implementation approach**:
- Replace empty `catch (...) {}` with `catch (const std::exception& e)`.
- Log **warn** (not error) and continue using defaults.
- Standardize message format: `[text_effects] effect=<name> arg=<raw> err=<what()>`.
- Where parsing uses `std::stoul()` (highlight hex), catch and warn similarly.

**Acceptance criteria**:
- [ ] No empty catch blocks remain in `text_effects.cpp`.
- [ ] Invalid args produce a warning log with effect name.
- [ ] Defaults still apply without crashing.

**Test plan**:
- Add/extend unit tests around text parsing (preferably alongside existing text tests e.g. `tests/unit/test_text_waiters.cpp` or add new `tests/unit/test_text_effects.cpp`).
- Test cases:
  1. Bad numeric: `[shake=abc,def]` → warn emitted, defaults used
  2. Bad hex: `[highlight=ZZZZZZ]` → warn emitted, fallback color used

**Rollback**:
- Revert only `text_effects.cpp` and the new/modified test file.

---

### 1.2 HIGH: Gamepad haptic feedback (rumble)

**Current state**:
- Input lives in `src/systems/input/*`.
- Raylib supports vibration: `SetGamepadVibration(gamepad, leftMotor, rightMotor, duration)`.

**Files**:
- NEW: `src/systems/input/input_rumble.hpp`
- NEW: `src/systems/input/input_rumble.cpp`
- Modify: `src/systems/input/input_polling.cpp` (or wherever per-frame update is centralized)
- Modify: `src/systems/input/input_lua_bindings.cpp` (Lua exposure)

**API design (C++)**:
- Add a simple per-gamepad rumble state machine:
  - `trigger(gamepadId, left, right, duration)`
  - `stop(gamepadId)`
  - `update(dt)` decrements timers and stops when duration ends

**Global toggle requirement**:
- Add `input.setRumbleEnabled(bool)` and `input.isRumbleEnabled()`.
- Default value: **enabled** (or load from config if you prefer; decide during implementation).
- If disabled: all rumble calls become no-ops and any active rumble is stopped.

**Lua API**:
```lua
input.setRumbleEnabled(true|false)
input.isRumbleEnabled() -> bool
input.rumble(intensity, duration)
input.rumbleDual(left, right, duration)
input.rumbleStop()
```

**Acceptance criteria**:
- [ ] Rumble works on supported platforms (desktop) when enabled.
- [ ] Rumble does nothing when globally disabled.
- [ ] Rumble stops automatically after duration.
- [ ] Multiple triggers override previous vibration.

**Test plan**:
- Unit-test the timer/override behavior in pure C++ (no hardware dependency).
- Manual test: bind rumble to a button press in Lua and verify feel.

**Rollback**:
- Remove new rumble files and revert binding/polling edits.

---

### 1.3 CRITICAL: Coverage reporting + enforce 60% minimum

**Current state**:
- CI: `.github/workflows/tests.yml` runs Lua tests + unit tests + ASAN.
- No coverage step.

**Files**:
- Modify: `CMakeLists.txt` (add coverage option)
- Modify: `.github/workflows/tests.yml` (add coverage job)
- Modify: `Justfile` (add `test-coverage` command)

**CMake**:
- Add `ENABLE_COVERAGE` option.
- Apply `--coverage` flags for GCC/Clang.
- Exclude third-party deps in lcov filtering.

**CI enforcement (60%)**:
- Generate lcov report.
- Compute line coverage percent.
- Fail CI if coverage < **60%**.

**Example enforcement step (shell)**:
- Parse `lcov --summary` output and compare numeric percent.

**Acceptance criteria**:
- [ ] `just test-coverage` generates HTML report locally.
- [ ] CI produces coverage artifact.
- [ ] CI fails if total line coverage < **60%**.

**Rollback**:
- Remove coverage job and coverage flags.

---

## Phase 2 — Medium Effort (4–8 hours)

### 2.1 HIGH: UI Animation / Transitions System (explicit opt-in)

**Current state**:
- Lua tweening exists: `assets/scripts/core/timer.lua` (`timer.tween_opts`) and `assets/scripts/core/tween.lua` (fluent wrapper).

**File**:
- NEW: `assets/scripts/ui/ui_anim.lua`

**Design requirement (explicit)**:
- No automatic behavior injection into all buttons.
- Users opt in via explicit API (e.g., `dsl.animatedButton(...)` or calling `ui_anim.attachHoverScale(entity, opts)` after spawn).

**Proposed UI API**:
```lua
local UIAnim = require("ui.ui_anim")

UIAnim.animate(entity, {
  scale = { from = 1.0, to = 1.1 },
  duration = 0.2,
  ease = "outBack",
})

UIAnim.attachButtonJuice(entity, {
  hoverScale = 1.05,
  pressScale = 0.98,
})
```

**Implementation approach**:
- Wrap `core.tween` with UI-friendly helpers:
  - `hoverScale`, `pressScale`, `slideIn`, `slideOut`, `fadeIn`, `fadeOut`, `pulse`.
- Provide cancellation/tagging strategy (using timer groups/tags) so UI teardown cancels animations.

**Acceptance criteria**:
- [ ] Library exists and is usable without modifying existing UI.
- [ ] At least one example UI uses it with explicit opt-in.
- [ ] Animations cancel safely on UI destroy.

**Rollback**:
- Delete `ui_anim.lua` and any example usage.

---

### 2.2 HIGH: 2.5D / positional audio (pan + attenuation)

**Current state**:
- `src/systems/sound/sound_system.hpp/.cpp` uses Raylib sounds.
- Already uses pan/volume controls.

**Files**:
- Modify: `src/systems/sound/sound_system.hpp`
- Modify: `src/systems/sound/sound_system.cpp`
- Modify: Lua exposure file where sound is bound (if present; likely `sound_system::ExposeToLua`)

**Implementation approach**:
- Add a global listener position.
- Add `PlaySoundAt(category, name, x, y, opts)`.
- Compute:
  - Pan from relative X (clamped)
  - Volume attenuation from distance (`referenceDistance`, `maxDistance`, `rolloff`)

**Acceptance criteria**:
- [ ] Sounds pan left/right based on relative position.
- [ ] Sounds attenuate with distance.
- [ ] Defaults preserve current 2D behavior when calling existing APIs.

**Rollback**:
- Revert sound system changes.

---

## Phase 3 — Larger Features (1–2 days)

### 3.1 CRITICAL: Centralized Resource Manager (wrap textures, fonts, sounds, shaders)

**Current state**:
- Textures loaded ad-hoc in `src/core/init.cpp` → `globals::textureAtlasMap`.
- Sounds managed in `sound_system`.
- Shaders managed in `shader_system`.

**Files**:
- NEW: `src/core/resource_manager.hpp`
- NEW: `src/core/resource_manager.cpp`
- Modify: `src/core/init.cpp` (migrate asset bootstrapping)
- Modify: `src/core/globals.hpp` (reduce direct asset storage usage over time)
- Modify: `src/systems/sound/sound_system.*` (integrate with RM)
- Modify: `src/systems/shaders/*` (integrate with RM)

**Design decision (wrap everything)**:
- ResourceManager becomes the authoritative lifecycle controller.
- Sounds and shaders remain logically in their subsystems, but load/unload is orchestrated by ResourceManager.

**Proposed responsibilities**:
- Track handles + refcounts
- Unified unload at shutdown
- Optional `unloadUnused()`
- Optional future: hot-reload/watch paths (deferred)

**Implementation approach**:
1. Introduce `ResourceManager` with typed APIs:
   - `loadTexture(path)` / `getTexture(key)`
   - `loadFont(path, size)`
   - `loadSoundBankFromJson(path)` (delegates to `sound_system::LoadFromJSON` but RM owns lifetime and ensures `Unload`)
   - `loadShaderPresetPack(path)` (delegates to shader system load routines)
2. Update init flow (`init.cpp`) to call RM once.
3. Ensure `ResourceManager::unloadAll()` is called during shutdown.
4. Add basic instrumentation (counts by asset type) for debugging.

**Acceptance criteria**:
- [ ] Single entry point for loading assets during init.
- [ ] `unloadAll()` cleans up textures/fonts/sounds/shaders (verify in ASAN run).
- [ ] Existing gameplay unaffected.

**Rollback**:
- Keep old init functions intact behind a flag or revert commit.

---

### 3.2 MEDIUM: CMake modularization

**Current state**: `CMakeLists.txt` ~1339 lines.

**Files**:
- NEW: `cmake/Dependencies.cmake`
- NEW: `cmake/CompilerFlags.cmake`
- NEW: `cmake/PlatformConfig.cmake`
- NEW: `cmake/WebBuild.cmake`
- NEW: `cmake/Testing.cmake`
- Modify: `CMakeLists.txt` (include modules)

**Acceptance criteria**:
- [ ] Main `CMakeLists.txt` under ~200 lines.
- [ ] CI unchanged and passing.
- [ ] Native + web + tests still build.

**Rollback**:
- Revert `CMakeLists.txt` and remove new cmake includes.

---

## Suggested Implementation Order

1. **Text effects logging** (small, high leverage)
2. **Coverage reporting with 60% gate** (improves confidence for larger changes)
3. **Rumble w/ global toggle** (contained feature)
4. **UI animation (explicit opt-in)**
5. **Positional audio**
6. **ResourceManager (wrap-all)**
7. **CMake modularization**

---

## Open Questions (to resolve at implementation time)

- ResourceManager keying: by filepath? logical name? UUID? (recommend: filepath + type-specific suffix)
- Rumble toggle location: config.json vs runtime-only (recommend: runtime API + optional config binding)
- Coverage gate: total lines vs tracked subset (recommend: total lines after excluding deps)
