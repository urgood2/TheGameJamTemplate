# Trigger Strip UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a left-side UI showing equipped trigger cards during action phase with wave-based hover interaction and cooldown visualization.

**Architecture:** Persistent sprite entities managed via state-based visibility. Wave math drives scale and slide-out position based on mouse proximity. Cooldown pie shader overlays on existing card shaders.

**Tech Stack:** Lua (trigger_strip_ui.lua), GLSL shaders (cooldown_pie), Transform component for easing, signal system for sync/activation events.

---

## Task 1: Create Cooldown Pie Shader Files

**Files:**
- Create: `assets/shaders/cooldown_pie_fragment.fs`
- Create: `assets/shaders/cooldown_pie_vertex.vs`

**Step 1: Create the vertex shader (passthrough)**

```glsl
// cooldown_pie_vertex.vs
#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;
in vec4 vertexColor;

out vec2 fragTexCoord;
out vec4 fragColor;

uniform mat4 mvp;

void main() {
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
```

**Step 2: Create the fragment shader**

```glsl
// cooldown_pie_fragment.fs
#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform float cooldown_progress;  // 0.0 = ready, 1.0 = full cooldown
uniform float dim_amount;         // How much to darken (e.g., 0.4)
uniform float flash_intensity;    // 0.0 = normal, 1.0 = full flash

// Atlas bounds for local UV calculation
uniform vec4 sprite_bounds;       // x, y, width, height in atlas UV space

const float PI = 3.14159265359;

void main() {
    // Convert atlas UV to local 0-1 UV within sprite
    vec2 localUV = (fragTexCoord - sprite_bounds.xy) / sprite_bounds.zw;
    vec2 centered = localUV - 0.5;

    // Calculate angle from center (0 at top, clockwise)
    float angle = atan(centered.x, -centered.y);  // -centered.y so 0 is at top
    float normalizedAngle = (angle + PI) / (2.0 * PI);  // 0 to 1

    // Determine if this pixel is in the cooldown region
    float inCooldown = step(normalizedAngle, cooldown_progress);

    // Sample texture at original atlas coordinates
    vec4 texColor = texture(texture0, fragTexCoord) * fragColor;

    // Apply dimming to cooldown region
    vec3 dimmed = texColor.rgb * (1.0 - dim_amount * inCooldown);

    // Apply flash effect (blend toward white)
    vec3 finalRGB = mix(dimmed, vec3(1.0), flash_intensity * 0.6);

    finalColor = vec4(finalRGB, texColor.a);
}
```

**Step 3: Commit shader files**

```bash
git add assets/shaders/cooldown_pie_fragment.fs assets/shaders/cooldown_pie_vertex.vs
git commit -m "feat(shader): add cooldown pie overlay shader"
```

---

## Task 2: Create Web Versions of Shader

**Files:**
- Create: `assets/shaders/web/cooldown_pie_fragment.fs`
- Create: `assets/shaders/web/cooldown_pie_vertex.vs`

**Step 1: Create web vertex shader (GLSL ES 100)**

```glsl
// web/cooldown_pie_vertex.vs
#version 100

attribute vec3 vertexPosition;
attribute vec2 vertexTexCoord;
attribute vec4 vertexColor;

varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform mat4 mvp;

void main() {
    fragTexCoord = vertexTexCoord;
    fragColor = vertexColor;
    gl_Position = mvp * vec4(vertexPosition, 1.0);
}
```

**Step 2: Create web fragment shader (GLSL ES 100)**

```glsl
// web/cooldown_pie_fragment.fs
#version 100

precision mediump float;

varying vec2 fragTexCoord;
varying vec4 fragColor;

uniform sampler2D texture0;
uniform float cooldown_progress;
uniform float dim_amount;
uniform float flash_intensity;
uniform vec4 sprite_bounds;

const float PI = 3.14159265359;

void main() {
    vec2 localUV = (fragTexCoord - sprite_bounds.xy) / sprite_bounds.zw;
    vec2 centered = localUV - 0.5;

    float angle = atan(centered.x, -centered.y);
    float normalizedAngle = (angle + PI) / (2.0 * PI);

    float inCooldown = step(normalizedAngle, cooldown_progress);

    vec4 texColor = texture2D(texture0, fragTexCoord) * fragColor;

    vec3 dimmed = texColor.rgb * (1.0 - dim_amount * inCooldown);
    vec3 finalRGB = mix(dimmed, vec3(1.0), flash_intensity * 0.6);

    gl_FragColor = vec4(finalRGB, texColor.a);
}
```

