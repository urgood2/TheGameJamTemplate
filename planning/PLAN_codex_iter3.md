# Descent (DCSS‑Lite) — Engineering Plan v3 (Multi‑Agent, Beads‑Executable)

> **Last verified:** 2026-02-01 against `Justfile` + `bd --help` in this repo.

## 0) Outcome, Scope, Non‑Goals

### 0.1 Target Outcome (MVP)
Implement a **traditional, DCSS‑faithful roguelike mode** (“Descent”) with:
- Turn-based action economy (no frame-time impact on turns)
- Shadowcasting FOV with **visible vs explored** state
- **5 floors** with stairs transitions **1→5**
- **Boss encounter on floor 5**
- Typical run time **15–20 minutes**
- **Reproducible runs via seed** (seed shown on HUD + death/victory)

### 0.2 MVP Content Minimums
- Species: **Human**
- Background: **Gladiator**
- God: **Trog**
- Spells: **3**
- Enemies: **5 + boss** (boss may be placeholder until boss bead completes)

### 0.3 Explicit Non‑Goals (must not be added in MVP)
- Save/load or meta-progression
- Autoexplore
- Hunger, branches
- Mouse support
- Inventory grid/tetris UI (use list UX even if backend supports grids)
- New animation system beyond existing flashes/FX

---

## 1) Canonical Commands (Repo‑Correct)

### 1.1 Build + run binary used by in-engine tests and UI baselines
```bash
just build-debug
./build/raylib-cpp-cmake-template
```

### 1.2 Optional fast debug build (does **not** satisfy `./build/...` binary path)
```bash
just build-debug-fast
./build-debug/raylib-cpp-cmake-template
```

### 1.3 C++ unit tests (gtest)
```bash
just test
```

### 1.4 UI Baseline Testing (required if shared UI/layout primitives changed)
Capture (before major UI refactors):
```bash
just ui-baseline-capture
```

Verify:
```bash
just ui-verify
```

(Optional broader UI suite)
```bash
just ui-test-all
```

### 1.5 Descent in-engine Lua test suite (required for all Descent beads)
After the `RUN_DESCENT_TESTS` hook exists:
```bash
just build-debug
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
```

Headless fallback (Linux; requires `xvfb-run` installed):
```bash
xvfb-run -a env AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
```

**Exit code contract**
- Exit **0**: all Descent tests passed
- Exit **1**: any Descent test failed, timed out, or any Descent test module failed to load

---

## 2) Feature Flags + Determinism Contract (Hard Requirements)

### 2.1 Required env flags (single source of truth)
- `ENABLE_DESCENT=1`: expose Descent entry from main menu (default hidden)
- `RUN_DESCENT_TESTS=1`: run Descent test runner and exit with 0/1
- `DESCENT_SEED=<int>`: force deterministic seed for gameplay and procgen (if unset, seed is generated and displayed)
- `AUTO_START_DESCENT=1` (optional but recommended): jump directly into Descent from boot for manual soak runs

### 2.2 Determinism rules (must be enforced by tests)
- All randomness flows through `descent/rng.lua` instance(s); **no `math.random`** in Descent modules.
- No reliance on Lua table iteration order for determinism:
  - Use arrays for ordered collections
  - Sort explicitly when order matters (define comparator; test it)
- HUD and end screens must show:
  - `seed`, `floor`, `turn`, `player(x,y)`
  - death/victory: `seed`, `final_floor`, `turns`, `kills`, `cause`

### 2.3 “No side effects on require”
Every `assets/scripts/descent/**` module must be safe to `require()` during tests:
- No timers registered at require-time
- No global state mutation at require-time
- No rendering calls at require-time

---

## 3) Spec Snapshot: Contract + Sync Policy

### 3.1 Spec file (required)
Create `planning/descent_spec.md` containing **complete, explicit** values:
- Movement model: **4-way or 8-way** (choose one; define keys; tests must match)
- FOV algorithm + radius (and whether diagonals block)
- Combat formulas (melee, defense, magic/ranged if applicable)
- HP/MP scaling + XP thresholds
- Floor dimensions, per-floor quotas/events (shop/altars/miniboss/boss rules)
- Inventory capacity, pickup rules, equipment slots (MVP-only)
- Scroll identification rules + label pool rules
- Boss phase thresholds + behaviors (if unknown, define placeholders explicitly)

