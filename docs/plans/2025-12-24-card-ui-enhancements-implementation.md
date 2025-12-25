# Card UI Enhancements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add right-click card transfer, alt-hold preview, and a reusable tooltip registry system.

**Architecture:** Three isolated features implemented incrementally. Alt-preview and right-click are self-contained in gameplay.lua. Tooltip registry is a new module that wraps existing tooltip functions with a name-based API.

**Tech Stack:** Lua, existing UI/input systems, `input.isMousePressed()` for right-click detection, `IsKeyDown()` for Alt detection.

---

## Task 1: Alt-Hold Preview — State Variables

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (near line 200, with other state variables)

**Step 1: Add state variables after `previously_hovered_tooltip`**

Find this line (~206):
```lua
local previously_hovered_tooltip = nil
```

Add after it:
```lua
-- Alt-preview state: show hovered card at top Z while Alt is held
local alt_preview_entity = nil
local alt_preview_original_z = nil
local currently_hovered_card = nil  -- Track which card is hovered for alt-check
```

**Step 2: Verify file saves correctly**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(cards): add alt-preview state variables"
```

---

## Task 2: Alt-Hold Preview — Helper Functions

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (after the state variables from Task 1)

**Step 1: Add helper functions after the state variables**

```lua
-- Check if Alt key is held
local function isAltHeld()
    return IsKeyDown(KeyboardKey.KEY_LEFT_ALT) or IsKeyDown(KeyboardKey.KEY_RIGHT_ALT)
end

-- Begin alt-preview: elevate card to top Z
local function beginAltPreview(entity)
    if alt_preview_entity == entity then return end
    if alt_preview_entity then
        -- End previous preview first
        local prevLayerOrder = component_cache.get(alt_preview_entity, LayerOrderComponent)
        if prevLayerOrder and alt_preview_original_z then
            prevLayerOrder.zIndex = alt_preview_original_z
        end
    end

    local layerOrder = component_cache.get(entity, LayerOrderComponent)
    if layerOrder then
        alt_preview_original_z = layerOrder.zIndex
        layerOrder.zIndex = z_orders.top_card
    end
    alt_preview_entity = entity
end

-- End alt-preview: restore card to original Z
local function endAltPreview()
    if not alt_preview_entity then return end

    local layerOrder = component_cache.get(alt_preview_entity, LayerOrderComponent)
    if layerOrder and alt_preview_original_z then
        layerOrder.zIndex = alt_preview_original_z
    end
    alt_preview_entity = nil
    alt_preview_original_z = nil
end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(cards): add alt-preview helper functions"
```

---

## Task 3: Alt-Hold Preview — Integrate with Card Hover

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (~line 2238, onHover handler)
- Modify: `assets/scripts/core/gameplay.lua` (~line 2276, onStopHover handler)
- Modify: `assets/scripts/core/gameplay.lua` (~line 2290, onDrag handler)

**Step 1: Modify onHover to track hovered card and check Alt**

Find the `onHover` handler (~line 2238). At the END of the function, before the closing `end`, add:

```lua
        -- Track for alt-preview
        currently_hovered_card = card

        -- If Alt is already held, begin preview
        if isAltHeld() then
            beginAltPreview(card)
        end
```

**Step 2: Modify onStopHover to end alt-preview**

Find the `onStopHover` handler (~line 2276). At the END of the function, before the closing `end`, add:

```lua
        -- Clear hover tracking and end alt-preview if this was the previewed card
        currently_hovered_card = nil
        if alt_preview_entity == card then
            endAltPreview()
        end
```

**Step 3: Modify onDrag to clear alt-preview state**

Find the `onDrag` handler (~line 2290). At the START of the function, after the first line, add:

```lua
        -- If alt-previewing this card, clear state (drag takes over at top Z)
        if alt_preview_entity == card then
            alt_preview_entity = nil
            alt_preview_original_z = nil
        end
```

**Step 4: Verify syntax**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 5: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(cards): integrate alt-preview with card hover/drag"
```

---

## Task 4: Alt-Hold Preview — Per-Frame Update

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (find the main update loop, or `onUpdateCardsAndBoards` function)

