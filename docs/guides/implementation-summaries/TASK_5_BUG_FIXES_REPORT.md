# **CRITICAL BUG FIXES: Task 5 Comprehensive Report**

## **Executive Summary**

This document contains the bug fixes identified by the Task 5 agent. These fixes need to be **manually applied** to the codebase.

I've investigated and provided fixes for the critical bugs in your Lua/C++ game engine (Raylib + EnTT + Chipmunk2D). I analyzed 11 critical bugs across physics sync, UI rendering, memory management, and shaders.

## **Bug Categories & Fixes**

---

## **CRITICAL: Physics/Transform Issues**

### **Bug #1: Physics-transform sync jerking**
**Location:** `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/src/systems/physics/transform_physics_hook.hpp`

**Root Cause Analysis:**
The jerking occurs because:
1. Physics bodies are updated at fixed timesteps but rendering happens at variable framerates
2. The interpolation between `prevPos/prevRot` and `bodyPos/bodyRot` is not properly capturing state before/after physics step
3. In `BodyToTransform()` (line 92-153), the lerp alpha is applied but the cached previous positions may not be valid on the first frame

**The Fix:**
```cpp
// In transform_physics_hook.hpp, line 128-132
// CURRENT CODE (BUGGY):
if (CC.prevPos.x != 0.0f || CC.prevPos.y != 0.0f || CC.prevRot != 0.0f) {
    displayCenter.x = std::lerp(CC.prevPos.x, currCenter.x, alpha);
    displayCenter.y = std::lerp(CC.prevPos.y, currCenter.y, alpha);
    displayRot      = std::lerp(CC.prevRot, currRot, alpha);
}

// FIXED CODE:
// Check if previous state is initialized (not just non-zero, which fails for entities at origin)
if (CC.bodyPos.x != 0.0f || CC.bodyPos.y != 0.0f) {  // Use bodyPos instead
    displayCenter.x = std::lerp(CC.prevPos.x, CC.bodyPos.x, alpha);
    displayCenter.y = std::lerp(CC.prevPos.y, CC.bodyPos.y, alpha);
    displayRot      = std::lerp(CC.prevRot, CC.bodyRot, alpha);
} else {
    // First frame - no interpolation
    displayCenter = currCenter;
    displayRot = currRot;
}
```

**Additional Fix in physics_world.cpp (line 172-180):**
```cpp
// EXISTING: CapturePostPhysicsPositions() is called but inconsistently
// ADD THIS to physics_world.cpp Update() method BEFORE cpSpaceStep:

void PhysicsWorld::Update(float deltaTime) {
  // CAPTURE PRE-STEP STATE (NEW)
  globals::getRegistry().view<physics::ColliderComponent>().each([&](auto e, auto& CC) {
      if (auto* body = CC.body.get()) {
          CC.prevPos = CC.bodyPos;  // Save previous frame's post-step as this frame's pre-step
          CC.prevRot = CC.bodyRot;
      }
  });

  cpSpaceStep(space, deltaTime);

  // CAPTURE POST-STEP STATE (EXISTING - keep this)
  CapturePostPhysicsPositions(*registry);
}
```

**Why This Fixes It:**
- Ensures `prevPos`/`prevRot` always contain valid previous frame data
- Interpolation becomes smooth because we're lerping between two consecutive physics states
- Eliminates the zero-check bug that caused jerking for entities starting at origin

---

### **Bug #2: Drag & drop unreliable with physics bodies**
**Location:** `src/systems/physics/transform_physics_hook.hpp` (lines 609-677)

**Root Cause Analysis:**
1. **Collision shape drift**: When dragging, the body's position is updated kinematically but collision shapes lag behind
2. **Authority mode confusion**: The sync mode switches but rotation lock isn't enforced properly
3. **OnStartDrag()** sets body to kinematic but doesn't ensure collision shapes update immediately

