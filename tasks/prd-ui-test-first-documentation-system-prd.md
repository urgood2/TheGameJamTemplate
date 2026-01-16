# UI Test-First Documentation System PRD

## Overview

A comprehensive testing and documentation system for the UI DSL that ensures correctness through strict validation, provides living documentation via executable showcases, and improves developer confidence with a feature-rich test runner.

## Problem Statement

The current UI DSL lacks:
1. **Validation** — Silent failures when components receive invalid props
2. **Test coverage** — No systematic way to verify UI behavior
3. **Documentation** — Examples scattered across codebase, often outdated
4. **Developer confidence** — Changes to UI code have unknown ripple effects

## Goals

| Goal | Success Metric |
|------|----------------|
| Catch configuration errors at dev time | 100% of invalid props caught before render |
| Comprehensive test coverage | 120+ tests covering all UI primitives and patterns |
| Living documentation | Every feature has both a test AND a showcase example |
| Fast feedback loop | Test suite runs in <5 seconds standalone |

## Non-Goals

- External/public API documentation (internal devs only)
- Interactive playground with live editing
- Migration tooling for existing code (additive system)
- Production runtime validation (strict mode is opt-in)

## Target Users

Internal developers working on the game UI. The system optimizes for:
- Quick iteration during development
- Confidence when refactoring
- Discoverable examples when learning new components

## Technical Approach

### 1. Strict API Layer (`dsl.strict.*`)

Opt-in validation wrapper around existing DSL:

```lua
-- Lenient (current behavior) - silent failures
dsl.vbox { childrn = { ... } }  -- typo ignored

-- Strict (new) - immediate error with context
dsl.strict.vbox { childrn = { ... } }
-- Error: Unknown property 'childrn' in vbox. Did you mean 'children'?
```

**Validation includes:**
- Required field checks
- Type validation (string, number, table, function)
- Enum validation for constrained values (e.g., `align = "center"`)
- Unknown property detection with suggestions

### 2. Test Framework

Feature-rich runner supporting:

| Feature | Description |
|---------|-------------|
| Filtering | Run specific tests by name pattern |
| Watch mode | Re-run on file changes |
| Verbose output | Show assertion details on failure |
| Timing stats | Identify slow tests |
| Standalone execution | Run without game via Lua interpreter |

**Test structure:**
```lua
describe("vbox", function()
    it("validates required children prop", function()
        local ok, err = pcall(function()
            dsl.strict.vbox {}
        end)
        expect(ok).to_be(false)
        expect(err).to_contain("missing required field: children")
    end)
end)
```

### 3. Showcase Gallery

Read-only browsable gallery of UI examples:

- **Organization**: By component type (primitives, layouts, patterns)
- **Each showcase includes**: Visual preview, source code, prop documentation
- **Code snippets**: Copy-pasteable into game code
- **Navigation**: Keyboard shortcuts for quick browsing

### 4. Documentation Format

**Hybrid approach:**

| Content | Format | Location |
|---------|--------|----------|
| API reference | LuaDoc comments | In source files |
| Usage guides | Markdown | `docs/ui/` |
| Examples | Lua showcases | `assets/scripts/ui/showcases/` |

## Architecture

```
assets/scripts/ui/
├── dsl.lua                    # Existing DSL (unchanged)
├── strict/
│   ├── init.lua               # dsl.strict.* entry point
│   ├── schemas.lua            # Prop schemas per component
│   └── validator.lua          # Validation engine
├── test/
│   ├── runner.lua             # Test runner with features
│   ├── matchers.lua           # expect().to_be(), etc.
│   └── specs/                 # Test files
│       ├── primitives_spec.lua
│       ├── layouts_spec.lua
│       └── patterns_spec.lua
└── showcases/
    ├── gallery.lua            # Gallery viewer
    ├── primitives/            # Component showcases
    ├── layouts/
    └── patterns/
```

## Rollout Plan

**Single release** when all components are complete:

| Component | Deliverable |
|-----------|-------------|
| Strict API | `dsl.strict.*` with full validation |
| Test runner | Filtering, watch mode, timing, standalone |
| Test suite | 120+ tests covering all features |
| Showcases | Gallery with all primitives, layouts, patterns |
| Documentation | API reference + usage guides |

## Success Criteria

1. **Test pass rate**: 100% of tests pass
2. **Coverage completeness**: Every UI feature has ≥1 test
3. **Showcase completeness**: Every UI feature has ≥1 showcase
4. **Error quality**: All validation errors include suggestions
5. **Standalone execution**: Tests run in <5s without game runtime

## Open Questions

1. Should showcase gallery be accessible in-game or as a separate tool?
2. What keyboard shortcut opens the showcase viewer?
3. Should strict mode log warnings for deprecated patterns?

## Appendix: Error Message Examples

```
-- Missing required field
Error: Missing required field 'children' in dsl.strict.vbox
  at assets/scripts/ui/my_panel.lua:42

-- Unknown property with suggestion  
Error: Unknown property 'onclick' in dsl.strict.button
  Did you mean 'onClick'?
  at assets/scripts/ui/my_panel.lua:15

-- Type mismatch
Error: Invalid type for 'fontSize' in dsl.strict.text
  Expected: number, got: string ("large")
  at assets/scripts/ui/my_panel.lua:28
```