**Step 1: Find the per-frame card update function**

Search for a function that runs every frame for card/board updates. Look for `function.*update` or `timer.every` patterns. Common names: `onUpdateCardsAndBoards`, `updateBoards`, or a timer callback.

If no such function exists, add to an existing per-frame timer or create one.

**Step 2: Add alt-preview frame check**

Add this function near the other alt-preview helpers:

```lua
-- Per-frame check: end alt-preview if Alt released
local function updateAltPreview()
    if not alt_preview_entity then return end

    if not isAltHeld() then
        endAltPreview()
    end
end
```

**Step 3: Hook into per-frame update**

Find where game updates run each frame. Add call to `updateAltPreview()`.

If using a timer pattern, add:
```lua
timer.every(0.016, updateAltPreview)  -- ~60fps check
```

Or if there's an existing update callback, add `updateAltPreview()` to it.

**Step 4: Verify syntax**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 5: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(cards): add per-frame alt-preview update"
```

---

## Task 5: Alt-Hold Preview — Also Begin Preview When Alt Pressed While Hovering

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (updateAltPreview function)

**Step 1: Extend updateAltPreview to also begin preview**

Replace the `updateAltPreview` function:

```lua
-- Per-frame check: manage alt-preview based on Alt key and hover state
local function updateAltPreview()
    local altHeld = isAltHeld()

    -- If Alt released while previewing, end preview
    if alt_preview_entity and not altHeld then
        endAltPreview()
        return
    end

    -- If Alt pressed while hovering a card (and not already previewing), begin preview
    if altHeld and currently_hovered_card and not alt_preview_entity then
        if entity_cache.valid(currently_hovered_card) then
            beginAltPreview(currently_hovered_card)
        end
    end
end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(cards): alt-preview triggers on Alt press while hovering"
```

---

## Task 6: Right-Click Transfer — Helper Functions

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (near the board management functions, ~line 1100)

**Step 1: Add helper function to get target board for transfer**

Add after `removeCardFromBoard` function (~line 1095):

```lua
-- Get the appropriate inventory board for a card type
local function getInventoryForCardType(cardScript)
    if cardScript.cardType == "trigger" then
        return trigger_inventory_board_id
    else
        return inventory_board_id
    end
end

-- Get the appropriate active board for a card type
local function getActiveBoardForCardType(cardScript)
    local activeSet = board_sets and board_sets[current_board_set_index]
    if not activeSet then return nil end

    if cardScript.cardType == "trigger" then
        return activeSet.trigger_board_id
    else
        return activeSet.action_board_id
    end
end

-- Check if a board can accept another card
local function canBoardAcceptCard(boardEntityID, cardScript)
    if not boardEntityID or not entity_cache.valid(boardEntityID) then
        return false
    end

    -- Inventory boards have unlimited capacity
    if boardEntityID == inventory_board_id or boardEntityID == trigger_inventory_board_id then
        return true
    end

    -- Check against wand capacity
    local board = boards[boardEntityID]
    if not board then return false end

    local currentCount = board.cards and #board.cards or 0
    local maxCapacity = wandDef and wandDef.total_card_slots or 99

    return currentCount < maxCapacity
end

-- Transfer card via right-click
local function transferCardViaRightClick(cardEntity, cardScript)
    local currentBoard = cardScript.currentBoardEntity
    if not currentBoard or not entity_cache.valid(currentBoard) then
        return
    end

    local targetBoard
    local isFromInventory = (currentBoard == inventory_board_id or currentBoard == trigger_inventory_board_id)

    if isFromInventory then
        targetBoard = getActiveBoardForCardType(cardScript)
    else
        targetBoard = getInventoryForCardType(cardScript)
    end

    if not targetBoard or not entity_cache.valid(targetBoard) then
        return
    end

    -- Check capacity
    if not canBoardAcceptCard(targetBoard, cardScript) then
        playSoundEffect("effects", "error_buzz", 0.8)
        return
    end

    -- Transfer
    removeCardFromBoard(cardEntity, currentBoard)
    addCardToBoard(cardEntity, targetBoard)

    -- Clear selection state
    cardScript.selected = false
    local nodeComp = component_cache.get(cardEntity, GameObject)
    if nodeComp then
        nodeComp.state.isBeingFocused = false
    end

    -- Play feedback sound
    playSoundEffect("effects", "card_put_down_1", 0.9)
