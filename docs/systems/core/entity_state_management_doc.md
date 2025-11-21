# State Tags & Active States — Lua API (Bindings Reference)

This document explains the Lua bindings you exposed for **entity state tagging** and a **global on/off state registry**. It matches the exact signatures bound in C++ and includes type annotations, examples, and best‑practice patterns. It makes entities disappear from rendering and input handling if not part of the active state.

> **Scope & intent**
>
> * `add_state_tag`, `remove_state_tag`, and `clear_state_tags` operate on an entity’s **`StateTag` component** in your ECS.
> * `active_states` is a single global **`ActiveStates`** instance with simple on/off flags you can query from anywhere in Lua.
> * Global wrappers `activate_state`, `deactivate_state`, `clear_states`, and `is_state_active` call into the same singleton for convenience.

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
7. [Changelog](#changelog)

---

## Quick Start

```lua
-- Tag an entity with a named state (component-level)
add_state_tag(entity, "IN_COMBAT")

-- Later, clear the tag
clear_state_tags(entity)

-- Flip global flags (process-level), two equivalent ways:
active_states:activate("paused")                 -- instance method
activate_state("paused")                         -- global wrapper

if is_state_active("paused") then                -- wrapper
  -- game paused logic
end

active_states:deactivate("paused")               -- instance method
-- or
deactivate_state("paused")                       -- wrapper
```

---

## API Reference

### Free Functions

> These are global wrappers that forward to the singleton returned by `active_states_instance()` on the C++ side.

#### `activate_state(name)`

```lua
---@param name string
---@return nil
```

Activates (enables) the given state name globally.

---

#### `deactivate_state(name)`

```lua
---@param name string
---@return nil
```

Deactivates (disables) the given state name globally.

---

#### `clear_states()`

```lua
---@return nil
```

Clears **all** currently active global states.

---

#### `is_state_active(x)`

```lua
---@overload fun(tag: StateTag): boolean
---@overload fun(name: string): boolean
---@return boolean
```

Checks whether a given state (by **tag** or by **name**) is currently active. Returns `true` if the state exists in the global set.

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

##### `active_states:is_active(name_or_tag)`

```lua
---@overload fun(tag: StateTag): boolean
---@overload fun(name: string): boolean
---@return boolean  -- true if currently active
```

Returns whether the given state is currently active.

> **Note:** Your C++ binding uses `sol::overload` to accept either a `StateTag` or a `string` name. Both are documented here.

---

## Usage Patterns

### 1) Entity‑local vs Global switches

* Use **entity tags** (`StateTag`) for *per‑entity* logic (e.g., an entity is `SLEEPING`, `IN_COMBAT`, `UI_ONLY`).
* Use **`active_states`** (or the global wrappers) for *global toggles* (e.g., `paused`, `debug_overlay`, `photo_mode`).

### 2) Conditional systems

```lua
if is_state_active("debug_overlay") then
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
  if is_state_active("paused") then return end
  if has_tag(enemy, "IN_COMBAT") then
    enemy_ai_tick(enemy, dt)
  end
end
```

### B) Toggle global photo mode

```lua
function toggle_photo_mode()
  if is_state_active("photo_mode") then
    deactivate_state("photo_mode")
  else
    activate_state("photo_mode")
  end
end
```

### C) Scene transitions

```lua
-- Entering a cutscene
activate_state("cutscene")
-- Tag the player as UI-only so input systems treat them differently
add_state_tag(player, "UI_ONLY")

-- Leaving the cutscene
deactivate_state("cutscene")
clear_state_tags(player)
```

### D) Pause overlay

```lua
if is_state_active("paused") then
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
   `active_states` is a single global instance shared across all scripts. If you need world‑scoped state sets (e.g., separate editor vs runtime), expose additional instances or namespaced tables, or rely on the free‑function wrappers mapped to different registries.

4. **Threading / coroutines**
   If you flip `active_states` inside coroutines, keep in mind any systems reading it should be consistent within a frame. Prefer flipping at frame boundaries or centralize state changes.

5. **Determinism**
   For replay/lockstep, log and replay `active_states` transitions and entity tag changes to keep simulation deterministic.

6. **Stable hashing vs std::hash**
   Your C++ uses `std::hash<std::string>` for `StateTag.hash` and the set. This is implementation‑defined and not stable across runs/versions. If you ever serialize/persist these, switch to a **stable hash** (e.g., FNV‑1a/xxHash) or store names directly.

7. **Binding safety note (C++)**
   Ensure you store **a reference** to the singleton when exposing to Lua:

   ```cpp
   ActiveStates &active_states = active_states_instance();
   lua["active_states"] = &active_states; // do not take & of a temporary copy
   ```

---

## FAQ

**Q: Can I add more than one tag to an entity?**
*A:* Not with this exact binding. It represents a single `StateTag` string. Extend your component to hold a set if you need multiple.

**Q: Is `active_states` saved/loaded automatically?**
*A:* Not by this binding. Decide in your save system whether to persist global flags.

**Q: Is there a way to query all entities with a given tag from Lua?**
*A:* Not exposed here. You can add a C++ side query (`view<StateTag>`) and bind a function like `find_entities_with_tag(name)` if needed.

**Q: Should I call wrappers or instance methods?**
*A:* Functionally equivalent. Use the style that keeps your Lua code cleaner. Wrappers are slightly terser for global toggles.

---

## Changelog

* **v1.1** — Added documentation for global wrappers (`activate_state`, `deactivate_state`, `clear_states`, `is_state_active`) and overload notes; clarified hashing and binding safety.
* **v1.0** — Initial documentation matching the provided bindings.
