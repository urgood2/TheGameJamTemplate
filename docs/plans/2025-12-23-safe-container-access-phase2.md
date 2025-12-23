# Safe Container Access Phase 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace remaining unsafe `.at()` container access with guarded patterns to prevent `std::out_of_range` exceptions in render and game logic hot paths.

**Architecture:** Defensive programming approach - add early-return guards for empty containers and use iterator-based access after `find()` checks. Each fix is isolated and independently testable. Changes preserve existing behavior while preventing crashes.

**Tech Stack:** C++20, EnTT ECS, Raylib

---

## Task 1: Fix Unsafe Animation List Access in graphics.cpp

**Files:**
- Modify: `src/core/graphics.cpp:27-46` (centerCameraOnEntity)
- Modify: `src/core/graphics.cpp:120-133` (drawSpriteComponentASCII)

**Why:** Both functions access `animationList.at(0)` or `animationList.at(index)` without checking if the list is empty. If an entity has an AnimationQueueComponent but no frames loaded, this crashes.

**Step 1: Add empty check to centerCameraOnEntity**

In `src/core/graphics.cpp`, find lines 27-46 and replace:

```cpp
// BEFORE (lines 27-46):
void centerCameraOnEntity( entt::entity entity) {
    // return if no animation queue component or location component
    if (globals::getRegistry().any_of<AnimationQueueComponent>(entity) == false) {
        return;
    }
    if (globals::getRegistry().any_of<LocationComponent>(entity) == false) {
        return;
    }
    AnimationQueueComponent &aqc = globals::getRegistry().get<AnimationQueueComponent>(entity);
    LocationComponent &lc = globals::getRegistry().get<LocationComponent>(entity);

    // if there is a sprite component, center the camera on the sprite
    float width=0, height=0;

    // no sprite component. Cannot center camera.
    width = aqc.defaultAnimation.animationList.at(0).first.spriteData.frame.width;
    height = aqc.defaultAnimation.animationList.at(0).first.spriteData.frame.height;
    globals::nextCameraTarget.x = lc.x * width + width / 2;
    globals::nextCameraTarget.y = lc.y * height + height / 2;
}

// AFTER:
void centerCameraOnEntity( entt::entity entity) {
    // return if no animation queue component or location component
    if (globals::getRegistry().any_of<AnimationQueueComponent>(entity) == false) {
        return;
    }
    if (globals::getRegistry().any_of<LocationComponent>(entity) == false) {
        return;
    }
    AnimationQueueComponent &aqc = globals::getRegistry().get<AnimationQueueComponent>(entity);
    LocationComponent &lc = globals::getRegistry().get<LocationComponent>(entity);

    // Guard: ensure animation list is not empty
    if (aqc.defaultAnimation.animationList.empty()) {
        SPDLOG_WARN("centerCameraOnEntity: entity {} has empty animation list", static_cast<int>(entity));
        return;
    }

    // if there is a sprite component, center the camera on the sprite
    const auto& firstFrame = aqc.defaultAnimation.animationList.front().first;
    float width = firstFrame.spriteData.frame.width;
    float height = firstFrame.spriteData.frame.height;
    globals::nextCameraTarget.x = lc.x * width + width / 2;
    globals::nextCameraTarget.y = lc.y * height + height / 2;
}
```

**Step 2: Add bounds checks to drawSpriteComponentASCII**

In `src/core/graphics.cpp`, find lines 120-133 and replace:

