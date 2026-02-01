# Descent (DCSS‑Lite) — Engineering Plan v2 (Multi‑Agent, Beads‑Executable)

## 0) Outcome, Scope, Non‑Goals

### Target Outcome (MVP)
A **DCSS-faithful traditional roguelike** mode (“Descent”) with:
- **Turn-based** movement/combat (no frame-time effects on action economy)
- **Shadowcasting FOV** with **visible vs explored** tiles
- **5 floors**, stairs transitions **1→5**
- **Boss encounter on floor 5**
- Typical run time: **15–20 minutes**
- Reproducible runs via **seed** (seed shown on HUD + death/victory)

### MVP Content Minimums
- Species: **Human**
- Background: **Gladiator**
- God: **Trog**
- Spells: **3**
- Enemies: **5** + **boss** (placeholder allowed until boss bead is complete)

### Explicit Non‑Goals (MVP must not include)
- Save/load, meta-progression
- Autoexplore
- Hunger, branches
- Mouse support
- Inventory tetris UI (use list UX even if backend can support grids)
- Full animation system beyond existing flashes/FX

---

## 1) Canonical Commands (Verified Against Repo `Justfile`)

> **Important:** UI baseline recipes reference `./build/raylib-cpp-cmake-template` (not `./build-debug/...`). If you run UBS or in-engine tests, build `build/` first.

### 1.1 Build (native)
```bash
just build-debug
# Binary used by UBS and in-engine tests:
./build/raylib-cpp-cmake-template
```

Optional fast single-config (does NOT satisfy UBS binary path):
```bash
just build-debug-fast
./build-debug/raylib-cpp-cmake-template
```

### 1.2 C++ unit tests (gtest)
```bash
just test
```

### 1.3 UBS (UI baseline suite) — required before commits that touch shared UI/layout primitives
Capture (only once per branch, before major UI changes):
```bash
just ui-baseline-capture
```

Verify (run after UI changes):
```bash
just ui-verify
```

### 1.4 In-engine Lua test execution (Descent suite)
After adding `RUN_DESCENT_TESTS` hook:
```bash
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template
```

Headless CI fallback (Linux):
```bash
xvfb-run -a env AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template
```

Acceptance for the hook:
- Exit code **0** when all Descent tests pass
- Exit code **1** when any Descent test fails or any Descent test module fails to load

---

## 2) Repo Source of Truth: Spec Snapshot (Make Design Self‑Contained)

### 2.1 Required file
Create `planning/descent_spec.md` containing (verbatim, as the implementation contract):
- Combat formulas (melee + ranged/magic + defense)
- HP/MP scaling + XP formulas
- Floor dimensions + per-floor quotas/events (shop/altars/miniboss/boss rules)
- MVP content tables (species/background/god/spells/enemies)
- Boss phases (thresholds + behaviors) **if defined**; otherwise define placeholders explicitly

### 2.2 Spec change policy
- Any formula/content change must update `planning/descent_spec.md` in the same PR.
- Any test that asserts spec values must reference a single canonical module (e.g., `descent/spec.lua`) that is generated/maintained to mirror the markdown.

---

## 3) Module Boundaries + Determinism Contract

### 3.1 New code location
All Descent Lua code lives under:
- `assets/scripts/descent/**`

### 3.2 Required determinism contract
All randomness routes through a single adapter:
- `descent/rng.lua` with:
  - `rng.new(seed)` → instance
  - `rng:next_int(min, max)` / `rng:next_float()` (exact API defined in bead C1)
  - deterministic scripted RNG for tests (sequence-based)

Repro requirements:
- HUD shows: `seed`, `floor`, `turn`, `player(x,y)`
- Death/victory screens show: `seed`, `final_floor`, `turns`, `kills`, `cause`

### 3.3 Required “no side effects on require”
Every `descent/*.lua` module must be safe to `require()` during tests:
- No timers registered at require-time
- No global state mutation at require-time
- No rendering calls at require-time

---

## 4) Test Strategy (Concrete + Automatable)

### 4.1 Descent tests (embedded Lua)
- Tests live at `assets/scripts/tests/test_descent_*.lua`
- A single runner module: `assets/scripts/tests/run_descent_tests.lua`
  - Uses `tests.test_runner` (same pattern as UIValidator runner)
  - Calls `TestRunner.reset()` then loads Descent tests then calls `TestRunner.run_all()`
  - Returns `true/false`

