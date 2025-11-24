# System Architecture (Overview)

Lightweight snapshot of the current engine boundaries while the EngineContext migration is in progress. Keep this aligned with in-flight refactors; update when APIs stabilize.

## Core Backbone
- EngineContext: owns registry/lua/resource caches; legacy globals still mirrored during transition.
- Event Bus: not yet standardized; prefer local, light event patterns and document ownership when adding new buses.
- Registry (entt): main ECS store; creation/destruction order currently driven by init routines.
- Rendering: raylib + rlgl; layering and command buffers remain the primary draw path.
- Physics: Chipmunk2D via PhysicsManager; raw pointers remain in some paths—call out ownership when extending.
- Scripting: sol2 bindings; Lua APIs still expect legacy globals, with ctx mirror being added incrementally.

## Communication Guidelines
- Prefer direct calls inside a subsystem for perf-sensitive paths (render, hot input handlers).
- Use event-style callbacks for cross-system notifications; document event order and threading assumptions.
- When adding new APIs, accept `EngineContext&` where practical; avoid introducing new globals.

## Ownership & Lifetimes
- Context-owned systems should use unique_ptr and document destruction order.
- Shared caches (textures, animations, colors) live in EngineContext; callers treat them as observers.
- Chipmunk bodies/shapes: clean up via the owning manager; avoid storing raw pointers without comments.

## Initialization Order (current)
1) Logging/config load
2) Window/renderer setup
3) Registry creation
4) Physics manager
5) Audio/input managers
6) Asset caches (atlas, animations, colors)
7) Lua bindings

## Migration Notes
- Legacy globals are bridged to EngineContext; new code should read from context-first, globals as compatibility.
- Lua bindings may temporarily expose both old and `ctx`-based accessors; keep both in sync during rollout.
- Adding tests: prefer mocks in `tests/mocks/` and keep rendering/input stubbed to stay hermetic.

## When Updating This Doc
- Add new subsystems only when their ownership/initialization contract is understood.
- Note any platform divergences (web vs native) and perf constraints if they affect API shape.
- Keep sections concise; link to deeper design docs when they exist.