```cpp
// BEFORE (lines 120-133):
        // does the entity have a animation queue component?
        if (globals::getRegistry().any_of<AnimationQueueComponent>(e)) {
            auto &aqc = globals::getRegistry().get<AnimationQueueComponent>(e);

            auto debugSize = aqc.defaultAnimation.animationList.size();

            // is the animation queue empty? Use default animation
            if (aqc.animationQueue.empty()) {
                // FIXME: weird out of bounds error here - possibly only on windows?
                sc = &aqc.defaultAnimation.animationList.at(aqc.defaultAnimation.currentAnimIndex).first;
            }
            else {
                auto &currentAnimObject = aqc.animationQueue.at(aqc.currentAnimationIndex);
                sc = &currentAnimObject.animationList.at(currentAnimObject.currentAnimIndex).first;
            }
        }

// AFTER:
        // does the entity have a animation queue component?
        if (globals::getRegistry().any_of<AnimationQueueComponent>(e)) {
            auto &aqc = globals::getRegistry().get<AnimationQueueComponent>(e);

            // is the animation queue empty? Use default animation
            if (aqc.animationQueue.empty()) {
                // Guard: ensure default animation has frames
                if (aqc.defaultAnimation.animationList.empty() ||
                    aqc.defaultAnimation.currentAnimIndex >= aqc.defaultAnimation.animationList.size()) {
                    SPDLOG_ERROR("Entity {} has invalid default animation state", static_cast<int>(e));
                    return;
                }
                sc = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first;
            }
            else {
                // Guard: ensure queue index is valid
                if (aqc.currentAnimationIndex >= aqc.animationQueue.size()) {
                    SPDLOG_ERROR("Entity {} has invalid animation queue index", static_cast<int>(e));
                    return;
                }
                auto &currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];

                // Guard: ensure animation frame index is valid
                if (currentAnimObject.animationList.empty() ||
                    currentAnimObject.currentAnimIndex >= currentAnimObject.animationList.size()) {
                    SPDLOG_ERROR("Entity {} has invalid animation frame index", static_cast<int>(e));
                    return;
                }
                sc = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first;
            }
        }
```

**Step 3: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 4: Commit**

```bash
git add src/core/graphics.cpp
git commit -m "fix(graphics): add bounds checks to animation list access

- centerCameraOnEntity: guard against empty animation list
- drawSpriteComponentASCII: validate all animation indices before access
- Use operator[] after bounds check instead of .at() for performance

Prevents std::out_of_range crashes when animation data is incomplete.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Fix Unsafe Canvas Access in game.cpp

**Files:**
- Modify: `src/core/game.cpp:471-510` (run_shader_pipeline)

**Why:** The `run_shader_pipeline` function uses `.at(mainCanvas)` without checking if the canvas exists. If the layer doesn't have the expected canvas, this crashes.

**Step 1: Add canvas existence guard**

In `src/core/game.cpp`, find lines 471-510 and add guard:

```cpp
// BEFORE (lines 495-510):
        // Ensure result ends up back in mainCanvas
        if (src != mainCanvas) {
            // Clear destination before drawing (prevents stale content bleed-through)
            BeginTextureMode(layer->canvases.at(mainCanvas));
            ClearBackground(BLANK);
            EndTextureMode();

            layer::DrawCanvasOntoOtherLayer(
                layer,
                src,
                layer,
                mainCanvas,
                0, 0, 0, 1, 1,
                WHITE
            );
        }

// AFTER:
        // Ensure result ends up back in mainCanvas
        if (src != mainCanvas) {
            // Guard: ensure mainCanvas exists
            auto canvasIt = layer->canvases.find(mainCanvas);
            if (canvasIt == layer->canvases.end()) {
                SPDLOG_WARN("run_shader_pipeline: mainCanvas '{}' not found", mainCanvas);
                return;
            }

            // Clear destination before drawing (prevents stale content bleed-through)
            BeginTextureMode(canvasIt->second);
            ClearBackground(BLANK);
            EndTextureMode();

            layer::DrawCanvasOntoOtherLayer(
                layer,
                src,
                layer,
                mainCanvas,
                0, 0, 0, 1, 1,
                WHITE
            );
        }
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/core/game.cpp
git commit -m "fix(game): add canvas existence guard in run_shader_pipeline

Use find() + iterator instead of .at() to prevent std::out_of_range
when mainCanvas doesn't exist in layer->canvases map.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Fix Unsafe Animation Access in anim_system.cpp

**Files:**
- Modify: `src/systems/anim_system.cpp:359-362` (createAnimatedObjectWithTransform)
- Modify: `src/systems/anim_system.cpp:393-396` (replaceAnimatedObjectOnEntity)
- Modify: `src/systems/anim_system.cpp:655-690` (updateAnimationQueue)

**Why:** Multiple `.at(0)` and `.at(index)` calls without checking if animation lists are empty or if indices are in bounds.