**Step 3: Commit web shaders**

```bash
git add assets/shaders/web/cooldown_pie_fragment.fs assets/shaders/web/cooldown_pie_vertex.vs
git commit -m "feat(shader): add web version of cooldown pie shader"
```

---

## Task 3: Register Shader in shaders.json

**Files:**
- Modify: `assets/shaders/shaders.json`

**Step 1: Add cooldown_pie entry to shaders.json**

Add this entry to the JSON object (after any existing entry, maintaining valid JSON):

```json
    "cooldown_pie": {
        "vertex": "cooldown_pie_vertex.vs",
        "fragment": "cooldown_pie_fragment.fs",

        "web": {
            "vertex": "web/cooldown_pie_vertex.vs",
            "fragment": "web/cooldown_pie_fragment.fs"
        }
    }
```

**Step 2: Commit shaders.json update**

```bash
git add assets/shaders/shaders.json
git commit -m "feat(shader): register cooldown_pie shader"
```

---

## Task 4: Add Shader Preset for Trigger Cards

**Files:**
- Modify: `assets/scripts/data/shader_presets.lua`

**Step 1: Add trigger_card preset**

Add before the `return ShaderPresets` line:

```lua
-- Trigger card with cooldown pie overlay
ShaderPresets.trigger_card = {
    id = "trigger_card",
    passes = {"3d_skew_holo", "cooldown_pie"},
    needs_atlas_uniforms = true,
    uniforms = {
        sheen_strength = 0.6,
        cooldown_progress = 0.0,
        dim_amount = 0.4,
        flash_intensity = 0.0,
    },
}
```

**Step 2: Commit preset**

```bash
git add assets/scripts/data/shader_presets.lua
git commit -m "feat(shader): add trigger_card preset with cooldown pie"
```

---

## Task 5: Create Trigger Strip UI Module - Core Structure

**Files:**
- Create: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Create module with constants and state**

```lua
--[[
================================================================================
TRIGGER STRIP UI
================================================================================
Left-side action phase UI showing equipped trigger cards with wave-based
hover interaction and cooldown visualization.

Features:
- Persistent entities with state-based visibility
- Wave ripple effect (scale + slide-out) on hover
- Cooldown pie shader overlay
- Flash + pop on trigger activation
- Delayed tooltips on focus
================================================================================
]]

local TriggerStripUI = {}

-- Dependencies
local timer = require("core.timer")
local signal = require("external.hump.signal")
local z_orders = require("core.z_orders")

-- Constants
local CARD_WIDTH = 60           -- 75% of 80
local CARD_HEIGHT = 84          -- 75% of 112
local PEEK_X = -30              -- Resting X position (half hidden)
local WAVE_RADIUS = 80          -- Wave influence radius in pixels
local MAX_SCALE_BUMP = 0.25     -- Max scale increase (1.0 -> 1.25)
local MAX_SLIDE_OUT = 40        -- Max slide-out distance
local STRIP_HOVER_ZONE = 100    -- Mouse X threshold for interaction
local TOOLTIP_DELAY = 0.3       -- Seconds before tooltip appears
local VERTICAL_SPACING = 20     -- Gap between cards
local ACTIVATION_SCALE = 1.4    -- Scale on trigger activation
local FLASH_DURATION = 0.15     -- Flash effect duration

-- State
local strip_entries = {}        -- Array of {entity, sourceCardEntity, wandId, triggerId, centerY, influence}
local strip_visible = false
local focusedEntry = nil
local previousFocusedEntry = nil
local activeTooltipEntry = nil
local tooltipTimerTag = nil

-- Screen dimensions cache
local screenHeight = 1080

return TriggerStripUI
```

