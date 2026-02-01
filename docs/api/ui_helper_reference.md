# UI DSL + Binding Dual Reference

Comprehensive overview of all Lua bindings relevant to UI construction, and their equivalent usage in the new declarative DSL (`dsl.*`).

---

## 1️⃣ UIConfigBuilder

The `UIConfigBuilder` constructs `UIConfig` components that define a UI element’s behavior, appearance, and logic.

### Binding

```lua
local cfg = UIConfigBuilder.create()
    :addId("shop_button")
    :addColor("green")
    :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
    :addButtonCallback(function() log_debug("Clicked!") end)
    :build()
```

### DSL Equivalent

```lua
dsl.hbox{
    config = {
        id = "shop_button",
        color = "green",
        align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER,
        buttonCallback = function()
            log_debug("Clicked!")
        end,
    },
    children = {
        dsl.text("Shop", { color = "white" })
    }
}
```

**Notes:**

* DSL table keys map directly to `UIConfigBuilder:addX()` functions via `ui.definitions.def`.
* `dsl.anim`, `dsl.text`, etc. automatically create nodes with corresponding `UITypeEnum` and `UIConfig`.

---

## 2️⃣ UIElementTemplateNodeBuilder

Creates nested element definitions used by the DSL.

### Binding

```lua
local node = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(cfg)
    :addChild(childNode)
    :build()
```

### DSL Equivalent

```lua
dsl.hbox{
    config = { color = "dusty_rose" },
    children = {
        dsl.text("Hello"),
        dsl.text("World")
    }
}
```

**Notes:**

* `ui.definitions.def()` converts DSL tables into these builder calls.
* `children` tables recursively produce `addChild` calls.

---

## 3️⃣ ui.element — Element-level Operations

### Initialize

```lua
ui.element.Initialize(registry, parent, uiBox, type, config)
```

**DSL Equivalent:**
Handled automatically by `dsl.root` / `dsl.hbox` / `dsl.vbox` when calling `ui.definitions.def`.

---

### ApplyAlignment

```lua
ui.element.ApplyAlignment(registry, entity, x, y)
```

**DSL Equivalent:**

```lua
ui.box.RenewAlignment(registry, myEntity)
```

(Automatically called when resizing or via `dsl.dynamicText(..., {autoAlign = true})`.)

---

### Click / Release / Hover

```lua
ui.element.Click(registry, entity)
ui.element.Release(registry, entity)
ui.element.ApplyHover(registry, entity)
ui.element.StopHover(registry, entity)
```

**DSL Equivalent:**

```lua
dsl.text("Buy", {
    onClick = function()
        playSoundEffect("effects", "button-click")
    end,
    hover = { title = "Shop", body = "Opens the store" }
})
```

**Notes:** Hover is automatically applied by `dsl.applyHoverRecursive`.

---

### DrawSelf / Update

```lua
ui.element.DrawSelf(layerPtr, entity, uie, cfg, state, node, transform)
ui.element.Update(registry, entity, dt, cfg, transform, uie, node)
```

**DSL Equivalent:** Internal — handled when rendering and layout updates occur.

---

### JuiceUp

```lua
ui.element.JuiceUp(registry, entity, amount, rot_amt)
```

**DSL Equivalent:**

```lua
ui.element.JuiceUp(registry, entity, 1.0, 0.5)
```

Can be triggered from callbacks (e.g., after button press).

---

## 4️⃣ ui.box — Container / Layout Operations

### Initialize

```lua
ui.box.Initialize({x=0, y=0}, defNode)
```

**DSL Equivalent:**

```lua
dsl.spawn({x=0, y=0}, dsl.root{
    config = { color = "blackberry" },
    children = { dsl.vbox{ children = { dsl.text("Title") } } }
})
```

---

### BuildUIElementTree

```lua
ui.box.BuildUIElementTree(registry, boxEntity, defNode, parentEntity)
```

**DSL Equivalent:**
Automatically used when calling `ui.box.Initialize()` inside `dsl.spawn`.

---

### AssignLayerOrderComponents

