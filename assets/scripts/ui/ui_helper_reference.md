# UI Binding Syntax Sugar Reference

This document provides an easy-to-read reference guide for using the **UI binding layer** and its **syntax sugar** wrappers in Lua. It covers how to use the builder-style APIs (`UIConfigBuilder`, `UIElementTemplateNodeBuilder`) and higher-level sugar like the DSL (`dsl.*`) to define and construct UI layouts, components, and behaviors.

---

## 🧱 1. Basic Concepts

Each UI element in this system is made of **three main parts**:

| Part    | C++ Type             | Description                                              |
| ------- | -------------------- | -------------------------------------------------------- |
| Element | `UIElementComponent` | The base type that identifies a UI entity.               |
| Config  | `UIConfig`           | The settings controlling visuals, layout, and callbacks. |
| State   | `UIState`            | Runtime state like text width, focus, click timers.      |

### Common Namespaces

| Namespace                      | Description                                                                 |
| ------------------------------ | --------------------------------------------------------------------------- |
| `ui.element`                   | Functions that operate on a single UI element (draw, update, hover, click). |
| `ui.box`                       | Functions that handle groups or trees of UI elements.                       |
| `UIConfigBuilder`              | Fluent syntax for creating `UIConfig` tables programmatically.              |
| `UIElementTemplateNodeBuilder` | Fluent syntax for building UI tree definitions (hierarchical layouts).      |
| `dsl`                          | Declarative Lua syntax sugar for rapid UI composition.                      |

---

## ⚙️ 2. UIConfigBuilder Syntax

### 📄 Purpose

`UIConfigBuilder` constructs complex `UIConfig` objects using a chainable API, returning a completed config via `.build()`.

### 🧩 Syntax Example

```lua
local cfg = UIConfigBuilder.create()
    :addId("shop_button")
    :addUiType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addColor("keppel")
    :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
    :addMinWidth(200)
    :addMinHeight(60)
    :addButtonCallback(function()
        playSoundEffect("effects", "button-click")
    end)
    :addTooltip("Open the shop")
    :build()
```

### 🔍 Key Builder Methods

| Method                                            | Description                                                     |                            |
| ------------------------------------------------- | --------------------------------------------------------------- | -------------------------- |
| `:addId(string)`                                  | Sets the UI element ID.                                         |                            |
| `:addUiType(UITypeEnum)`                          | Sets the element type (e.g., TEXT, ROOT, HORIZONTAL_CONTAINER). |                            |
| `:addColor(string                                 | Color)`                                                         | Sets the background color. |
| `:addOutlineColor(string)`                        | Sets outline color.                                             |                            |
| `:addAlign(flags)`                                | Sets alignment bitmask.                                         |                            |
| `:addWidth(number)` / `:addHeight(number)`        | Sets dimensions.                                                |                            |
| `:addTooltip(string)`                             | Simple hover text tooltip.                                      |                            |
| `:addButtonCallback(fn)`                          | Called when button is clicked.                                  |                            |
| `:addInitFunc(fn)` / `:addUpdateFunc(fn)`         | Lifecycle hooks for initialization or updates.                  |                            |
| `:addProgressBar(true)`                           | Converts element to a progress bar.                             |                            |
| `:addDynamicMotion(true)`                         | Enables motion interpolation / springy feel.                    |                            |
| `:addShadow(Vector2)` / `:addShadowColor(string)` | Adds shadow offset and color.                                   |                            |
| `:addNoFill(true)`                                | Removes fill (outline-only drawing).                            |                            |
| `:addStylingType(UIStylingType)`                  | Switches between RoundedRect or NinePatch border.               |                            |
| `:build()`                                        | Finalizes and returns a `UIConfig` instance.                    |                            |

---

## 🧩 3. UIElementTemplateNodeBuilder

### 📄 Purpose

Used to build UI **hierarchies** (templates). Each node has a `type`, a `config`, and optional `children`.

### 🧩 Example

```lua
local node = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(cfg)
    :addChildren({
        UIElementTemplateNodeBuilder.create()
            :addType(UITypeEnum.TEXT)
            :addConfig(UIConfigBuilder.create()
                :addText("Hello World!")
                :addColor("white")
                :build())
            :build(),
    })
    :build()
```

### 🔍 Methods

| Method                             | Description                        |
| ---------------------------------- | ---------------------------------- |
| `:create()`                        | Starts a new node.                 |
| `:addType(UITypeEnum)`             | Sets node type.                    |
| `:addConfig(UIConfig)`             | Assigns configuration.             |
| `:addChild(UIElementTemplateNode)` | Adds one child node.               |
| `:addChildren({nodes})`            | Adds multiple children.            |
| `:build()`                         | Finalizes the node and returns it. |

---

## 🧰 4. ui.element Namespace

| Function                                                                              | Description                            |
| ------------------------------------------------------------------------------------- | -------------------------------------- |
| `ui.element.Initialize(registry, parent, uiBox, type, config)`                        | Creates a new UI element.              |
| `ui.element.Update(registry, entity, dt, config, transform, element, node)`           | Updates element per frame.             |
| `ui.element.DrawSelf(layer, entity, element, config, state, node, transform, zIndex)` | Draws element.                         |
| `ui.element.Click(registry, entity)`                                                  | Simulates a click event.               |
| `ui.element.Release(registry, entity, draggedEntity)`                                 | Handles mouse release.                 |
| `ui.element.ApplyHover(registry, entity)` / `StopHover()`                             | Triggers hover state.                  |
| `ui.element.JuiceUp(registry, entity, amount, rotation)`                              | Applies dynamic motion.                |
| `ui.element.Remove(registry, entity)`                                                 | Deletes element and children.          |
| `ui.element.DebugPrintTree(registry, root)`                                           | Prints the UI hierarchy for debugging. |