**Step 1: Fix createAnimatedObjectWithTransform**

In `src/systems/anim_system.cpp`, find lines 357-362 and replace:

```cpp
// BEFORE (lines 357-362):
  // set width and height to the animation size
  // TODO: optionally provide custom size upon init
  transform.setActualW(animQueue.defaultAnimation.animationList.at(0)
                           .first.spriteFrame->frame.width);
  transform.setActualH(animQueue.defaultAnimation.animationList.at(0)
                           .first.spriteFrame->frame.height);

// AFTER:
  // set width and height to the animation size
  // TODO: optionally provide custom size upon init
  if (!animQueue.defaultAnimation.animationList.empty()) {
    const auto& firstFrame = animQueue.defaultAnimation.animationList.front().first;
    transform.setActualW(firstFrame.spriteFrame->frame.width);
    transform.setActualH(firstFrame.spriteFrame->frame.height);
  } else {
    SPDLOG_WARN("createAnimatedObjectWithTransform: empty animation list for entity {}", static_cast<int>(e));
  }
```

**Step 2: Fix replaceAnimatedObjectOnEntity**

In `src/systems/anim_system.cpp`, find lines 393-397 and replace:

```cpp
// BEFORE (lines 393-397):
  // 4) size the transform to match the first frame
  const auto &firstFrame =
      animQueue.defaultAnimation.animationList.at(0).first.spriteFrame->frame;
  transform.setActualW(firstFrame.width);
  transform.setActualH(firstFrame.height);

// AFTER:
  // 4) size the transform to match the first frame
  if (!animQueue.defaultAnimation.animationList.empty()) {
    const auto &firstFrame =
        animQueue.defaultAnimation.animationList.front().first.spriteFrame->frame;
    transform.setActualW(firstFrame.width);
    transform.setActualH(firstFrame.height);
  } else {
    SPDLOG_WARN("replaceAnimatedObjectOnEntity: empty animation list for entity {}", static_cast<int>(e));
  }
```

**Step 3: Fix updateAnimationQueue loop**

In `src/systems/anim_system.cpp`, find lines 655-690 and replace all `.at()` with bounds-checked access:

```cpp
// BEFORE (lines 655-690):
    } else {
      if (ac.currentAnimationIndex >= ac.animationQueue.size()) {
        ac.currentAnimationIndex = 0;
      }

      auto &currentAnimation = ac.animationQueue.at(ac.currentAnimationIndex);

      // Update the current animation
      currentAnimation.currentElapsedTime += delta;

      if (currentAnimation.currentElapsedTime >
          currentAnimation.animationList.at(currentAnimation.currentAnimIndex)
              .second) {
        if (currentAnimation.currentAnimIndex >=
            currentAnimation.animationList.size() - 1) {
          // The current animation has completed
          if (ac.currentAnimationIndex + 1 < ac.animationQueue.size()) {
            // Move to the next animation in the queue
            ac.currentAnimationIndex++;
            // Reset the next animation's state
            ac.animationQueue.at(ac.currentAnimationIndex).currentAnimIndex = 0;
            ac.animationQueue.at(ac.currentAnimationIndex).currentElapsedTime =
                0;
          } else {
            // ...
          }
        }
      }
    }

// AFTER:
    } else {
      if (ac.currentAnimationIndex >= ac.animationQueue.size()) {
        ac.currentAnimationIndex = 0;
      }

      // Guard: queue should not be empty at this point
      if (ac.animationQueue.empty()) {
        continue;
      }

      auto &currentAnimation = ac.animationQueue[ac.currentAnimationIndex];

      // Update the current animation
      currentAnimation.currentElapsedTime += delta;

      // Guard: ensure animation list has frames
      if (currentAnimation.animationList.empty() ||
          currentAnimation.currentAnimIndex >= currentAnimation.animationList.size()) {
        continue;
      }

      if (currentAnimation.currentElapsedTime >
          currentAnimation.animationList[currentAnimation.currentAnimIndex].second) {
        if (currentAnimation.currentAnimIndex >=
            currentAnimation.animationList.size() - 1) {
          // The current animation has completed
          if (ac.currentAnimationIndex + 1 < ac.animationQueue.size()) {
            // Move to the next animation in the queue
            ac.currentAnimationIndex++;
            // Reset the next animation's state (already bounds-checked above)
            ac.animationQueue[ac.currentAnimationIndex].currentAnimIndex = 0;
            ac.animationQueue[ac.currentAnimationIndex].currentElapsedTime = 0;
          } else {
            // ...existing code...
          }
        }
      }
    }
```