### 3.2 Code mirror policy (required)
- Create `assets/scripts/descent/spec.lua` that exports spec constants used by code/tests.
- Any change to values in `planning/descent_spec.md` must update `assets/scripts/descent/spec.lua` in the **same bead**.
- Tests must assert against `descent.spec` (never duplicate constants inside tests).

---

## 4) Architecture & Module Boundaries (Conflict‑Minimizing)

### 4.1 Folder layout (required)
All Descent Lua code under:
- `assets/scripts/descent/**`

Recommended substructure (to reduce multi-agent conflicts):
- `descent/init.lua` (mode entry + lifecycle)
- `descent/state.lua` (single state object; no globals)
- `descent/spec.lua` (constants)
- `descent/rng.lua` (deterministic RNG)
- `descent/map.lua` (grid + occupancy)
- `descent/fov.lua` (visibility + explored)
- `descent/pathfinding.lua` (BFS/A*)
- `descent/procgen.lua` (generation; must not own transitions)
- `descent/floor_transition.lua` (stairs + floor index changes)
- `descent/turn_manager.lua` (turn FSM)
- `descent/combat.lua`
- `descent/player.lua`
- `descent/enemy.lua` + `descent/enemies/*.lua`
- `descent/items.lua` + `descent/items_scrolls.lua`
- `descent/shop.lua`, `descent/god.lua`, `descent/spells.lua`
- `descent/ui/*` (HUD, inventory, shop, altars, char create, endings, targeting)

### 4.2 Chokepoint files (minimize touches; coordinate tightly)
Only the designated “integration agent” should touch these except by explicit dependency bead:
- `assets/scripts/core/main.lua` (env hooks + test runner hook)
- `assets/scripts/ui/main_menu_buttons.lua` (menu entry wiring)

---

## 5) Test Strategy (Automatable + Non‑Flaky)

### 5.1 Test locations (required)
- Test runner: `assets/scripts/tests/run_descent_tests.lua`
- Tests: `assets/scripts/tests/test_descent_*.lua`
- Use existing `tests.test_runner` patterns:
  - `TestRunner.reset()` before loading tests
  - `TestRunner.run_all()` returns pass/fail

### 5.2 Mandatory test categories (minimum)
- RNG determinism:
  - same seed → identical procgen outputs (hashable snapshot)
  - scripted RNG sequence → deterministic combat/AI outcomes
- Dungeon validity:
  - start and stairs are walkable (floors 1–4)
  - start→stairs reachable (BFS)
  - no overlaps (walls/entities/items)
  - quotas enforced per floor (explicit counts)
  - failure mode: after `MAX_ATTEMPTS=50`, fallback layout produced and logs seed + attempts
- FOV:
  - player tile visible
  - walls occlude correctly
  - bounds safe (corners/edges)
  - explored persists after leaving LOS
- Turn manager:
  - `PLAYER_TURN → ENEMY_TURN → PLAYER_TURN`
  - invalid/no-op input does not consume a turn
  - enemy list mutation safe during iteration
- Combat:
  - hit chance clamp matches spec
  - damage floors at 0 after armor
  - negative stats rejected (fail fast with clear error)
- AI:
  - adjacent → attack
  - visible with path → move toward
  - visible with no path → idle
  - not visible → idle
- Inventory:
  - pickup/equip/use
  - capacity enforcement and UX choice (block vs swap flow) is tested

### 5.3 Test runner timeout (anti-hang requirement)
`RUN_DESCENT_TESTS=1` must include a watchdog timeout (e.g., 15s) that:
- prints seed + module name currently loading/running
- exits with **1** if exceeded

---

## 6) Multi‑Agent Execution Protocol (Beads + Agent Mail)

### 6.1 Triage (“BV”)
Use `bd ready` as the BV equivalent:
```bash
bd ready --limit 50 --sort hybrid
bd blocked --limit 50
bd dep cycles
```

### 6.2 Claim discipline
```bash
bd update <ID> --claim --actor "$USER"
```

### 6.3 Issue template (required fields in bead description)
Every bead description must include these sections (so `bd lint` is meaningful):
- **Owned files (exclusive)**
- **Non-owned files (must not edit)**
- **Acceptance criteria (testable)**
- **Commands to run**
- **Evidence paths**
- **Dependencies / blockers**