```lua
ui.box.AssignLayerOrderComponents(registry, box)
```

**DSL Equivalent:**
Handled internally by `dsl.spawn(pos, defNode, layer, z)`.

---

### Recalculate

```lua
ui.box.Recalculate(registry, boxEntity)
```

**DSL Equivalent:**

```lua
ui.box.Recalculate(registry, myUIBox)
```

(You might call this manually if layout changes dynamically.)

---

### RenewAlignment

```lua
ui.box.RenewAlignment(registry, entity)
```

**DSL Equivalent:**
Automatically used by `dsl.dynamicText(..., {autoAlign = true})`.

---

### AddChild / Remove / RemoveGroup

```lua
ui.box.AddChild(registry, uiBox, node, parent)
ui.box.Remove(registry, entity)
ui.box.RemoveGroup(registry, entity, group)
```

**DSL Equivalent:**
Automatically managed via nested `children` arrays.

Manual example:

```lua
ui.box.RemoveGroup(registry, myUIRoot, "inventory")
```

---

### DebugPrint

```lua
ui.box.DebugPrint(registry, boxEntity)
```

**DSL Equivalent:**

```lua
print(ui.box.DebugPrint(registry, myUIBox))
```

Use to inspect generated trees from DSL definitions.

---

### GetUIEByID

```lua
ui.box.GetUIEByID(registry, boxEntity, id)
```

**DSL Equivalent:**

```lua
local button = ui.box.GetUIEByID(registry, myUIBox, "shop_button")
```

Retrieves entities by ID assigned in `config.id`.

---

### AssignTreeOrderComponents / AssignLayerOrderComponents

```lua
ui.box.AssignTreeOrderComponents(registry, rootUIElement)
ui.box.AssignLayerOrderComponents(registry, boxEntity)
```

**DSL Equivalent:**
Handled internally by `dsl.spawn()` for new boxes.

---

### Move / Drag

```lua
ui.box.Move(registry, boxEntity, dt)
ui.box.Drag(registry, boxEntity, offset, dt)
```

**DSL Equivalent:**
Can be manually triggered for animated repositioning.

---

## 5️⃣ Extended DSL Convenience Wrappers

### dsl.hbox / dsl.vbox / dsl.root

Simplified constructors for `UITypeEnum.HORIZONTAL_CONTAINER`, `VERTICAL_CONTAINER`, and `ROOT`.

### dsl.text

Creates text elements (`UITypeEnum.TEXT`) with optional click, hover, or tooltip behavior.

### dsl.anim

Wraps `animation_system.createAnimatedObjectWithTransform` with width, height, and shadow toggles.

### dsl.spawn

Creates a new UIBox root and populates it from a definition.
Supports:

```lua
dsl.spawn({x=0,y=0}, defNode, "MainLayer", 2, { onBoxResize = function() ... end })
```

### dsl.grid

Generates uniform grid layouts:

```lua
local icons = dsl.grid(3,4,function(r,c)
    return dsl.anim("icon_"..(r*c), {w=48,h=48})
end)
```

### dsl.applyHoverRecursive

Traverses entities and applies hover handlers based on config.

---

## ✅ Summary

| Layer                        | Purpose                            | Accessed Via DSL           |
| ---------------------------- | ---------------------------------- | -------------------------- |
| UIConfigBuilder              | Element config properties          | `config = { ... }`         |
| UIElementTemplateNodeBuilder | Node structure & children          | `type` / `children` tables |
| ui.element                   | Element logic (hover, click, draw) | automatic / callbacks      |
| ui.box                       | Layout management & spawning       | `dsl.spawn`, auto-called   |

This document provides 1:1 correspondence between your DSL syntax and C++ binding calls for rapid, data-driven UI construction.

---

## 🧩 UIConfigBuilder addX() to DSL Mapping (Full Coverage)

Comprehensive mapping between all `UIConfigBuilder:addX()` bindings and their equivalent DSL `config = { ... }` usage.

### 🔹 General / Identity

