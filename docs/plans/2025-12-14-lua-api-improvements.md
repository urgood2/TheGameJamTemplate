# Lua API Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce Lua boilerplate by 40-60% through new builder APIs, promote existing helpers, and improve discoverability.

**Architecture:** Create fluent builder patterns (EntityBuilder, PhysicsBuilder) following the successful ShaderBuilder model. Add options-table variants to timer.lua for better ergonomics while maintaining backward compatibility. Promote existing utility functions to global scope for easier access.

**Tech Stack:** Pure Lua, follows existing module patterns (singleton with `_G` registration)

---

## Design Principle: Non-Rigid APIs

**CRITICAL:** These builders are **convenience layers**, not **gatekeepers**. Users must be able to:

1. **Escape at any point** - Access the raw entity/components mid-chain
2. **Mix builder + manual** - Use builder for common setup, then manual for edge cases
3. **Never lose access** - All underlying APIs remain accessible
4. **Return raw objects** - Functions return entity IDs and components, not opaque wrappers

### Example: Mixing Builder with Manual Operations

```lua
-- Builder handles common stuff...
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { 100, 200 },
    size = { 64, 64 },
    data = { health = 100 }
})

-- ...then manual for edge cases the builder doesn't cover
local transform = component_cache.get(entity, Transform)
transform.actualR = math.rad(45)  -- rotation not in builder

local nodeComp = registry:get(entity, GameObject)
nodeComp.methods.onCustomEvent = function() ... end  -- custom callback

-- Physics builder, then escape for manual tweaks
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :apply()

-- Manual physics calls for advanced features
local world = PhysicsManager.get_world("world")
physics.SetLinearDamping(world, entity, 0.5)  -- not in builder
```

### Escape Hatch Methods

Each builder provides explicit escape hatches:

```lua
-- EntityBuilder: returns (entity, script) - both raw objects
local entity, script = EntityBuilder.create({ ... })
-- entity is a raw EnTT entity ID
-- script is the raw script table

-- PhysicsBuilder: getEntity() returns raw entity mid-chain
local builder = PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
local eid = builder:getEntity()  -- escape hatch
builder:apply()
```

### What NOT to Do

```lua
-- DON'T: Hide functionality behind "blessed" methods only
-- DON'T: Return opaque wrapper objects that can't be used with other APIs
-- DON'T: Require users to use builder for ALL operations on an entity
-- DON'T: Prevent access to underlying registry/components
```

---

## Overview

| Task | Description | Impact | New File? |
|------|-------------|--------|-----------|
| 1 | EntityBuilder - fluent entity creation | HIGH - eliminates 15-30 line patterns | Yes |
| 2 | PhysicsBuilder - fluent physics setup | MEDIUM - eliminates 10-15 line patterns | Yes |
| 3 | Timer options-table variants | MEDIUM - better ergonomics | Modify |
| 4 | Promote helpers to global scope | HIGH - enables adoption | Modify |
| 5 | Imports bundle module | LOW - cleaner requires | Yes |
| 6 | Update CLAUDE.md documentation | MEDIUM - discoverability | Modify |

---

## Task 1: EntityBuilder - Fluent Entity Creation API

**Files:**
- Create: `assets/scripts/core/entity_builder.lua`
- Test manually in-game (no unit test file for Lua)

### Step 1: Create the EntityBuilder module

Create `assets/scripts/core/entity_builder.lua`:

```lua
--[[
================================================================================
ENTITY BUILDER - Fluent API for Entity Creation
================================================================================
Reduces 15-30 line entity creation patterns to 3-5 lines.

DESIGN PRINCIPLE: Non-rigid API
- All methods return raw objects (entity IDs, components), not opaque wrappers
- Escape hatches available at every step (getEntity, getTransform, getScript)
- Mix builder + manual operations freely
- Builder never prevents access to underlying APIs

Usage (static):
    local entity, script = EntityBuilder.create({
        sprite = "kobold",
        position = { x = 100, y = 200 },
        size = { 64, 64 },
        data = { health = 100 }
    })
    -- entity is raw EnTT ID, script is raw table
    -- Continue with manual operations:
    local transform = component_cache.get(entity, Transform)
    transform.actualR = math.rad(45)

Usage (fluent):
    local builder = EntityBuilder.new("kobold")
        :at(100, 200)
        :size(64, 64)
        :withData({ health = 100 })

    -- Escape hatch: get entity before finishing
    local eid = builder:getEntity()

    -- Continue building
    builder:withHover("Title", "Body")
        :build()

Dependencies:
    - animation_system (C++ binding)
    - registry (global ECS registry)
    - entity_cache, component_cache
    - monobehavior.behavior_script_v2 (Node)
]]

-- Singleton guard
if _G.__ENTITY_BUILDER__ then
    return _G.__ENTITY_BUILDER__
end

local EntityBuilder = {}

-- Dependencies
local animation_system = _G.animation_system
local registry = _G.registry
local entity_cache = require("core.entity_cache")
local component_cache = require("core.component_cache")
local Node = require("monobehavior.behavior_script_v2")

-- Optional dependencies (may not exist in all contexts)
local showSimpleTooltipAbove = _G.showSimpleTooltipAbove
local hideSimpleTooltip = _G.hideSimpleTooltip
local add_state_tag = _G.add_state_tag

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------

EntityBuilder.DEFAULTS = {
    size = { 32, 32 },
    shadow = false,
    fromSprite = true,  -- true = animation, false = sprite identifier
}

--------------------------------------------------------------------------------
-- PRIVATE HELPERS
--------------------------------------------------------------------------------

local function setup_tooltip(entity, nodeComp, hover)
    if not hover then return end
    if not showSimpleTooltipAbove or not hideSimpleTooltip then
        log_warn("EntityBuilder: tooltip functions not available")
        return
    end

    local tooltipId = hover.id or ("tooltip_" .. tostring(entity))
    local title = hover.title or ""
    local body = hover.body or ""

    nodeComp.methods.onHover = function()
        showSimpleTooltipAbove(tooltipId, title, body, entity)
    end
    nodeComp.methods.onStopHover = function()
        hideSimpleTooltip(tooltipId)
    end
end

local function setup_interactions(entity, nodeComp, interactive)
    if not interactive then return end

    local state = nodeComp.state

    -- Enable interaction modes based on provided callbacks
    if interactive.hover then
        state.hoverEnabled = true
        setup_tooltip(entity, nodeComp, interactive.hover)
    end

    if interactive.click then
        state.clickEnabled = true
        nodeComp.methods.onClick = interactive.click
    end

    if interactive.drag then
        state.dragEnabled = true
        if type(interactive.drag) == "function" then
            nodeComp.methods.onDrag = interactive.drag
        end
    end

    if interactive.stopDrag then
        nodeComp.methods.onStopDrag = interactive.stopDrag
    end

    if interactive.collision ~= nil then
        state.collisionEnabled = interactive.collision
    end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create an entity with all common setup in one call.
--- @param opts table Configuration options
--- @return number entity The created entity ID
--- @return table script The script table (if data provided)
function EntityBuilder.create(opts)
    opts = opts or {}

    -- Extract options with defaults
    local sprite = opts.sprite
    local fromSprite = opts.fromSprite ~= false  -- default true
    local x = opts.x or (opts.position and opts.position.x) or (opts.position and opts.position[1]) or 0
    local y = opts.y or (opts.position and opts.position.y) or (opts.position and opts.position[2]) or 0
    local w = (opts.size and opts.size[1]) or (opts.size and opts.size.w) or EntityBuilder.DEFAULTS.size[1]
    local h = (opts.size and opts.size[2]) or (opts.size and opts.size.h) or EntityBuilder.DEFAULTS.size[2]
    local shadow = opts.shadow or EntityBuilder.DEFAULTS.shadow
    local data = opts.data
    local interactive = opts.interactive
    local state = opts.state
    local shaders = opts.shaders

    -- Create entity
    local entity
    if sprite and animation_system then
        entity = animation_system.createAnimatedObjectWithTransform(
            sprite,
            fromSprite,
            x,
            y,
            nil,  -- shader pass
            shadow
        )

        -- Resize if size provided
        if opts.size then
            animation_system.resizeAnimationObjectsInEntityToFit(entity, w, h)
        end
    else
        -- Fallback: create raw entity
        entity = registry:create()
        local transform = registry:emplace(entity, Transform)
        transform.actualX = x
        transform.actualY = y
        transform.actualW = w
        transform.actualH = h
    end

    -- Initialize script table if data provided
    local script = nil
    if data then
        local EntityType = Node:extend()
        script = EntityType {}

        -- CRITICAL: Assign data BEFORE attach_ecs per CLAUDE.md
        for k, v in pairs(data) do
            script[k] = v
        end

        script:attach_ecs { create_new = false, existing_entity = entity }
    end

    -- Set up interactions
    if interactive then
        local nodeComp = registry:get(entity, GameObject)
        if nodeComp then
            setup_interactions(entity, nodeComp, interactive)
        end
    end

    -- Add state tag
    if state and add_state_tag then
        add_state_tag(entity, state)
    end

    -- Apply shaders
    if shaders then
        local ShaderBuilder = require("core.shader_builder")
        local builder = ShaderBuilder.for_entity(entity)
        for _, shader in ipairs(shaders) do
            if type(shader) == "string" then
                builder:add(shader)
            elseif type(shader) == "table" then
                builder:add(shader[1], shader[2])
            end
        end
        builder:apply()
    end

    return entity, script
end

--- Create an entity with only position and size (minimal version)
--- @param sprite string Sprite/animation ID
--- @param x number X position
--- @param y number Y position
--- @param w number? Width (default 32)
--- @param h number? Height (default 32)
--- @return number entity The created entity ID
function EntityBuilder.simple(sprite, x, y, w, h)
    return EntityBuilder.create({
        sprite = sprite,
        x = x,
        y = y,
        size = { w or 32, h or 32 }
    })
end

--- Create an interactive entity with hover tooltip
--- @param opts table Options including sprite, position, size, hover
--- @return number entity
--- @return table script
function EntityBuilder.interactive(opts)
    -- Ensure interactive is set
    opts.interactive = opts.interactive or {}
    if opts.hover then
        opts.interactive.hover = opts.hover
        opts.hover = nil
    end
    if opts.click then
        opts.interactive.click = opts.click
        opts.click = nil
    end
    return EntityBuilder.create(opts)
end

--------------------------------------------------------------------------------
-- FLUENT BUILDER INSTANCE (Alternative API)
--------------------------------------------------------------------------------
-- For users who prefer method chaining over options tables.
-- Provides escape hatches at every step.

local BuilderInstance = {}
BuilderInstance.__index = BuilderInstance

--- Create a new fluent builder
--- @param sprite string? Sprite/animation ID (optional, can set later)
--- @return table Builder instance
function EntityBuilder.new(sprite)
    local self = setmetatable({}, BuilderInstance)
    self._opts = {
        sprite = sprite,
        size = { 32, 32 },
        position = { 0, 0 },
    }
    self._entity = nil  -- created lazily or on build()
    self._script = nil
    return self
end

-- Chainable setters
function BuilderInstance:sprite(s) self._opts.sprite = s; return self end
function BuilderInstance:at(x, y) self._opts.position = { x, y }; return self end
function BuilderInstance:size(w, h) self._opts.size = { w, h }; return self end
function BuilderInstance:shadow(v) self._opts.shadow = v ~= false; return self end
function BuilderInstance:withData(data) self._opts.data = data; return self end
function BuilderInstance:withState(state) self._opts.state = state; return self end
function BuilderInstance:withShaders(shaders) self._opts.shaders = shaders; return self end

function BuilderInstance:withHover(title, body, id)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.hover = { title = title, body = body, id = id }
    return self
end

function BuilderInstance:onClick(fn)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.click = fn
    return self
end

function BuilderInstance:onDrag(fn)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.drag = fn or true
    return self
end

function BuilderInstance:withCollision(enabled)
    self._opts.interactive = self._opts.interactive or {}
    self._opts.interactive.collision = enabled ~= false
    return self
end

--------------------------------------------------------------------------------
-- ESCAPE HATCHES - Access raw objects at any point
--------------------------------------------------------------------------------

--- Get the entity ID (creates entity if not yet created)
--- ESCAPE HATCH: Use this to access the raw entity for manual operations
--- @return number entity Raw EnTT entity ID
function BuilderInstance:getEntity()
    if not self._entity then
        self._entity, self._script = EntityBuilder.create(self._opts)
    end
    return self._entity
end

--- Get the Transform component
--- ESCAPE HATCH: Direct access to transform for manual modifications
--- @return userdata|nil Transform component
function BuilderInstance:getTransform()
    local eid = self:getEntity()
    return component_cache.get(eid, Transform)
end

--- Get the GameObject component
--- ESCAPE HATCH: Direct access to GameObject for custom callbacks
--- @return userdata|nil GameObject component
function BuilderInstance:getGameObject()
    local eid = self:getEntity()
    return registry:get(eid, GameObject)
end

--- Get the script table
--- ESCAPE HATCH: Direct access to script for custom data
--- @return table|nil Script table
function BuilderInstance:getScript()
    self:getEntity()  -- ensure created
    return self._script
end

--------------------------------------------------------------------------------
-- BUILD - Finalize and return raw objects
--------------------------------------------------------------------------------

--- Build the entity and return raw objects
--- @return number entity Raw EnTT entity ID
--- @return table|nil script Raw script table
function BuilderInstance:build()
    local eid = self:getEntity()
    return eid, self._script
end

_G.__ENTITY_BUILDER__ = EntityBuilder
return EntityBuilder
```