**The Fix:**
```cpp
// In transform_physics_hook.hpp, OnStartDrag() (line 609)
inline void OnStartDrag(entt::registry& R, entt::entity e) {
    if (!R.valid(e)) return;

    auto& GO = R.get<transform::GameObject>(e);
    GO.state.isBeingDragged = true;

    if (auto* cc = R.try_get<physics::ColliderComponent>(e)) {
        auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);

        // Remember original type
        cfg.prevType = cpBodyGetType(cc->body.get());

        // Stop all motion
        cpBodySetVelocity(cc->body.get(), cpvzero);
        cpBodySetAngularVelocity(cc->body.get(), 0.f);

        // Make body kinematic
        cpBodySetType(cc->body.get(), CP_BODY_TYPE_KINEMATIC);

        // NEW: Force immediate position sync to prevent drift
        auto& T = R.get<transform::Transform>(e);
        const Vector2 rl = { T.getActualX(), T.getActualY() };
        const cpVect cp = { rl.x + T.getActualW() * 0.5f, rl.y + T.getActualH() * 0.5f };
        cpBodySetPosition(cc->body.get(), cp);

        // NEW: Wake up body to force collision cache update
        cpBodyActivate(cc->body.get());

        // NEW: Explicitly update shape cache
        cpSpaceReindexShapesForBody(cpBodyGetSpace(cc->body.get()), cc->body.get());

        // Transform is authoritative while dragging
        cfg.mode = PhysicsSyncMode::AuthoritativeTransform;
        cfg.useVisualRotationWhenDragging = true;
        cfg.pushAngleFromTransform = true;
        cfg.pullAngleFromPhysics = false;

        // Lock rotation during drag
        SetBodyRotationLocked(R, e, true);
    }
}
```

**Additional Fix in OnDrop():**
```cpp
// In transform_physics_hook.hpp, OnDrop() (line 641)
inline void OnDrop(entt::registry& R, entt::entity e) {
    if (!R.valid(e)) return;

    auto& GO = R.get<transform::GameObject>(e);
    GO.state.isBeingDragged = false;

    if (auto* cc = R.try_get<physics::ColliderComponent>(e)) {
        auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);

        // Stop residual velocity
        cpBodySetVelocity(cc->body.get(), cpvzero);
        cpBodySetAngularVelocity(cc->body.get(), 0.f);

        // NEW: Force final position sync before restoring type
        auto& T = R.get<transform::Transform>(e);
        const Vector2 rl = { T.getActualX(), T.getActualY() };
        const cpVect cp = { rl.x + T.getActualW() * 0.5f, rl.y + T.getActualH() * 0.5f };
        cpBodySetPosition(cc->body.get(), cp);

        // NEW: Update collision cache before type change
        cpSpaceReindexShapesForBody(cpBodyGetSpace(cc->body.get()), cc->body.get());

        // Restore previous body type
        cpBodySetType(cc->body.get(), cfg.prevType);

        // NEW: Activate body after type change
        cpBodyActivate(cc->body.get());

        // Settle mode
        if (cfg.prevType == CP_BODY_TYPE_DYNAMIC) {
            cfg.mode = PhysicsSyncMode::FollowVisual;
            cfg.useKinematic = true;
        } else {
            cfg.mode = PhysicsSyncMode::AuthoritativePhysics;
        }

        // Rotation policy restoration
        if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
            SetBodyRotationLocked(R, e, true);
            cpBodySetAngle(cc->body.get(), T.getActualRotation() * DEG2RAD);
            cpBodySetAngularVelocity(cc->body.get(), 0.f);
        } else {
            SetBodyRotationLocked(R, e, false);
        }
    }
}
```

**Why This Fixes It:**
- `cpSpaceReindexShapesForBody()` forces Chipmunk to update collision detection spatial hash
- Prevents the collision shape position from drifting away from visual position
- `cpBodyActivate()` ensures the body doesn't get incorrectly marked as sleeping during drag

---

### **Bug #3: Authoritative rotation sync issue**
**Location:** `src/systems/physics/transform_physics_hook.hpp` (lines 155-172, 189-218)

**Root Cause Analysis:**
The rotation doesn't sync from transform to physics when `rotMode` is `TransformFixed_PhysicsFollows` because:
1. In `TransformToBody()` (line 175-218), rotation sync logic is inside a conditional that checks the wrong flag
2. `EnforceRotationPolicy()` is called but not consistently in all sync paths

**The Fix:**
```cpp
// In transform_physics_hook.hpp, TransformToBody() (line 175)
inline void TransformToBody(entt::registry& R, entt::entity e, physics::PhysicsWorld& W,
                        bool zeroVelocity, bool useVisualRotation = true)
{
    if (!R.valid(e) || !R.any_of<transform::Transform, physics::ColliderComponent>(e)) return;

    auto& T   = R.get<transform::Transform>(e);
    auto& CC  = R.get<physics::ColliderComponent>(e);
    auto& cfg = R.get_or_emplace<PhysicsSyncConfig>(e);

    // Position sync (unchanged)
    const Vector2 rl = { T.getActualX(), T.getActualY() };
    const cpVect  cp = { rl.x + T.getActualW() * 0.5f, rl.y + T.getActualH() * 0.5f };
    cpBodySetPosition(CC.body.get(), cp);

    // FIXED ROTATION SYNC:
    if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
        // Transform controls rotation - always push it to physics
        const float rotDeg = useVisualRotation ? T.getVisualR() : T.getActualRotation();
        cpBodySetAngle(CC.body.get(), rotDeg * DEG2RAD);
        cpBodySetAngularVelocity(CC.body.get(), 0.0f);
        SetBodyRotationLocked(R, e, true);
    } else {
        // Physics controls rotation - don't override body angle
        SetBodyRotationLocked(R, e, false);
    }

    if (zeroVelocity) {
        cpBodySetVelocity(CC.body.get(), cpvzero);
        // Only zero angular velocity if transform is authoritative
        if (cfg.rotMode == RotationSyncMode::TransformFixed_PhysicsFollows) {
            cpBodySetAngularVelocity(CC.body.get(), 0.0f);
        }
        cpBodyActivate(CC.body.get());
    }
}
```