| Binding                         | DSL Equivalent                  | Notes                           |
| ------------------------------- | ------------------------------- | ------------------------------- |
| `addId(id: string)`             | `id = "my_button"`              | Unique element ID.              |
| `addUiType(type: UITypeEnum)`   | `type = "HORIZONTAL_CONTAINER"` | Usually set by `dsl.hbox`, etc. |
| `addDrawLayer(layer: string)`   | `drawLayer = "MainLayer"`       | Render layer name.              |
| `addGroup(group: string)`       | `group = "inventory"`           | Focus or grouping label.        |
| `addInstanceType(type: string)` | `instanceType = "ButtonType"`   | Categorization for reuse.       |
| `addTag(tag: string)`           | `tag = "menu"`                  | Arbitrary tagging.              |

---

### 🔹 Transform / Alignment / Dimensions

| Binding                                          | DSL Equivalent                           | Notes                          |                          |
| ------------------------------------------------ | ---------------------------------------- | ------------------------------ | ------------------------ |
| `addAlign(flags: integer)`                       | `align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER` | Element alignment flags. |
| `addOffset(offset: Vector2)`                     | `offset = {x=5,y=10}`                    | Pixel offset from parent.      |                          |
| `addScale(scale: number)`                        | `scale = 1.25`                           | Scaling multiplier.            |                          |
| `addPadding(padding: number)`                    | `padding = 6`                            | Inner padding (px).            |                          |
| `addWidth(w: number)`                            | `width = 300`                            | Fixed width.                   |                          |
| `addHeight(h: number)`                           | `height = 120`                           | Fixed height.                  |                          |
| `addMinWidth(w: number)`                         | `minWidth = 200`                         | Minimum width constraint.      |                          |
| `addMinHeight(h: number)`                        | `minHeight = 120`                        | Minimum height constraint.     |                          |
| `addMaxWidth(w: number)`                         | `maxWidth = 400`                         | Maximum width constraint.      |                          |
| `addMaxHeight(h: number)`                        | `maxHeight = 300`                        | Maximum height constraint.     |                          |
| `addTextSpacing(spacing: number)`                | `textSpacing = 2`                        | Text character spacing.        |                          |
| `addRotation(angle: number)`                     | `rotation = 45`                          | Rotation in degrees.           |                          |
| `addResolution(vec: Vector2)`                    | `resolution = {x=1920,y=1080}`           | Rendering resolution scaling.  |                          |
| `addExtendUp(bool)`                              | `extendUp = true`                        | Extend vertically upward.      |                          |
| `addMid(bool)`                                   | `mid = true`                             | Midpoint alignment flag.       |                          |
| `addScaleBond(bond: InheritedPropertiesSync)`    | `scaleBond = someBond`                   | Sync scale between elements.   |                          |
| `addLocationBond(bond: InheritedPropertiesSync)` | `locationBond = someBond`                | Sync location.                 |                          |
| `addRotationBond(bond: InheritedPropertiesSync)` | `rotationBond = someBond`                | Sync rotation.                 |                          |
| `addSizeBond(bond: InheritedPropertiesSync)`     | `sizeBond = someBond`                    | Sync width/height.             |                          |

---

### 🔹 Appearance / Visual Styling

