# Lua API Refactoring Proposal v2

## Summary of Your Feedback

| Decision | Your Response |
|----------|---------------|
| Content validation | **Use existing** `content_validator.lua` + `schema.lua` |
| Validation alerts | **Add modal popup** following `PatchNotesModal` pattern |
| fx module | **Approved** - test carefully for breakage |
| Timer deprecation | **Yes** - add @deprecated + console warnings |
| Naming convention | **snake_case** going forward |
| fx scope | **Include camera effects** |

---

## 1. VALIDATION MODAL (Builds on Existing Code)

### Current State
Your `content_validator.lua` already validates cards, jokers, projectiles, avatars.
It returns `{ errors = {...}, warnings = {...} }` but only prints to console.

### Proposed Enhancement

Create `ui/validation_modal.lua` following `PatchNotesModal` pattern:

```lua
--[[
================================================================================
Validation Modal
================================================================================
Displays content validation errors/warnings at startup.
Follows PatchNotesModal pattern for consistency.
]]

local ValidationModal = {}

local dsl = require("ui.ui_syntax_sugar")
local signal = require("external.hump.signal")
local z_orders = require("core.z_orders")
local ContentValidator = require("tools.content_validator")

ValidationModal.isOpen = false
ValidationModal._backdrop = nil
ValidationModal._modalBox = nil
ValidationModal._errors = {}
ValidationModal._warnings = {}

local MODAL_WIDTH = 600
local MODAL_HEIGHT = 500

-- Called during game init
function ValidationModal.checkAndShow()
    local result = ContentValidator.validate_all()

    ValidationModal._errors = result.errors
    ValidationModal._warnings = result.warnings

    -- Only show modal if there are errors (warnings still print to console)
    if #result.errors > 0 then
        ValidationModal.open()
        return false -- validation failed
    end

    return true -- validation passed
end

function ValidationModal.open()
    if ValidationModal.isOpen then return end

    ValidationModal.isOpen = true
    ValidationModal._createUI()
    signal.emit("validation_modal_opened")
end

function ValidationModal.close()
    if not ValidationModal.isOpen then return end
    ValidationModal.isOpen = false
    ValidationModal._destroyUI()
    signal.emit("validation_modal_closed")
end

function ValidationModal._createUI()
    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()
    local modalX = (screenW - MODAL_WIDTH) / 2
    local modalY = (screenH - MODAL_HEIGHT) / 2

    -- Build error list
    local errorNodes = {}
    for _, err in ipairs(ValidationModal._errors) do
        table.insert(errorNodes, dsl.text(
            string.format("[%s] %s: %s", err.type, err.id, err.message),
            { fontSize = 14, color = "red", shadow = true }
        ))
    end

    -- Build warning list (first 10 only)
    local warningNodes = {}
    local maxWarnings = math.min(10, #ValidationModal._warnings)
    for i = 1, maxWarnings do
        local warn = ValidationModal._warnings[i]
        table.insert(warningNodes, dsl.text(
            string.format("[%s] %s: %s", warn.type, warn.id, warn.message),
            { fontSize = 14, color = "yellow", shadow = true }
        ))
    end
    if #ValidationModal._warnings > 10 then
        table.insert(warningNodes, dsl.text(
            string.format("... and %d more warnings", #ValidationModal._warnings - 10),
            { fontSize = 14, color = "gray", shadow = true }
        ))
    end

    local modalDef = dsl.root {
        config = {
            color = util.getColor("dark_red"),
            padding = 20,
            emboss = 3,
            minWidth = MODAL_WIDTH,
            minHeight = MODAL_HEIGHT,
        },
        children = {
            dsl.vbox {
                config = { spacing = 10 },
                children = {
                    dsl.text("Content Validation Failed", {
                        fontSize = 28, color = "red", shadow = true
                    }),
                    dsl.text(string.format("%d errors, %d warnings",
                        #ValidationModal._errors, #ValidationModal._warnings), {
                        fontSize = 18, color = "white", shadow = true
                    }),
                    dsl.divider("horizontal", { color = "red", thickness = 2 }),
                    dsl.spacer(8),
                    dsl.vbox {
                        config = { spacing = 4 },
                        children = errorNodes
                    },
                    #warningNodes > 0 and dsl.divider("horizontal", { color = "yellow" }) or nil,
                    dsl.vbox {
                        config = { spacing = 4 },
                        children = warningNodes
                    },
                    dsl.spacer(10),
                    dsl.hbox {
                        config = { spacing = 10, align = "center" },
                        children = {
                            dsl.button("Continue Anyway", {
                                color = "orange",
                                onClick = function() ValidationModal.close() end
                            }),
                            dsl.button("Exit", {
                                color = "red",
                                onClick = function() os.exit(1) end
                            }),
                        }
                    }
                }
            }
        }
    }

    ValidationModal._modalBox = dsl.spawn(
        { x = modalX, y = modalY },
        modalDef, "ui", z_orders.ui_modal + 5
    )
end

return ValidationModal
```

