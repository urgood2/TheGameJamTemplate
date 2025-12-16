# Lua API Improvements Design

**Date:** 2025-12-16
**Status:** Approved

## Overview

Improve Lua API usability for rapid prototyping by fixing bugs, adding documentation, and providing type annotations.

## Scope

### In Scope
1. Fix EntityBuilder `remove_default_state_tag` bug
2. Document timer options-table API in CLAUDE.md
3. Add header documentation to key modules
4. Add LuaLS type annotations to core APIs
5. Add troubleshooting section to CLAUDE.md

### Out of Scope
- New quick.lua module (existing APIs sufficient)
- Comprehensive type annotations (core APIs only)
- Separate documentation files (inline in CLAUDE.md)

## 1. EntityBuilder Fix

### Problem
EntityBuilder doesn't call `remove_default_state_tag(entity)` after adding a custom state tag. Entities appear in multiple states.

### Solution
In `core/entity_builder.lua` lines 203-206, add:
```lua
if state and add_state_tag then
    add_state_tag(entity, state)
    if remove_default_state_tag then
        remove_default_state_tag(entity)
    end
end
```

## 2. Timer Documentation

Add to CLAUDE.md Timer System section:
- `timer.every_opts({ delay, action, times?, immediate?, tag? })`
- `timer.after_opts({ delay, action, tag? })`
- `timer.cooldown_opts({ delay, condition, action, tag? })`

## 3. Module Header Documentation

### ui/ui_syntax_sugar.lua
- Purpose: Declarative UI DSL
- Examples: dsl.root, dsl.vbox, dsl.hbox, dsl.text, dsl.anim, dsl.spawn
- Hover/tooltip pattern

### combat/wave_helpers.lua
- Purpose: Helper functions for enemy behaviors
- Document all public functions with signatures

### combat/enemy_factory.lua
- Purpose: Enemy creation with combat system integration
- `EnemyFactory.spawn(enemy_type, position, modifiers)`
- `EnemyFactory.kill(e, ctx)`

## 4. Type Annotations

### Files
- `core/entity_builder.lua`
- `core/physics_builder.lua`
- `core/timer.lua`
- `core/entity_cache.lua`
- `core/component_cache.lua`
- `combat/enemy_factory.lua`

### Style
LuaLS format with `---@class`, `---@param`, `---@return` annotations.

## 5. Troubleshooting Section

Add to CLAUDE.md:

### Entity Issues
- Entity disappeared
- Data lost on script table
- getScriptTableFromEntityID returns nil

### Physics Issues
- Collisions not working
- Physics world is nil

### Rendering Issues
- Entity not visible
- Wrong layer or z-order

### Common Lua Errors
- attempt to index nil value
- attempt to call nil value

## Estimated Effort

| Item | Effort |
|------|--------|
| EntityBuilder fix | 15 min |
| Timer docs | 30 min |
| Module header docs | 1.5 hours |
| Type annotations | 2 hours |
| Troubleshooting section | 45 min |
| **Total** | ~5 hours |