Lint open issues:
```bash
bd lint
```

### 6.4 Evidence convention (required)
For each bead `<ID>`:
```bash
mkdir -p .sisyphus/evidence/descent/<ID>
```

Evidence must include:
- `summary.md` (what changed + how verified)
- `run.log` (or `test.log`) for any test runs
- screenshots where UI/FOV is involved
- seeds used (explicitly listed)

### 6.5 Close with evidence + comments
```bash
bd close <ID> --session "descent-mvp" --actor "$USER"
bd comments add <ID> --file .sisyphus/evidence/descent/<ID>/summary.md --actor "$USER"
```

### 6.6 Dependencies
```bash
bd dep add --type blocks <BLOCKED_ID> <BLOCKER_ID> --actor "$USER"
bd dep cycles
```

### 6.7 Agent Mail (mandatory for edits)
Before edits, reserve exact files/globs (exclusive). Avoid broad globs like `assets/scripts/**`.
- Suggested TTL: 60–120 minutes; renew as needed.
- If you need a chokepoint file (`core/main.lua`, `ui/main_menu_buttons.lua`), coordinate in-thread first.

---

## 7) Rollout / Gating (Safe Integration + One‑Line Rollback)

### 7.1 Phase 1 — Hidden (default)
- Descent code can ship inert.
- Menu entry only appears when `ENABLE_DESCENT=1`.

### 7.2 Phase 2 — Experimental (opt-in label)
When “5 floors + stairs + boss placeholder” is complete:
- Expose in main menu with label “Experimental” when `ENABLE_DESCENT=1`.
- Merge gate checklist:
  - `just test` (if any C++ touched)
  - `just build-debug`
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template`
  - `just ui-verify` if any shared UI/layout primitives changed

### 7.3 Phase 3 — MVP launch
Remove “Experimental” label only after:
- boss + victory/death screens complete
- 5-run soak evidence recorded
- 3 timed runs recorded; runtime within 15–20 min or tuning knobs documented

### 7.4 Rollback plan (must remain trivial)
Rollback is “hide entry”:
- remove/disable menu routing behind `ENABLE_DESCENT`
- keep Descent modules unused (no deletes required)

---

## 8) Beads Backlog (Parallelizable DAG, Explicit Ownership)

> Naming: every bead title prefixed with `[Descent]`.  
> Use labels: `descent`, and a lane label like `lane:A`, `lane:B`, etc.

### EPIC — `[Descent] MVP`
Create epic:
```bash
bd create "[Descent] MVP" --type epic --status open --priority P1 --actor "$USER"
```

---

### Lane A — Spec + Harness + Chokepoints (do first; unblocks everything)

#### A1 — `[Descent] Spec snapshot + spec.lua mirror`
- Owned files: `planning/descent_spec.md`, `assets/scripts/descent/spec.lua`
- Blocks: none
- Acceptance:
  - All constants needed by code/tests exist in `descent.spec`
  - `planning/descent_spec.md` explicitly defines movement model, FOV radius, inventory cap, clamp ranges
- Commands:
  - (N/A; doc-only) plus run `bd lint <ID>`
- Evidence: `.sisyphus/evidence/descent/<ID>/summary.md`

#### A2 — `[Descent] Test runner + RUN_DESCENT_TESTS hook + watchdog`
- Owned files: `assets/scripts/tests/run_descent_tests.lua`, `assets/scripts/tests/test_descent_smoke.lua`, `assets/scripts/core/main.lua`
- Blocks: none
- Acceptance:
  - `just build-debug`
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template` exits **0**
  - Introduce a temporary failing assertion → exits **1** (revert before closing bead)
  - Module load failures print a clear error and exit **1**
  - Watchdog timeout exits **1** with seed/context
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

#### A3 — `[Descent] Evidence README + standard log capture commands`
- Owned files: `.sisyphus/evidence/descent/README.md`
- Blocks: none
- Acceptance:
  - Defines required evidence artifacts per bead
  - Provides copy/paste commands to capture logs with `tee`
- Evidence: `.sisyphus/evidence/descent/<ID>/summary.md`

