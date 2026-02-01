# Card UI Enhancements Design

**Date:** 2025-12-24
**Status:** Ready for implementation

## Overview

Three card/UI interaction enhancements:

1. **Right-click card transfer** — Quick move cards between inventory and active board
2. **Alt-hold card preview** — Elevate hovered card to top Z while Alt is held
3. **Tooltip hooking system** — Reusable, name-based tooltip registry with parameterized templates

---

## Feature 1: Right-Click Card Transfer

### Behavior

- Right-click card in **inventory** → moves to **active wand/deck board**
- Right-click card on **active board** → moves to **inventory**
- If target board is at capacity → play error sound, no transfer
- Stacked cards (modifiers on actions) transfer together as a unit

### Implementation

**Location:** `assets/scripts/core/gameplay.lua`

Add `onRightClick` handler to card creation (~line 2233):

```lua
local function transferCardViaRightClick(cardEntity, cardScript)
    local currentBoard = cardScript.currentBoardEntity
    local targetBoard

    if currentBoard == inventory_board_id or currentBoard == trigger_inventory_board_id then
        -- From inventory → active board
        targetBoard = getActiveBoardForCardType(cardScript)
    else
        -- From active board → inventory
        targetBoard = getInventoryForCardType(cardScript)
    end

    if not canAcceptCard(targetBoard, cardScript) then
        playSound("error_buzz")
        return
    end

    removeCardFromBoard(cardEntity, currentBoard)
    addCardToBoard(cardEntity, targetBoard)
    triggerBoardResort(targetBoard)
end

-- In card creation, add to nodeComp.methods:
nodeComp.methods.onRightClick = function(reg, entity)
    local cardScript = getScriptTableFromEntityID(entity)
    if cardScript then
        transferCardViaRightClick(entity, cardScript)
    end
end
```

### Helper Functions Needed

```lua
-- Determine which active board based on card type (action vs trigger)
local function getActiveBoardForCardType(cardScript)
    if cardScript.cardType == "trigger" then
        return current_active_trigger_board_id
    else
        return current_active_action_board_id
    end
end

-- Determine which inventory based on card type
local function getInventoryForCardType(cardScript)
    if cardScript.cardType == "trigger" then
        return trigger_inventory_board_id
    else
        return inventory_board_id
    end
end
```

---

## Feature 2: Alt-Hold Card Preview

### Behavior

- When Alt is held AND a card is hovered → card renders at `z_orders.top_card`
- Works both ways: hover-then-Alt or Alt-then-hover
- When Alt released OR hover ends → card returns to normal Z-order
- Visual only — no functional change to card state
- If user drags while previewing → drag takes over, no re-enter preview on drop

### Implementation

**Location:** `assets/scripts/core/gameplay.lua`

**New state variables:**
```lua
local alt_preview_entity = nil
local alt_preview_original_z = nil
```

**New functions:**
```lua
local function isAltHeld()
    return IsKeyDown(KeyboardKey.KEY_LEFT_ALT) or IsKeyDown(KeyboardKey.KEY_RIGHT_ALT)
end

local function beginAltPreview(entity)
    if alt_preview_entity == entity then return end
    if alt_preview_entity then endAltPreview() end

    local layerOrder = component_cache.get(entity, LayerOrderComponent)
    if layerOrder then
        alt_preview_original_z = layerOrder.zIndex
        layerOrder.zIndex = z_orders.top_card
    end
    alt_preview_entity = entity
end

local function endAltPreview()
    if not alt_preview_entity then return end

    local layerOrder = component_cache.get(alt_preview_entity, LayerOrderComponent)
    if layerOrder and alt_preview_original_z then
        layerOrder.zIndex = alt_preview_original_z
    end
    alt_preview_entity = nil
    alt_preview_original_z = nil
end

-- Called from main update loop
local function updateAltPreview()
    if alt_preview_entity and not isAltHeld() then
        endAltPreview()
    end
end
```

**Modified onHover handler:**
```lua
nodeComp.methods.onHover = function(reg, entity, releasedOn)
    -- ... existing tooltip/motion code ...

    -- Alt preview check
    if isAltHeld() then
        beginAltPreview(entity)
    end
end
```