### Step 2: Verify syntax is valid

Run: `luac -p assets/scripts/core/entity_builder.lua`

Expected: No output (success) or syntax errors to fix.

### Step 3: Commit

```bash
git add assets/scripts/core/entity_builder.lua
git commit -m "feat(lua): add EntityBuilder fluent API for entity creation

Reduces 15-30 line entity creation patterns to 3-5 lines.
Follows ShaderBuilder pattern with options table.

Usage:
  local entity, script = EntityBuilder.create({
      sprite = 'kobold',
      position = { x = 100, y = 200 },
      size = { 64, 64 },
      data = { health = 100 },
      interactive = { hover = { title = 'Enemy', body = 'desc' } }
  })

$(cat <<'EOF'
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: PhysicsBuilder - Fluent Physics Setup API

**Files:**
- Create: `assets/scripts/core/physics_builder.lua`

### Step 1: Create the PhysicsBuilder module

Create `assets/scripts/core/physics_builder.lua`:

```lua
--[[
================================================================================
PHYSICS BUILDER - Fluent API for Physics Body Setup
================================================================================
Reduces 10-15 line physics setup patterns to 3-5 lines.

DESIGN PRINCIPLE: Non-rigid API
- Escape hatches: getEntity(), getWorld(), getConfig()
- Returns raw objects, not opaque wrappers
- Mix builder + manual operations freely

Usage:
    PhysicsBuilder.for_entity(entity)
        :circle()
        :tag("projectile")
        :bullet()
        :friction(0)
        :collideWith({ "enemy", "WORLD" })
        :apply()

Escape Hatches:
    local builder = PhysicsBuilder.for_entity(entity):circle():tag("proj")

    -- Get raw world for manual operations
    local world = builder:getWorld()
    physics.SetLinearDamping(world, builder:getEntity(), 0.5)

    -- Then continue with builder
    builder:apply()

Dependencies:
    - physics (C++ binding)
    - PhysicsManager (Lua module)
    - registry (global ECS registry)
]]