end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(cards): add right-click transfer helper functions"
```

---

## Task 7: Right-Click Transfer — Per-Frame Detection

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (updateAltPreview function or create new update function)

**Step 1: Add right-click detection to the per-frame update**

Add a new function or extend the existing update:

```lua
-- Per-frame check for right-click on hovered card
local function updateRightClickTransfer()
    if not currently_hovered_card then return end
    if not entity_cache.valid(currently_hovered_card) then
        currently_hovered_card = nil
        return
    end

    -- Check for right-click this frame
    if input.isMousePressed(MouseButton.MOUSE_BUTTON_RIGHT) then
        local cardScript = getScriptTableFromEntityID(currently_hovered_card)
        if cardScript then
            transferCardViaRightClick(currently_hovered_card, cardScript)
        end
    end
end
```

**Step 2: Hook into the per-frame update**

If using timer pattern:
```lua
timer.every(0.016, function()
    updateAltPreview()
    updateRightClickTransfer()
end)
```

Or combine into a single card UI update function.

**Step 3: Verify syntax**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 4: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(cards): add right-click transfer detection"
```

---

## Task 8: Tooltip Registry — Create Module

**Files:**
- Create: `assets/scripts/core/tooltip_registry.lua`

**Step 1: Create the new module file**

```lua
--[[
================================================================================
Tooltip Registry - Name-based tooltip management with parameterized templates
================================================================================

USAGE:
    local tooltips = require("core.tooltip_registry")

    -- Register a tooltip template
    tooltips.register("fire_damage", {
        title = "Fire Damage",
        body = "Deals {damage} fire damage"
    })

    -- Attach to entity (shows on hover)
    tooltips.attachToEntity(entity, "fire_damage", { damage = 25 })

    -- Manual show/hide
    tooltips.showFor(entity)
    tooltips.hide()

TEMPLATE SYNTAX:
    {param}         -- Simple substitution
    {param|color}   -- Substitution with color (uses styled markup)
]]

local tooltips = {}

-- Dependencies (will be set during init)
local component_cache = require("core.component_cache")
local entity_cache = _G.entity_cache

--------------------------------------------------------------------------------
-- Internal State
--------------------------------------------------------------------------------

local tooltip_definitions = {}      -- name → { title, body, opts }
local entity_attachments = {}       -- entity → { name, params, originalOnHover, originalOnStopHover }
local active_tooltip = nil          -- Currently visible tooltip entity
local active_target = nil           -- Entity the tooltip is shown for

--------------------------------------------------------------------------------
-- Template Interpolation
--------------------------------------------------------------------------------

-- Interpolate {param} and {param|color} in template string
local function interpolateTemplate(template, params)
    if not template or not params then return template or "" end

    return template:gsub("{([^}]+)}", function(match)
        -- Check for color syntax: {param|color}
        local param, color = match:match("^(%w+)|(%w+)$")
        if param and color then
            local value = params[param]
            if value ~= nil then
                return string.format("[%s](color=%s)", tostring(value), color)
            end
        else
            -- Simple substitution: {param}
            local value = params[match]
            if value ~= nil then
                return tostring(value)
            end
        end
        return "{" .. match .. "}"  -- Return unchanged if not found
    end)
end

-- Generate cache key from name + params
local function getCacheKey(name, params)
    if not params or next(params) == nil then
        return name
    end
    -- Simple serialization for cache key
    local parts = { name }
    local keys = {}
    for k in pairs(params) do table.insert(keys, k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        table.insert(parts, k .. "=" .. tostring(params[k]))
    end
    return table.concat(parts, ":")
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Register a tooltip template by name
--- @param name string Unique identifier for the tooltip
--- @param def table { title = string, body = string, opts = table? }
function tooltips.register(name, def)
    tooltip_definitions[name] = {
        title = def.title or "",
        body = def.body or "",
        opts = def.opts or {}
    }
end

--- Check if a tooltip is registered
--- @param name string Tooltip name
--- @return boolean
function tooltips.isRegistered(name)
    return tooltip_definitions[name] ~= nil
end

--- Attach a tooltip to an entity (will show on hover)
--- @param entity number Entity ID
--- @param tooltipName string Registered tooltip name
--- @param params table? Parameters for template interpolation
function tooltips.attachToEntity(entity, tooltipName, params)
    if not entity or not entity_cache.valid(entity) then return end
    if not tooltip_definitions[tooltipName] then
        log_error("Tooltip not registered:", tooltipName)
        return
    end

    local go = component_cache.get(entity, GameObject)
    if not go then return end

    -- Store attachment info
    entity_attachments[entity] = {
        name = tooltipName,
        params = params or {},
        originalOnHover = go.methods.onHover,
        originalOnStopHover = go.methods.onStopHover
    }

    -- Enable hover if not already
    go.state.hoverEnabled = true
    go.state.collisionEnabled = true

    -- Wrap hover handlers
    go.methods.onHover = function(reg, eid, releasedOn)
        local attachment = entity_attachments[entity]
        if attachment and attachment.originalOnHover then
            attachment.originalOnHover(reg, eid, releasedOn)
        end
        tooltips.showFor(entity)
    end

    go.methods.onStopHover = function(reg, eid)
        local attachment = entity_attachments[entity]
        if attachment and attachment.originalOnStopHover then
            attachment.originalOnStopHover(reg, eid)
        end
        tooltips.hide()
    end
end

--- Detach tooltip from an entity
--- @param entity number Entity ID
function tooltips.detachFromEntity(entity)
    local attachment = entity_attachments[entity]
    if not attachment then return end

    -- Restore original handlers
    local go = component_cache.get(entity, GameObject)
    if go then
        go.methods.onHover = attachment.originalOnHover
        go.methods.onStopHover = attachment.originalOnStopHover
    end

    entity_attachments[entity] = nil

    -- If this entity's tooltip is showing, hide it
    if active_target == entity then
        tooltips.hide()
    end
end

--- Show tooltip for an entity
--- @param entity number Entity ID with attached tooltip
function tooltips.showFor(entity)
    local attachment = entity_attachments[entity]
    if not attachment then return end

    local def = tooltip_definitions[attachment.name]
    if not def then return end

    -- Same target? Just reposition
    if active_target == entity and active_tooltip then
        if centerTooltipAboveEntity then
            centerTooltipAboveEntity(active_tooltip, entity, 12)
        end
        return
    end

    -- Hide previous
    tooltips.hide()

    -- Interpolate template
    local title = interpolateTemplate(def.title, attachment.params)
    local body = interpolateTemplate(def.body, attachment.params)

    -- Create tooltip using existing system
    local cacheKey = "tooltip_registry:" .. getCacheKey(attachment.name, attachment.params)

    if showSimpleTooltipAbove then
        active_tooltip = showSimpleTooltipAbove(cacheKey, title, body, entity, def.opts)
        active_target = entity
    end
end

--- Hide the currently visible tooltip
function tooltips.hide()
    if active_tooltip and hideSimpleTooltip then
        -- The cache key was used when creating, find it
        for entity, attachment in pairs(entity_attachments) do
            if entity == active_target then
                local cacheKey = "tooltip_registry:" .. getCacheKey(attachment.name, attachment.params)
                hideSimpleTooltip(cacheKey)
                break
            end
        end
    end
    active_tooltip = nil
    active_target = nil
end

--- Get the currently active tooltip entity (if any)
--- @return number? tooltipEntity
function tooltips.getActiveTooltip()
    return active_tooltip
end

--- Clear all attachments (for cleanup/reset)
function tooltips.clearAll()
    for entity in pairs(entity_attachments) do
        tooltips.detachFromEntity(entity)
    end
    tooltips.hide()
end

return tooltips
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/core/tooltip_registry.lua`
Expected: No output (syntax OK)