| Binding                                | DSL Equivalent                            | Notes                       |                               |
| -------------------------------------- | ----------------------------------------- | --------------------------- | ----------------------------- |
| `addColor(color: Color                 | string)`                                  | `color = "keppel"`          | Fill color (string or Color). |
| `addOutlineColor(color: Color          | string)`                                  | `outlineColor = "black"`    | Outline color.                |
| `addOutlineThickness(value: number)`   | `outlineThickness = 2.0`                  | Outline width (px).         |                               |
| `addShadow(offset: Vector2)`           | `shadow = {x=2,y=2}`                      | Drop shadow offset.         |                               |
| `addShadowColor(color: Color           | string)`                                  | `shadowColor = "gray"`      | Shadow tint.                  |
| `addStylingType(type: UIStylingType)`  | `stylingType = UIStylingType.FILLED_RECT` | Draw style.                 |                               |
| `addNPatchInfo(info: NPatchInfo)`      | `npatchInfo = myInfo`                     | N-Patch slicing data.       |                               |
| `addNPatchSourceTexture(path: string)` | `npatchSourceTexture = "ui/button.png"`   | Texture path.               |                               |
| `addPixelatedRectangle(bool)`          | `pixelatedRectangle = true`               | Nearest-neighbor rectangle. |                               |
| `addEmboss(bool)`                      | `emboss = true`                           | Beveled border visual.      |                               |
| `addLineEmboss(bool)`                  | `lineEmboss = true`                       | Outline-only emboss.        |                               |
| `addNoFill(bool)`                      | `noFill = true`                           | Disable rectangle fill.     |                               |
| `addMakeMovementDynamic(bool)`         | `makeMovementDynamic = true`              | Adds fluid motion.          |                               |
| `addStylingClass(class: string)`       | `stylingClass = "hud_button"`             | CSS-like style category.    |                               |

---

### 🔹 Interactivity / Collision / Input

| Binding                          | DSL Equivalent                        | Notes                        |
| -------------------------------- | ------------------------------------- | ---------------------------- |
| `addButtonUIE(bool)`             | `buttonUIE = true`                    | Makes element clickable.     |
| `addButtonCallback(func)`        | `buttonCallback = function() ... end` | Called on click.             |
| `addDisableButton(bool)`         | `disableButton = true`                | Disables clicking.           |
| `addButtonClicked(bool)`         | `buttonClicked = true`                | Initial clicked state.       |
| `addOnePress(bool)`              | `onePress = true`                     | Single activation only.      |
| `addButtonDelayStart(bool)`      | `buttonDelayStart = true`             | Delay before press.          |
| `addButtonDelay(number)`         | `buttonDelay = 0.3`                   | Delay duration.              |
| `addButtonDelayEnd(bool)`        | `buttonDelayEnd = true`               | Delay on release.            |
| `addButtonDelayProgress(number)` | `buttonDelayProgress = 0.5`           | Current progress value.      |
| `addButtonDistance(number)`      | `buttonDistance = 50`                 | Spacing between button sets. |
| `addCanCollide(bool)`            | `canCollide = true`                   | Enables collision area.      |
| `addDrag(bool)`                  | `drag = true`                         | Enables dragging.            |
| `addDraggable(bool)`             | `draggable = true`                    | Explicit drag flag.          |
| `addMouseWheel(bool)`            | `mouseWheel = true`                   | Enables mouse wheel input.   |

---

### 🔹 Behavior / Animation / State

| Binding                              | DSL Equivalent               | Notes                         |
| ------------------------------------ | ---------------------------- | ----------------------------- |
| `addDynamicMotion(bool)`             | `dynamicMotion = true`       | Allows smooth transitions.    |
| `addChoice(bool)`                    | `choice = true`              | Toggle behavior.              |
| `addChosen(bool)`                    | `chosen = true`              | Currently selected.           |
| `addChosenVert(bool)`                | `chosenVert = true`          | Vertically chosen state.      |
| `addFocusWithObject(bool)`           | `focusWithObject = true`     | Focus follows object.         |
| `addForceFocus(bool)`                | `forceFocus = true`          | Force focus even if disabled. |
| `addRole(role: InheritedProperties)` | `role = roleProp`            | Assigns role reference.       |
| `addNoRole(bool)`                    | `noRole = true`              | Removes inherited role.       |
| `addMid(bool)`                       | `mid = true`                 | Used for centering.           |
| `addMakeMovementDynamic(bool)`       | `makeMovementDynamic = true` | Animated repositioning.       |

---

### 🔹 Progress Bar Configuration