**Modified onStopHover handler:**
```lua
nodeComp.methods.onStopHover = function(reg, entity)
    -- ... existing tooltip hide code ...

    -- End alt preview if this was the previewed card
    if alt_preview_entity == entity then
        endAltPreview()
    end
end
```

**Edge case — drag interaction:**
```lua
nodeComp.methods.onDrag = function(reg, entity)
    -- If alt-previewing, end it (drag takes over at same Z)
    if alt_preview_entity == entity then
        alt_preview_entity = nil  -- Clear without restoring Z (drag is at top_card anyway)
        alt_preview_original_z = nil
    end
    -- ... existing drag code ...
end
```

---

## Feature 3: Tooltip Hooking System

### Overview

A centralized tooltip registry that:
- Registers tooltips by name with parameterized templates
- Attaches tooltips to any entity (cards, jokers, relics, DSL boxes)
- Handles positioning, caching, and visibility automatically
- Migrates existing tooltip patterns for consistency

### API

**New module:** `assets/scripts/core/tooltip_registry.lua`

```lua
local tooltips = require("core.tooltip_registry")

-- Register a tooltip template
tooltips.register("fire_damage", {
    title = "Fire Damage",
    body = "Deals {damage} fire damage to the target"
})

-- Register with styled colors (uses localization.getStyled internally)
tooltips.register("attack_info", {
    title = "Attack",
    body = "Deals {damage|red} {element|fire} damage"
})

-- Attach to any entity (cards, jokers, DSL boxes, etc.)
tooltips.attachToEntity(entity, "fire_damage", { damage = 25 })

-- Detach (cleanup)
tooltips.detachFromEntity(entity)

-- Manual show/hide (used by hover handlers)
tooltips.showFor(entity)
tooltips.hide()
```

### Template Interpolation

```lua
-- Template: "Deals {damage} damage"
-- Params: { damage = 25 }
-- Result: "Deals 25 damage"

-- With color: "Deals {damage|red} damage"
-- Result: "Deals [25](color=red) damage"
```

### Internal Storage

```lua
local tooltip_definitions = {}      -- name → { title, body, opts }
local entity_attachments = {}       -- entity → { name, params }
local tooltip_cache = {}            -- cache_key → tooltip entity
local active_tooltip = nil          -- currently visible tooltip entity
local active_target = nil           -- entity the tooltip is shown for
```

### Core Implementation

```lua
local tooltips = {}

function tooltips.register(name, def)
    tooltip_definitions[name] = {
        title = def.title,
        body = def.body,
        opts = def.opts or {}
    }
end

function tooltips.attachToEntity(entity, tooltipName, params)
    entity_attachments[entity] = { name = tooltipName, params = params or {} }

    -- Set up hover handlers on entity's GameObject
    local go = component_cache.get(entity, GameObject)
    if not go then return end

    go.state.hoverEnabled = true
    go.state.collisionEnabled = true

    local originalOnHover = go.methods.onHover
    local originalOnStopHover = go.methods.onStopHover

    go.methods.onHover = function(reg, eid, releasedOn)
        if originalOnHover then originalOnHover(reg, eid, releasedOn) end
        tooltips.showFor(eid)
    end

    go.methods.onStopHover = function(reg, eid)
        if originalOnStopHover then originalOnStopHover(reg, eid) end
        tooltips.hide()
    end
end

function tooltips.detachFromEntity(entity)
    entity_attachments[entity] = nil
    if active_target == entity then
        tooltips.hide()
    end
end

function tooltips.showFor(entity)
    local attachment = entity_attachments[entity]
    if not attachment then return end

    -- Same target? Just reposition
    if active_target == entity and active_tooltip then
        positionTooltip(active_tooltip, entity)
        return
    end

    tooltips.hide()

    local def = tooltip_definitions[attachment.name]
    if not def then return end

    local content = interpolateTemplate(def, attachment.params)
    local cacheKey = attachment.name .. ":" .. serializeParams(attachment.params)

    active_tooltip = getOrCreateTooltip(cacheKey, content)
    active_target = entity

    positionTooltip(active_tooltip, entity)
    showEntity(active_tooltip)
end

function tooltips.hide()
    if active_tooltip then
        hideEntity(active_tooltip)
        active_tooltip = nil
        active_target = nil
    end
end
```

