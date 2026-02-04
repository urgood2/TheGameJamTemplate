# API Reference Index

This index provides links to all documentation generated for the engine.

> **Note:** Binding/component/pattern counts are extracted from machine-readable inventories.
> Run `scripts/recount_scope_stats.py` to regenerate counts.

## Bindings Documentation

Sol2 Lua bindings extracted from C++ source files.

| System | Bindings | Doc | Inventory |
|--------|----------|-----|-----------|
| Core | 149 | [core_bindings.md](../../planning/bindings/core_bindings.md) | [bindings.core.json](../../planning/inventory/bindings.core.json) |
| Physics | 135 | [physics_bindings.md](../../planning/bindings/physics_bindings.md) | [bindings.physics.json](../../planning/inventory/bindings.physics.json) |
| UI | 327 | [ui_bindings.md](../../planning/bindings/ui_bindings.md) | [bindings.ui.json](../../planning/inventory/bindings.ui.json) |
| Timer + Animation | 116 | [timer_anim_bindings.md](../../planning/bindings/timer_anim_bindings.md) | [bindings.timer_anim.json](../../planning/inventory/bindings.timer_anim.json) |
| Input + Sound + AI | 145 | [input_sound_ai_bindings.md](../../planning/bindings/input_sound_ai_bindings.md) | [bindings.input_sound_ai.json](../../planning/inventory/bindings.input_sound_ai.json) |
| Shader + Layer | 507 | [shader_layer_bindings.md](../../planning/bindings/shader_layer_bindings.md) | [bindings.shader_layer.json](../../planning/inventory/bindings.shader_layer.json) |

## Component Documentation

ECS components extracted from `src/components/components.hpp`.

| Category | Components | Inventory | Doc |
|----------|------------|-----------|-----|
| Core | 15 | [components.core.json](../../planning/inventory/components.core.json) | Pending (Phase 3) |
| UI | 126 | [components.ui.json](../../planning/inventory/components.ui.json) | Pending (Phase 3) |
| Combat | 54 | [components.combat.json](../../planning/inventory/components.combat.json) | Pending (Phase 3) |
| Physics | 18 | [components.physics.json](../../planning/inventory/components.physics.json) | Pending (Phase 3) |
| Particles | 6 | [components.particles.json](../../planning/inventory/components.particles.json) | Pending (Phase 3) |
| Input | 7 | [components.input.json](../../planning/inventory/components.input.json) | Pending (Phase 3) |
| Scripting | 5 | [components.scripting.json](../../planning/inventory/components.scripting.json) | Pending (Phase 3) |
| AI | 1 | [components.ai.json](../../planning/inventory/components.ai.json) | Pending (Phase 3) |
| Other | 414 | [components.other.json](../../planning/inventory/components.other.json) | Pending (Phase 3) |

## Pattern Documentation

Code patterns mined from the codebase.

| Area | Patterns | Doc | Inventory |
|------|----------|-----|-----------|
| Core | 12 | [core_patterns.md](../../planning/patterns/core_patterns.md) | [patterns.core.json](../../planning/inventory/patterns.core.json) |
| Combat | 12 | [combat_patterns.md](../../planning/patterns/combat_patterns.md) | [patterns.combat.json](../../planning/inventory/patterns.combat.json) |
| UI | 16 | [ui_patterns.md](../../planning/patterns/ui_patterns.md) | [patterns.ui.json](../../planning/inventory/patterns.ui.json) |
| Data | 9 | [data_patterns.md](../../planning/patterns/data_patterns.md) | [patterns.data.json](../../planning/inventory/patterns.data.json) |
| Wand | 7 | [wand_patterns.md](../../planning/patterns/wand_patterns.md) | [patterns.wand.json](../../planning/inventory/patterns.wand.json) |

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
- `test_output/status.json` - Pass/fail summary
- `test_output/results.json` - Per-test details
- `test_output/report.md` - Human-readable report
- `test_output/junit.xml` - CI integration
- `test_output/test_manifest.json` - doc_id mappings

## CLAUDE.md Reference

Main developer guidance:
- [CLAUDE.md](../../CLAUDE.md)