| Binding                                    | DSL Equivalent                                     | Notes                         |
| ------------------------------------------ | -------------------------------------------------- | ----------------------------- |
| `addProgressBar(bool)`                     | `progressBar = true`                               | Enables progress bar.         |
| `addProgressBarFetchValueLamnda(func)`     | `progressBarFetchValueLambda = function() ... end` | Getter for bar value.         |
| `addProgressBarEmptyColor(string)`         | `progressBarEmptyColor = "gray"`                   | Empty bar color.              |
| `addProgressBarFullColor(string)`          | `progressBarFullColor = "green"`                   | Full bar color.               |
| `addProgressBarMaxValue(number)`           | `progressBarMaxValue = 100`                        | Max bar range.                |
| `addProgressBarValueComponentName(string)` | `progressBarValueComponentName = "Stats"`          | Component to read value from. |
| `addProgressBarValueFieldName(string)`     | `progressBarValueFieldName = "hp"`                 | Field name for value lookup.  |

---

### 🔹 Tooltip / Hover Support

| Binding                       | DSL Equivalent                                         | Notes                    |
| ----------------------------- | ------------------------------------------------------ | ------------------------ |
| `addTooltip(string)`          | `tooltip = "Opens shop window"`                        | Simple tooltip text.     |
| `addDetailedTooltip(Tooltip)` | `tooltip = { title = "Shop", text = "Buy items" }`     | Rich tooltip object.     |
| `addOnDemandTooltip(func)`    | `onDemandTooltip = function() return Tooltip(...) end` | Dynamic tooltip builder. |
| `addHover(bool)`              | `hover = true`                                         | Enables hover detection. |

---

### 🔹 Callbacks / Script Integration

| Binding                          | DSL Equivalent                                  | Notes                          |
| -------------------------------- | ----------------------------------------------- | ------------------------------ |
| `addUpdateFunc(func)`            | `updateFunc = function() ... end`               | Called per-frame.              |
| `addInitFunc(func)`              | `initFunc = function(registry, entity) ... end` | Runs on initialization.        |
| `addInstaFunc(func)`             | `instaFunc = function() ... end`                | Executes immediately on build. |
| `addOnUIResizeFunc(func)`        | `onUIResize = function() ... end`               | Runs on UI resize.             |
| `addOnUIScalingResetToOne(func)` | `onUIScalingResetToOne = function() ... end`    | Resets scaling.                |

---

### 🔹 Popup / Focus Handling

| Binding                    | DSL Equivalent                    | Notes                        |
| -------------------------- | --------------------------------- | ---------------------------- |
| `addHPopup(bool)`          | `hPopup = true`                   | Horizontal popup.            |
| `addDPopup(bool)`          | `dPopup = true`                   | Downward popup.              |
| `addHPopupConfig(config)`  | `hPopupConfig = someConfig`       | Config for horizontal popup. |
| `addDPopupConfig(config)`  | `dPopupConfig = someConfig`       | Config for downward popup.   |
| `addFocusArgs(FocusArgs)`  | `focusArgs = {speed=2, margin=3}` | Focus behavior data.         |
| `addFocusWithObject(bool)` | `focusWithObject = true`          | Attach focus to object.      |
| `addForceFocus(bool)`      | `forceFocus = true`               | Forces focus active.         |

---

### 🔹 Advanced / Miscellaneous

| Binding                  | DSL Equivalent                | Notes                                           |
| ------------------------ | ----------------------------- | ----------------------------------------------- |
| `addResolution(Vector2)` | `resolution = {x=1280,y=720}` | Custom resolution override.                     |
| `addEmboss(bool)`        | `emboss = true`               | Adds depth highlight.                           |
| `addLineEmboss(bool)`    | `lineEmboss = true`           | Draws embossed edge.                            |
| `addExtendUp(bool)`      | `extendUp = true`             | Extends layout upward.                          |
| `addMid(bool)`           | `mid = true`                  | Centers vertically.                             |
| `build()`                | *(implicit in DSL)*           | Automatically called in `ui.definitions.def()`. |

---

✅ **Summary:** Every `addX()` builder method can be expressed directly as a field inside a DSL `config = { ... }` table. The conversion occurs automatically through dynamic reflection logic in `makeConfigFromTable()`.  Each key is transformed to the corresponding `addX()` call, making the DSL declarative, compact, and future-proof.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