#### A4 — `[Descent] Optional just recipes for Descent tests`
- Owned files: `Justfile` (only if adding recipes)
- Blocks: A2
- Acceptance:
  - Adds `just test-descent` and (optional) `just test-descent-headless` that run the canonical commands
- Commands:
  - `just test-descent`
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

---

### Lane B — Mode entry + menu routing (single agent; chokepoint)

#### B1 — `[Descent] Main menu entry + ENABLE_DESCENT gating + AUTO_START_DESCENT`
- Owned files: `assets/scripts/ui/main_menu_buttons.lua`, `assets/scripts/descent/init.lua` (and only minimal supporting files needed)
- Blocks: A2
- Acceptance:
  - With `ENABLE_DESCENT=1`, Descent is reachable from main menu
  - Without `ENABLE_DESCENT=1`, Descent is not visible/accessible
  - `AUTO_START_DESCENT=1` boots into Descent directly (for soak)
  - Exiting Descent returns to main menu with cleanup (timers/entities/UI) explicitly verified
- Commands:
  - `just build-debug`
  - `ENABLE_DESCENT=1 ./build/raylib-cpp-cmake-template`
  - `AUTO_START_DESCENT=1 DESCENT_SEED=123 ./build/raylib-cpp-cmake-template`
- Evidence: `.sisyphus/evidence/descent/<ID>/seed_and_entry.md`

---

### Lane C — Core loop (turns, input, map, FOV) (parallel after B1)

#### C1 — `[Descent] Turn manager FSM`
- Owned files: `assets/scripts/descent/turn_manager.lua`
- Blocks: B1
- Acceptance (tests):
  - FSM transitions correct
  - invalid/no-op input does not advance turn
  - enemy list mutation safe mid-iteration
