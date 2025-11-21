# Controller Navigation System (`controller_nav`)

This document explains how to use the **controller navigation system** exposed by `controller_nav.hpp` and bound to Lua as `controller_nav`. The system allows you to control UI and gameplay focus navigation using directional input (e.g., gamepad D-pad, keyboard arrows, etc.) in both **spatial** and **linear** modes, with full support for layers, groups, callbacks, and entity enable/disable control.

---

## 🧩 Overview

The system is composed of three main layers:

1. **Layers** – Group together related UI or in-game navigation contexts (e.g., menu layer, shop layer).
2. **Groups** – Contain collections of entities that can be navigated between.
3. **Entries** – Individual entities registered into groups (e.g., buttons, cards, or interactable objects).

Navigation is handled by the `NavManager` singleton, accessible globally as:

```lua
controller_nav.ud -- NavManagerUD instance
```

And convenience wrappers are exposed directly under:

```lua
controller_nav -- Global Lua table with helper functions
```

---

## 🏗️ Basic Setup

### 1. Create Groups and Layers

```lua
controller_nav.create_group("menu_buttons")
controller_nav.create_layer("main_menu")
controller_nav.add_group_to_layer("main_menu", "menu_buttons")
```

### 2. Add Entities to Groups

When creating UI or interactive entities (buttons, items, etc.), add them to the group:

```lua
controller_nav.ud:add_entity("menu_buttons", e)
```

Where `e` is an `entt::entity` representing a button or UI element.

### 3. Set Active Layer

To control which layer receives navigation input:

```lua
controller_nav.ud:set_active_layer("main_menu")
```

You can also **push** and **pop** layers dynamically to handle popups or submenus:

```lua
controller_nav.ud:push_layer("pause_menu")
controller_nav.ud:pop_layer()
```

---

## 🎮 Navigation

You can manually trigger navigation in Lua:

```lua
controller_nav.navigate("menu_buttons", "R") -- move right
controller_nav.navigate("menu_buttons", "L") -- move left
controller_nav.navigate("menu_buttons", "U") -- move up
controller_nav.navigate("menu_buttons", "D") -- move down
```

### Modes

Groups can be navigated in two modes:

* **Spatial**: Chooses the nearest element in the given direction based on screen position.
* **Linear**: Moves sequentially through the entity list.

Switch modes like this:

```lua
controller_nav.set_group_mode("menu_buttons", "spatial")
controller_nav.set_group_mode("inventory_items", "linear")
```

Enable wrap-around for linear lists:

```lua
controller_nav.set_wrap("inventory_items", true)
```

---

## 🔄 Linking Groups

You can link groups together so navigation naturally transitions between them:

```lua
controller_nav.link_groups("menu_buttons", {
    down = "shop_items",
    up = "title_buttons"
})
```

When the cursor moves down from the last entry in `menu_buttons`, it will automatically switch to the `shop_items` group.

---

## ⚡ Callbacks

You can register per-group Lua callbacks for focus and selection events:

```lua
controller_nav.set_group_callbacks("menu_buttons", {
    on_focus = function(e)
        log_debug("Focused entity:", e)
    end,
    on_unfocus = function(e)
        log_debug("Unfocused entity:", e)
    end,
    on_select = function(e)
        log_debug("Selected entity:", e)
    end
})
```

If no group-specific callback is set, global callbacks (if provided) will be used instead.

---

## 🧠 Managing Entity States

You can enable or disable entities for navigation dynamically:

```lua
controller_nav.set_entity_enabled(entity, false) -- disable
controller_nav.set_entity_enabled(entity, true)  -- enable
```

Disabled entities are skipped during navigation.

---

## 🧭 Manual Focus Control

You can force the cursor to focus on a specific entity manually:

```lua
controller_nav.focus_entity(entity)
```

This is useful when transitioning between screens or after creating UI dynamically.

---

## 🧱 Example Workflow

```lua
-- Define layout
controller_nav.create_layer("main_menu")
controller_nav.create_group("menu_buttons")
controller_nav.add_group_to_layer("main_menu", "menu_buttons")

-- Populate
for _, button in ipairs(buttonEntities) do
    controller_nav.ud:add_entity("menu_buttons", button)
end

-- Configure
controller_nav.set_group_mode("menu_buttons", "spatial")
controller_nav.set_wrap("menu_buttons", true)
controller_nav.ud:set_active_layer("main_menu")

-- Link navigation
controller_nav.link_groups("menu_buttons", { down = "shop_items" })

-- Callbacks
controller_nav.set_group_callbacks("menu_buttons", {
    on_focus = function(e) highlight(e) end,
    on_unfocus = function(e) unhighlight(e) end,
    on_select = function(e) activate_button(e) end,
})

-- Input-driven update
if input:is_pressed("ui_right") then
    controller_nav.navigate("menu_buttons", "R")
elseif input:is_pressed("ui_accept") then
    controller_nav.select_current("menu_buttons")
end
```

---

## 🧰 Debug and Validation

Validate your configuration:

```lua
controller_nav.validate()
```

Print debug information to the log:

```lua
controller_nav.debug_print_state()
```

---

## 🔍 Summary of Functions

| Function                           | Description                             |
| ---------------------------------- | --------------------------------------- |
| `create_group(name)`               | Create a navigation group               |
| `create_layer(name)`               | Create a navigation layer               |
| `add_group_to_layer(layer, group)` | Attach a group to a layer               |
| `navigate(group, dir)`             | Move focus in a direction (L/R/U/D)     |
| `select_current(group)`            | Trigger the select callback             |
| `set_entity_enabled(e, enabled)`   | Enable/disable entity                   |
| `focus_entity(e)`                  | Force focus on entity                   |
| `set_group_mode(group, mode)`      | Set group to 'spatial' or 'linear' mode |
| `set_wrap(group, bool)`            | Enable/disable wrap navigation          |
| `link_groups(from, dirs)`          | Link groups together directionally      |
| `set_group_callbacks(group, tbl)`  | Assign per-group callbacks              |
| `validate()`                       | Check layer/group consistency           |
| `debug_print_state()`              | Log the current navigation state        |

---

## 🧩 Notes

* The system automatically integrates with `entity_gamestate_management` to skip inactive entities.
* Supports **multi-layer focus stack**, useful for nested menus.
* Designed to work with `InputState` from the `input` system for full controller integration.

---

## 📘 Recommended Usage

* Define groups and layers during scene/UI initialization.
* Use `controller_nav.navigate` in your main update loop when processing input.
* Combine with visual highlights or sound cues on `on_focus`/`on_select` callbacks for responsive UI.