**Step 2: Commit core structure**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger_strip_ui module skeleton"
```

---

## Task 6: Add Entity Creation and Destruction

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add helper functions for entity lifecycle**

Add after the state variables, before `return TriggerStripUI`:

```lua
--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

local function getScreenHeight()
    if globals and globals.screenHeight then
        return globals.screenHeight()
    elseif globals and globals.getScreenHeight then
        return globals.getScreenHeight()
    end
    return 1080
end

local function calculateYPosition(index, totalCount)
    screenHeight = getScreenHeight()
    local totalHeight = (totalCount - 1) * (CARD_HEIGHT + VERTICAL_SPACING)
    local startY = (screenHeight - totalHeight) / 2
    return startY + (index - 1) * (CARD_HEIGHT + VERTICAL_SPACING)
end

local function destroyEntry(entry)
    if not entry then return end

    -- Hide tooltip if showing for this entry
    if activeTooltipEntry == entry then
        if hideSimpleTooltip then
            hideSimpleTooltip("trigger_strip_" .. entry.entity)
        end
        activeTooltipEntry = nil
    end

    -- Destroy entity
    if entry.entity and registry and registry:valid(entry.entity) then
        registry:destroy(entry.entity)
    end
end

local function destroyAllEntries()
    for _, entry in ipairs(strip_entries) do
        destroyEntry(entry)
    end
    strip_entries = {}
    focusedEntry = nil
    previousFocusedEntry = nil
end
```

**Step 2: Commit helper functions**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip entity lifecycle helpers"
```

---

## Task 7: Add Entity Creation from Trigger Cards

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add createStripEntry function**

Add after the helper functions:

```lua
--------------------------------------------------------------------------------
-- ENTITY CREATION
--------------------------------------------------------------------------------

local function createStripEntry(sourceCardEntity, wandId, triggerId, index, totalCount)
    if not animation_system then
        log_error("TriggerStripUI: animation_system not available")
        return nil
    end

    -- Get sprite from source card
    local spriteId = "sample_card.png"  -- Default fallback
    if sourceCardEntity and registry:valid(sourceCardEntity) then
        local sourceScript = getScriptTableFromEntityID(sourceCardEntity)
        if sourceScript and sourceScript.cardID then
            local cardDef = WandEngine and WandEngine.trigger_card_defs and WandEngine.trigger_card_defs[sourceScript.cardID]
            if cardDef and cardDef.sprite then
                spriteId = cardDef.sprite
            end
        end
    end

    -- Calculate position
    local yPos = calculateYPosition(index, totalCount)

    -- Create animated entity
    local entity = animation_system.createAnimatedObjectWithTransform(spriteId, true, PEEK_X, yPos, nil, false)
    if not ensure_entity(entity) then
        log_error("TriggerStripUI: failed to create entity for trigger", triggerId)
        return nil
    end

    -- Set to screen space
    if transform and transform.set_space then
        transform.set_space(entity, "screen")
    end

    -- Resize to trigger strip size
    animation_system.resizeAnimationObjectsInEntityToFit(entity, CARD_WIDTH, CARD_HEIGHT)

    -- Apply shader preset with cooldown pie
    if applyShaderPreset then
        applyShaderPreset(registry, entity, "trigger_card", {
            cooldown_progress = 0.0,
            dim_amount = 0.4,
            flash_intensity = 0.0,
        })
    end

    -- Start hidden (not in any render state)
    if clear_state_tags then
        clear_state_tags(entity)
    end

    return {
        entity = entity,
        sourceCardEntity = sourceCardEntity,
        wandId = wandId,
        triggerId = triggerId,
        centerY = yPos + CARD_HEIGHT / 2,
        influence = 0,
    }
end
```

**Step 2: Commit entity creation**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip entity creation"
```

---

## Task 8: Add Sync Logic to Match Equipped Triggers

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add collectEquippedTriggers and sync functions**

Add after createStripEntry:

```lua
--------------------------------------------------------------------------------
-- SYNC WITH WAND TRIGGERS
--------------------------------------------------------------------------------