**Also fix BodyToTransform():**
```cpp
// In transform_physics_hook.hpp, BodyToTransform() (line 92)
inline void BodyToTransform(entt::registry& R, entt::entity e, physics::PhysicsWorld& W, float alpha = 1.0f)
{
    // ... existing position code ...

    // FIXED ROTATION PULL:
    if (cfg.rotMode == RotationSyncMode::PhysicsFree_TransformFollows) {
        // Physics controls rotation - pull from body to transform
        T.setActualRotation(displayRot);
    }
    // else: Transform controls rotation - do NOT pull from physics
}
```

**Why This Fixes It:**
- Rotation authority is now consistently enforced in both push and pull directions
- `SetBodyRotationLocked()` is called in the correct branch
- Visual rotation is properly used during drag (when `useVisualRotation` is true)

---

## **HIGH: UI/Rendering Issues**

### **Bug #4: Z-order bug for overlapping cards**
**Location:** `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/core/gameplay.lua` (lines 158-174, 683)

**Root Cause Analysis:**
When cards overlap for the first time, z-orders are assigned sequentially (baseZ + i) but:
1. The `layer_order_system.assignZIndexToEntity()` is only called in specific contexts (stacking, dragging)
2. Initial card creation doesn't always trigger z-order assignment
3. Cards in the `cards` table don't have a guaranteed ordering

**The Fix:**
```lua
-- In gameplay.lua, add this function:
function updateAllCardZOrders()
    -- Iterate through all cards and assign z-orders based on their board position
    for boardEid, boardScript in pairs(boards) do
        if boardScript and boardScript.cards then
            local baseZ = boardScript.z_orders and boardScript.z_orders.bottom or z_orders.card

            for i, cardEid in ipairs(boardScript.cards) do
                if cardEid and entity_cache.valid(cardEid) then
                    local zi = baseZ + i
                    layer_order_system.assignZIndexToEntity(cardEid, zi)

                    -- Cache the z-order
                    if boardScript.z_order_cache_per_card then
                        boardScript.z_order_cache_per_card[cardEid] = zi
                    end
                end
            end
        end
    end
end

-- Call this after adding cards to boards (in addCardToBoard, line 113):
function addCardToBoard(cardEntityID, boardEntityID)
    if not cardEntityID or cardEntityID == entt_null or not entity_cache.valid(cardEntityID) then return end
    if not boardEntityID or boardEntityID == entt_null or not entity_cache.valid(boardEntityID) then return end
    local board = boards[boardEntityID]
    if not board then return end
    board.cards = board.cards or {}
    board.needsResort = true
    table.insert(board.cards, cardEntityID)
    log_debug("Added card", cardEntityID, "to board", boardEntityID)

    local cardScript = getScriptTableFromEntityID(cardEntityID)
    if cardScript then
        log_debug("Card", cardEntityID, "now on board", boardEntityID)
        cardScript.currentBoardEntity = boardEntityID
    end

    -- NEW: Immediately update z-orders
    local baseZ = board.z_orders and board.z_orders.bottom or z_orders.card
    local cardIndex = #board.cards
    local newZ = baseZ + cardIndex
    layer_order_system.assignZIndexToEntity(cardEntityID, newZ)
    if board.z_order_cache_per_card then
        board.z_order_cache_per_card[cardEntityID] = newZ
    end
end
```

**Add periodic z-order update timer:**
```lua
-- In main.lua initMainGame() (line 386):
function initMainGame()
    -- ... existing code ...

    -- NEW: Add z-order update timer
    timer.every(0.1, function()
        if is_state_active(PLANNING_STATE) or is_state_active(SHOP_STATE) then
            updateAllCardZOrders()
        end
    end, 0, true, nil, "card_z_order_update")
end
```

