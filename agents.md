# AGENTS.md - AI Agent Knowledge Base

**Purpose**: Hierarchical knowledge base for AI agents working with this codebase.  
**Last Updated**: 2026-01-30

---

## Entry Point

For all AI coding assistance, start here:

1. **[claude.md](claude.md)** - Primary coding guidelines, patterns, and common mistakes
2. **[docs/README.md](docs/README.md)** - Full documentation index

---

## Quick Navigation by Task

### Adding Game Content
| Task | Go To |
|------|-------|
| Add a card (spell/modifier) | [docs/content-creation/ADDING_CARDS.md](docs/content-creation/ADDING_CARDS.md) |
| Add a joker (passive artifact) | [docs/content-creation/ADDING_JOKERS.md](docs/content-creation/ADDING_JOKERS.md) |
| Add a projectile | [docs/content-creation/ADDING_PROJECTILES.md](docs/content-creation/ADDING_PROJECTILES.md) |
| Add a trigger | [docs/content-creation/ADDING_TRIGGERS.md](docs/content-creation/ADDING_TRIGGERS.md) |
| Add an avatar | [docs/content-creation/ADDING_AVATARS.md](docs/content-creation/ADDING_AVATARS.md) |
| Content overview | [docs/content-creation/CONTENT_OVERVIEW.md](docs/content-creation/CONTENT_OVERVIEW.md) |

### UI Work
| Task | Go To |
|------|-------|
| Build UI panels (inventory, skill tree, etc.) | [docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md](docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md) |
| UI DSL reference | [docs/api/ui-dsl-reference.md](docs/api/ui-dsl-reference.md) |
| Sprite panels & decorations | [docs/api/sprite-panels.md](docs/api/sprite-panels.md) |
| Inventory grids | [docs/api/inventory-grid.md](docs/api/inventory-grid.md) |
| Z-order reference | [docs/api/z-order-rendering.md](docs/api/z-order-rendering.md) |

### Combat & Wand Systems
| Task | Go To |
|------|-------|
| Combat architecture overview | [docs/systems/combat/ARCHITECTURE.md](docs/systems/combat/ARCHITECTURE.md) |
| Combat quick reference | [docs/systems/combat/QUICK_REFERENCE.md](docs/systems/combat/QUICK_REFERENCE.md) |
| Wand integration | [docs/systems/combat/WAND_INTEGRATION_GUIDE.md](docs/systems/combat/WAND_INTEGRATION_GUIDE.md) |
| Wand execution internals | [docs/systems/combat/WAND_EXECUTION_ARCHITECTURE.md](docs/systems/combat/WAND_EXECUTION_ARCHITECTURE.md) |
| Projectile system | [docs/systems/combat/PROJECTILE_SYSTEM_DOCUMENTATION.md](docs/systems/combat/PROJECTILE_SYSTEM_DOCUMENTATION.md) |

### Core Systems
| System | Go To |
|--------|-------|
| Physics & collision | [docs/api/physics_docs.md](docs/api/physics_docs.md) |
| Camera | [docs/api/lua_camera_docs.md](docs/api/lua_camera_docs.md) |
| Timers & chaining | [docs/api/timer_docs.md](docs/api/timer_docs.md) |
| Signals & events | [docs/api/signal_system.md](docs/api/signal_system.md) |
| Particles | [docs/api/particles_doc.md](docs/api/particles_doc.md) |
| Entity state management | [docs/systems/core/entity_state_management_doc.md](docs/systems/core/entity_state_management_doc.md) |

### Shaders
| Task | Go To |
|------|-------|
| Shader basics | [docs/guides/shaders/RAYLIB_SHADER_GUIDE.md](docs/guides/shaders/RAYLIB_SHADER_GUIDE.md) |
| Shader snippets | [docs/guides/shaders/SHADER_SNIPPETS.md](docs/guides/shaders/SHADER_SNIPPETS.md) |
| WebGL errors | [docs/guides/shaders/shader_web_error_msgs.md](docs/guides/shaders/shader_web_error_msgs.md) |
| Shader builder API | [docs/api/shader-builder.md](docs/api/shader-builder.md) |

### Debugging & Troubleshooting
| Issue | Go To |
|-------|-------|
| General troubleshooting | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| Common pitfalls (183 documented) | [docs/guides/COMMON_PITFALLS.md](docs/guides/COMMON_PITFALLS.md) |
| Lua debugging | [docs/tools/DEBUGGING_LUA.md](docs/tools/DEBUGGING_LUA.md) |
| Profiling with Tracy | [USING_TRACY.md](USING_TRACY.md) |

---

## Source of Truth

| Domain | Authoritative Source |
|--------|---------------------|
| Lua API bindings | `assets/scripts/chugget_code_definitions.lua` |
| C++ components | `src/components/` |
| Rendering pipeline | `src/systems/shaders/` |
| Combat/wand system | `assets/scripts/combat/` + `assets/scripts/wand/` |
| UI DSL | `assets/scripts/ui/` |
| Entity factory | `assets/scripts/core/entity_builder.lua` |

---

## Code Patterns

### Entity Creation
```lua
local script = EntityType {}
script.data = { health = 100 }  -- Data BEFORE attach
script:attach_ecs {
  Transform { position = pos },
  SpriteComponent { ... }
}
```

### UI Elements (Clickable)
```lua
registry:emplace(entity, ScreenSpaceCollisionMarker {})
command_buffer.queueDraw(layer, fn, z, layer.DrawCommandSpace.Screen)
```

### Signal Handling
```lua
signal.on("event_name", handler)  -- Register
signal.emit("event_name", data)   -- Emit
signal.remove(handler_id)         -- Cleanup
```

### Timer Chains
```lua
timer.chain()
  :wait(0.5)
  :call(function() ... end)
  :start()  -- MUST call start!
```

---

## Critical Rules

1. **Data before attach**: Always assign `script.data` before `attach_ecs()`
2. **UI clicks need marker**: Add `ScreenSpaceCollisionMarker` for all clickable UI
3. **Screen vs World**: Use `DrawCommandSpace.Screen` for HUD
4. **Validate in callbacks**: Check `entity:valid()` before using in timers/signals
5. **Start your timers**: Chains require `:start()`, tweens require `:start()`
6. **Clean up groups**: Use timer groups and `timer.kill_group()` on destroy

---

## Documentation Verification Status

| Category | Files | Status |
|----------|-------|--------|
| API docs | 31 | Verified 2026-01-30 |
| UI guides | 12 | Verified 2026-01-30 |
| Combat docs | 11 | Verified 2026-01-30 |
| Content creation | 6 | Verified 2026-01-30 |
| Total pitfalls documented | 183 | [COMMON_PITFALLS.md](docs/guides/COMMON_PITFALLS.md) |

---

## See Also

- [claude.md](claude.md) - Primary AI coding guidelines
- [docs/README.md](docs/README.md) - Complete documentation index
- [docs/lua-cookbook/cookbook.md](docs/lua-cookbook/cookbook.md) - Comprehensive Lua patterns