### 4.2 Required test categories (minimum set)
- RNG determinism: same seed → identical generation outputs
- Dungeon validity:
  - start tile walkable
  - stairs tile walkable (floors 1–4)
  - start→stairs reachable (BFS)
  - no overlaps (walls/entities/items)
  - quota enforcement per floor
- FOV correctness:
  - player tile always visible
  - walls occlude
  - bounds safe at edges/corners
  - explored persists
- Turn manager:
  - state transitions: `PLAYER_TURN → ENEMY_TURN → PLAYER_TURN`
  - “no-op” inputs do not consume turns
  - enemy list mutation safe during iteration
- Combat math:
  - hit chance clamp (define clamp range in spec and assert)
  - damage floors at 0 after armor
  - deterministic outcomes with scripted RNG
- AI:
  - adjacent → attack
  - visible with path → move toward
  - visible with no path → idle
  - not visible → idle
- Inventory rules:
  - pickup/equip/use
  - full inventory handling (max size defined)

### 4.3 `RUN_DESCENT_TESTS` hook integration
Add a branch in `assets/scripts/core/main.lua` consistent with existing env-flag tests:
- If `RUN_DESCENT_TESTS=1`:
  - `pcall(require, "tests.run_descent_tests")`
  - if load fails → print error → `os.exit(1)`
  - run; exit `0` on success else `1`
- Must execute **before** entering normal game state (`changeGameState(...)`)

---

## 5) Multi‑Agent Execution Protocol (Beads + Agent Mail)

### 5.1 Beads triage (“BV”)
```bash
bd ready --limit 50 --sort hybrid
```

### 5.2 Claim / status discipline
- Claim sets assignee to actor and status to `in_progress`:
```bash
bd update <ID> --claim --actor "$USER"
```

### 5.3 Close with evidence
- Evidence must be written under `.sisyphus/evidence/descent/<ID>/`
- Close + comment:
```bash
bd close <ID> --session "descent-mvp" --actor "$USER"
bd comments add <ID> --file .sisyphus/evidence/descent/<ID>/summary.md --actor "$USER"
```

### 5.4 Dependencies
```bash
bd dep add --type blocks <BLOCKED_ID> <BLOCKER_ID> --actor "$USER"
bd dep cycles
```

### 5.5 Agent Mail file reservations (mandatory before edits)
- Reserve only the exact files/globs you will touch (exclusive).
- Never reserve broad globs like `assets/scripts/**`.

---

## 6) Rollout / Gating Plan (Safe Integration)

### Phase 1: Hidden mode (default)
- Descent entry is gated behind `ENABLE_DESCENT=1` (env flag) or a Dev-only menu path.
- Default builds do not expose Descent.