---

## 🧩 5. ui.box Namespace

Handles *whole UI trees* — alignment, placement, resizing, and drawing.

### 🔍 Common Operations

| Function                                                         | Purpose                                 |
| ---------------------------------------------------------------- | --------------------------------------- |
| `ui.box.Initialize({x=0,y=0}, templateNode)`                     | Creates a full UI tree from a template. |
| `ui.box.Recalculate(registry, uiBoxEntity)`                      | Forces a layout recalculation.          |
| `ui.box.Move(registry, uiBoxEntity, dt)`                         | Updates movement/springs.               |
| `ui.box.AddChild(registry, uiBox, templateNode, parent)`         | Adds new child to UI box.               |
| `ui.box.Remove(registry, uiBox)`                                 | Removes entire UI box tree.             |
| `ui.box.RenewAlignment(registry, entity)`                        | Refreshes alignment.                    |
| `ui.box.CalcTreeSizes(registry, root, rect, forceRecalc, scale)` | Recalculates element sizes.             |
| `ui.box.GetUIEByID(registry, node, id)`                          | Finds UI element by ID.                 |
| `ui.box.DebugPrint(registry, root)`                              | Prints structure for debugging.         |

---

## 🧩 6. Syntax Sugar DSL Layer (Recommended)

The DSL (`dsl.lua`) provides clean shorthand for creating layouts and templates.

### ✨ Example

```lua
local dsl = require("ui.ui_dsl")

local root = dsl.root{
    config = {
        color = "keppel",
        align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER,
    },
    children = {
        dsl.text("Welcome!", { color = "white", fontSize = 32 }),
        dsl.hbox{
            config = { color = "taupe_warm", padding = 4 },
            children = {
                dsl.text("Play", { color = "blackberry" }),
                dsl.text("Quit", { color = "blackberry" }),
            }
        }
    }
}

local box = dsl.spawn({x=100,y=100}, root, "HUD", 0, {
    onBoxResize = function(registry, eid, w, h)
        log_debug("Resized to:", w, h)
    end
})
```

### DSL Constructors

| DSL Function                                                      | Purpose                                         |
| ----------------------------------------------------------------- | ----------------------------------------------- |
| `dsl.root{config, children}`                                      | Creates the root UI container.                  |
| `dsl.hbox{config, children}`                                      | Creates a horizontal layout container.          |
| `dsl.vbox{config, children}`                                      | Creates a vertical layout container.            |
| `dsl.text(text, opts)`                                            | Creates a text node.                            |
| `dsl.dynamicText(fn, fontSize, effect, opts)`                     | Dynamic updating text.                          |
| `dsl.anim(id, { sprite = true, w = 40, h = 40, shadow = false })` | Animation or sprite with size + shadow toggle.  |
| `dsl.grid(rows, cols, fn)`                                        | Automatically creates a grid of child elements. |
| `dsl.applyHoverRecursive(entity)`                                 | Recursively applies hover definitions.          |
| `dsl.spawn(pos, def, layer, z, opts)`                             | Instantiates and places a full UI tree.         |

---

## 💡 7. Common Patterns

### 🧭 Declarative Layout Example

```lua
local button = dsl.hbox{
    config = {
        color = "green",
        id = "shop_button",
        align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER,
        hover = { title = "Shop", body = "Open store" },
        onClick = function() playSoundEffect("effects", "button-click") end,
    },
    children = {
        dsl.anim("icon_coin.png", { sprite = true, w = 40, h = 40, shadow = false }),
        dsl.text("Shop", { color = "blackberry" }),
    }
}
```

### 🧩 Root + Grid Example

```lua
local grid = dsl.grid(3, 3, function(r, c)
    return dsl.anim("icon_" .. tostring(r * c) .. ".png", { sprite = true, shadow = false })
end)

dsl.root{
    config = { color = "blue", minWidth = 300, minHeight = 400 },
    children = grid
}
```

---

## 🔍 8. Quick Lookup Table

| Category      | Key Types / Common Options                                                             |
| ------------- | -------------------------------------------------------------------------------------- |
| **Visuals**   | `color`, `outlineColor`, `shadowColor`, `emboss`, `stylingType`, `nPatchSourceTexture` |
| **Layout**    | `align`, `padding`, `width`, `minWidth`, `maxHeight`, `extend_up`                      |
| **Behavior**  | `buttonCallback`, `hover`, `tooltip`, `focusArgs`, `dynamicMotion`                     |
| **Hierarchy** | `parent`, `master`, `group`, `groupParent`                                             |
| **Text**      | `text`, `language`, `verticalText`, `textGetter`                                       |
| **Popups**    | `hPopup`, `dPopup`, `hPopupConfig`, `dPopupConfig`                                     |

---

## 🧠 9. Best Practices

* Prefer **DSL syntax** (`dsl.*`) for in-game UIs — it’s concise and readable.
* Use **UIConfigBuilder** only when you need procedural or conditional UI creation.
* Always use `util.getColor("colorName")` or pass strings for auto-conversion.
* Define layout widths and heights to prevent invisible backgrounds.
* Disable shadows for performance-heavy animation nodes: `shadow = false`.
* Use `dsl.applyHoverRecursive()` to ensure tooltips and hover are propagated.

---

**End of Reference**