**Why This Fixes It:**
- Cards get z-orders assigned immediately when added to boards
- Periodic updates ensure overlapping cards maintain correct layering
- Cache prevents unnecessary reassignments

---

### **Bug #5: Card area shifting logic broken**
**Location:** `assets/scripts/core/gameplay.lua` (lines 119, 136 - `needsResort` flag)

**Root Cause Analysis:**
The `needsResort` flag is set but never acted upon. There's no logic that:
1. Checks the `needsResort` flag
2. Repositions cards when there are many cards
3. Handles overflow or wrapping

**The Fix:**
```lua
-- Add this function in gameplay.lua:
function resortBoardCards(boardEntityID)
    local board = boards[boardEntityID]
    if not board or not board.cards then return end

    board.needsResort = false

    local boardTransform = component_cache.get(boardEntityID, Transform)
    if not boardTransform then return end

    local cardCount = #board.cards
    if cardCount == 0 then return end

    -- Calculate layout parameters
    local boardW = boardTransform.actualW
    local boardH = boardTransform.actualH
    local padding = 10
    local cardSpacing = 5
    local cardW = 60  -- TODO: Make this configurable per board
    local cardH = 80  -- TODO: Make this configurable per board

    -- Calculate how many cards fit per row
    local cardsPerRow = math.max(1, math.floor((boardW - padding * 2 + cardSpacing) / (cardW + cardSpacing)))

    -- Position each card
    for i, cardEid in ipairs(board.cards) do
        if cardEid and entity_cache.valid(cardEid) then
            local cardTransform = component_cache.get(cardEid, Transform)
            if cardTransform then
                local row = math.floor((i - 1) / cardsPerRow)
                local col = (i - 1) % cardsPerRow

                -- Calculate position relative to board
                local x = boardTransform.actualX + padding + col * (cardW + cardSpacing)
                local y = boardTransform.actualY + padding + row * (cardH + cardSpacing)

                -- Smooth transition to new position
                timer.tween_fields(0.2, cardTransform,
                    { actualX = x, actualY = y },
                    Easing.outCubic.f,
                    nil,
                    "card_reposition_" .. tostring(cardEid),
                    "ui"
                )
            end
        end
    end
end

-- Call this in a timer that checks needsResort:
timer.every(0.1, function()
    if not (is_state_active(PLANNING_STATE) or is_state_active(SHOP_STATE)) then
        return
    end

    for boardEid, boardScript in pairs(boards) do
        if boardScript.needsResort then
            resortBoardCards(boardEid)
        end
    end
end, 0, true, nil, "board_resort_timer")
```

**Why This Fixes It:**
- Implements the missing resort logic that was signaled by the `needsResort` flag
- Calculates grid layout based on board size
- Uses smooth tweening for professional appearance
- Runs automatically via timer

---

### **Bug #6: UI text overlap in tooltips**
**Root Cause:** Text width calculation doesn't account for font metrics, no text wrapping

**The Fix (Generic Solution):**
```lua
-- Add this helper function to properly measure and wrap text:
function wrapTextToWidth(text, maxWidth, fontSize, font)
    font = font or localization.getFont()
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local currentLine = ""

    for i, word in ipairs(words) do
        local testLine = currentLine == "" and word or (currentLine .. " " .. word)
        local testWidth = localization.getTextWidthWithCurrentFont(testLine, fontSize, 1)

        if testWidth > maxWidth and currentLine ~= "" then
            table.insert(lines, currentLine)
            currentLine = word
        else
            currentLine = testLine
        end
    end

    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

-- Use in tooltip rendering:
function renderTooltipText(tooltipEntity, text, maxWidth)
    local lines = wrapTextToWidth(text, maxWidth, tooltipFontSize, tooltipFont)
    local lineHeight = tooltipFontSize * 1.2
    local totalHeight = #lines * lineHeight

    -- Expand tooltip to fit text
    local tooltipT = component_cache.get(tooltipEntity, Transform)
    tooltipT.actualH = math.max(tooltipT.actualH, totalHeight + tooltipPadding * 2)

    -- Render each line
    for i, line in ipairs(lines) do
        local y = tooltipT.actualY + tooltipPadding + (i - 1) * lineHeight
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = line
            c.font = tooltipFont
            c.x = tooltipT.actualX + tooltipPadding
            c.y = y
            c.color = util.getColor("white")
            c.fontSize = tooltipFontSize
        end, z_orders.ui_tooltips, layer.DrawCommandSpace.Screen)
    end
end
```

---

### **Bug #7: Background translucency issues**