**Step 4: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 5: Commit**

```bash
git add src/systems/anim_system.cpp
git commit -m "fix(anim): add bounds checks to animation list access

- createAnimatedObjectWithTransform: guard empty animation list
- replaceAnimatedObjectOnEntity: guard empty animation list
- updateAnimationQueue: validate all indices before access

Use operator[] after bounds check instead of .at() for performance
in the animation update hot path.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Fix Unsafe Map Access in input_functions.cpp

**Files:**
- Modify: `src/systems/input/input_functions.cpp:430`

**Why:** `activeInputLocks.at("frame_lock_reset_next_frame")` throws if the key doesn't exist.

**Step 1: Replace .at() with find() or count()**

In `src/systems/input/input_functions.cpp`, find line 430 and replace:

```cpp
// BEFORE (line 430):
        if (inputState.activeInputLocks.at("frame_lock_reset_next_frame"))

// AFTER:
        // Use count() for safe bool map access (returns 0 if key missing)
        if (inputState.activeInputLocks.count("frame_lock_reset_next_frame") &&
            inputState.activeInputLocks["frame_lock_reset_next_frame"])
```

**Alternative (cleaner pattern):**

```cpp
// AFTER (alternative using find):
        auto it = inputState.activeInputLocks.find("frame_lock_reset_next_frame");
        if (it != inputState.activeInputLocks.end() && it->second)
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/input/input_functions.cpp
git commit -m "fix(input): use safe map access for activeInputLocks

Replace .at() with count() + operator[] pattern to avoid
std::out_of_range when key doesn't exist.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Fix Unsafe JSON Access in sound_system.cpp

**Files:**
- Modify: `src/systems/sound/sound_system.cpp:461`

**Why:** `soundData.at("categories")` throws if "categories" key is missing from JSON.

**Step 1: Add contains() guard**

In `src/systems/sound/sound_system.cpp`, find line 461 and replace:

```cpp
// BEFORE (line 461):
        for (const auto& category : soundData.at("categories").items()) {

// AFTER:
        if (!soundData.contains("categories")) {
            SPDLOG_WARN("[SOUND] No 'categories' key in sound data JSON");
            return;
        }
        for (const auto& category : soundData["categories"].items()) {
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/sound/sound_system.cpp
git commit -m "fix(sound): add contains() guard for JSON categories access

Prevents crash when sound config JSON is missing the 'categories' key.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Final Verification

**Step 1: Full build and test suite**

Run: `just build-debug && just test`
Expected: All tests pass

**Step 2: Run with AddressSanitizer**

Run: `just test-asan`
Expected: No memory errors detected

**Step 3: Manual smoke test**

Run: `./build/raylib-cpp-cmake-template`
Expected: Game starts, no crashes during normal gameplay

**Step 4: Grep verification - confirm no remaining high-risk .at() calls**

Run: `grep -rn "\.at(" src/core/graphics.cpp src/core/game.cpp src/systems/anim_system.cpp src/systems/input/input_functions.cpp src/systems/sound/sound_system.cpp`
Expected: Only safe uses remain (inside try-catch or after contains() checks)

---

## Summary of Changes

| File | Change | Lines Modified |
|------|--------|----------------|
| `graphics.cpp` | Empty list guards + use `front()`/`[]` | ~27-46, 120-133 |
| `game.cpp` | Canvas find() + iterator | ~495-510 |
| `anim_system.cpp` | Empty/bounds guards | ~359-362, 393-397, 655-690 |
| `input_functions.cpp` | count() before access | ~430 |
| `sound_system.cpp` | contains() guard | ~461 |

**Total estimated time:** 1-2 hours

**Risk assessment:** LOW - All changes are additive guards. No control flow changes except early returns on error conditions. Existing behavior preserved for valid data.
