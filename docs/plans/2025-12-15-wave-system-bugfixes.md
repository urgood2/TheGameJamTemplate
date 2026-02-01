# Wave System Bug Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix wave system enemies so they spawn with proper physics bodies, are recognized by the combat system, and integrate with existing game infrastructure.

**Architecture:** The wave system's `EnemyFactory` currently creates "visual-only" enemies. We need to add physics body creation, combat actor registration, enemy health UI state tracking, and state tag management to match the working enemy spawning pattern in `gameplay.lua:8626-8791`.

**Tech Stack:** Lua, EnTT ECS, Chipmunk physics (via `physics` module), Sol2 scripting bindings

---

## Summary of Issues

| Issue | Root Cause | Fix Location |
|-------|-----------|--------------|
| No physics bodies | Missing `physics.create_physics_for_transform()` | `enemy_factory.lua` |
| Not recognized as enemies | Missing `enemyHealthUiState[e]` registration | `enemy_factory.lua` |
| Missing state tags | No `add_state_tag(e, ACTION_STATE)` | `enemy_factory.lua` |
| Collision doesn't work | Missing collision mask updates | `enemy_factory.lua` |
| No shader rendering | Missing `ShaderPipelineComponent` | `enemy_factory.lua` |
| Movement ignores physics | Transform-based instead of steering-based | `enemy_factory.lua` + `enemies.lua` |

---

## Task 1: Add Physics Body Creation

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua:28-96`

**Step 1: Add physics module access at top of file**

Add after line 11 (after `local elite_modifiers = require("data.elite_modifiers")`):

```lua
-- Physics
local PhysicsManager = require("core.physics_manager")
```

**Step 2: Add physics body creation after transform setup (around line 95)**

Find this code block:
```lua
    -- Resize animation
    animation_system.resizeAnimationObjectsInEntityToFit(e, ctx.size[1], ctx.size[2])
```

Add AFTER it:

```lua
    -- Give physics body (CRITICAL: must match gameplay.lua pattern)
    local world = PhysicsManager.get_world("world")
    if world then
        local info = {
            shape = "rectangle",
            tag = "enemy",
            sensor = false,
            density = 1.0,
            inflate_px = -4
        }
        physics.create_physics_for_transform(
            registry,
            physics_manager_instance,
            e,
            "world",
            info
        )

        -- Update collision masks so enemies collide with player and other enemies
        physics.update_collision_masks_for(world, "enemy", { "player", "enemy", "bullet" })
        physics.update_collision_masks_for(world, "player", { "enemy" })
        physics.update_collision_masks_for(world, "bullet", { "enemy" })
    else
        print("[EnemyFactory] WARNING: Physics world not available!")
    end
```

**Step 3: Test manually**

Run game, trigger action phase, verify:
- Enemies have physics (check with ImGui physics debugger if available)
- Enemies collide with player instead of passing through

**Step 4: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "fix(wave): add physics body creation to enemy factory"
```

---

## Task 2: Add State Tag Management

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua:28-96`

**Step 1: Add state tag after entity creation (after line 37)**

Find this code:
```lua
    if not e or not entity_cache.valid(e) then
        log_warn("Failed to create enemy entity for: " .. enemy_type)
        return nil, nil
    end
```

Add AFTER it:

```lua
    -- Add state tag so enemy updates/renders during action phase
    add_state_tag(e, ACTION_STATE)
    remove_default_state_tag(e)
```

**Step 2: Test manually**

Run game, trigger action phase:
- Enemies should now be visible and updating
- Check that they disappear when action phase ends

**Step 3: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "fix(wave): add ACTION_STATE tag to wave enemies"
```

---

## Task 3: Add Shader Pipeline Component

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua`

**Step 1: Add shader pipeline after physics setup**

Find the physics setup block you added in Task 1, and add AFTER the `end` that closes the `if world then` block:

```lua
    -- Add shader pipeline for proper rendering
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        registry:emplace(e, shader_pipeline.ShaderPipelineComponent)
    end
```

**Step 2: Test manually**

Run game, verify enemies render with proper shaders (not just plain sprites).

**Step 3: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "fix(wave): add shader pipeline component to wave enemies"
```

---

## Task 4: Register Enemies with Health UI State

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua`

**Step 1: Add enemyHealthUiState registration**

This is CRITICAL for `isEnemyEntity()` to work, which is used by auto-aim and projectile targeting.

Find the signal emit near the end of `EnemyFactory.spawn()`:
```lua
    -- Emit spawned event
    signal.emit("enemy_spawned", e, ctx)
```

Add BEFORE it:

```lua
    -- Register in enemyHealthUiState (CRITICAL: required for isEnemyEntity() to work)
    -- This enables auto-aim, projectile targeting, and health bar display
    if _G.enemyHealthUiState then
        _G.enemyHealthUiState[e] = {
            actor = nil,  -- No combat actor yet, but entry needed for isEnemyEntity()
            visibleUntil = 0,
            -- Store our ctx for wave system health tracking
            wave_ctx = ctx,
        }
    end
```

**Step 2: Add cleanup on enemy death**

In `EnemyFactory.kill()`, add cleanup BEFORE `registry:destroy(e)`:

Find:
```lua
    -- Destroy entity
    if entity_cache.valid(e) then
        registry:destroy(e)
    end
```

Add BEFORE it:

```lua
    -- Remove from enemyHealthUiState
    if _G.enemyHealthUiState then
        _G.enemyHealthUiState[e] = nil
    end
```

**Step 3: Test manually**

Run game, fire projectiles at wave enemies:
- Auto-aim should now target wave enemies
- Projectiles should hit and damage them

**Step 4: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "fix(wave): register enemies in enemyHealthUiState for targeting"
```

