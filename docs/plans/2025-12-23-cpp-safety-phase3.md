# C++ Safety Improvements Phase 3 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete remaining C++ safety hardening: fix all remaining `.at()` calls, add Sol2 error handling, and improve resource validation.

**Architecture:** Same defensive programming approach as Phase 2 - add guards without changing control flow. Assertions are replaced with runtime guards since assertions are removed in release builds.

**Tech Stack:** C++20, EnTT ECS, Sol2 Lua bindings, Raylib, nlohmann/json

---

## Task 1: Fix Remaining Animation .at() in setupAnimatedObjectOnEntity

**Files:**
- Modify: `src/systems/anim_system.cpp:450-454`

**Why:** `setupAnimatedObjectOnEntity` uses `.at(0)` without checking if animation list is empty.

**Step 1: Add empty check with fallback dimensions**

In `src/systems/anim_system.cpp`, find lines 450-454:

```cpp
// BEFORE (lines 450-454):
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
    SPDLOG_WARN("setupAnimatedObjectOnEntity: empty animation list for entity {}", static_cast<int>(e));
    transform.setActualW(1);
    transform.setActualH(1);
  }
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/anim_system.cpp
git commit -m "fix(anim): add bounds check in setupAnimatedObjectOnEntity

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Fix Animation .at() in resetAnimationUIRenderScale

**Files:**
- Modify: `src/systems/anim_system.cpp:507-516`

**Why:** Line 514 uses `.at(0)` but line 507 only checks `empty()` on `animationQueue`, not `defaultAnimation.animationList`.

**Step 1: Add proper guard before line 514**

In `src/systems/anim_system.cpp`, find lines 511-516:

```cpp
// BEFORE (lines 511-516):
  // calc intrinsic size, set to transform
  auto &transform = globals::getRegistry().get<transform::Transform>(e);
  auto &role = globals::getRegistry().get<transform::InheritedProperties>(e);
  auto &firstFrame = animQueue.defaultAnimation.animationList.at(0).first;
  float rawWidth = firstFrame.spriteFrame->frame.width;
  float rawHeight = firstFrame.spriteFrame->frame.height;

// AFTER:
  // calc intrinsic size, set to transform
  auto &transform = globals::getRegistry().get<transform::Transform>(e);
  auto &role = globals::getRegistry().get<transform::InheritedProperties>(e);

  // Guard: ensure default animation has frames
  if (animQueue.defaultAnimation.animationList.empty()) {
    SPDLOG_WARN("resetAnimationUIRenderScale: empty animation list for entity {}", static_cast<int>(e));
    return;
  }

  auto &firstFrame = animQueue.defaultAnimation.animationList.front().first;
  float rawWidth = firstFrame.spriteFrame->frame.width;
  float rawHeight = firstFrame.spriteFrame->frame.height;
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/anim_system.cpp
git commit -m "fix(anim): add bounds check in resetAnimationUIRenderScale

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Fix Animation .at() in resizeAnimationObjectsInEntityToFitAndCenterUI

**Files:**
- Modify: `src/systems/anim_system.cpp:542-546`

**Why:** Line 543 has an assertion (`AssertThat`) which is removed in release builds. Line 545 uses `.at(0)` which will crash in release if assertion would have failed.

**Step 1: Replace assertion with runtime guard**

In `src/systems/anim_system.cpp`, find lines 542-546:

```cpp
// BEFORE (lines 542-546):
  using namespace snowhouse;
  AssertThat(animQueue.defaultAnimation.animationList.size(), IsGreaterThan(0));

  const auto &firstFrame = animQueue.defaultAnimation.animationList.at(0).first;
  float rawWidth = firstFrame.spriteFrame->frame.width;

// AFTER:
  // Runtime guard (assertions removed in release builds)
  if (animQueue.defaultAnimation.animationList.empty()) {
    SPDLOG_ERROR("resizeAnimationObjectsInEntityToFitAndCenterUI: empty animation list for entity {}", static_cast<int>(e));
    return;
  }

  const auto &firstFrame = animQueue.defaultAnimation.animationList.front().first;
  float rawWidth = firstFrame.spriteFrame->frame.width;
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/anim_system.cpp
git commit -m "fix(anim): replace assertion with runtime guard in resizeAnimationObjectsInEntityToFitAndCenterUI

Assertions are removed in release builds - use runtime guard instead.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Fix Animation .at() in resizeAnimationObjectToFit

**Files:**
- Modify: `src/systems/anim_system.cpp:593-601`

**Why:** Lines 595 has assertion, lines 598-600 use `.at(currentAnimIndex)` which can crash in release.

**Step 1: Replace assertion with runtime guard and fix .at() calls**

In `src/systems/anim_system.cpp`, find lines 593-601:

```cpp
// BEFORE (lines 593-601):
  // assert the animation list is not empty
  using namespace snowhouse;
  AssertThat(animObj.animationList.size(), IsGreaterThan(0));

  // get the scale factor which will fit the target width and height
  scaleX = targetWidth / animObj.animationList.at(animObj.currentAnimIndex)
                             .first.spriteFrame->frame.width;
  scaleY = targetHeight / animObj.animationList.at(animObj.currentAnimIndex)
                              .first.spriteFrame->frame.height;

// AFTER:
  // Runtime guard (assertions removed in release builds)
  if (animObj.animationList.empty() ||
      animObj.currentAnimIndex >= animObj.animationList.size()) {
    SPDLOG_WARN("resizeAnimationObjectToFit: invalid animation state");
    return;
  }

  // get the scale factor which will fit the target width and height
  const auto& currentFrame = animObj.animationList[animObj.currentAnimIndex].first;
  scaleX = targetWidth / currentFrame.spriteFrame->frame.width;
  scaleY = targetHeight / currentFrame.spriteFrame->frame.height;
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/anim_system.cpp
git commit -m "fix(anim): replace assertion with runtime guard in resizeAnimationObjectToFit

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Fix Gamepad Map .at() in input_functions.cpp

**Files:**
- Modify: `src/systems/input/input_functions.cpp:734`

**Why:** `gamepadHeldButtonDurations.at(xboxAButton)` throws if key doesn't exist.

**Step 1: Replace .at() with safe access**

In `src/systems/input/input_functions.cpp`, find line 734:

```cpp
// BEFORE (line 734):
            state.gamepadHeldButtonDurations.at(xboxAButton) != 0 /** A for xbox */ > 0 && state.gamepadHeldButtonDurations[xboxAButton] < constants::BUTTON_HOLD_COYOTE_TIME &&

// AFTER:
            state.gamepadHeldButtonDurations.count(xboxAButton) && state.gamepadHeldButtonDurations[xboxAButton] != 0 && state.gamepadHeldButtonDurations[xboxAButton] < constants::BUTTON_HOLD_COYOTE_TIME &&
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/input/input_functions.cpp
git commit -m "fix(input): use safe map access for gamepadHeldButtonDurations

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Fix Music File .at() in sound_system.cpp

**Files:**
- Modify: `src/systems/sound/sound_system.cpp:533-534`

**Why:** `musicFiles.at(name)` throws if music name doesn't exist.

**Step 1: Add existence check before PlayMusic**

In `src/systems/sound/sound_system.cpp`, find lines 533-534:

```cpp
// BEFORE (lines 533-534):
    void PlayMusic(const std::string& name, bool loop) {
        Music m = LoadMusicStream(musicFiles.at(name).c_str());

// AFTER:
    void PlayMusic(const std::string& name, bool loop) {
        auto it = musicFiles.find(name);
        if (it == musicFiles.end()) {
            SPDLOG_WARN("[SOUND] PlayMusic: music '{}' not found", name);
            return;
        }
        Music m = LoadMusicStream(it->second.c_str());
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/sound/sound_system.cpp
git commit -m "fix(sound): add existence check for music file lookup

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Add Sol2 Try-Catch in load_actions_from_lua

**Files:**
- Modify: `src/systems/ai/ai_system.cpp:388-410`

**Why:** Multiple `.as<T>()` calls can throw `sol::error` if Lua provides wrong types.

**Step 1: Wrap function body in try-catch**

In `src/systems/ai/ai_system.cpp`, find lines 388-410:

```cpp
// BEFORE (lines 388-410):
    void load_actions_from_lua(GOAPComponent &comp, actionplanner_t &planner)
    {
        sol::table actions = comp.def["actions"];
        for (auto &[key, val] : actions)
        {
            std::string name = key.as<std::string>();
            sol::table tbl = val.as<sol::table>();
            // ... rest of function
        }
    }

// AFTER:
    void load_actions_from_lua(GOAPComponent &comp, actionplanner_t &planner)
    {
        try {
            sol::table actions = comp.def["actions"];
            for (auto &[key, val] : actions)
            {
                std::string name = key.as<std::string>();
                sol::table tbl = val.as<sol::table>();

                int cost = tbl["cost"].get_or(1);
                goap_set_cost(&planner, name.c_str(), cost);

                sol::table pre = tbl["pre"];
                for (auto &[pre_key, pre_val] : pre)
                    goap_set_pre(&planner, name.c_str(), pre_key.as<std::string>().c_str(), pre_val.as<bool>());

                sol::table post = tbl["post"];
                for (auto &[post_key, post_val] : post)
                {
                    goap_set_pst(&planner, name.c_str(), post_key.as<std::string>().c_str(), post_val.as<bool>());
                    allPostconditionsForEveryAction[name][post_key.as<std::string>()] = post_val.as<bool>();
                }
            }
        } catch (const sol::error& e) {
            SPDLOG_ERROR("Lua error in load_actions_from_lua: {}", e.what());
        } catch (const std::exception& e) {
            SPDLOG_ERROR("Exception in load_actions_from_lua: {}", e.what());
        }
    }
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/ai/ai_system.cpp
git commit -m "fix(ai): add try-catch to load_actions_from_lua for Sol2 safety

Prevents crashes when Lua provides unexpected types to GOAP action loading.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Add File Validation in sound_system LoadFromJSON

**Files:**
- Modify: `src/systems/sound/sound_system.cpp:451-456`

**Why:** No check if file opens successfully before parsing JSON.

**Step 1: Add file open validation**

In `src/systems/sound/sound_system.cpp`, find lines 451-456:

```cpp
// BEFORE (lines 451-456):
        std::ifstream file;
        nlohmann::json soundData;
        file.open(filepath);
        soundData = json::parse(file);
        file.close();

// AFTER:
        std::ifstream file(filepath);
        if (!file.is_open()) {
            SPDLOG_ERROR("[SOUND] Failed to open sound config: {}", filepath);
            return;
        }

        nlohmann::json soundData;
        try {
            soundData = json::parse(file);
        } catch (const json::parse_error& e) {
            SPDLOG_ERROR("[SOUND] JSON parse error in {}: {}", filepath, e.what());
            file.close();
            return;
        }
        file.close();
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/sound/sound_system.cpp
git commit -m "fix(sound): add file open and JSON parse validation

Prevents cryptic errors when sound config file is missing or malformed.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Final Verification

**Step 1: Full build and test suite**

Run: `just build-debug && just test`
Expected: All tests pass

**Step 2: Grep verification - confirm no high-risk .at() calls remain in modified files**

Run:
```bash
grep -n "\.at(" src/systems/anim_system.cpp src/systems/input/input_functions.cpp src/systems/sound/sound_system.cpp src/systems/ai/ai_system.cpp
```
Expected: Only safe uses remain (inside try-catch or after validation)

**Step 3: Manual smoke test**

Run: `./build/raylib-cpp-cmake-template`
Expected: Game starts, no crashes during normal gameplay

---

## Summary of Changes

| Task | File | Change |
|------|------|--------|
| 1 | `anim_system.cpp` | setupAnimatedObjectOnEntity guard |
| 2 | `anim_system.cpp` | resetAnimationUIRenderScale guard |
| 3 | `anim_system.cpp` | resizeAnimationObjectsInEntityToFitAndCenterUI guard |
| 4 | `anim_system.cpp` | resizeAnimationObjectToFit guard |
| 5 | `input_functions.cpp` | gamepadHeldButtonDurations safe access |
| 6 | `sound_system.cpp` | PlayMusic existence check |
| 7 | `ai_system.cpp` | Sol2 try-catch wrapper |
| 8 | `sound_system.cpp` | File open + JSON parse validation |

**Total estimated time:** 1.5-2 hours

**Risk assessment:** LOW - All changes are additive guards. Assertions replaced with runtime guards that work in release builds.
