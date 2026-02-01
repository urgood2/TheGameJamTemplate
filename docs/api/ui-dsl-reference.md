# UI DSL Reference

This document provides a comprehensive guide to the UI DSL (Domain Specific Language) system, used for creating both simple and complex retained-mode UI elements in the game engine.

## Table of Contents
1. [Quick Start](#quick-start)
2. [Layout Containers](#layout-containers)
3. [Basic Elements](#basic-elements)
4. [Sprite Elements](#sprite-elements)
5. [Inventory Grid System](#inventory-grid-system)
6. [Advanced Patterns](#advanced-patterns)
7. [Complete Examples](#complete-examples)
8. [Important Notes](#important-notes)

---

## Quick Start

Creating UI with the DSL follows a simple "Define once, Spawn once" pattern.

```lua
local dsl = require("ui.ui_syntax_sugar")

-- 1. Define your UI structure
local myUI = dsl.vbox {
    config = { padding = 10, color = "darkgray" },
    children = {
        dsl.text("Hello World", { fontSize = 16, color = "white" }),
        dsl.button("Click Me", { onClick = function() print("clicked!") end })
    }
}

-- 2. Spawn it at a position
local entity = dsl.spawn({ x = 100, y = 100 }, myUI, "ui", 100)
```

---

## Layout Containers

Containers organize their children into vertical or horizontal stacks.

| Function | Description |
|----------|-------------|
| `dsl.vbox { ... }` | Vertical stack: children are placed one below another. |
| `dsl.hbox { ... }` | Horizontal stack: children are placed side-by-side. |
| `dsl.root { ... }` | Root container: used as the top-level element of a UI tree. |

---

## Basic Elements

| Function | Description |
|----------|-------------|
| `dsl.text(label, opts)` | A text label. `opts` can include `fontSize`, `color`, `shadow`, etc. |
| `dsl.button(label, opts)` | A clickable button with a text label. |
| `dsl.spacer(size)` | An empty space that takes up `size` pixels in the layout direction. |
| `dsl.divider(direction, opts)` | A horizontal or vertical line that participates in the layout. |

---

## Sprite Elements

Sprite elements allow for more visually rich UI using nine-patch stretching and multi-state buttons.

### `dsl.spritePanel`
A panel that uses a sprite as its background. It can stretch to fit its content using nine-patch borders.

**Options:**
- `sprite`: Path to the sprite asset.
- `borders`: `{ left, top, right, bottom }` pixel values for nine-patch stretching.
- `sizing`: Set to `"fit_sprite"` to force the panel to the original sprite dimensions.
- `decorations`: A list of `UIDecoration` objects (see [Advanced Patterns](#advanced-patterns)).
- `children`: List of child elements.

### `dsl.spriteButton`
A button that changes its background sprite based on its state.

**Options:**
- `states`: A table mapping states to sprite paths:
  - `normal`: Default state.
  - `hover`: When the mouse is over the button.
  - `pressed`: When the button is being clicked.
  - `disabled`: When the button is not interactive.
- `borders`: Nine-patch borders for the state sprites.
- `label`: Text to display on the button.
- `onClick`: Function called when the button is clicked.

---

## Configuration Options

The `config` table for elements supports the following common options:

| Option | Description |
|--------|-------------|
| `id` | Unique string ID for looking up the element later via `ui.box.GetUIEByID`. |
| `padding` | Inner padding in pixels. |
| `color` | Background color (name string or `Color.new()`). |
| `minWidth` | Minimum width in pixels. |
| `minHeight` | Minimum height in pixels. |
| `emboss` | Depth of the 3D border effect. |
| `hover` | Boolean to enable/disable hover detection. |
| `canCollide` | Boolean to enable/disable click detection. |
| `buttonCallback` | Function called on click (alternative to `onClick`). |

---

## Spawning UI

Use `dsl.spawn` to instantiate a UI definition into the game world.

```lua
local entity = dsl.spawn(position, definition, layer, zOrder)
```

- `position`: `{ x, y }` table in screen coordinates.
- `definition`: The UI tree created using `dsl` functions.
- `layer`: The render layer (usually `"ui"`).
- `zOrder`: Higher values are drawn on top of lower values.

---

## Inventory Grid System

The `dsl.inventoryGrid` provides a high-level system for managing grids of items with drag-and-drop support.

### Creating a Grid

```lua
local gridDef = dsl.inventoryGrid {
    id = "my_inventory",
    rows = 3,
    cols = 4,
    slotSize = { w = 72, h = 100 },
    slotSpacing = 6,
    config = {
        allowDragIn = true,
        allowDragOut = true,
        stackable = false,
        maxStackSize = 5,
        slotColor = "gray",
        padding = 8,
        backgroundColor = "blackberry",
    },
    slots = {
        [1] = { filter = function(item) return true end, color = "red" },
        [12] = { locked = true },
    },
    onSlotChange = function(gridEntity, slotIndex, oldItem, newItem) end,
    onSlotClick = function(gridEntity, slotIndex, button) end,
}
```

### Tab System

Use `dsl.tabs` for tabbed interfaces:

```lua
local tabDef = dsl.tabs({
    tabs = {
        { id = "inv", label = "Inventory", content = function() return myGridDef end },
        { id = "equip", label = "Equipment", content = function() return equipGridDef end },
    },
    activeTab = "inv",
})
```

### Grid API Reference

Import the grid module: `local grid = require("core.inventory_grid")`

| Function | Description |
|----------|-------------|
| `grid.addItem(gridEntity, itemEntity, [slotIndex])` | Adds an item to the first empty slot or a specific slot. |
| `grid.removeItem(gridEntity, slotIndex)` | Removes and returns the item at the specified slot. |
| `grid.getItemAt(gridEntity, row, col)` | Returns the item entity at the given grid coordinates. |
| `grid.findEmptySlot(gridEntity)` | Returns the index of the first empty slot. |
| `grid.getUsedSlotCount(gridEntity)` | Returns the number of occupied slots. |
| `grid.getCapacity(gridEntity)` | Returns the total number of slots. |
| `grid.getAllItems(gridEntity)` | Returns a table of all items indexed by slot. |
| `grid.getSlotEntity(gridEntity, slotIndex)` | Returns the UI entity representing the slot. |
| `grid.findSlotContaining(gridEntity, itemEntity)` | Returns the slot index containing the given item. |
| `grid.getStackCount(gridEntity, slotIndex)` | Returns the number of items in the stack at that slot. |
| `grid.isSlotLocked(gridEntity, slotIndex)` | Returns true if the slot is locked. |
| `grid.getItemList(gridEntity)` | Returns a list of items with their slot indices. |
| `grid.cleanup(gridEntity)` | Cleans up grid resources. |
| `dsl.cleanupGrid(gridId)` | Cleans up internal DSL state for a grid. |

### Grid Events (via hump.signal)

| Event | Parameters |
|-------|------------|
| `grid_item_added` | `gridEntity, slotIndex, itemEntity` |
| `grid_item_removed` | `gridEntity, slotIndex, itemEntity` |
| `grid_item_moved` | `gridEntity, fromSlot, toSlot, itemEntity` |
| `grid_stack_changed` | `gridEntity, slotIndex, itemEntity, oldCount, newCount` |
| `grid_items_swapped` | `gridEntity, slot1, slot2, item1, item2` |
| `grid_slot_clicked` | `gridEntity, slotIndex, button, modifiers` |

---

## Advanced Patterns

### UIDecorations System
Used for adding badges, overlays, and ornate corners to UI elements without affecting the layout.

**Decoration Positions:**
`top_left`, `top_center`, `top_right`, `middle_left`, `center`, `middle_right`, `bottom_left`, `bottom_center`, `bottom_right`

**Decoration Options:**
- `offset`: `{ x, y }` relative to the anchor point.
- `scale`: `{ x, y }` scaling factor.
- `flip`: `"x"`, `"y"`, or `"both"`.

**Usage Example:**
```lua
local UIDecorations = require("ui.ui_decorations")

-- Add a badge to an entity
UIDecorations.addBadge(entity, {
    id = "my_badge",
    text = "5",
    position = UIDecorations.Position.BOTTOM_RIGHT,
    backgroundColor = "charcoal",
})

-- Draw decorations (must be called in a render loop)
UIDecorations.draw(entity, baseZ)
```

### Custom Immediate-Mode Panels
For pixel-perfect control, you can combine DSL containers with immediate-mode rendering.

```lua
-- 1. Create a DSL container to reserve space
local panel = dsl.vbox {
    config = { minWidth = 200, minHeight = 150, color = "blackberry" },
    children = { dsl.text("Custom Header") }
}
local entity = dsl.spawn({x=100, y=100}, panel, "ui", 100)

-- 2. Render custom primitives every frame
timer.every_opts({
    delay = 0.016,
    action = function()
        local t = component_cache.get(entity, Transform)
        command_buffer.queueDrawCircleFilled("ui", function(c)
            c.x = t.actualX + 50
            c.y = t.actualY + 80
            c.radius = 20
            c.color = Color.new(255, 0, 0, 255)
        end, 105, layer.DrawCommandSpace.Screen)
    end
})
```

### Card Entity Creation with Shaders
When creating items for the inventory, you often want them to have special rendering (like 3D skew shaders).

```lua
local function createCard(spriteName, x, y)
    local entity = animation_system.createAnimatedObjectWithTransform(spriteName, true, x, y, nil, true)
    
    -- Set screen-space collision for UI interaction
    transform.set_space(entity, "screen")
    
    -- Add shader pipeline for effects
    local shader_pipeline = _G.shader_pipeline
    local shaderPipelineComp = registry:emplace(entity, shader_pipeline.ShaderPipelineComponent)
    shaderPipelineComp:addPass("3d_skew")
    
    -- Enable interaction
    local go = component_cache.get(entity, GameObject)
    go.state.dragEnabled = true
    go.state.collisionEnabled = true
    go.state.hoverEnabled = true
    
    return entity
end
```

### Per-frame Snapping & Batched Rendering
To keep items centered on slots and render them efficiently:

```lua
-- In a render loop:
timer.run_every_render_frame(function()
    -- 1. Snap items to slots
    local items = grid.getAllItems(gridEntity)
    for slotIndex, itemEntity in pairs(items) do
        local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
        InventoryGridInit.centerItemOnSlot(itemEntity, slotEntity)
    end
    
    -- 2. Batched rendering for performance
    command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
        cmd.entities = entityList
        cmd.autoOptimize = true
    end, zOrder, layer.DrawCommandSpace.World)
end)
```

---

## Complete Examples

### Nine-Patch Panel with Decorations
```lua
function createSpritePanelDemo()
    return dsl.spritePanel {
        sprite = "ui-decor-test-2.png",
        borders = { 8, 8, 8, 8 },
        minWidth = 200,
        minHeight = 100,
        padding = 16,
        decorations = {
            { sprite = "ornate-corner.png", position = "top_left", offset = { -8, -8 } },
            { sprite = "ornate-corner.png", position = "top_right", offset = { 8, -8 }, flip = "x" },
            { sprite = "gem.png", position = "top_center", offset = { 0, -14 }, scale = { 0.6, 0.6 } },
        },
        children = {
            dsl.text("Ornate Panel", { fontSize = 12, color = "white" }),
        }
    }
end
```

### Sprite Button with States
```lua
function createSpriteButtonDemo()
    return dsl.spriteButton {
        states = {
            normal = "button-normal.png",
            hover = "button-hover.png",
            pressed = "button-pressed.png",
            disabled = "button-disabled.png"
        },
        borders = { 6, 6, 6, 6 },
        label = "Click Me",
        onClick = function()
            print("Button clicked!")
        end
    }
end
```

---

## Important Notes

- **Retained Mode**: The DSL uses retained-mode UI. You define the structure once and spawn it. The engine handles layout and rendering until the entity is removed.
- **Cleanup**: UI entities must be explicitly cleaned up to avoid memory leaks.
  ```lua
  ui.box.Remove(registry, entity)
  ```
- **Timer Cleanup**: Always use timer groups for UI-related timers so they can be killed together.
  ```lua
  timer.kill_group("my_ui_group")
  ```
- **Collision Space**: UI elements typically use screen-space collision.
  ```lua
  transform.set_space(entity, "screen")
  ```
- **Signal Handlers**: Remember to remove signal handlers when the UI is destroyed.
  ```lua
  signal.remove("event_name", handler_function)
  ```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