### Integration Point

In your game init (likely `gameplay.lua` or `main.lua`):

```lua
-- After loading content data
local ValidationModal = require("ui.validation_modal")
ValidationModal.checkAndShow()
```

---

## 2. TIMER API: Add pulse_opts + Deprecation Warnings

### File: `assets/scripts/core/timer.lua`

```lua
-- Add after line 254 (current timer.pulse)

--- @deprecated Use timer.pulse_opts instead
--- Timer.pulse creates a repeating timer that fires immediately
--- @param interval number Time between pulses
--- @param action function Callback function
--- @param tag string|nil Optional tag for cancellation
function timer.pulse(interval, action, tag)
    log_warn("[timer.pulse] DEPRECATED: Use timer.pulse_opts({ interval=..., action=..., tag=... }) instead")
    return timer.pulse_opts({ interval = interval, action = action, tag = tag })
end

--- Pulse timer with options table (PREFERRED)
--- @param opts {interval: number, action: function, tag?: string, group?: string, immediate?: boolean}
function timer.pulse_opts(opts)
    assert(opts.interval, "timer.pulse_opts: interval required")
    assert(opts.action, "timer.pulse_opts: action required")
    return timer.every_opts({
        delay = opts.interval,
        action = opts.action,
        immediate = opts.immediate ~= false, -- default true for pulse
        tag = opts.tag,
        group = opts.group
    })
end

-- Also add deprecation warnings to other positional APIs:
local _original_after = timer.after
function timer.after(delay, action, tag, group)
    if type(delay) == "number" and type(action) == "function" then
        -- Positional call detected
        log_warn("[timer.after] Consider using timer.after_opts({ delay=..., action=..., tag=... })")
    end
    return _original_after(delay, action, tag, group)
end
```

---

## 3. Q.LUA: Add snake_case Aliases

### File: `assets/scripts/core/Q.lua`

Add at the end of the file (before `return Q`):

```lua
--------------------------------------------------------------------------------
-- snake_case Aliases (Lua convention)
-- Keep camelCase for backwards compatibility
--------------------------------------------------------------------------------

Q.is_valid = Q.isValid
Q.visual_center = Q.visualCenter
Q.visual_bounds = Q.visualBounds
Q.distance_to_point = Q.distanceToPoint
Q.is_in_range = Q.isInRange
Q.get_transform = Q.getTransform
Q.with_transform = Q.withTransform
Q.set_rotation = Q.setRotation
Q.set_velocity = Q.setVelocity
Q.get_velocity = Q.getVelocity
```

---

## 4. ENTITY VALIDATION: Consolidate to Single Function

### File: `assets/scripts/core/entity_cache.lua`

Update the `cache.valid()` function to be the canonical validator:

```lua
--- Canonical entity validator - all other modules should delegate here
--- @param eid number|nil Entity ID to validate
--- @return boolean True if entity is valid
function cache.valid(eid)
    -- All edge cases in one place
    if not eid then return false end
    if eid == entt_null then return false end  -- ADD THIS CHECK
    if not registry then return false end

    local ok = registry:valid(eid)
    cache._valid[eid] = ok or false
    return ok
end
```

### File: `assets/scripts/core/Q.lua`

Simplify to delegate:

```lua
--- Check if entity is valid (delegates to entity_cache)
function Q.isValid(entity)
    if entity_cache and entity_cache.valid then
        return entity_cache.valid(entity)
    end
    -- Fallback only if entity_cache not loaded
    if not entity then return false end
    if entity == entt_null then return false end
    return registry and registry:valid(entity) or false
end
```

---

## 5. UNIFIED FX MODULE (WITH CAMERA EFFECTS)

### New File: `assets/scripts/core/fx.lua`

```lua
--[[
================================================================================
core/fx.lua - Unified Visual Effects API
================================================================================
Single entry point for all visual effects. Wraps existing modules.

Usage:
    local fx = require("core.fx")

    -- Entity effects
    fx.flash(entity, 0.1)
    fx.shake(entity, { intensity = 5, duration = 0.2 })
    fx.damage(entity, 25)
    fx.heal(entity, 50)

    -- Particles
    fx.particles(entity, "blood_splatter")
    fx.particles_at(x, y, "explosion")

    -- Text
    fx.text(entity, "[CRIT!](color=gold)")
    fx.text_at(x, y, "[+50 XP](color=cyan)")

    -- Camera
    fx.camera_shake(intensity, duration)
    fx.camera_flash(color, duration)
]]

local fx = {}

-- Lazy-loaded dependencies to avoid circular requires
local _hitfx, _popup, _particles, _Text, _Q, _camera

local function get_hitfx()
    if not _hitfx then _hitfx = require("core.hitfx") end
    return _hitfx
end

local function get_popup()
    if not _popup then _popup = require("core.popup") end
    return _popup
end

local function get_particles()
    if not _particles then _particles = require("core.particles") end
    return _particles
end

local function get_Text()
    if not _Text then _Text = require("core.text") end
    return _Text
end

local function get_Q()
    if not _Q then _Q = require("core.Q") end
    return _Q
end

local function get_camera()
    if not _camera then _camera = _G.camera or require("core.camera") end
    return _camera
end

--------------------------------------------------------------------------------
-- Entity Effects (from hitfx)
--------------------------------------------------------------------------------

--- Flash entity white/red
--- @param entity number Entity to flash
--- @param duration number|nil Flash duration (default 0.1)
--- @param color string|nil Flash color (default "white")
function fx.flash(entity, duration, color)
    local hitfx = get_hitfx()
    if hitfx.flash then
        hitfx.flash(entity, duration or 0.1, color)
    end
end

--- Shake entity
--- @param entity number Entity to shake
--- @param opts {intensity?: number, duration?: number}|nil
function fx.shake(entity, opts)
    local hitfx = get_hitfx()
    opts = opts or {}
    if hitfx.shake then
        hitfx.shake(entity, opts.intensity or 5, opts.duration or 0.2)
    end
end

--- Freeze-frame effect
--- @param duration number Freeze duration
function fx.freeze_frame(duration)
    local hitfx = get_hitfx()
    if hitfx.freeze_frame then
        hitfx.freeze_frame(duration)
    end
end

--------------------------------------------------------------------------------
-- Popup Numbers (from popup)
--------------------------------------------------------------------------------

--- Show damage number above entity
--- @param entity number Entity to show damage above
--- @param amount number Damage amount
function fx.damage(entity, amount)
    local popup = get_popup()
    if popup.damage then
        popup.damage(entity, amount)
    end
end

--- Show heal number above entity
--- @param entity number Entity to show heal above
--- @param amount number Heal amount
function fx.heal(entity, amount)
    local popup = get_popup()
    if popup.heal then
        popup.heal(entity, amount)
    end
end

--- Show custom text above entity
--- @param entity number Entity
--- @param text string Text to display
--- @param opts {color?: string, offset?: number}|nil
function fx.popup(entity, text, opts)
    local popup = get_popup()
    if popup.above then
        popup.above(entity, text, opts)
    end
end

--------------------------------------------------------------------------------
-- Particles
--------------------------------------------------------------------------------

--- Spawn particles at entity
--- @param entity number Entity
--- @param preset string Particle preset name
function fx.particles(entity, preset)
    local particles = get_particles()
    local Q = get_Q()
    if particles.spawn and Q.visual_center then
        local vx, vy = Q.visual_center(entity) or Q.visualCenter(entity)
        if vx and vy then
            particles.spawn(preset, vx, vy)
        end
    end
end

--- Spawn particles at position
--- @param x number X position
--- @param y number Y position
--- @param preset string Particle preset name
function fx.particles_at(x, y, preset)
    local particles = get_particles()
    if particles.spawn then
        particles.spawn(preset, x, y)
    end
end

--------------------------------------------------------------------------------
-- Text Effects
--------------------------------------------------------------------------------

--- Show animated text at entity
--- @param entity number Entity
--- @param content string Rich text content (supports [text](color=...;pop=...))
function fx.text(entity, content)
    local Text = get_Text()
    local Q = get_Q()
    local vx, vy = Q.visual_center(entity) or Q.visualCenter(entity)
    if vx and vy and Text.define then
        Text.define():content(content):spawn():at(vx, vy - 20)
    end
end

--- Show animated text at position
--- @param x number X position
--- @param y number Y position
--- @param content string Rich text content
function fx.text_at(x, y, content)
    local Text = get_Text()
    if Text.define then
        Text.define():content(content):spawn():at(x, y)
    end
end

--------------------------------------------------------------------------------
-- Camera Effects
--------------------------------------------------------------------------------

--- Shake the camera
--- @param intensity number|nil Shake intensity (default 10)
--- @param duration number|nil Shake duration (default 0.3)
function fx.camera_shake(intensity, duration)
    local camera = get_camera()
    if camera and camera.shake then
        camera.shake(intensity or 10, duration or 0.3)
    elseif rawget(_G, "shake_camera") then
        shake_camera(intensity or 10, duration or 0.3)
    end
end

--- Flash the screen
--- @param color table|string|nil Color (default white)
--- @param duration number|nil Flash duration (default 0.1)
function fx.camera_flash(color, duration)
    local camera = get_camera()
    if camera and camera.flash then
        camera.flash(color or "white", duration or 0.1)
    end
end

--- Zoom camera briefly (punch-in effect)
--- @param amount number Zoom amount (1.0 = no zoom, 1.1 = 10% zoom in)
--- @param duration number|nil Duration (default 0.2)
function fx.camera_zoom_punch(amount, duration)
    local camera = get_camera()
    if camera and camera.zoom_punch then
        camera.zoom_punch(amount, duration or 0.2)
    end
end

return fx
```