**Step 3: Commit**

```bash
git add assets/scripts/core/tooltip_registry.lua
git commit -m "feat(tooltips): create tooltip registry module"
```

---

## Task 9: Tooltip Registry — Integration Test

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (add test usage)

**Step 1: Add require at top of gameplay.lua**

Near other requires at the top of the file:

```lua
local tooltip_registry = require("core.tooltip_registry")
```

**Step 2: Add a test registration (temporary)**

Add near the initialization section:

```lua
-- TEST: Register a sample tooltip
tooltip_registry.register("test_tooltip", {
    title = "Test Tooltip",
    body = "This is a test with value: {value}"
})
```

**Step 3: Verify the module loads**

Run: `luac -p assets/scripts/core/gameplay.lua`
Expected: No output (syntax OK)

**Step 4: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(tooltips): integrate tooltip registry with gameplay"
```

---

## Task 10: Tooltip Registry — Migrate DSL attachHover

**Files:**
- Modify: `assets/scripts/ui/ui_syntax_sugar.lua` (~line 180, attachHover function)

**Step 1: Update attachHover to use registry**

Replace the `attachHover` function:

```lua
local function attachHover(eid, hover)
    local go = component_cache.get(eid, GameObject)
    if not go then return end

    go.state.hoverEnabled = true
    go.state.collisionEnabled = true

    -- Generate unique tooltip name for this entity
    local tooltipName = "dsl_hover_" .. tostring(eid)

    -- Try to use tooltip_registry if available
    local tooltip_registry_ok, tooltip_registry = pcall(require, "core.tooltip_registry")

    if tooltip_registry_ok and tooltip_registry then
        -- Register and attach via registry
        tooltip_registry.register(tooltipName, {
            title = localization.get(hover.title),
            body = localization.get(hover.body)
        })
        tooltip_registry.attachToEntity(eid, tooltipName, {})
    else
        -- Fallback to old behavior
        go.methods.onHover = function(_, hoveredOn, hovered)
            if showSimpleTooltipAbove then
                showSimpleTooltipAbove(
                    tooltipName,
                    localization.get(hover.title),
                    localization.get(hover.body),
                    eid
                )
            end
            go._tooltipKey = tooltipName
        end

        go.methods.onStopHover = function()
            if hideSimpleTooltip and go._tooltipKey then
                hideSimpleTooltip(go._tooltipKey)
            end
        end
    end
