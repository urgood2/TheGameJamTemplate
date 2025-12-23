# C++ Safety Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix critical safety issues in C++ codebase: nullptr checks, unsafe container access, vector<bool> performance issues, and Lua boundary error handling.

**Architecture:** Defensive programming approach - add guards without changing control flow. Each fix is isolated and independently testable. Changes preserve existing behavior while preventing crashes.

**Tech Stack:** C++20, EnTT ECS, Chipmunk2D physics, Sol2 Lua bindings, Raylib

---

## Task 1: Add nullptr Guards in Physics Callbacks

**Files:**
- Modify: `src/systems/physics/physics_world.cpp:26-43`

**Why:** The `getE()` lambda calls `cpShapeGetUserData(s)` without checking if `s` is null. If Chipmunk passes a null shape (e.g., during cleanup), this crashes.

**Step 1: Add null guard to getE lambda**

In `src/systems/physics/physics_world.cpp`, find the `LuaArbiter::entities()` function around line 22-34:

```cpp
// BEFORE (lines 26-31):
auto getE = [](cpShape *s) -> entt::entity {
  if (void *ud = cpShapeGetUserData(s)) {
    return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(ud));
  }
  return entt::entity{entt::null};
};

// AFTER:
auto getE = [](cpShape *s) -> entt::entity {
  if (!s) return entt::entity{entt::null};  // Guard against null shape
  if (void *ud = cpShapeGetUserData(s)) {
    return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(ud));
  }
  return entt::entity{entt::null};
};
```

**Step 2: Add null guard to tags() function**

In the same file, find `LuaArbiter::tags()` around line 36-43:

```cpp
// BEFORE (lines 36-43):
std::pair<std::string, std::string> LuaArbiter::tags(PhysicsWorld &W) const {
  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  auto fA = cpShapeGetFilter(sa);
  auto fB = cpShapeGetFilter(sb);
  return {W.GetTagFromCategory(int(fA.categories)),
          W.GetTagFromCategory(int(fB.categories))};
}

// AFTER:
std::pair<std::string, std::string> LuaArbiter::tags(PhysicsWorld &W) const {
  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  // Guard against null shapes
  if (!sa || !sb) return {"", ""};
  auto fA = cpShapeGetFilter(sa);
  auto fB = cpShapeGetFilter(sb);
  return {W.GetTagFromCategory(int(fA.categories)),
          W.GetTagFromCategory(int(fB.categories))};
}
```

**Step 3: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 4: Commit**

```bash
git add src/systems/physics/physics_world.cpp
git commit -m "fix(physics): add nullptr guards to LuaArbiter shape access

Prevents crashes if Chipmunk passes null shapes during cleanup or
edge cases in collision callbacks.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Fix Unsafe .at() Access in Layer Render Functions

**Files:**
- Modify: `src/systems/layer/layer.cpp:3033-3047, 3240-3277, 4295-4329`

**Why:** `.at()` throws `std::out_of_range` exceptions. In the render loop, exceptions are catastrophic and cause frame drops. Some functions have `find()` checks but still use `.at()` (safe but wasteful), while others have NO guards at all.

**Step 1: Fix DrawCustomLambdaToSpecificCanvas - use iterator**

In `src/systems/layer/layer.cpp`, find lines 3033-3047:

```cpp
// BEFORE (lines 3033-3047):
void DrawCustomLamdaToSpecificCanvas(const std::shared_ptr<Layer> layer,
                                     const std::string &canvasName,
                                     std::function<void()> drawActions) {
  if (layer->canvases.find(canvasName) == layer->canvases.end())
    return; // no canvas to draw to

  BeginTextureMode(layer->canvases.at(canvasName));
  // ...
}

// AFTER:
void DrawCustomLamdaToSpecificCanvas(const std::shared_ptr<Layer> layer,
                                     const std::string &canvasName,
                                     std::function<void()> drawActions) {
  auto it = layer->canvases.find(canvasName);
  if (it == layer->canvases.end())
    return; // no canvas to draw to

  BeginTextureMode(it->second);

  // clear screen
  ClearBackground(layer->backgroundColor);

  drawActions();

  EndTextureMode();
}
```

**Step 2: Fix ApplyPostProcessShaders - guard ping canvas access**

Find lines 3240-3277 in `ApplyPostProcessShaders`:

```cpp
// BEFORE (lines 3240-3248):
  const std::string ping = canvasName;
  const std::string pong = canvasName + "_double";
  if (layerPtr->canvases.find(pong) == layerPtr->canvases.end()) {
    // create it with same size as ping:
    auto &srcTex = layerPtr->canvases.at(ping);  // UNSAFE - assumes ping exists!
    // ...
  }