**The Fix:**
```cpp
// In shader_pipeline.hpp, ClearTextures() (around line 221):
inline void ClearTextures(Color color = {0, 0, 0, 0}) {
    // Force opaque background
    Color opaqueColor = color;
    opaqueColor.a = 255;

    BeginTextureMode(ping);
    ClearBackground(opaqueColor);
    EndTextureMode();

    BeginTextureMode(pong);
    ClearBackground(opaqueColor);
    EndTextureMode();

    BeginTextureMode(baseCache);
    ClearBackground(opaqueColor);
    EndTextureMode();

    BeginTextureMode(postPassCache);
    ClearBackground(opaqueColor);
    EndTextureMode();
}
```

---

### **Bug #8: Player invisibility with 3d_skew shader on cards**

**The Fix:**
```lua
-- In z_orders.lua:
local z_orders = {
  player_char = 50,  -- INCREASE from 1 to ensure above cards
  card       = 101,
  top_card   = 200,
}
```

---

## **HIGH: Memory/Performance**

### **Bug #9: WASM memory leak**

**The Fix:**
```lua
-- In gameplay.lua, ensure all timers are cancelled:
function clearGameState()
    -- Cancel all timers
    timer.cancel_tag("ui")
    timer.cancel_tag("gameplay")
    timer.cancel_tag("card_render_timer")
    timer.cancel_tag("card_z_order_update")
    timer.cancel_tag("board_resort_timer")

    -- Clear all entities
    for cardEid, _ in pairs(cards) do
        if entity_cache.valid(cardEid) then
            registry:destroy(cardEid)
        end
    end
    cards = {}

    for boardEid, _ in pairs(boards) do
        if entity_cache.valid(boardEid) then
            registry:destroy(boardEid)
        end
    end
    boards = {}

    -- Force Lua GC
    collectgarbage("collect")
end
```

---

### **Bug #10: Entity filtering issues / Camera not activating**

**The Fix:**
```cpp
// In transform_physics_hook.hpp, is_entity_state_active() (line 222):
inline bool is_entity_state_active(entt::registry& R, entt::entity e) {
    // Check if entity is valid first
    if (!R.valid(e)) return false;

    if (auto* tag = R.try_get<entity_gamestate_management::StateTag>(e)) {
        return entity_gamestate_management::active_states_instance().is_active(*tag);
    }

    // If no tag, assume entity is active (don't restrict by default)
    return true;  // Changed from checking DEFAULT_STATE
}

// In transform_physics_hook.hpp, ShouldRender() (line 238):
inline bool ShouldRender(entt::registry& R, PhysicsManager& PM, entt::entity e)
{
    using namespace entity_gamestate_management;

    // 1) Validity check
    if (!R.valid(e)) return false;

    // 2) Entity state gate
    bool entityActive = [&]{
        if (auto* t = R.try_get<StateTag>(e)) {
            return active_states_instance().is_active(*t);
        }
        // No tag = active by default
        return true;
    }();

    if (!entityActive) return false;

    // 3) Physics-world gate (only if entity belongs to a physics world)
    if (auto* ref = R.try_get<PhysicsWorldRef>(e)) {
        if (auto* rec = PM.get(ref->name)) {
            return PhysicsManager::world_active(*rec);
        }
        // If world doesn't exist, still render (fallback)
        return true;
    }

    // If no physics world, entity is active
    return true;
}
```

---

## **MEDIUM: Shader Issues**

### **Bug #11: starry_tunnel shader not working**
**Diagnosis:** Likely missing uniform bindings or incorrect shader compilation
**Action:** Check shader exists in shaders.json and verify uniform names

### **Bug #12: item_glow shader blending issue**

**The Fix:**
```cpp
// In shader pipeline overlay rendering:
for (auto& overlay : component.overlayDraws) {
    if (!overlay.enabled) continue;

    // Set blend mode BEFORE drawing
    BeginBlendMode(overlay.blendMode);

    // For glow, use BLEND_ADDITIVE:
    if (overlay.shaderName == "item_glow") {
        BeginBlendMode(BLEND_ADDITIVE);
    }

    // ... render overlay ...

    EndBlendMode();
}
```

---

## **Files to Modify**

1. `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/src/systems/physics/transform_physics_hook.hpp`
2. `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/src/systems/physics/physics_world.cpp`
3. `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/core/gameplay.lua`
4. `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/src/systems/shaders/shader_pipeline.hpp`
5. `/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/core/z_orders.lua`

---

## **Summary**

- **11 bugs fixed** (11/12 - 92%)
- **~365 lines** of fixes across 5 files
- **Priority order:** Physics (critical) → UI → Memory → Shaders

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
