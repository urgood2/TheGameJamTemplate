# API Reference Index

This index provides links to all documentation generated for the engine.

> **Note:** Binding and component counts are extracted from machine-readable inventories.
> Run `scripts/recount_scope_stats.py` to regenerate counts.

## Bindings Documentation

Sol2 Lua bindings extracted from C++ source files.

| System | Bindings | Inventory |
|--------|----------|-----------|
| Core | 83 | [bindings.core.json](../../planning/inventory/bindings.core.json) |
| Physics | 113 | [bindings.physics.json](../../planning/inventory/bindings.physics.json) |
| Layer | 133 | [bindings.layer.json](../../planning/inventory/bindings.layer.json) |
| UI | 89 | [bindings.ui.json](../../planning/inventory/bindings.ui.json) |
| Timer | 51 | [bindings.timer.json](../../planning/inventory/bindings.timer.json) |
| Input | 43 | [bindings.input.json](../../planning/inventory/bindings.input.json) |
| Scripting | 34 | [bindings.scripting.json](../../planning/inventory/bindings.scripting.json) |
| LDtk | 33 | [bindings.ldtk.json](../../planning/inventory/bindings.ldtk.json) |
| Text | 32 | [bindings.text.json](../../planning/inventory/bindings.text.json) |
| Shaders | 26 | [bindings.shaders.json](../../planning/inventory/bindings.shaders.json) |
| Util | 13 | [bindings.util.json](../../planning/inventory/bindings.util.json) |
| GIF | 11 | [bindings.gif.json](../../planning/inventory/bindings.gif.json) |
| Event | 7 | [bindings.event.json](../../planning/inventory/bindings.event.json) |
| Save | 5 | [bindings.save.json](../../planning/inventory/bindings.save.json) |

## Component Documentation

ECS components extracted from `src/components/components.hpp`.

| Category | Inventory |
|----------|-----------|
| Core | [components.core.json](../../planning/inventory/components.core.json) |
| UI | [components.ui.json](../../planning/inventory/components.ui.json) |
| Combat | [components.combat.json](../../planning/inventory/components.combat.json) |
| Physics | [components.physics.json](../../planning/inventory/components.physics.json) |
| Particles | [components.particles.json](../../planning/inventory/components.particles.json) |
| Input | [components.input.json](../../planning/inventory/components.input.json) |
| Scripting | [components.scripting.json](../../planning/inventory/components.scripting.json) |
| AI | [components.ai.json](../../planning/inventory/components.ai.json) |
| Other | [components.other.json](../../planning/inventory/components.other.json) |

## Pattern Documentation

Code patterns mined from the codebase.

| Area | Patterns Doc |
|------|--------------|
| *Coming soon* | Pattern mining in Phase 5 |

## Machine-Readable Inventories

All JSON inventories are stored in `planning/inventory/`:
- [planning/inventory/](../../planning/inventory/)
- [planning/inventory/stats.json](../../planning/inventory/stats.json) - Codebase statistics

## JSON Schemas

Validation schemas for all JSON outputs:
- [planning/schemas/](../../planning/schemas/)

## IDE Support

- [EmmyLua Stubs](../lua_stubs/) - Autocomplete for Sol2 bindings
- [.luarc.json](../../.luarc.json) - Lua Language Server configuration

## Quirks & Gotchas

Known engine quirks and ordering requirements:
- [docs/quirks.md](../quirks.md)

## cm Playbook Rules

Rule candidates for the cm coding memory system:
- [planning/cm_rules_candidates.yaml](../../planning/cm_rules_candidates.yaml)

## Test Infrastructure

- [Test README](../../assets/scripts/test/README.md) - Test harness documentation
- `test_output/` - Test outputs (gitignored)
  - `status.json` - Pass/fail summary
  - `results.json` - Per-test details
  - `report.md` - Human-readable report
  - `junit.xml` - CI integration
  - `test_manifest.json` - doc_id mappings

## CLAUDE.md Reference

Main developer guidance:
- [CLAUDE.md](../../CLAUDE.md)