-- Singleton guard
if _G.__PHYSICS_BUILDER__ then
    return _G.__PHYSICS_BUILDER__
end

local PhysicsBuilder = {}

-- Dependencies
local registry = _G.registry
local physics = _G.physics
local physics_manager_instance = _G.physics_manager_instance
local entity_cache = require("core.entity_cache")

-- Lazy-load PhysicsManager to avoid circular dependency
local PhysicsManager

--------------------------------------------------------------------------------
-- DEFAULTS
--------------------------------------------------------------------------------

PhysicsBuilder.DEFAULTS = {
    shape = "circle",
    tag = "default",
    sensor = false,
    density = 1.0,
    friction = 0.3,
    restitution = 0.0,
    bullet = false,
    fixedRotation = false,
    syncMode = "physics",  -- "physics" or "transform"
    worldName = "world",
}

--------------------------------------------------------------------------------
-- BUILDER INSTANCE
--------------------------------------------------------------------------------

local BuilderMethods = {}
BuilderMethods.__index = BuilderMethods

function BuilderMethods:shape(shape)
    self._shape = shape
    return self
end

function BuilderMethods:circle()
    self._shape = "circle"
    return self
end

function BuilderMethods:rectangle()
    self._shape = "rectangle"
    return self
end

function BuilderMethods:tag(t)
    self._tag = t
    return self
end

function BuilderMethods:sensor(v)
    self._sensor = v ~= false
    return self
end

function BuilderMethods:density(v)
    self._density = v
    return self
end

function BuilderMethods:friction(v)
    self._friction = v
    return self
end

function BuilderMethods:restitution(v)
    self._restitution = v
    return self
end

function BuilderMethods:bullet(v)
    self._bullet = v ~= false
    return self
end

function BuilderMethods:fixedRotation(v)
    self._fixedRotation = v ~= false
    return self
end

function BuilderMethods:syncMode(mode)
    self._syncMode = mode
    return self
end

function BuilderMethods:world(name)
    self._worldName = name
    return self
end

function BuilderMethods:collideWith(tags)
    if type(tags) == "string" then
        tags = { tags }
    end
    self._collideWith = tags
    return self
end

--------------------------------------------------------------------------------
-- ESCAPE HATCHES - Access raw objects at any point
--------------------------------------------------------------------------------

--- Get the entity ID
--- ESCAPE HATCH: Use for manual physics operations not covered by builder
--- @return number entity Raw EnTT entity ID
function BuilderMethods:getEntity()
    return self._entity
end

--- Get the physics world (lazy-loaded)
--- ESCAPE HATCH: Use for advanced physics operations
--- @return userdata|nil world The physics world object
function BuilderMethods:getWorld()
    if not PhysicsManager then
        local ok, pm = pcall(require, "core.physics_manager")
        if ok then PhysicsManager = pm end
    end
    if PhysicsManager and PhysicsManager.get_world then
        return PhysicsManager.get_world(self._worldName)
    end
    return nil
end

--- Get the current configuration (before apply)
--- ESCAPE HATCH: Inspect or modify config before applying
--- @return table config Copy of current configuration
function BuilderMethods:getConfig()
    return {
        shape = self._shape,
        tag = self._tag,
        sensor = self._sensor,
        density = self._density,
        friction = self._friction,
        restitution = self._restitution,
        bullet = self._bullet,
        fixedRotation = self._fixedRotation,
        syncMode = self._syncMode,
        worldName = self._worldName,
        collideWith = self._collideWith,
    }
end