- Commands:
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template`
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

#### C2 — `[Descent] Map grid + occupancy API + tile↔screen transforms`
- Owned files: `assets/scripts/descent/map.lua`
- Blocks: B1
- Acceptance:
  - rectangular maps for all spec sizes
  - stable occupancy API (player/enemies/items) used by movement/procgen
  - missing glyph/sprite uses defined fallback and logs once per missing id
  - transform tests: tile→screen→tile roundtrip for on-screen tiles
- Evidence: `.sisyphus/evidence/descent/<ID>/map_screenshot.png`

#### C3 — `[Descent] Input + action selection (move vs bump-attack)`
- Owned files: `assets/scripts/descent/input.lua`
- Blocks: C1, C2
- Acceptance:
  - legal move consumes exactly one turn
  - illegal move consumes zero turns
  - bump enemy produces melee action
  - key repeat does not consume multiple turns per frame (debounce behavior defined + tested)
- Evidence: `.sisyphus/evidence/descent/<ID>/input_notes.md`

#### C4 — `[Descent] FOV + explored tracking`
- Owned files: `assets/scripts/descent/fov.lua`
- Blocks: C2
- Acceptance (tests):
  - bounds safe
  - occlusion correct
  - explored persistence correct
- Evidence: `.sisyphus/evidence/descent/<ID>/fov_screenshot.png`

---

### Lane D — RNG + Procgen + Stairs (determinism-critical; parallelizable by file split)

#### D1 — `[Descent] RNG adapter + seed plumbing + HUD seed display`
- Owned files: `assets/scripts/descent/rng.lua`, `assets/scripts/descent/ui/hud.lua`, `assets/scripts/descent/state.lua`
- Blocks: B1, A1
- Acceptance:
  - same seed → identical procgen snapshot (test)
  - HUD shows seed/floor/turn/pos
- Evidence: `.sisyphus/evidence/descent/<ID>/seed_screenshot.png`

#### D2 — `[Descent] Procgen + validation + fallback layout`
- Owned files: `assets/scripts/descent/procgen.lua`, `assets/scripts/descent/pathfinding.lua`
- Blocks: D1, C2
- Acceptance (tests):
  - walkable start/stairs
  - reachable start→stairs (BFS)
  - quotas enforced
  - no overlaps
  - fallback after `MAX_ATTEMPTS=50` with log including seed + attempts
- Evidence: `.sisyphus/evidence/descent/<ID>/gen_seeds.md` (≥5 seeds)

#### D3 — `[Descent] Stairs + floor transitions 1→5`
- Owned files: `assets/scripts/descent/floor_transition.lua`, `assets/scripts/descent/state.lua`, `assets/scripts/descent/init.lua` (only if required)
- Blocks: D2, C3
- Acceptance:
  - stepping on stairs triggers next floor
  - player state persists (HP/MP/XP/inventory)
  - floor 5 uses boss floor rules hook even if boss placeholder
- Evidence: `.sisyphus/evidence/descent/<ID>/stairs_walkthrough.md`

---

### Lane E — Combat + Enemies (parallel after D1 + C1/C2/C4)

#### E1 — `[Descent] Combat math (spec-locked)`
- Owned files: `assets/scripts/descent/combat.lua`
- Blocks: D1, C1, A1
- Acceptance (tests):
  - clamp range matches `descent.spec`
  - damage floors at 0 after armor
  - scripted RNG produces deterministic outcomes
  - negative stats rejected with clear error
- Evidence: `.sisyphus/evidence/descent/<ID>/combat_test_output.md`

#### E2 — `[Descent] Enemy definitions (5) + AI decision`
- Owned files: `assets/scripts/descent/enemy.lua`, `assets/scripts/descent/enemies/*.lua`
- Blocks: E1, D2, C4
- Acceptance (tests):
  - adjacent attack
  - chase when visible and path exists
  - idle when no path or not visible
  - deterministic processing order defined and tested
- Evidence: `.sisyphus/evidence/descent/<ID>/ai_cases.md`

#### E3 — `[Descent] Enemy turn execution + collision-safe movement`
- Owned files: `assets/scripts/descent/turn_manager.lua` (enemy-turn section only), `assets/scripts/descent/map.lua` (only if occupancy API extension needed)
- Blocks: E2, C1, C2
- Acceptance:
  - no moves into occupied tiles
  - stable iteration order (id/spawn order) tested
- Evidence: `.sisyphus/evidence/descent/<ID>/enemy_turn_log.md`

---

### Lane F — Player + Items + Character creation (UI-touching; coordinate if shared UI primitives)

#### F1 — `[Descent] Player stats + XP/leveling (spec-locked)`
- Owned files: `assets/scripts/descent/player.lua`
- Blocks: D1, E1, A1
- Acceptance:
  - XP thresholds match spec exactly (tests)
  - level-up recalculations match spec (tests)
  - level-up triggers spell selection event (UI may be stubbed until G3)
- Evidence: `.sisyphus/evidence/descent/<ID>/leveling_notes.md`

#### F2 — `[Descent] Items + inventory list UX + equip/use`
- Owned files: `assets/scripts/descent/items.lua`, `assets/scripts/descent/ui/inventory.lua`
- Blocks: C2, D1, A1
- Acceptance:
  - pickup/drop/use/equip works
  - equip modifies combat stats via `player.lua` APIs (no hidden globals)
  - capacity enforcement per spec with explicit UX (block or swap) + tests
- Evidence: `.sisyphus/evidence/descent/<ID>/inventory_screenshot.png`

#### F3 — `[Descent] Scroll identification (seeded labels, unique, persistent)`
- Owned files: `assets/scripts/descent/items_scrolls.lua`
- Blocks: F2, D1, A1
- Acceptance (tests):
  - labels randomized per run seed
  - labels unique within run
  - identification persists for the run and updates future scroll display
- Evidence: `.sisyphus/evidence/descent/<ID>/scroll_id.md`

#### F4 — `[Descent] Character creation UI (species/background)`
- Owned files: `assets/scripts/descent/ui/char_create.lua`
- Blocks: F1, F2, A1
- Acceptance:
  - cannot start without selecting both
  - starting gear matches spec
  - cancel/back returns to main menu cleanly
- Evidence: `.sisyphus/evidence/descent/<ID>/char_create_screenshot.png`

---

### Lane G — Shops / God / Spells (staggered by dependencies)

#### G1 — `[Descent] Shop system (floor 1 guaranteed) + buy/sell + reroll`
- Owned files: `assets/scripts/descent/shop.lua`, `assets/scripts/descent/ui/shop.lua`
- Blocks: D2, F2, D1, A1
- Acceptance:
  - shop appears on floor 1 per spec
  - stock deterministic per seed+floor
  - purchase atomic (no partial state)
  - reroll cost enforced; reroll deterministic given seed + reroll count
  - full inventory behavior defined + tested
- Evidence: `.sisyphus/evidence/descent/<ID>/shop_walkthrough.md`

#### G2 — `[Descent] God system (Trog) + altars + conduct enforcement`
- Owned files: `assets/scripts/descent/god.lua`, `assets/scripts/descent/ui/altar.lua`
- Blocks: D2, F1, A1
- Acceptance:
  - altars appear on required floors per spec
  - worship state persists across floors
  - conduct enforced: spell cast blocked with message while worshiping Trog (tests)
  - altar UI always has cancel/back path
- Evidence: `.sisyphus/evidence/descent/<ID>/trog_altar.md`

#### G3 — `[Descent] Spells (3) + targeting + MP usage`
- Owned files: `assets/scripts/descent/spells.lua`, `assets/scripts/descent/ui/targeting.lua`
- Blocks: F1, E1, C4, D1, G2, A1
- Acceptance (tests):
  - spell selection triggered on level-up (or start if spec says)
  - casts validate MP, LOS, range, targeting rules (explicit in spec)
  - damage/heal deterministic with scripted RNG
- Evidence: `.sisyphus/evidence/descent/<ID>/spells_demo.md`

---

### Lane H — Boss + Endings + Soak (late; gated)

#### H1 — `[Descent] Boss floor rules + boss AI + phase transitions`
- Owned files: `assets/scripts/descent/boss.lua`, `assets/scripts/descent/floor5.lua`
- Blocks: D3, E1, E3, F1, A1
- Acceptance:
  - floor 5 arena spawns per spec
  - boss phases trigger at spec thresholds
  - win condition triggers victory state
  - runtime script error does not hang: transitions to terminal ending screen showing seed + error (and exits in test mode)
- Evidence: `.sisyphus/evidence/descent/<ID>/boss_seed.md`

#### H2 — `[Descent] Victory + Death screens (seed + stats + return to menu)`
- Owned files: `assets/scripts/descent/ui/endings.lua`
- Blocks: H1, D1
- Acceptance:
  - shows seed, turns, final floor, kills, cause
  - return to main menu cleanly
- Evidence: `.sisyphus/evidence/descent/<ID>/ending_screenshot.png`

#### H3 — `[Descent] 5-run soak + timing evidence`
- Owned files: evidence only unless fixes required
- Blocks: A1–H2
- Acceptance:
  - 5 full runs without crash/hang
  - record ≥3 timed runs (wall clock start/end) and compare to 15–20 min target
  - list tuning knobs if out of band (enemy HP, floor size, spawn quotas, shop availability)
- Evidence: `.sisyphus/evidence/descent/<ID>/soak.md`

---

## 9) Shared Failure Modes + Required Behaviors (Add Tests When Applicable)

- Procgen failure to place start/stairs: fallback after `MAX_ATTEMPTS`, log seed/attempts, still produces valid reachable map
- Turn deadlock (never returns to player): watchdog/assertion in tests
- AI pathing returns nil/unreachable: enemy idles; no crash
- FOV OOB at edges/corners: clamp + explicit corner tests
- Flaky randomness: all tests inject deterministic RNG
- UI modal lock: every modal must have cancel/back; prove via scripted test or deterministic walkthrough
- Data tables malformed (missing fields/negative stats): validate on load; fail fast with module+id
- Seed visibility: on any terminal path (death/victory/error), seed/floor/turn must be shown and logged

---

## 10) Definition of Done (MVP Gate)

MVP is done only when all are true:
- Character creation (species + background) works; cancel-safe
- Turn-based movement/combat works; invalid/no-op input does not consume turns
- Shadowcasting FOV correct; explored persists
- 5 floors generate to spec; stairs transitions preserve player state
- Items: pickup/equip/use; scroll identification works
- Shop works (floor 1 guaranteed) including reroll rules
- Trog worship works; conduct blocks spellcasting with message
- 3 spells work with targeting + MP + LOS
- Boss floor 5 completes; victory/death screens show seed + stats; return to menu
- Test commands are green:
  - `just test` (when relevant)
  - `just build-debug`
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template`
  - `just ui-verify` if shared UI/layout primitives changed (and baseline captured when appropriate)
- Soak evidence recorded under `.sisyphus/evidence/descent/`