local function collectEquippedTriggers()
    local triggers = {}

    -- Access the trigger_board_id_to_action_board_id mapping from gameplay
    if not trigger_board_id_to_action_board_id then return triggers end
    if not boards then return triggers end

    local index = 1
    for triggerBoardID, actionBoardID in pairs(trigger_board_id_to_action_board_id) do
        if ensure_entity(triggerBoardID) then
            local triggerBoard = boards[triggerBoardID]
            if triggerBoard and triggerBoard.cards and #triggerBoard.cards > 0 then
                local cardEntity = triggerBoard.cards[1]
                if ensure_entity(cardEntity) then
                    local script = getScriptTableFromEntityID(cardEntity)
                    local triggerId = script and script.cardID or "unknown"
                    table.insert(triggers, {
                        cardEntity = cardEntity,
                        wandId = actionBoardID,  -- Use action board ID as wand identifier
                        triggerId = triggerId,
                        index = index,
                    })
                    index = index + 1
                end
            end
        end
    end

    return triggers
end

local function findEntryBySource(sourceCardEntity)
    for _, entry in ipairs(strip_entries) do
        if entry.sourceCardEntity == sourceCardEntity then
            return entry
        end
    end
    return nil
end

local function findEntryByWandId(wandId)
    for _, entry in ipairs(strip_entries) do
        if entry.wandId == wandId then
            return entry
        end
    end
    return nil
end