function BuilderMethods:apply()
    -- Lazy load PhysicsManager
    if not PhysicsManager then
        local ok, pm = pcall(require, "core.physics_manager")
        if ok then
            PhysicsManager = pm
        end
    end

    -- Get physics world
    local world
    if PhysicsManager and PhysicsManager.get_world then
        world = PhysicsManager.get_world(self._worldName)
    end

    if not world then
        log_warn("PhysicsBuilder: physics world '" .. self._worldName .. "' not available")
        return false
    end

    if not physics then
        log_warn("PhysicsBuilder: physics module not available")
        return false
    end

    -- Create physics body
    local config = {
        shape = self._shape,
        tag = self._tag,
        sensor = self._sensor,
        density = self._density,
    }

    physics.create_physics_for_transform(
        registry,
        physics_manager_instance,
        self._entity,
        self._worldName,
        config
    )

    -- Set physics properties
    if self._bullet then
        physics.SetBullet(world, self._entity, true)
    end

    if self._friction ~= nil then
        physics.SetFriction(world, self._entity, self._friction)
    end

    if self._restitution ~= nil then
        physics.SetRestitution(world, self._entity, self._restitution)
    end

    if self._fixedRotation then
        physics.SetFixedRotation(world, self._entity, true)
    end

    -- Set sync mode
    if self._syncMode and physics.PhysicsSyncMode then
        local syncModes = {
            physics = physics.PhysicsSyncMode.AuthoritativePhysics,
            transform = physics.PhysicsSyncMode.AuthoritativeTransform,
        }
        local mode = syncModes[self._syncMode]
        if mode then
            physics.set_sync_mode(registry, self._entity, mode)
        end
    end

    -- Set up collision masks
    if self._collideWith and #self._collideWith > 0 then
        for _, targetTag in ipairs(self._collideWith) do
            physics.enable_collision_between_many(world, self._tag, { targetTag })
            physics.update_collision_masks_for(world, self._tag, { targetTag })
        end
    end

    return true
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Create a builder for the given entity
--- @param entity number Entity ID
--- @return table Builder instance with fluent API
function PhysicsBuilder.for_entity(entity)
    if not entity_cache.valid(entity) then
        error("PhysicsBuilder.for_entity: invalid entity")
    end

    local self = setmetatable({}, BuilderMethods)

    -- Set defaults
    self._entity = entity
    self._shape = PhysicsBuilder.DEFAULTS.shape
    self._tag = PhysicsBuilder.DEFAULTS.tag
    self._sensor = PhysicsBuilder.DEFAULTS.sensor
    self._density = PhysicsBuilder.DEFAULTS.density
    self._friction = PhysicsBuilder.DEFAULTS.friction
    self._restitution = PhysicsBuilder.DEFAULTS.restitution
    self._bullet = PhysicsBuilder.DEFAULTS.bullet
    self._fixedRotation = PhysicsBuilder.DEFAULTS.fixedRotation
    self._syncMode = PhysicsBuilder.DEFAULTS.syncMode
    self._worldName = PhysicsBuilder.DEFAULTS.worldName
    self._collideWith = {}

    return self
end

--- Quick physics setup with common options
--- @param entity number Entity ID
--- @param opts table Options { shape, tag, bullet, collideWith, ... }
--- @return boolean success
function PhysicsBuilder.quick(entity, opts)
    opts = opts or {}
    local builder = PhysicsBuilder.for_entity(entity)

    if opts.shape then builder:shape(opts.shape) end
    if opts.tag then builder:tag(opts.tag) end
    if opts.sensor ~= nil then builder:sensor(opts.sensor) end
    if opts.density then builder:density(opts.density) end
    if opts.friction then builder:friction(opts.friction) end
    if opts.restitution then builder:restitution(opts.restitution) end
    if opts.bullet then builder:bullet(opts.bullet) end
    if opts.fixedRotation then builder:fixedRotation(opts.fixedRotation) end
    if opts.syncMode then builder:syncMode(opts.syncMode) end
    if opts.collideWith then builder:collideWith(opts.collideWith) end

    return builder:apply()
end

_G.__PHYSICS_BUILDER__ = PhysicsBuilder
return PhysicsBuilder
```

### Step 2: Verify syntax

Run: `luac -p assets/scripts/core/physics_builder.lua`

Expected: No output (success)

### Step 3: Commit

```bash
git add assets/scripts/core/physics_builder.lua
git commit -m "feat(lua): add PhysicsBuilder fluent API for physics setup

Reduces 10-15 line physics setup patterns to 3-5 lines.

Usage:
  PhysicsBuilder.for_entity(entity)
      :circle()
      :tag('projectile')
      :bullet()
      :collideWith({ 'enemy', 'WORLD' })
      :apply()

