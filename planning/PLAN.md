# Counter Demo Engineering Plan v1 (roguelike-1)

## Goal
Add a small, in-engine “Counter Demo” UI screen (increment/decrement/reset) that can be launched via an environment variable, with automated unit tests validating the counter logic and a reproducible smoke-run path.

## Context (repo-specific)
- Runtime: C++20 + Lua on Raylib (native + web/Emscripten builds).
- Build/test entrypoints: `just build-debug`, `just test` (GoogleTest).
- UI authoring: Lua UI DSL via `assets/scripts/ui/ui_syntax_sugar.lua`.
- Main menu bootstrap: `assets/scripts/core/main.lua` already supports env-var gated demos/tests (e.g., `RUN_UI_FILLER_DEMO=1`).

## Non-Goals
- No new frontend stack (no Vite/React/Playwright).
- No persistence, analytics, save/load, or network.
- No changes under `assets/scripts/descent` (avoid determinism lint risks).

## Decisions (resolved before coding)
- Implement the counter as a Lua demo module under `assets/scripts/demos/`.
- Keep counter logic in a pure-Lua “model” module with zero engine/UI dependencies to make unit testing trivial.
- Integrate demo launch into `assets/scripts/core/main.lua` behind `RUN_COUNTER_DEMO=1`.
- Add GoogleTest coverage (runs under `just test`) by embedding Lua via `sol` to test the pure-Lua model.

## Acceptance Criteria (specific + testable)
### Runtime behavior
- Launching the game with `RUN_COUNTER_DEMO=1` shows a counter panel on screen.
- Initial displayed value is `Count: 0`.
- Clicking/tapping buttons updates the displayed value:
  - `Increment` increases by `+1`
  - `Decrement` decreases by `-1` (negatives allowed)
  - `Reset` sets to `0`
- Demo can be cleanly stopped/removed without leaving orphan UI entities (no errors in logs during stop).

### Automated tests (CI/local)
- `just test` passes and includes unit tests covering:
  - Initial state (`0`)
  - Increment, decrement, reset
  - Multiple operations sequence (e.g., `0 -> 1 -> 2 -> 1 -> 0`)
  - Input validation defaults (e.g., nil/invalid step uses default `1` if step is supported)

### Accessibility / Input (engine-appropriate)
- Buttons have clear text labels (`Increment`, `Decrement`, `Reset`).
- Buttons are activatable via keyboard/controller navigation using the repo’s existing UI/controller-nav behavior (manual verification).

## Public Interface / Files (concrete)
### New Lua modules
- `assets/scripts/demos/counter_model.lua`
  - Pure Lua, no `ui.*`, no `globals`, no `registry`.
  - API:
    - `new(initialCount?) -> model`
    - `increment(model, step?)`
    - `decrement(model, step?)`
    - `reset(model)`
    - `get(model) -> number`
- `assets/scripts/demos/counter_demo.lua`
  - Depends on `ui.ui_syntax_sugar` and `demos.counter_model`.
  - API:
    - `start()` spawns UI
    - `stop()` cleans up spawned UI and restores any menu offsets if changed

### Modified integration point
- `assets/scripts/core/main.lua`
  - Add env var gate:
    - `RUN_COUNTER_DEMO=1` starts demo after a short timer (pattern matches `RUN_UI_FILLER_DEMO`)
    - Optional: `AUTO_EXIT_AFTER_DEMO=1` exits after a fixed delay (for smoke runs)

### New C++ unit test
- `tests/unit/test_counter_model_lua.cpp`
  - Uses `sol::state` to set `package.path` to include `assets/scripts`.
  - Requires `demos.counter_model` and asserts acceptance sequences.

## Implementation Steps
### Phase 0 — Process + Coordination
- Triage a ready bead with `BV`, claim it (`in_progress`).
- Reserve files (exclusive) before edits:
  - `assets/scripts/core/main.lua`
  - `assets/scripts/demos/counter_demo.lua`
  - `assets/scripts/demos/counter_model.lua`
  - `tests/unit/test_counter_model_lua.cpp`
- Notify dependents via Agent Mail when the bead is closed.

### Phase 1 — Pure Counter Model (unblocks tests)
- Implement `assets/scripts/demos/counter_model.lua` as pure state + functions.
- Define step behavior:
  - Default step = `1`
  - If `step` provided, coerce to integer `>= 1` (or explicitly reject invalid and use default).

### Phase 2 — Demo UI Module
- Implement `assets/scripts/demos/counter_demo.lua`:
  - Create a single root panel using `dsl.root { ... }`.
  - Display uses either:
    - `dsl.dynamicText(function() return "Count: " .. model.count end, ...)`, or
    - a text node that is re-rendered via a small update hook (choose whichever matches existing patterns best).
  - Buttons wire to model ops and ensure displayed text updates.

### Phase 3 — Wire Into Main Menu
- In `assets/scripts/core/main.lua`, add:
  - `local runCounterDemo = os.getenv("RUN_COUNTER_DEMO") == "1"`
  - If true: `require("demos.counter_demo").start()` after a short delay (e.g., `timer.after(0.5, ...)`).
  - Optional auto-exit: if `AUTO_EXIT_AFTER_DEMO=1`, exit after a fixed duration (e.g., 5–10s) to allow smoke runs.

### Phase 4 — Unit Tests (GoogleTest + Sol)
- Add `tests/unit/test_counter_model_lua.cpp`:
  - Configure `sol::state lua; lua.open_libraries(sol::lib::base, sol::lib::package, sol::lib::math, sol::lib::table);`
  - Set `package.path` to include `<repo>/assets/scripts/?.lua` and `<repo>/assets/scripts/?/init.lua`.
  - `auto model = lua.require_script("demos.counter_model", ... )` (or `lua["require"]("demos.counter_model")`).
  - Call exported functions and assert count values.

### Phase 5 — Verification + Quality Gates
- Local verification commands (must be green):
  - `just test`
  - `just lint-descent-determinism`
- Smoke-run demo:
  - Build: `just build-debug`
  - Run: `RUN_COUNTER_DEMO=1 AUTO_EXIT_AFTER_DEMO=1 ./build/raylib-cpp-cmake-template`
  - Expect clean exit and no error logs related to UI spawning/removal.

## Parallelization Plan
- Track A (Model): `counter_model.lua` (independent, start first).
- Track B (Tests): `test_counter_model_lua.cpp` (depends only on Track A API).
- Track C (UI + Integration): `counter_demo.lua` + `core/main.lua` wiring (can proceed once Track A API is fixed).

## Deliverables
- `assets/scripts/demos/counter_model.lua`
- `assets/scripts/demos/counter_demo.lua`
- `assets/scripts/core/main.lua` demo launch hook
- `tests/unit/test_counter_model_lua.cpp`
- Verified commands documented in the bead closure message (Agent Mail)

## Done Checklist
- [ ] Bead claimed and later closed; Agent Mail notification sent
- [ ] All reserved files released
- [ ] `just test` passes
- [ ] `just lint-descent-determinism` passes
- [ ] Smoke-run works with `RUN_COUNTER_DEMO=1 AUTO_EXIT_AFTER_DEMO=1`