---

## 6. ENTITYBUILDER.SIMPLE() RETURN VALUE

### File: `assets/scripts/core/entity_builder.lua`

Find and update `EntityBuilder.simple()`:

```lua
--- Create a simple entity with sprite and position
--- @param sprite string Sprite name
--- @param x number X position
--- @param y number Y position
--- @param w number|nil Width
--- @param h number|nil Height
--- @return number entity, table|nil script (NOW RETURNS BOTH)
function EntityBuilder.simple(sprite, x, y, w, h)
    local entity, script = EntityBuilder.create({
        sprite = sprite,
        position = { x = x, y = y },
        size = w and { w, h } or nil
    })
    return entity, script  -- Return both for consistency
end
```

---

## 7. TEXT.NEW ALIAS

### File: `assets/scripts/core/text.lua`

Add near the end before `return Text`:

```lua
--- Alias for consistency with other builders
Text.new = Text.define
```

---

## Implementation Order

1. **Quick wins (15 min):** Text.new alias, EntityBuilder.simple fix
2. **Timer deprecation (30 min):** Add pulse_opts, wrap positional APIs
3. **snake_case aliases (15 min):** Add to Q.lua
4. **Entity validation (20 min):** Consolidate to entity_cache
5. **Unified fx module (45 min):** New file with all wrappers
6. **Validation modal (1 hr):** New UI following PatchNotesModal pattern

---

## Testing Checklist

Before merging:

- [ ] Run game with intentionally broken card definition - modal appears?
- [ ] Call `timer.pulse()` - deprecation warning printed?
- [ ] `Q.is_valid(entity)` works same as `Q.isValid(entity)`?
- [ ] `fx.damage(entity, 25)` equivalent to `popup.damage(entity, 25)`?
- [ ] `fx.camera_shake(10, 0.3)` works?
- [ ] `EntityBuilder.simple()` returns both entity and script?
- [ ] Existing code using old APIs still works?

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