$(cat <<'EOF'
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Timer Options-Table Variants

**Files:**
- Modify: `assets/scripts/core/timer.lua`

### Step 1: Add options-table variants to timer.lua

Add the following functions after the existing `timer.every` function (around line 128):

```lua
--------------------------------------------------------
-- Options-Table API (Ergonomic alternatives)
--------------------------------------------------------

--- Options-table variant of timer.after
--- @param opts table { delay, action, tag?, group? }
--- @return string tag The timer tag
function timer.after_opts(opts)
    assert(opts.delay, "timer.after_opts: delay required")
    assert(opts.action, "timer.after_opts: action required")
    return timer.after(opts.delay, opts.action, opts.tag, opts.group)
end

--- Options-table variant of timer.every
--- @param opts table { delay, action, times?, immediate?, after?, tag?, group? }
--- @return string tag The timer tag
function timer.every_opts(opts)
    assert(opts.delay, "timer.every_opts: delay required")
    assert(opts.action, "timer.every_opts: action required")
    return timer.every(
        opts.delay,
        opts.action,
        opts.times or 0,
        opts.immediate or false,
        opts.after,
        opts.tag,
        opts.group
    )
end

--- Options-table variant of timer.cooldown
--- @param opts table { delay, condition, action, times?, after?, tag?, group? }
--- @return string tag The timer tag
function timer.cooldown_opts(opts)
    assert(opts.delay, "timer.cooldown_opts: delay required")
    assert(opts.condition, "timer.cooldown_opts: condition required")
    assert(opts.action, "timer.cooldown_opts: action required")
    return timer.cooldown(
        opts.delay,
        opts.condition,
        opts.action,
        opts.times or 0,
        opts.after,
        opts.tag,
        opts.group
    )
end

--- Options-table variant of timer.for_time
--- @param opts table { delay, action, after?, tag?, group? }
--- @return string tag The timer tag
function timer.for_time_opts(opts)
    assert(opts.delay, "timer.for_time_opts: delay required")
    assert(opts.action, "timer.for_time_opts: action required")
    return timer.for_time(opts.delay, opts.action, opts.after, opts.tag, opts.group)
end
```

### Step 2: Add convenience wrapper for timer.sequence

Add after the options-table variants:

```lua
--- Create a new TimerChain for fluent sequential timing
--- Convenience wrapper for require("core.timer_chain").new()
--- @param group string? Optional group name
--- @return TimerChain
function timer.sequence(group)
    local TimerChain = require("core.timer_chain")
    return TimerChain.new(group)
end
```

### Step 3: Verify syntax

Run: `luac -p assets/scripts/core/timer.lua`

Expected: No output (success)

### Step 4: Commit

```bash
git add assets/scripts/core/timer.lua
git commit -m "feat(lua): add options-table variants to timer API

Adds ergonomic alternatives that use named parameters:
- timer.after_opts({ delay, action, tag?, group? })
- timer.every_opts({ delay, action, times?, immediate?, after?, tag?, group? })
- timer.cooldown_opts({ delay, condition, action, ... })
- timer.for_time_opts({ delay, action, after?, ... })
- timer.sequence(group) - convenience wrapper for TimerChain

$(cat <<'EOF'
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Promote Helper Functions to Global Scope

**Files:**
- Modify: `assets/scripts/util/util.lua`

### Step 1: Add global exports at the end of util.lua

Find the end of the file and add global exports:

```lua
--------------------------------------------------------
-- GLOBAL EXPORTS
--------------------------------------------------------
-- These helpers are used frequently enough to warrant global access.
-- See CLAUDE.md for documentation on each function.

_G.ensure_entity = ensure_entity
_G.ensure_scripted_entity = ensure_scripted_entity
_G.safe_script_get = safe_script_get
_G.script_field = script_field

-- Re-export getScriptTableFromEntityID (already global, but ensure it)
if not _G.getScriptTableFromEntityID then
    _G.getScriptTableFromEntityID = getScriptTableFromEntityID
end
```

### Step 2: Verify syntax

Run: `luac -p assets/scripts/util/util.lua`

Expected: No output (success)

### Step 3: Commit

```bash
git add assets/scripts/util/util.lua
git commit -m "feat(lua): promote entity validation helpers to global scope

Exports to global:
- ensure_entity(eid) - validates entity exists and is valid
- ensure_scripted_entity(eid) - validates entity has script component
- safe_script_get(eid, warn?) - safely gets script table
- script_field(eid, field, default) - safely gets script field

These were already defined but rarely used. Global access encourages adoption.

$(cat <<'EOF'
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Create Imports Bundle Module

**Files:**
- Create: `assets/scripts/core/imports.lua`

### Step 1: Create imports.lua

Create `assets/scripts/core/imports.lua`:

```lua
--[[
================================================================================
IMPORTS - Common Module Bundles
================================================================================
Reduces repetitive require blocks at the top of files.

Usage:
    local imports = require("core.imports")

    -- Core bundle (most common)
    local component_cache, entity_cache, timer, signal, z_orders = imports.core()

    -- Entity creation bundle
    local Node, animation_system, EntityBuilder = imports.entity()

    -- Physics bundle
    local PhysicsManager, PhysicsBuilder = imports.physics()

    -- Full bundle (everything)
    local i = imports.all()
    -- Access: i.timer, i.signal, i.EntityBuilder, etc.
]]

local imports = {}

--- Core utilities bundle (5 modules)
--- @return table component_cache
--- @return table entity_cache
--- @return table timer
--- @return table signal
--- @return table z_orders
function imports.core()
    return
        require("core.component_cache"),
        require("core.entity_cache"),
        require("core.timer"),
        require("external.hump.signal"),
        require("core.z_orders")
end

--- Entity creation bundle (3 modules)
--- @return table Node (behavior_script_v2)
--- @return table animation_system (may be nil if not available)
--- @return table EntityBuilder
function imports.entity()
    return
        require("monobehavior.behavior_script_v2"),
        _G.animation_system,
        require("core.entity_builder")
end

--- Physics bundle (2 modules)
--- @return table|nil PhysicsManager
--- @return table PhysicsBuilder
function imports.physics()
    local PhysicsManager
    pcall(function()
        PhysicsManager = require("core.physics_manager")
    end)
    return
        PhysicsManager,
        require("core.physics_builder")
end

--- UI bundle (3 modules)
--- @return table dsl (ui_syntax_sugar)
--- @return table z_orders
--- @return table util
function imports.ui()
    return
        require("ui.ui_syntax_sugar"),
        require("core.z_orders"),
        require("util.util")
end

--- Shader bundle (2 modules)
--- @return table ShaderBuilder
--- @return table draw
function imports.shaders()
    return
        require("core.shader_builder"),
        require("core.draw")
end

--- All common modules as a single table
--- @return table All imports keyed by name
function imports.all()
    local component_cache, entity_cache, timer, signal, z_orders = imports.core()
    local Node, animation_system, EntityBuilder = imports.entity()
    local PhysicsManager, PhysicsBuilder = imports.physics()

    return {
        -- Core
        component_cache = component_cache,
        entity_cache = entity_cache,
        timer = timer,
        signal = signal,
        z_orders = z_orders,

        -- Entity
        Node = Node,
        animation_system = animation_system,
        EntityBuilder = EntityBuilder,

        -- Physics
        PhysicsManager = PhysicsManager,
        PhysicsBuilder = PhysicsBuilder,
    }
end

return imports
```

### Step 2: Verify syntax

Run: `luac -p assets/scripts/core/imports.lua`

Expected: No output (success)

### Step 3: Commit

```bash
git add assets/scripts/core/imports.lua
git commit -m "feat(lua): add imports.lua module bundle for cleaner requires

Provides bundled imports for common module combinations:
- imports.core() - component_cache, entity_cache, timer, signal, z_orders
- imports.entity() - Node, animation_system, EntityBuilder
- imports.physics() - PhysicsManager, PhysicsBuilder
- imports.ui() - dsl, z_orders, util
- imports.shaders() - ShaderBuilder, draw
- imports.all() - everything as a keyed table

$(cat <<'EOF'
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Update CLAUDE.md Documentation

**Files:**
- Modify: `CLAUDE.md`

### Step 1: Add new API documentation sections

Add the following sections to CLAUDE.md after the existing "Shader Builder API" section:

```markdown
---

## Entity Builder API

### Fluent Entity Creation

```lua
local EntityBuilder = require("core.entity_builder")

-- Full options
local entity, script = EntityBuilder.create({
    sprite = "kobold",
    position = { x = 100, y = 200 },  -- or { 100, 200 }
    size = { 64, 64 },
    shadow = true,
    data = { health = 100, faction = "enemy" },
    interactive = {
        hover = { title = "Enemy", body = "A dangerous kobold" },
        click = function(reg, eid) print("clicked!") end,
        drag = true,
        collision = true
    },
    state = PLANNING_STATE,
    shaders = { "3d_skew_holo" }
})

-- Simple version (just sprite + position)
local entity = EntityBuilder.simple("kobold", 100, 200, 64, 64)

-- Interactive with hover tooltip
local entity, script = EntityBuilder.interactive({
    sprite = "button",
    position = { 100, 100 },
    hover = { title = "Click me", body = "Description" },
    click = function() print("clicked!") end
})
```

### EntityBuilder.create Options

| Option | Type | Description |
|--------|------|-------------|
| `sprite` | string | Animation/sprite ID |
| `position` | table | `{ x, y }` or `{ x = n, y = n }` |
| `size` | table | `{ w, h }` (default: 32x32) |
| `shadow` | boolean | Enable shadow (default: false) |
| `data` | table | Script table data (assigned before attach_ecs) |
| `interactive` | table | Interaction config (see below) |
| `state` | string | State tag to add |
| `shaders` | table | List of shader names |

### Interactive Options

| Option | Type | Description |
|--------|------|-------------|
| `hover` | table | `{ title, body, id? }` for tooltip |
| `click` | function | onClick callback |
| `drag` | boolean/function | Enable drag or custom handler |
| `stopDrag` | function | onStopDrag callback |
| `collision` | boolean | Enable collision |

---

## Physics Builder API

### Fluent Physics Setup

```lua
local PhysicsBuilder = require("core.physics_builder")

-- Fluent API
PhysicsBuilder.for_entity(entity)
    :circle()                           -- or :rectangle()
    :tag("projectile")
    :bullet()                           -- high-speed collision detection
    :friction(0)
    :fixedRotation()
    :syncMode("physics")                -- or "transform"
    :collideWith({ "enemy", "WORLD" })
    :apply()

-- Quick setup with options table
PhysicsBuilder.quick(entity, {
    shape = "circle",
    tag = "projectile",
    bullet = true,
    collideWith = { "enemy", "WORLD" }
})
```

### PhysicsBuilder Methods

| Method | Description |
|--------|-------------|
| `:circle()` | Circle collider shape |
| `:rectangle()` | Rectangle collider shape |
| `:tag(string)` | Collision tag |
| `:sensor(bool)` | Is sensor (no physical response) |
| `:density(number)` | Body density |
| `:friction(number)` | Surface friction |
| `:restitution(number)` | Bounciness |
| `:bullet(bool)` | CCD for fast objects |
| `:fixedRotation(bool)` | Lock rotation |
| `:syncMode(string)` | "physics" or "transform" |
| `:collideWith(table)` | Tags to collide with |
| `:apply()` | Apply all settings |

---

## Timer Options API

### Options-Table Variants

```lua
local timer = require("core.timer")

-- Clearer than positional parameters
timer.after_opts({
    delay = 2.0,
    action = function() print("done") end,
    tag = "my_timer"
})

timer.every_opts({
    delay = 0.5,
    action = updateHealth,
    times = 10,           -- 0 = infinite
    immediate = true,     -- run once immediately
    tag = "health_update"
})

timer.cooldown_opts({
    delay = 1.0,
    condition = function() return canAttack end,
    action = doAttack,
    tag = "attack_cd"
})
```

### Timer Sequences (Fluent Chaining)

```lua
-- Avoid nested timer.after calls
timer.sequence("animation")
    :wait(0.5)
    :do_now(function() print("start") end)
    :wait(0.3)
    :do_now(function() print("middle") end)
    :wait(0.2)
    :do_now(function() print("end") end)
    :onComplete(function() print("done!") end)
    :start()
```

---

## Global Helper Functions

These functions are available globally after util.lua loads:

```lua
-- Entity validation (use instead of manual nil checks)
if ensure_entity(eid) then
    -- entity is valid
end

if ensure_scripted_entity(eid) then
    -- entity is valid AND has ScriptComponent
end

-- Safe script access
local script = safe_script_get(eid)           -- returns nil if missing
local script = safe_script_get(eid, true)     -- logs warning if missing

-- Safe field access with default
local health = script_field(eid, "health", 100)  -- returns 100 if missing
```

### Replace This Pattern

```lua
-- OLD (verbose)
if not entity or entity == entt_null or not entity_cache.valid(entity) then
    return
end

-- NEW (use the helper!)
if not ensure_entity(entity) then return end
```

---

## Imports Bundle

Reduce repetitive requires with bundled imports:

```lua
local imports = require("core.imports")

-- Core bundle (most common set)
local component_cache, entity_cache, timer, signal, z_orders = imports.core()

-- Entity creation
local Node, animation_system, EntityBuilder = imports.entity()

-- Physics
local PhysicsManager, PhysicsBuilder = imports.physics()

-- UI
local dsl, z_orders, util = imports.ui()

-- Everything as a table
local i = imports.all()
print(i.timer, i.EntityBuilder, i.signal)
```
```

### Step 2: Commit

```bash
git add CLAUDE.md
git commit -m "docs: add documentation for new Lua API improvements

Documents:
- EntityBuilder fluent API
- PhysicsBuilder fluent API
- Timer options-table variants
- Timer sequence chaining
- Global helper functions
- Imports bundle module

$(cat <<'EOF'
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Final Verification and Code Review

### Step 1: Verify all new files have valid Lua syntax

```bash
luac -p assets/scripts/core/entity_builder.lua
luac -p assets/scripts/core/physics_builder.lua
luac -p assets/scripts/core/imports.lua
luac -p assets/scripts/core/timer.lua
luac -p assets/scripts/util/util.lua
```

Expected: All commands return no output (success)

### Step 2: Run code review

Use `superpowers:requesting-code-review` skill to dispatch a review agent.

### Step 3: Final commit summary

```bash
git log --oneline -6
```

Expected output should show 6 commits:
1. EntityBuilder
2. PhysicsBuilder
3. Timer options-table variants
4. Global helper exports
5. Imports bundle
6. CLAUDE.md documentation

---

## Summary

**Files Created:**
- `assets/scripts/core/entity_builder.lua` - Fluent entity creation
- `assets/scripts/core/physics_builder.lua` - Fluent physics setup
- `assets/scripts/core/imports.lua` - Module bundles

**Files Modified:**
- `assets/scripts/core/timer.lua` - Added options-table variants + sequence()
- `assets/scripts/util/util.lua` - Added global exports
- `CLAUDE.md` - Added documentation

**Impact:**
- Entity creation: 15-30 lines → 3-5 lines
- Physics setup: 10-15 lines → 3-5 lines
- Timer calls: 7 positional params → named options
- Entity validation: manual checks → single helper call