---

## Task 5: Snap Visual Position to Actual Position

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua`

**Step 1: Add visual snap after transform setup**

Find:
```lua
    -- Set position
    local transform = component_cache.get(e, Transform)
    if transform then
        transform.actualX = position.x
        transform.actualY = position.y
        transform.actualW = ctx.size[1]
        transform.actualH = ctx.size[2]
    end
```

Add after the transform assignments (inside the `if transform then` block):

```lua
        -- Snap visual to actual (prevents interpolation from spawn point)
        transform.visualX = transform.actualX
        transform.visualY = transform.actualY
```

**Step 2: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua
git commit -m "fix(wave): snap enemy visual position on spawn"
```

---

## Task 6: Add Steering for Physics-Based Movement (Optional Enhancement)

**Files:**
- Modify: `assets/scripts/combat/enemy_factory.lua`
- Modify: `assets/scripts/data/enemies.lua`

**Context:** The current movement in `enemies.lua` uses direct transform manipulation (`transform.actualX = ...`). This works but ignores physics collisions. For full physics integration, we should use the `steering` system.

**Step 1: Add steering setup in enemy_factory.lua**

After the shader pipeline setup, add:

```lua
    -- Make steerable for physics-based movement (optional but recommended)
    if steering and steering.make_steerable then
        steering.make_steerable(registry, e, 3000.0, 30000.0, math.pi * 2.0, 2.0)
    end
```

**Step 2: Update movement helpers in wave_helpers.lua to use steering (OPTIONAL)**

This is a larger change. For now, the transform-based movement will work, but enemies will pass through walls. If physics-respecting movement is required, we need to refactor `WaveHelpers.move_toward_player()` etc. to use `physics.SetVelocity()` or `steering.seek_point()`.

**Simple physics velocity approach** - modify `wave_helpers.lua:47-61`:

```lua
function WaveHelpers.move_toward_player(e, speed)
    if not entity_cache.valid(e) then return end
    local transform = component_cache.get(e, Transform)
    if not transform then return end

    local player_pos = WaveHelpers.get_player_position()
    local dx = player_pos.x - transform.actualX
    local dy = player_pos.y - transform.actualY
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 1 then
        -- Use physics velocity instead of direct transform manipulation
        local world = PhysicsManager.get_world("world")
        if world and physics.SetVelocity then
            physics.SetVelocity(world, e, (dx / dist) * speed, (dy / dist) * speed)
        else
            -- Fallback to transform-based movement
            local dt = GetFrameTime()
            transform.actualX = transform.actualX + (dx / dist) * speed * dt
            transform.actualY = transform.actualY + (dy / dist) * speed * dt
        end
    end
end
```

**Step 3: Commit**

```bash
git add assets/scripts/combat/enemy_factory.lua assets/scripts/combat/wave_helpers.lua
git commit -m "feat(wave): add steering and physics-based movement option"
```

---

## Task 7: Integration Testing

**Step 1: Manual testing checklist**

Run the game and verify:

- [ ] Wave enemies spawn during action phase
- [ ] Enemies are visible (not invisible)
- [ ] Enemies have physics bodies (collide with player)
- [ ] `isEnemyEntity()` returns true for wave enemies
- [ ] Auto-aim targets wave enemies
- [ ] Projectiles damage wave enemies
- [ ] Enemies die when HP reaches 0
- [ ] Dead enemies are cleaned up properly
- [ ] Wave progresses when all enemies killed

**Step 2: Commit final state**

```bash
git add -A
git commit -m "test(wave): verify wave system integration complete"
```

---

## Final Checklist

After all tasks complete, the `EnemyFactory.spawn()` function should:

1. ✅ Create entity with `animation_system.createAnimatedObjectWithTransform()`
2. ✅ Add `ACTION_STATE` tag
3. ✅ Remove default state tag
4. ✅ Set transform position
5. ✅ Snap visual to actual position
6. ✅ Create physics body with `physics.create_physics_for_transform()`
7. ✅ Update collision masks
8. ✅ Add `ShaderPipelineComponent`
9. ✅ Register in `enemyHealthUiState`
10. ✅ Optionally add steering for physics-based movement

---

## Reference: Working Pattern from gameplay.lua:8626-8791

```lua
-- 1. Create entity
local enemyEntity = animation_system.createAnimatedObjectWithTransform("b1060.png", true)

-- 2. Add state tag
add_state_tag(enemyEntity, ACTION_STATE)
remove_default_state_tag(enemyEntity)

-- 3. Set position
local enemyTransform = component_cache.get(enemyEntity, Transform)
enemyTransform.actualX = ...
enemyTransform.actualY = ...

-- 4. Snap visual
enemyTransform.visualX = enemyTransform.actualX
enemyTransform.visualY = enemyTransform.actualY

-- 5. Physics
local info = { shape = "rectangle", tag = "enemy", sensor = false, density = 1.0, inflate_px = -4 }
physics.create_physics_for_transform(registry, physics_manager_instance, enemyEntity, "world", info)

-- 6. Shader pipeline
registry:emplace(enemyEntity, shader_pipeline.ShaderPipelineComponent)

-- 7. Collision masks
physics.update_collision_masks_for(PhysicsManager.get_world("world"), "enemy", { "player", "enemy" })

-- 8. Steering
steering.make_steerable(registry, enemyEntity, 3000.0, 30000.0, math.pi * 2.0, 2.0)

-- 9. Script node + combat actor
local enemyScriptNode = Node {}
enemyScriptNode.combatTable = ogre
enemyScriptNode:attach_ecs { create_new = false, existing_entity = enemyEntity }

-- 10. Health UI state
enemyHealthUiState[enemyEntity] = { actor = ogre, visibleUntil = 0 }
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