function TriggerStripUI.sync()
    local currentTriggers = collectEquippedTriggers()
    local totalCount = #currentTriggers

    -- Build lookup of current source entities
    local currentSources = {}
    for _, trigger in ipairs(currentTriggers) do
        currentSources[trigger.cardEntity] = trigger
    end

    -- Remove orphaned entries (triggers no longer equipped)
    for i = #strip_entries, 1, -1 do
        local entry = strip_entries[i]
        if not currentSources[entry.sourceCardEntity] then
            destroyEntry(entry)
            table.remove(strip_entries, i)
        end
    end

    -- Add missing entries and update positions
    for idx, trigger in ipairs(currentTriggers) do
        local existing = findEntryBySource(trigger.cardEntity)
        if existing then
            -- Update position
            existing.centerY = calculateYPosition(idx, totalCount) + CARD_HEIGHT / 2
            if registry:valid(existing.entity) then
                local t = component_cache.get(existing.entity, Transform)
                if t then
                    t.actualY = calculateYPosition(idx, totalCount)
                end
            end
        else
            -- Create new entry
            local entry = createStripEntry(
                trigger.cardEntity,
                trigger.wandId,
                trigger.triggerId,
                idx,
                totalCount
            )
            if entry then
                table.insert(strip_entries, entry)
                -- If strip is visible, add state tag
                if strip_visible and add_state_tag then
                    add_state_tag(entry.entity, ACTION_STATE)
                end
            end
        end
    end

    log_debug("TriggerStripUI: synced", #strip_entries, "trigger entries")
end
```

**Step 2: Commit sync logic**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip sync with wand triggers"
```

---

## Task 9: Add Show/Hide State Management

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add show and hide functions**

Add after sync functions:

```lua
--------------------------------------------------------------------------------
-- VISIBILITY STATE
--------------------------------------------------------------------------------

function TriggerStripUI.show()
    if strip_visible then return end

    -- Sync first to ensure we have current triggers
    TriggerStripUI.sync()

    for _, entry in ipairs(strip_entries) do
        if registry:valid(entry.entity) then
            -- Add to action state for rendering
            if add_state_tag then
                add_state_tag(entry.entity, ACTION_STATE)
            end

            -- Reset to peeking position
            local t = component_cache.get(entry.entity, Transform)
            if t then
                t.actualX = PEEK_X
                t.actualScaleX = 1.0
                t.actualScaleY = 1.0
            end
        end
    end

    strip_visible = true
    focusedEntry = nil
    previousFocusedEntry = nil

    log_debug("TriggerStripUI: shown with", #strip_entries, "triggers")
end

function TriggerStripUI.hide()
    if not strip_visible then return end

    -- Hide any active tooltip
    if activeTooltipEntry then
        if hideSimpleTooltip then
            hideSimpleTooltip("trigger_strip_" .. activeTooltipEntry.entity)
        end
        activeTooltipEntry = nil
    end

    -- Cancel tooltip timer
    if tooltipTimerTag then
        timer.cancel(tooltipTimerTag)
        tooltipTimerTag = nil
    end

    -- Remove from all render states
    for _, entry in ipairs(strip_entries) do
        if registry:valid(entry.entity) then
            if clear_state_tags then
                clear_state_tags(entry.entity)
            end
        end
    end

    strip_visible = false
    focusedEntry = nil
    previousFocusedEntry = nil

    log_debug("TriggerStripUI: hidden")
end

function TriggerStripUI.isVisible()
    return strip_visible
end
```

**Step 2: Commit show/hide**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip show/hide state management"
```

---

## Task 10: Add Wave Interaction Math

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add wave calculation and update function**

Add after show/hide functions:

```lua
--------------------------------------------------------------------------------
-- WAVE INTERACTION
--------------------------------------------------------------------------------

local function calculateWaveInfluence(cardCenterY, mouseY)
    local distance = math.abs(cardCenterY - mouseY)
    if distance > WAVE_RADIUS then return 0 end

    -- Smooth cosine falloff: 1.0 at center, 0 at edge
    local t = distance / WAVE_RADIUS
    return 0.5 * (1 + math.cos(t * math.pi))
end

function TriggerStripUI.update(dt)
    if not strip_visible then return end
    if #strip_entries == 0 then return end

    -- Get mouse position (screen space)
    local mouseX, mouseY = 0, 0
    if input and input.getMousePosition then
        mouseX, mouseY = input.getMousePosition()
    elseif globals and globals.mouseX then
        mouseX = globals.mouseX
        mouseY = globals.mouseY or 0
    end

    local inStripArea = mouseX < STRIP_HOVER_ZONE

    previousFocusedEntry = focusedEntry
    focusedEntry = nil
    local maxInfluence = 0.3  -- Minimum threshold to count as focused

    for _, entry in ipairs(strip_entries) do
        if not registry:valid(entry.entity) then goto continue end

        -- Calculate wave influence
        if inStripArea then
            entry.influence = calculateWaveInfluence(entry.centerY, mouseY)
        else
            entry.influence = 0
        end

        -- Track most-focused card
        if entry.influence > maxInfluence then
            maxInfluence = entry.influence
            focusedEntry = entry
        end

        -- Apply wave to transform
        local t = component_cache.get(entry.entity, Transform)
        if t then
            local scale = 1.0 + (MAX_SCALE_BUMP * entry.influence)
            t.actualScaleX = scale
            t.actualScaleY = scale
            t.actualX = PEEK_X + (MAX_SLIDE_OUT * entry.influence)
        end

        ::continue::
    end

    -- Jiggle on focus change
    if focusedEntry and focusedEntry ~= previousFocusedEntry then
        if transform and transform.InjectDynamicMotion then
            transform.InjectDynamicMotion(focusedEntry.entity, 0, 1)
        end
    end

    -- Handle tooltip
    TriggerStripUI.updateTooltip()

    -- Update cooldowns
    TriggerStripUI.updateCooldowns()
end
```

**Step 2: Commit wave interaction**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip wave interaction"
```

---

## Task 11: Add Tooltip Handling

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add tooltip update function**

Add after update function:

```lua
--------------------------------------------------------------------------------
-- TOOLTIPS
--------------------------------------------------------------------------------

local function showTriggerTooltip(entry)
    if not entry or not registry:valid(entry.entity) then return end
    if not showSimpleTooltipAbove then return end

    -- Get trigger card definition
    local title = entry.triggerId or "Trigger"
    local body = ""

    if WandEngine and WandEngine.trigger_card_defs then
        local cardDef = WandEngine.trigger_card_defs[entry.triggerId]
        if cardDef then
            title = cardDef.name or entry.triggerId
            body = cardDef.description or ""

            -- Add trigger type info
            if cardDef.trigger_type then
                body = body .. "\n\nType: " .. cardDef.trigger_type
            end
        end
    end

    showSimpleTooltipAbove(
        "trigger_strip_" .. entry.entity,
        title,
        body,
        entry.entity,
        { titleFontSize = 28, bodyFontSize = 24, offset = 10 }
    )

    activeTooltipEntry = entry
end

function TriggerStripUI.updateTooltip()
    -- Focus changed - reset tooltip
    if focusedEntry ~= activeTooltipEntry then
        -- Hide existing tooltip
        if activeTooltipEntry and hideSimpleTooltip then
            hideSimpleTooltip("trigger_strip_" .. activeTooltipEntry.entity)
        end

        -- Cancel pending tooltip timer
        if tooltipTimerTag then
            timer.cancel(tooltipTimerTag)
            tooltipTimerTag = nil
        end

        -- Start new delayed tooltip if we have a focused entry
        if focusedEntry then
            tooltipTimerTag = "trigger_strip_tooltip_" .. focusedEntry.entity
            timer.after_opts({
                delay = TOOLTIP_DELAY,
                action = function()
                    if focusedEntry and strip_visible then
                        showTriggerTooltip(focusedEntry)
                    end
                end,
                tag = tooltipTimerTag
            })
        end

        activeTooltipEntry = nil
    end
end
```

**Step 2: Commit tooltip handling**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip tooltip handling"
```

---

## Task 12: Add Cooldown Updates

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add cooldown update function**

Add after tooltip functions:

```lua
--------------------------------------------------------------------------------
-- COOLDOWN UPDATES
--------------------------------------------------------------------------------

function TriggerStripUI.updateCooldowns()
    if not WandTriggers or not WandTriggers.registrations then return end
    if not setShaderUniform then return end

    for _, entry in ipairs(strip_entries) do
        if not registry:valid(entry.entity) then goto continue end

        local registration = WandTriggers.registrations[entry.wandId]
        if registration then
            local progress = 0.0

            -- Calculate cooldown progress based on trigger type
            if registration.triggerType == "every_N_seconds" then
                -- Timer-based: check remaining time
                local interval = registration.triggerDef.interval or 1.0
                local elapsed = registration.elapsed or 0
                progress = 1.0 - (elapsed / interval)
                progress = math.max(0, math.min(1, progress))
            end

            -- Update shader uniform
            setShaderUniform(entry.entity, "cooldown_pie", "cooldown_progress", progress)
        end

        ::continue::
    end
end
```

**Step 2: Commit cooldown updates**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip cooldown updates"
```

---

## Task 13: Add Trigger Activation Feedback

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add activation handler**

Add after cooldown updates:

```lua
--------------------------------------------------------------------------------
-- ACTIVATION FEEDBACK
--------------------------------------------------------------------------------

function TriggerStripUI.onTriggerActivated(wandId, triggerId)
    local entry = findEntryByWandId(wandId)
    if not entry then return end
    if not registry:valid(entry.entity) then return end

    -- Pop: quick scale bump
    local t = component_cache.get(entry.entity, Transform)
    if t then
        t.actualScaleX = ACTIVATION_SCALE
        t.actualScaleY = ACTIVATION_SCALE
    end

    -- Jiggle
    if transform and transform.InjectDynamicMotion then
        transform.InjectDynamicMotion(entry.entity, 0.3, 1.5)
    end

    -- Flash via shader uniform
    if setShaderUniform then
        setShaderUniform(entry.entity, "cooldown_pie", "flash_intensity", 1.0)

        -- Reset flash after short delay
        timer.after_opts({
            delay = FLASH_DURATION,
            action = function()
                if registry:valid(entry.entity) then
                    setShaderUniform(entry.entity, "cooldown_pie", "flash_intensity", 0.0)
                end
            end,
            tag = "trigger_flash_" .. entry.entity
        })
    end

    log_debug("TriggerStripUI: activation feedback for wand", wandId)
end
```

**Step 2: Commit activation feedback**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip activation feedback"
```

---

## Task 14: Add Init and Cleanup

**Files:**
- Modify: `assets/scripts/ui/trigger_strip_ui.lua`

**Step 1: Add init and cleanup functions**

Add after activation feedback, before `return TriggerStripUI`:

```lua
--------------------------------------------------------------------------------
-- INITIALIZATION & CLEANUP
--------------------------------------------------------------------------------

function TriggerStripUI.init()
    -- Register for sync signals
    signal.register("deck_changed", function()
        if strip_visible then
            TriggerStripUI.sync()
        end
    end)

    -- Note: trigger_activated signal needs to be emitted from wand_triggers.lua
    -- This will be handled in the integration task

    log_debug("TriggerStripUI: initialized")
end

function TriggerStripUI.cleanup()
    TriggerStripUI.hide()
    destroyAllEntries()

    log_debug("TriggerStripUI: cleaned up")
end
```

**Step 2: Commit init/cleanup**

```bash
git add assets/scripts/ui/trigger_strip_ui.lua
git commit -m "feat(ui): add trigger strip init and cleanup"
```

---

## Task 15: Add Trigger Activated Signal to Wand Triggers

**Files:**
- Modify: `assets/scripts/wand/wand_triggers.lua`

**Step 1: Find the executor call in setupTimerTrigger and add signal emission**

In `wand_triggers.lua`, find the `setupTimerTrigger` function and add signal emission after the executor call. Look for where `registration.executor(wandId, ...)` is called and add:

```lua
-- After executor call:
signal.emit("trigger_activated", wandId, registration.triggerType)
```

Do the same for other trigger types that call the executor.

**Step 2: Commit signal emission**

```bash
git add assets/scripts/wand/wand_triggers.lua
git commit -m "feat(wand): emit trigger_activated signal for UI feedback"
```

---

## Task 16: Integrate with gameplay.lua

**Files:**
- Modify: `assets/scripts/core/gameplay.lua`

**Step 1: Add require at top of file**

Near other UI requires (search for `require.*ui`):

```lua
local TriggerStripUI = require("ui.trigger_strip_ui")
```

**Step 2: Initialize in game init**

Find the game initialization section (search for `AvatarJokerStrip.init` or similar UI init calls) and add:

```lua
TriggerStripUI.init()
```

**Step 3: Show in initActionPhase**

Find `initActionPhase` function and add after other UI initialization:

```lua
TriggerStripUI.show()
```

**Step 4: Hide in startPlanningPhase or endActionPhase**

Find where planning phase starts or action phase ends and add:

```lua
TriggerStripUI.hide()
```

**Step 5: Update in main loop**

Find the main update loop where other UI is updated (search for `AvatarJokerStrip.update` or similar) and add:

```lua
if is_state_active(ACTION_STATE) then
    TriggerStripUI.update(dt)
end
```

**Step 6: Register for trigger_activated signal**

After the TriggerStripUI.init() call:

```lua
signal.register("trigger_activated", function(wandId, triggerType)
    TriggerStripUI.onTriggerActivated(wandId, triggerType)
end)
```

**Step 7: Commit integration**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(gameplay): integrate trigger strip UI"
```

---

## Task 17: Test Build and Verify

**Step 1: Run debug build**

```bash
just build-debug
```

Expected: Build completes without errors.

**Step 2: Run the game and enter action phase**

Launch the game, equip trigger cards to wands, and enter action phase.

Expected:
- Trigger cards appear on left side, half-peeking
- Moving mouse near left edge causes wave effect
- Focused card slides out and scales up
- Adjacent cards follow with smaller effect
- Tooltip appears after 0.3s delay on focused card
- Cooldown pie shows for timer-based triggers

**Step 3: Commit any fixes if needed**

---

## Task 18: Final Cleanup and Polish

**Step 1: Review all changes**

```bash
git diff master..HEAD --stat
```

**Step 2: Ensure all commits are clean**

```bash
git log --oneline master..HEAD
```

**Step 3: Create summary commit if needed**

If there are many small fix commits, consider squashing or leaving as-is for traceability.

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1-2 | Create cooldown pie shader (desktop + web) | `assets/shaders/cooldown_pie_*.fs/vs` |
| 3 | Register shader | `shaders.json` |
| 4 | Add shader preset | `shader_presets.lua` |
| 5-14 | Create trigger_strip_ui module | `trigger_strip_ui.lua` |
| 15 | Add trigger_activated signal | `wand_triggers.lua` |
| 16 | Integrate with gameplay | `gameplay.lua` |
| 17-18 | Test and polish | — |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