### Positioning Logic

Reuses existing `centerTooltipAboveEntity()` logic:

```lua
local function positionTooltip(tooltipEntity, targetEntity)
    -- Priority: above → below → right → left
    -- Check screen clipping for each position
    -- Choose closest position without overlap
    -- Clamp to screen bounds with gap
    centerTooltipAboveEntity(tooltipEntity, targetEntity, 12)
end
```

### Caching Strategy

```lua
local tooltip_cache = {}  -- cacheKey → { entity, version }
local CACHE_VERSION = 1   -- Increment on font/language change

local function getOrCreateTooltip(cacheKey, content)
    local cached = tooltip_cache[cacheKey]
    if cached and cached.version == CACHE_VERSION then
        return cached.entity
    end

    -- Create new tooltip using existing builder
    local entity = makeSimpleTooltip(content.title, content.body, content.opts)
    tooltip_cache[cacheKey] = { entity = entity, version = CACHE_VERSION }
    return entity
end

-- On language change, invalidate cache
signal.register("language_changed", function()
    CACHE_VERSION = CACHE_VERSION + 1
end)
```

### Migration Strategy

**Phase 1: Add registry alongside existing system**
- Create `tooltip_registry.lua` with full API
- Existing tooltips continue to work

**Phase 2: Migrate card tooltips**
- In `createNewCard()`, register card tooltip: `tooltips.registerCard(cardID, card_def)`
- Attach to entity: `tooltips.attachToEntity(entity, "card:" .. cardID)`
- Simplify hover handlers to call `tooltips.showFor(entity)`

**Phase 3: Migrate other tooltips**
- Jokers, relics, avatars use `tooltips.register()` + `attachToEntity()`
- DSL `attachHover()` uses registry internally

**Backward compatibility:**
- `makeSimpleTooltip()` remains available during migration
- `showSimpleTooltipAbove()` / `hideSimpleTooltip()` continue to work

### Convenience: Card Auto-Registration

```lua
function tooltips.registerCard(cardID, card_def)
    -- Auto-generate tooltip name
    local name = "card:" .. cardID

    -- Build tooltip content from card definition
    tooltips.register(name, {
        title = card_def.name or cardID,
        body = buildCardTooltipBody(card_def),
        opts = { style = "card" }
    })

    return name
end
```

### Cleanup

```lua
-- Hook into entity destruction
signal.register("entity_destroyed", function(entity)
    tooltips.detachFromEntity(entity)
end)
```

---

## File Changes Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `assets/scripts/core/tooltip_registry.lua` | NEW | Main tooltip registry module |
| `assets/scripts/core/gameplay.lua` | MODIFY | Add right-click handler, alt-preview, migrate card tooltips |
| `assets/scripts/ui/ui_syntax_sugar.lua` | MODIFY | Use registry in `attachHover()` |

---

## Implementation Order

1. **tooltip_registry.lua** — Create new module with full API
2. **Alt-hold preview** — Add to gameplay.lua (isolated, low risk)
3. **Right-click transfer** — Add to gameplay.lua (isolated, low risk)
4. **Card tooltip migration** — Integrate registry with existing card system
5. **DSL migration** — Update `attachHover()` to use registry

---

## Testing Checklist

### Right-Click Transfer
- [ ] Right-click card in inventory → moves to active board
- [ ] Right-click card on active board → moves to inventory
- [ ] Right-click when target full → error sound, no move
- [ ] Stacked cards transfer together
- [ ] Trigger cards go to trigger board/inventory

### Alt-Hold Preview
- [ ] Hover then Alt → card elevates
- [ ] Alt then hover → card elevates immediately
- [ ] Release Alt → card returns to normal Z
- [ ] Stop hover → card returns to normal Z
- [ ] Drag while previewing → drag works, no glitch on drop
- [ ] Multiple cards → only one previewed at a time

### Tooltip Registry
- [ ] Register tooltip by name
- [ ] Attach to entity, hover shows tooltip
- [ ] Parameterized templates interpolate correctly
- [ ] Styled color syntax works
- [ ] Same tooltip reuses cached entity
- [ ] Entity destroyed → tooltip cleaned up
- [ ] DSL boxes work with attachToEntity
- [ ] Language change invalidates cache

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
