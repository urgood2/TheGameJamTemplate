# State Tags & Active States — Lua API (Bindings Reference)

This document explains the Lua bindings you exposed for **entity state tagging** and a **global on/off state registry**. It matches the exact signatures bound in C++ and includes type annotations, examples, and best‑practice patterns. It makes entities disappear from rendering and input handling if not part of the active state.

> **Scope & intent**
>
> * `add_state_tag`, `remove_state_tag`, and `clear_state_tags` operate on an entity’s **`StateTag` component** in your ECS.
> * `active_states` is a single global **`ActiveStates`** instance with simple on/off flags you can query from anywhere in Lua.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [API Reference](#api-reference)

   * [Free Functions](#free-functions)
   * [`ActiveStates` Usertype](#activestates-usertype)
3. [Usage Patterns](#usage-patterns)
4. [Examples](#examples)
5. [Gotchas & Notes](#gotchas--notes)
6. [FAQ](#faq)

---

## Quick Start

```lua
-- Tag an entity with a named state (component-level)
add_state_tag(entity, "IN_COMBAT")

-- Later, clear the tag
clear_state_tags(entity)

-- Flip global flags (process-level)
active_states:activate("paused")
if active_states:is_active("paused") then
  -- game paused logic
end
active_states:deactivate("paused")
```

---

## API Reference

### Free Functions

#### `add_state_tag(entity, name)`

```lua
---@param entity Entity   # The entity to tag
---@param name string     # The name of the state tag
---@return nil
```

Adds or **replaces** a `StateTag` component on `entity` with the given `name`.

*Behavior*: Internally uses `registry.emplace_or_replace<StateTag>(e, name)`.

---

#### `remove_state_tag(entity)`

```lua
---@param entity Entity   # The entity from which to remove its state tag
---@return nil
```

Removes the `StateTag` component from `entity` (no-op if absent).

---

#### `clear_state_tags(entity)`

```lua
---@param entity Entity   # The entity whose state tags you want to clear
---@return nil
```

Clears any `StateTag` component(s) from `entity`. (Your binding checks the presence of `StateTag` and removes it.)

> **Note**: The current binding models a **single** `StateTag` component per entity (i.e., a single string). If you need **multiple** tags on one entity, see [Gotchas & Notes](#gotchas--notes).

---

### `ActiveStates` Usertype

The global `active_states` variable exposed to Lua references a singleton `ActiveStates` instance. Use it to toggle and query process‑wide flags.

```lua
---@class ActiveStates  # A global registry of named states you can turn on/off
```

#### Methods

##### `active_states:activate(name)`

```lua
---@param name string
---@return nil
```

Marks the given state as **active**.

##### `active_states:deactivate(name)`

```lua
---@param name string
---@return nil
```

Marks the given state as **inactive**.

##### `active_states:clear()`

```lua
---@return nil
```

Clears **all** active states.

##### `active_states:is_active(name)`

```lua
---@param name string
---@return boolean  -- true if currently active
```

Returns whether `name` is currently active.

---

## Usage Patterns

### 1) Entity‑local vs Global switches

* Use **entity tags** (`StateTag`) for *per‑entity* logic (e.g., an entity is `SLEEPING`, `IN_COMBAT`, `UI_ONLY`).
* Use **`active_states`** for *global toggles* (e.g., `paused`, `debug_overlay`, `photo_mode`).

### 2) Conditional systems

```lua
if active_states:is_active("debug_overlay") then
  draw_debug_overlay()
end

if has_tag(e, "IN_COMBAT") then  -- see the helper below
  run_combat_ai(e)
end
```

### 3) Convenience helper (Lua-side)

You can provide a small helper to check the entity’s `StateTag` value:

```lua
---Returns true if the entity has a StateTag matching name
---@param e Entity
---@param name string
---@return boolean
function has_tag(e, name)
  -- if your C++ side exposes a way to read StateTag, use it here.
  -- If not, mirror the tag on the Lua side whenever you call add/remove.
  return __state_tag_cache and __state_tag_cache[e] == name
end

-- Example cache maintenance
__state_tag_cache = __state_tag_cache or {}
function tag_entity(e, name)
  add_state_tag(e, name)
  __state_tag_cache[e] = name
end
function untag_entity(e)
  remove_state_tag(e)
  __state_tag_cache[e] = nil
end
```

> If you later expose a `get_state_tag(e)` binding, prefer that over any cache.

---

## Examples

### A) Gate AI by tag

```lua
add_state_tag(enemy, "IN_COMBAT")

function update_enemy(enemy, dt)
  if active_states:is_active("paused") then return end
  if has_tag(enemy, "IN_COMBAT") then
    enemy_ai_tick(enemy, dt)
  end
end
```

### B) Toggle global photo mode

```lua
function toggle_photo_mode()
  if active_states:is_active("photo_mode") then
    active_states:deactivate("photo_mode")
  else
    active_states:activate("photo_mode")
  end
end
```

### C) Scene transitions

```lua
-- Entering a cutscene
active_states:activate("cutscene")
-- Tag the player as UI-only so input systems treat them differently
add_state_tag(player, "UI_ONLY")

-- Leaving the cutscene
active_states:deactivate("cutscene")
clear_state_tags(player)
```

### D) Pause overlay

```lua
if active_states:is_active("paused") then
  draw_pause_menu()
else
  run_gameplay(dt)
end
```

---

## Gotchas & Notes

1. **Single `StateTag` per entity**
   The current binding uses `emplace_or_replace<StateTag>` which implies each entity can hold **only one** tag string at a time. Calling `add_state_tag(e, "B")` after `"A"` will **replace** the previous tag.
   *If you need multiple tags:* consider migrating to a `StateTags` component that stores a small set/array of strings (or hashed IDs), with bindings like `add_tag`, `remove_tag`, `has_tag`.

2. **Reading tags from Lua**
   This binding does **not** expose a getter for `StateTag`. If you need read access, either:

   * expose `get_state_tag(entity) -> string?` from C++, or
   * mirror changes in a Lua table as shown in [Usage Patterns](#usage-patterns).

3. **Global vs per-world**
   `active_states` is a single global instance shared across all scripts. If you need world‑scoped state sets (e.g., separate editor vs runtime), expose additional instances or namespaced tables.

4. **Threading / coroutines**
   If you flip `active_states` inside coroutines, keep in mind any systems reading it should be consistent within a frame. Prefer flipping at frame boundaries or centralize state changes.

5. **Determinism**
   For replay/lockstep, log and replay `active_states` transitions and entity tag changes to keep simulation deterministic.

---

## FAQ

**Q: Can I add more than one tag to an entity?**
*A:* Not with this exact binding. It represents a single `StateTag` string. Extend your component to hold a set if you need multiple.

**Q: Is `active_states` saved/loaded automatically?**
*A:* Not by this binding. Decide in your save system whether to persist global flags.

**Q: Is there a way to query all entities with a given tag from Lua?**
*A:* Not exposed here. You can add a C++ side query (`view<StateTag>`) and bind a function like `find_entities_with_tag(name)` if needed.

**Q: What about enums instead of strings?**
*A:* Strings are flexible but slower and error‑prone. For performance, consider hashed IDs or enums mapped through a registry.

---

### Changelog

* **v1.0** — Initial documentation matching the provided bindings.