// AFTER:
  const std::string ping = canvasName;
  const std::string pong = canvasName + "_double";

  // First ensure ping canvas exists
  auto pingIt = layerPtr->canvases.find(ping);
  if (pingIt == layerPtr->canvases.end()) {
    SPDLOG_WARN("ApplyPostProcessShaders: ping canvas '{}' not found", ping);
    return;
  }

  if (layerPtr->canvases.find(pong) == layerPtr->canvases.end()) {
    // create it with same size as ping:
    auto &srcTex = pingIt->second;
    layerPtr->canvases[pong] =
        LoadRenderTextureStencilEnabled(srcTex.texture.width,
                                        srcTex.texture.height);
  }
```

Then fix the loop at lines 3252-3277:

```cpp
// BEFORE (lines 3252-3277):
  std::string src = ping, dst = pong;
  for (auto &shaderName : layerPtr->postProcessShaders) {
    // clear dst
    BeginTextureMode(layerPtr->canvases.at(dst));  // UNSAFE
    // ...
  }
  if (src != canvasName) {
    BeginTextureMode(layerPtr->canvases.at(canvasName));  // UNSAFE
    // ...
  }

// AFTER:
  std::string src = ping, dst = pong;
  for (auto &shaderName : layerPtr->postProcessShaders) {
    // clear dst - use operator[] since we know pong was just created
    auto dstIt = layerPtr->canvases.find(dst);
    if (dstIt == layerPtr->canvases.end()) continue;

    BeginTextureMode(dstIt->second);
    ClearBackground(BLANK);
    EndTextureMode();

    layer::DrawCanvasOntoOtherLayerWithShader(layerPtr, src, layerPtr, dst,
                                              0, 0, 0, 1, 1, WHITE, shaderName);
    std::swap(src, dst);
  }

  // 4) If the final result isn't back in "main", copy it home:
  if (src != canvasName) {
    auto canvasIt = layerPtr->canvases.find(canvasName);
    if (canvasIt == layerPtr->canvases.end()) return;

    BeginTextureMode(canvasIt->second);
    ClearBackground(BLANK);
    EndTextureMode();
    layer::DrawCanvasOntoOtherLayer(layerPtr, src, layerPtr, canvasName, 0, 0,
                                    0, 1, 1, WHITE);
  }