### Phase 2: Experimental label
- After “5 floors + stairs” milestone passes, expose in main menu with “Experimental”.
- Required checks before merge:
  - `just test`
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template`
  - `just ui-verify` if shared UI/layout primitives changed

### Phase 3: MVP launch
- Remove “Experimental” after:
  - boss + victory/death complete
  - 5-run soak evidence recorded
  - average run time measured (≥3 timed runs) within target band

Rollback:
- One-line rollback path: disable menu routing / ignore `ENABLE_DESCENT` and keep code inert.

---

## 7) Beads Backlog (Parallelizable, With Ownership + Dependencies)

> Convention: bead titles prefixed with `[Descent]`.  
> Each bead’s description MUST include: **Owned files**, **Acceptance**, **Commands run**, **Evidence paths**.

### EPIC: `[Descent] MVP`
Create epic:
```bash
bd create "[Descent] MVP" --type epic --status open --priority P1 --actor "$USER"
```

---

### Lane A — Spec + Harness (highest leverage; minimal conflicts)

#### A1 — `[Descent] Add spec snapshot (repo-local)`
- Owned files: `planning/descent_spec.md`
- Blocks: none
- Acceptance:
  - File exists with complete formulas + floor rules + MVP content tables
  - Any constants needed by code are explicitly stated (clamp ranges, inventory max, FOV radius)
- Evidence: `.sisyphus/evidence/descent/<ID>/descent_spec.md` (copy of the final spec file contents or key excerpts)

#### A2 — `[Descent] Add Descent Lua test runner + core hook`
- Owned files: `assets/scripts/tests/run_descent_tests.lua`, `assets/scripts/tests/test_descent_smoke.lua`, `assets/scripts/core/main.lua`
- Blocks: none
- Acceptance:
  - `just build-debug`
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template` exits **0** with passing tests
  - Add one intentionally failing assertion in `test_descent_smoke.lua` → exits **1** (then revert the intentional failure)
  - Failure to `require()` any Descent test module prints a clear error and exits **1**
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log` (captured console output)

#### A3 — `[Descent] Create evidence directory conventions`
- Owned files: `.sisyphus/evidence/descent/README.md` (and directory creation)
- Blocks: none
- Acceptance:
  - Defines required evidence artifacts per bead (logs, screenshots, seeds, commands)
  - Defines naming: `.sisyphus/evidence/descent/<ID>/...`
- Evidence: `.sisyphus/evidence/descent/<ID>/summary.md`

---

### Lane B — Mode entry + minimal UI routing (keep surface area small)

#### B1 — `[Descent] Mode entrypoint + gating flag`
- Owned files: `assets/scripts/descent/init.lua`, the smallest possible router/menu file needed for entry
- Blocks: A2
- Acceptance:
  - With `ENABLE_DESCENT=1`, Descent mode is reachable
  - Without `ENABLE_DESCENT=1`, Descent mode is not reachable
  - Exiting Descent returns cleanly to main menu without leaving timers/entities behind (define exact cleanup actions in bead)
- Evidence: `.sisyphus/evidence/descent/<ID>/seed_and_entry.md` (seed shown + reproduction steps)

---

### Lane C — Core loop (turns, map, input, FOV) (can be split across agents by file ownership)

#### C1 — `[Descent] Turn manager (deterministic state machine)`
- Owned files: `assets/scripts/descent/turn_manager.lua`
- Blocks: B1
- Acceptance (tests):
  - `PLAYER_TURN → ENEMY_TURN → PLAYER_TURN`
  - Player invalid action does **not** advance the turn
  - Enemy iteration safe under mutation (kill/remove mid-loop)
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

#### C2 — `[Descent] Map grid + coordinate transforms + draw adapter`
- Owned files: `assets/scripts/descent/map.lua`
- Blocks: B1
- Acceptance:
  - Can render a rectangular map at all specified floor sizes
  - Missing glyph/sprite name renders a defined fallback glyph and logs once
  - Coordinate transforms tested: tile↔screen mapping is bijective for on-screen tiles
- Evidence: `.sisyphus/evidence/descent/<ID>/map_screenshot.png`

#### C3 — `[Descent] Input handling + bump-to-attack action selection`
- Owned files: `assets/scripts/descent/input.lua` (or `player.lua` if that’s the established pattern; pick one and document)
- Blocks: C1, C2
- Acceptance:
  - Movement consumes a turn only if legal
  - Bump enemy triggers melee attack action
  - Held/repeat keys do not consume multiple turns per frame (explicit debounce behavior defined and tested)
- Evidence: `.sisyphus/evidence/descent/<ID>/input_notes.md`

#### C4 — `[Descent] FOV (recursive shadowcasting) + explored tracking`
- Owned files: `assets/scripts/descent/fov.lua`
- Blocks: C2
- Acceptance (tests):
  - Edge/corner bounds safe
  - Player tile always visible
  - Walls occlude correctly
  - Explored persists after leaving LOS
- Evidence: `.sisyphus/evidence/descent/<ID>/fov_screenshot.png`

---

### Lane D — RNG + Procgen + Stairs (determinism-critical)

#### D1 — `[Descent] RNG adapter + seed plumbing + HUD seed display`
- Owned files: `assets/scripts/descent/rng.lua`, `assets/scripts/descent/ui/hud.lua` (or equivalent), `assets/scripts/descent/state.lua` (if created)
- Blocks: B1
- Acceptance:
  - Same seed produces identical generated content (validated by tests)
  - Seed displayed during play + on death/victory
- Evidence: `.sisyphus/evidence/descent/<ID>/seed_screenshot.png`

#### D2 — `[Descent] Dungeon generation + validation + fallback generator`
- Owned files: `assets/scripts/descent/dungeon.lua`, `assets/scripts/descent/pathfinding.lua`
- Blocks: D1, C2
- Acceptance (tests must assert all):
  - start/stairs on walkable tiles
  - start→stairs reachable (BFS)
  - quotas per floor enforced (size + events)
  - no overlaps (entities/items/walls)
  - if generation fails `MAX_ATTEMPTS=50`, fallback layout is produced and logs seed + attempt count
- Evidence: `.sisyphus/evidence/descent/<ID>/gen_seeds.md` (at least 5 seeds validated)

#### D3 — `[Descent] Stairs + floor transitions 1→5`
- Owned files: `assets/scripts/descent/dungeon.lua`, `assets/scripts/descent/init.lua` (only if required), `assets/scripts/descent/state.lua`
- Blocks: D2, C3
- Acceptance:
  - Stepping on stairs triggers next floor generation
  - Player state persists (HP/MP/XP/inventory)
  - Floor index tracked; floor 5 uses boss arena rules (even if boss placeholder)
- Evidence: `.sisyphus/evidence/descent/<ID>/stairs_walkthrough.md`

---

### Lane E — Combat + Enemies (can run in parallel after RNG + turn loop exists)

#### E1 — `[Descent] Combat math module (spec-locked)`
- Owned files: `assets/scripts/descent/combat.lua`
- Blocks: D1, C1
- Acceptance (tests):
  - Hit chance clamp range matches spec exactly
  - Damage floors at 0 after armor
  - Deterministic outcomes with scripted RNG
  - Data validation rejects negative stats (explicit error)
- Evidence: `.sisyphus/evidence/descent/<ID>/combat_test_output.md`

#### E2 — `[Descent] Enemy defs (5) + AI decide_action`
- Owned files: `assets/scripts/descent/enemy.lua`, `assets/scripts/descent/enemies/*.lua` (if split)
- Blocks: E1, D2, C4
- Acceptance (tests):
  - Adjacent → attack
  - Visible with path → move toward player
  - Not visible → idle
  - No path → idle (no crash)
- Evidence: `.sisyphus/evidence/descent/<ID>/ai_cases.md`

#### E3 — `[Descent] Enemy turn execution + collision-safe movement`
- Owned files: `assets/scripts/descent/turn_manager.lua` (only enemy-turn portion), `assets/scripts/descent/map.lua` (occupancy API if needed)
- Blocks: E2, C1, C2
- Acceptance:
  - Enemies never move into occupied tiles
  - Stable deterministic processing order (define: spawn order or id order; test it)
- Evidence: `.sisyphus/evidence/descent/<ID>/enemy_turn_log.md`

---

### Lane F — Player progression + Items + Character creation UI (UI-touching lane; coordinate carefully)

#### F1 — `[Descent] Player stats + leveling (spec-locked)`
- Owned files: `assets/scripts/descent/player.lua`
- Blocks: D1, E1
- Acceptance:
  - XP thresholds match spec
  - Level-up recalculates HP/MP exactly per spec
  - Level-up triggers “spell selection” event (UI can be stubbed until F4)
- Evidence: `.sisyphus/evidence/descent/<ID>/leveling_notes.md`

#### F2 — `[Descent] Items + inventory list UX + equip/use`
- Owned files: `assets/scripts/descent/items.lua`, `assets/scripts/descent/ui/inventory.lua`
- Blocks: C2, D1
- Acceptance:
  - pickup/drop/use/equip works
  - equip modifies `weapon_base`/`armor_value` (or spec-equivalent)
  - inventory capacity enforced (max defined in spec) with clear UX
- Evidence: `.sisyphus/evidence/descent/<ID>/inventory_screenshot.png`

#### F3 — `[Descent] Scroll identification (seeded labels, no collisions)`
- Owned files: `assets/scripts/descent/items_scrolls.lua` (or equivalent)
- Blocks: F2, D1
- Acceptance:
  - unknown scroll labels randomized per run using seed
  - labels are unique within a run (collision prevention tested)
  - once identified, future scrolls display true name
- Evidence: `.sisyphus/evidence/descent/<ID>/scroll_id.md`

#### F4 — `[Descent] Character creation UI (species/background)`
- Owned files: `assets/scripts/descent/ui/char_create.lua`
- Blocks: F1, F2
- Acceptance:
  - cannot start without selecting both
  - starting gear applied correctly
  - cancel returns to main menu without leaks
- Evidence: `.sisyphus/evidence/descent/<ID>/char_create_screenshot.png`

---

### Lane G — Shops / God / Spells (system features; staggered by dependencies)

#### G1 — `[Descent] Shop system (F1 guaranteed) + buy/sell + reroll`
- Owned files: `assets/scripts/descent/shop.lua`, `assets/scripts/descent/ui/shop.lua`
- Blocks: D2, F2, D1
- Acceptance:
  - shop guaranteed on floor 1 per spec
  - stock deterministic per seed + floor
  - purchase atomic: gold decreases, item added, no partial state on failure
  - reroll cost enforced; reroll deterministic given same seed + reroll count
  - full inventory: purchase is blocked or supports explicit “swap” flow (choose one and test)
- Evidence: `.sisyphus/evidence/descent/<ID>/shop_walkthrough.md`

#### G2 — `[Descent] God system (Trog) + altar interaction + conduct enforcement`
- Owned files: `assets/scripts/descent/god.lua`, `assets/scripts/descent/ui/altar.lua`
- Blocks: D2, F1
- Acceptance:
  - altars appear on required floors per spec
  - worship state persists across floors
  - conduct enforced: spell cast blocked with message while worshiping Trog
  - altar UI always has an exit path (cancel/back)
- Evidence: `.sisyphus/evidence/descent/<ID>/trog_altar.md`

#### G3 — `[Descent] Spells (3) + targeting + MP usage`
- Owned files: `assets/scripts/descent/spells.lua`, `assets/scripts/descent/ui/targeting.lua`
- Blocks: F1, E1, C4, D1 (and must respect G2 conduct)
- Acceptance:
  - level-up spell selection UI works
  - casts validate MP, LOS, range, and target rules (explicitly defined and tested)
  - damage uses spec magic formula deterministically with scripted RNG in tests
- Evidence: `.sisyphus/evidence/descent/<ID>/spells_demo.md`

---

### Lane H — Boss + Endings + Soak (gated; late integration)

#### H1 — `[Descent] Boss floor rules + boss AI + phase transitions`
- Owned files: `assets/scripts/descent/boss.lua`, `assets/scripts/descent/floor5.lua` (or equivalent)
- Blocks: D3, E1, E3, F1
- Acceptance:
  - floor 5 spawns arena + guards exactly per spec
  - boss phases trigger at explicit HP thresholds (spec must define)
  - win condition triggers victory state
  - runtime script error fails into a terminal state (death screen) with seed + error text (no hang)
- Evidence: `.sisyphus/evidence/descent/<ID>/boss_seed.md`

#### H2 — `[Descent] Victory + Death screens (seed + stats + return to menu)`
- Owned files: `assets/scripts/descent/ui/endings.lua`
- Blocks: H1, D1
- Acceptance:
  - shows: seed, turns, final level, kills, cause
  - returns to main menu cleanly
- Evidence: `.sisyphus/evidence/descent/<ID>/ending_screenshot.png`

#### H3 — `[Descent] 5-run crash-free soak + timing evidence`
- Owned files: `.sisyphus/evidence/descent/<ID>/soak.md` (evidence only; no code unless fixes required)
- Blocks: A1–H2
- Acceptance:
  - 5 full runs without crash/hang
  - record at least 3 timed runs; note start/end wall clock; confirm within target band or list tuning knobs
- Evidence: `.sisyphus/evidence/descent/<ID>/soak.md`

---

## 8) Shared Failure Modes Checklist (Each Bead Adds Tests Where Applicable)

- Procgen cannot place start/stairs → triggers fallback after `MAX_ATTEMPTS`
- Turn manager deadlock (never returns to `PLAYER_TURN`) → add watchdog assertion in debug/test mode
- Enemy AI path returns nil/unreachable → enemy idles (no crash)
- FOV out-of-bounds access → bounds clamp + test at edges/corners
- Flaky tests due to randomness → all tests use injected deterministic RNG
- UI modal input lock → every modal must bind cancel/back and prove it via test or scripted walkthrough
- Data table malformed (missing fields/negative stats) → validate on load, fail fast with module name + data id
- Seed not surfaced on crash → ensure error handler prints seed + floor + turn before exit

---

## 9) Definition of Done (MVP Gate)

MVP is “done” only when all are true:
- Character creation (species + background) works and is cancel-safe
- Turn-based movement/combat works; invalid actions do not consume turns
- Shadowcasting FOV correct; explored persists
- 5 floors generate to spec; stairs transitions preserve player state
- Items: pickup/equip/use; scroll identification works
- Shop works (F1 guaranteed) including reroll rules
- Trog worship works; conduct blocks spellcasting with message
- 3 spells work with targeting + MP + LOS
- Boss floor 5 completes; victory/death screens show seed + stats; return to menu
- Commands are green:
  - `just test`
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template`
  - `just ui-verify` for any shared UI/layout primitive changes (and baseline captured when appropriate)
- Soak evidence recorded under `.sisyphus/evidence/descent/`