end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/ui/ui_syntax_sugar.lua`
Expected: No output (syntax OK)

**Step 3: Commit**

```bash
git add assets/scripts/ui/ui_syntax_sugar.lua
git commit -m "feat(tooltips): migrate DSL attachHover to use registry"
```

---

## Task 11: Final Cleanup and Testing

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (remove test code if added)

**Step 1: Remove any temporary test code**

Remove the test registration if added in Task 9.

**Step 2: Manual testing checklist**

Run the game and verify:

1. **Alt-hold preview:**
   - [ ] Hover card, hold Alt → card elevates
   - [ ] Hold Alt, hover card → card elevates
   - [ ] Release Alt → card returns to normal Z
   - [ ] Stop hovering → card returns to normal Z
   - [ ] Drag while previewing → works correctly

2. **Right-click transfer:**
   - [ ] Right-click card in inventory → moves to active board
   - [ ] Right-click card on active board → moves to inventory
   - [ ] Right-click when target is full → error sound
   - [ ] Sound plays on successful transfer

3. **Tooltip registry:**
   - [ ] DSL hover tooltips still work
   - [ ] Existing card tooltips still work

**Step 3: Commit final cleanup**

```bash
git add -A
git commit -m "feat(cards): complete card UI enhancements

- Alt-hold preview: show card at top Z while Alt held
- Right-click transfer: quick move between inventory and active board
- Tooltip registry: reusable name-based tooltip system"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1-5 | Alt-hold preview | gameplay.lua |
| 6-7 | Right-click transfer | gameplay.lua |
| 8-10 | Tooltip registry | tooltip_registry.lua, gameplay.lua, ui_syntax_sugar.lua |
| 11 | Cleanup & testing | gameplay.lua |

**Total estimated tasks:** 11 bite-sized steps with frequent commits.