```

**Step 3: Fix DrawCanvasToCurrentRenderTarget - THE CRITICAL BUG**

Find lines 4295-4329 in `DrawCanvasToCurrentRenderTarget`. This function has NO find check before multiple `.at()` calls:

```cpp
// BEFORE (lines 4318-4325 - no guard!):
  DrawTexturePro(
      layer->canvases.at(canvasName).texture,
      {0, 0, (float)layer->canvases.at(canvasName).texture.width,
       (float)-layer->canvases.at(canvasName).texture.height},
      // ...

// Find the function start around line 4295 and add guard + cache:
void DrawCanvasToCurrentRenderTarget(const std::shared_ptr<Layer> layer,
                                     const std::string &canvasName, float x,
                                     float y, float rotation, float scaleX,
                                     float scaleY, const Color &color,
                                     std::string shaderName) {
  // ADD THIS GUARD:
  auto canvasIt = layer->canvases.find(canvasName);
  if (canvasIt == layer->canvases.end()) {
    SPDLOG_WARN("DrawCanvasToCurrentRenderTarget: canvas '{}' not found", canvasName);
    return;
  }
  const auto& canvas = canvasIt->second;

  Shader shader = shaders::getShader(shaderName);

  // Optional shader
  if (shader.id != 0) {
    BeginShaderMode(shader);
    shaders::TryApplyUniforms(shader, globals::getGlobalShaderUniforms(),
                              shaderName);
  }

  // Use cached canvas reference instead of .at()
  DrawTexturePro(
      canvas.texture,
      {0, 0, (float)canvas.texture.width, (float)-canvas.texture.height},
      {x, y, (float)canvas.texture.width * scaleX,
       (float)-canvas.texture.height * scaleY},
      {0, 0}, rotation, {color.r, color.g, color.b, color.a});

  if (shader.id != 0)
    EndShaderMode();
}
```

**Step 4: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 5: Commit**

```bash
git add src/systems/layer/layer.cpp
git commit -m "fix(layer): replace unsafe .at() with guarded iterator access

- DrawCustomLamdaToSpecificCanvas: use iterator from find()
- ApplyPostProcessShaders: add ping canvas existence check
- DrawCanvasToCurrentRenderTarget: add missing guard (was crashing)

Prevents std::out_of_range exceptions in render hot path.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Replace std::vector<bool> with std::vector<uint8_t>

**Files:**
- Modify: `src/core/engine_context.hpp:105`
- Modify: `src/core/globals.cpp:479-484`
- Modify: `src/systems/line_of_sight/line_of_sight.cpp:25, 30`
- Modify: `src/systems/input/input_polling.cpp:96`

**Why:** `std::vector<bool>` is a space-optimized specialization that uses bit-packing. Each access requires bit manipulation, making it slower than `std::vector<uint8_t>`. For visibility maps accessed every frame, this matters.

**Note:** `physics_world.cpp:2238` uses `std::vector<std::vector<bool>>` as an API parameter. This is harder to change (would break external callers), so we'll document it but leave it for now.

**Step 1: Update engine_context.hpp**

In `src/core/engine_context.hpp`, find line 105:

```cpp
// BEFORE (line 105):
std::vector<std::vector<bool>> visibilityMap{};

// AFTER:
std::vector<std::vector<uint8_t>> visibilityMap{};  // uint8_t for performance (vector<bool> is slow)
```

**Step 2: Update globals.cpp**

In `src/core/globals.cpp`, find lines 479-484:

```cpp
// BEFORE (lines 479-484):
std::vector<std::vector<bool>> globalVisibilityMap{};
bool useLineOfSight{false};
std::vector<std::vector<bool>>& getGlobalVisibilityMap() {
    if (g_ctx) return g_ctx->visibilityMap;
    return globalVisibilityMap;
}

// AFTER:
std::vector<std::vector<uint8_t>> globalVisibilityMap{};  // uint8_t for performance
bool useLineOfSight{false};
std::vector<std::vector<uint8_t>>& getGlobalVisibilityMap() {
    if (g_ctx) return g_ctx->visibilityMap;
    return globalVisibilityMap;
}
```

**Step 3: Update globals.hpp declaration (if exists)**

Check if there's a declaration in globals.hpp that needs updating. Search for `getGlobalVisibilityMap` declaration and update the return type.

**Step 4: Update line_of_sight.cpp**

In `src/systems/line_of_sight/line_of_sight.cpp`, find line 25:

```cpp
// BEFORE (line 25):
globals::getGlobalVisibilityMap() = std::vector<std::vector<bool>>(globals::getWorldWidth(), std::vector<bool>(globals::getWorldHeight(), false));

// AFTER:
globals::getGlobalVisibilityMap() = std::vector<std::vector<uint8_t>>(globals::getWorldWidth(), std::vector<uint8_t>(globals::getWorldHeight(), 0));
```

And line 30:

```cpp
// BEFORE (line 30):
globals::getGlobalVisibilityMap()[x][y] = true;

// AFTER:
globals::getGlobalVisibilityMap()[x][y] = 1;  // Use 1/0 instead of true/false
```

**Step 5: Update input_polling.cpp**

In `src/systems/input/input_polling.cpp`, find line 96:

```cpp
// BEFORE (line 96):
static std::vector<bool> s_keyDownLastFrame(KEY_KP_EQUAL + 1, false);

// AFTER:
static std::vector<uint8_t> s_keyDownLastFrame(KEY_KP_EQUAL + 1, 0);  // uint8_t for performance
```

Also update any assignments to this vector (e.g., `= true` becomes `= 1`, `= false` becomes `= 0`).

**Step 6: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 7: Commit**

```bash
git add src/core/engine_context.hpp src/core/globals.cpp src/systems/line_of_sight/line_of_sight.cpp src/systems/input/input_polling.cpp
git commit -m "perf: replace std::vector<bool> with std::vector<uint8_t>

std::vector<bool> is a bit-packed specialization that requires
bit manipulation for each access. Using uint8_t is faster for
visibility maps and input state that are accessed every frame.

Files changed:
- engine_context.hpp: visibilityMap
- globals.cpp: globalVisibilityMap
- line_of_sight.cpp: visibility map initialization
- input_polling.cpp: key state tracking

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add Try-Catch to Sol2 Lua Conversions

**Files:**
- Modify: `src/systems/scripting/scripting_system.hpp:43-65`

**Why:** Sol2 can throw `sol::error` on invalid type conversions. The `add_task()` function does type checking but doesn't catch conversion failures, which could crash the game when Lua passes unexpected types.

**Step 1: Wrap add_task in try-catch**

In `src/systems/scripting/scripting_system.hpp`, find the `add_task` function around lines 43-65:

```cpp
// BEFORE (lines 43-65):
void add_task(sol::object obj) {
    if (obj.is<sol::function>()) {
        sol::function fn = obj.as<sol::function>();
        sol::thread thread = sol::thread::create(ai_system::masterStateLua);
        sol::state_view ts = thread.state();
        ts["__fn"] = fn;
        sol::coroutine co = ts["__fn"];
        tasks.emplace_back(std::move(co));
        SPDLOG_DEBUG("Added coroutine from function via new thread.");
    }
    else if (obj.is<sol::coroutine>()) {
        tasks.emplace_back(obj.as<sol::coroutine>());
        SPDLOG_DEBUG("Added coroutine.");
    }
    else if (obj.get_type() == sol::type::thread) {
        sol::thread th = obj;
        tasks.emplace_back(sol::coroutine(th));
        SPDLOG_DEBUG("Added coroutine from thread object.");
    }
    else {
        spdlog::warn("Invalid coroutine object: type = {}", static_cast<int>(obj.get_type()));
    }
}

// AFTER:
void add_task(sol::object obj) {
    try {
        if (obj.is<sol::function>()) {
            sol::function fn = obj.as<sol::function>();
            sol::thread thread = sol::thread::create(ai_system::masterStateLua);
            sol::state_view ts = thread.state();
            ts["__fn"] = fn;
            sol::coroutine co = ts["__fn"];
            tasks.emplace_back(std::move(co));
            SPDLOG_DEBUG("Added coroutine from function via new thread.");
        }
        else if (obj.is<sol::coroutine>()) {
            tasks.emplace_back(obj.as<sol::coroutine>());
            SPDLOG_DEBUG("Added coroutine.");
        }
        else if (obj.get_type() == sol::type::thread) {
            sol::thread th = obj;
            tasks.emplace_back(sol::coroutine(th));
            SPDLOG_DEBUG("Added coroutine from thread object.");
        }
        else {
            spdlog::warn("Invalid coroutine object: type = {}", static_cast<int>(obj.get_type()));
        }
    }
    catch (const sol::error& e) {
        spdlog::error("Lua error in add_task: {}", e.what());
    }
    catch (const std::exception& e) {
        spdlog::error("Exception in add_task: {}", e.what());
    }
}
```

**Step 2: Build and run tests**

Run: `just build-debug && just test`
Expected: Build succeeds, all tests pass

**Step 3: Commit**

```bash
git add src/systems/scripting/scripting_system.hpp
git commit -m "fix(scripting): add try-catch to Sol2 conversions in add_task

Prevents crashes when Lua passes unexpected types that fail
sol::object::as<T>() conversion.

$(cat <<'EOF'

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Final Verification

**Step 1: Full build and test suite**

Run: `just build-debug && just test`
Expected: All tests pass

**Step 2: Run with AddressSanitizer**

Run: `just test-asan`
Expected: No memory errors detected

**Step 3: Manual smoke test**

Run: `./build/raylib-cpp-cmake-template`
Expected: Game starts, no crashes during normal gameplay

**Step 4: Final commit (if any cleanup needed)**

If any issues were found and fixed, commit them.

---

## Summary of Changes

| File | Change | Impact |
|------|--------|--------|
| `physics_world.cpp` | Add nullptr guards | Prevents physics crash |
| `layer.cpp` | Safe container access | Prevents render crash |
| `engine_context.hpp` | vector<uint8_t> | Performance improvement |
| `globals.cpp` | vector<uint8_t> | Performance improvement |
| `line_of_sight.cpp` | vector<uint8_t> | Performance improvement |
| `input_polling.cpp` | vector<uint8_t> | Performance improvement |
| `scripting_system.hpp` | try-catch | Prevents Lua crash |

**Total estimated time:** 2-3 hours

**Risk assessment:** LOW - All changes are additive guards or type changes with equivalent semantics. No control flow changes except early returns on error conditions.
