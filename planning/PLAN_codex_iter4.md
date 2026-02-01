# Descent (DCSS‑Lite) — Engineering Plan v4 (Multi‑Agent, Beads‑Executable)

> **Last verified:** 2026-02-01 (repo has `Justfile`; some environments may lack `just`—fallback commands included).  
> **Integration chokepoints:** `assets/scripts/core/main.lua`, `assets/scripts/ui/main_menu_buttons.lua` (single integration agent only).

---

## 0) Outcome, Scope, Non‑Goals

### 0.1 Target Outcome (MVP)
Ship a **traditional, DCSS‑faithful roguelike mode** (“Descent”) with:
- Turn-based action economy (**dt/frame-rate must not change turn outcomes**).
- Shadowcasting FOV with **visible vs explored** per-floor state.
- **5 floors** with deterministic procgen and stairs transitions **1→5**.
- **Boss encounter on floor 5** (may start as placeholder, but must complete a win path).
- Typical run time **15–20 minutes** on default spec tuning.
- **Reproducible runs via seed** (seed displayed on HUD + on death/victory/error).

### 0.2 MVP Content Minimums
- Species: **Human**
- Background: **Gladiator**
- God: **Trog**
- Spells: **3**
- Enemies: **5 + boss**

### 0.3 Explicit Non‑Goals (must not be added in MVP)
- Save/load or meta-progression
- Autoexplore
- Hunger, branches
- Mouse support
- Inventory grid/tetris UI (use list UX)
- New animation system beyond existing flashes/FX

---

## 1) Preconditions + Canonical Commands (Exact)

### 1.1 Required tooling checks
```bash
cmake --version
c++ --version || clang++ --version || g++ --version
bd --version
```

Optional (recommended) `just`:
```bash
just --version
```

If `just` is missing, install via your platform (one-time):
- macOS: `brew install just`
- Ubuntu/Debian: `sudo apt-get update && sudo apt-get install -y just`
- Any (Rust): `cargo install just`

### 1.2 Build + run (native debug)
Preferred:
```bash
just build-debug
./build/raylib-cpp-cmake-template
```

Fallback (no `just`):
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
./build/raylib-cpp-cmake-template
```

### 1.3 C++ unit tests (gtest)
Preferred:
```bash
just test
```

Fallback:
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
ctest --test-dir build --output-on-failure
```

### 1.4 UI Baseline Suite (“UBS”) — required when shared UI/layout primitives change
Preferred:
```bash
just ui-baseline-capture
just ui-verify
```

Fallback: if there is no documented non-`just` equivalent, treat `just` as a prerequisite for UBS changes.

### 1.5 Descent in-engine Lua tests (required for all Descent beads once A2 lands)
```bash
# Build must produce ./build/raylib-cpp-cmake-template
just build-debug || (cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j)

AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
echo "exit=$?"
```

Headless fallback (Linux; requires Xvfb):
```bash
xvfb-run -a env AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
echo "exit=$?"
```

**Exit code contract (hard requirement)**
- Exit **0**: all Descent tests passed
- Exit **1**: any Descent test failed, timed out, or any Descent test module failed to load

---

## 2) Feature Flags + Determinism Contract (Hard Requirements)

### 2.1 Environment flags (single source of truth)
- `ENABLE_DESCENT=1`: show Descent entry in main menu (default hidden)
- `RUN_DESCENT_TESTS=1`: run Descent in-engine test runner and exit 0/1
- `DESCENT_SEED=<int>`: force deterministic seed (if unset, generate and display)
- `AUTO_START_DESCENT=1`: boot directly into Descent (manual soak)

### 2.2 Determinism rules (must be enforced by tests)
- All randomness flows through `assets/scripts/descent/rng.lua`; **no `math.random`** in Descent modules.
- No reliance on Lua table iteration order:
  - ordered collections must be arrays
  - if ordering depends on keys, sort explicitly with a comparator (and test it)
- Deterministic tie-breaks must be defined and tested for:
  - pathfinding neighbor order
  - enemy processing order
  - procgen placement ordering
  - shop stock ordering and reroll sequencing
- HUD and terminal screens must show:
  - always: `seed`, `floor`, `turn`, `player(x,y)`
  - death/victory/error: `seed`, `final_floor`, `turns`, `kills`, `cause` (or error string)

### 2.3 “No side effects on require” (testability rule)
Every `assets/scripts/descent/**` module must be safe to `require()`:
- No timers registered at require-time
- No global state mutation at require-time
- No rendering calls at require-time

---

## 3) Spec Snapshot (Single Source of Gameplay Truth)

### 3.1 Required spec artifacts
- `planning/descent_spec.md`: the human-readable spec (explicit values, no TODOs)
- `assets/scripts/descent/spec.lua`: code mirror used by runtime + tests

### 3.2 Mandatory decisions (must be explicit in spec + mirrored in `descent.spec`)
- Movement: **4-way vs 8-way**, key bindings, and whether diagonals are allowed through corners.
- Turn costs: move, melee, spell cast, item use, stairs.
- FOV algorithm: shadowcasting variant, radius, opaque tiles, corner/diagonal blocking rules.
- Combat: hit chance, damage, armor, clamps (min/max), rounding rules.
- HP/MP + XP: starting stats, per-level gains, thresholds.
- Floors: width/height per floor, wall density, room/corridor approach, quotas (enemies/items/shop/altars), guaranteed placements.
- Inventory: capacity, pickup/drop rules, equip slots, swap policy when full.
- Scroll identification: label pool size, uniqueness, persistence, reveal rules.
- Boss: arena rules, phase thresholds, abilities, win condition, post-win behavior.

### 3.3 Change policy (enforced)
- Any change to `planning/descent_spec.md` **must** update `assets/scripts/descent/spec.lua` in the **same bead**.
- Tests assert against `require("descent.spec")`; tests must not duplicate constants.

---

## 4) Architecture & Ownership Rules (Minimize Merge Conflicts)

### 4.1 Folder layout (required)
All Descent Lua code lives under:
- `assets/scripts/descent/**`

Recommended structure (file split optimized for parallel work):
- `descent/init.lua` (mode lifecycle + scene wiring)
- `descent/state.lua` (single state object; no globals)
- `descent/spec.lua` (constants)
- `descent/rng.lua` (deterministic RNG + helpers)
- `descent/map.lua` (grid, occupancy, tile metadata)
- `descent/fov.lua` (visible + explored per floor)
- `descent/pathfinding.lua` (BFS/A*, deterministic neighbor order)
- `descent/procgen.lua` (generation only; no transitions)
- `descent/floor_transition.lua` (stairs + floor index change + persistence rules)
- `descent/turn_manager.lua` (FSM only; delegates to action executors)
- `descent/actions_player.lua` (player action execution)
- `descent/actions_enemy.lua` (enemy turn execution)
- `descent/combat.lua`
- `descent/player.lua`
- `descent/enemy.lua`, `descent/enemies/*.lua`
- `descent/items.lua`, `descent/items_scrolls.lua`
- `descent/shop.lua`, `descent/god.lua`, `descent/spells.lua`
- `descent/ui/*` (hud, inventory, shop, altar, char_create, endings, targeting)

### 4.2 Chokepoint files (single integration agent)
Only the designated integration agent edits these (unless a bead explicitly assigns it):
- `assets/scripts/core/main.lua` (env hooks + test runner hook)
- `assets/scripts/ui/main_menu_buttons.lua` (menu entry wiring)

---

## 5) Test Strategy (Automatable, Non‑Flaky, Seeded)

### 5.1 Test locations (required)
- Runner: `assets/scripts/tests/run_descent_tests.lua`
- Tests: `assets/scripts/tests/test_descent_*.lua`

Runner requirements:
- `TestRunner.reset()` before loading tests
- `TestRunner.run_all()` returns pass/fail
- Runner prints: seed, currently-running test name, and a short summary

### 5.2 Mandatory test categories (minimum set)
- **RNG determinism**
  - same seed → identical procgen snapshot hash (define hash format; see D2)
  - scripted RNG sequence → deterministic combat + AI outcomes
- **Dungeon validity**
  - start and stairs are walkable on floors 1–4
  - start→stairs reachable (BFS)
  - no overlaps: walls/entities/items/stairs
  - per-floor quotas enforced exactly (spec-defined)
  - failure mode: after `MAX_ATTEMPTS` (spec constant), fallback layout generated; logs seed + attempts
- **FOV/explored**
  - player tile visible
  - walls occlude correctly
  - bounds safe (corners/edges)
  - explored persists after leaving LOS
  - per-floor persistence: explored state is stored per floor and restored on return (if backtracking is supported; if not supported in MVP, spec must forbid it and tests must assert one-way progression)
- **Turn manager**
  - `PLAYER_TURN → ENEMY_TURN → PLAYER_TURN`
  - invalid/no-op input consumes 0 turns
  - enemy list mutation safe during iteration
  - dt independence: running N frames with no input does not advance turns
- **Combat**
  - hit chance clamps to spec min/max
  - damage floors at 0 after armor
  - negative stats rejected with clear error
- **AI**
  - adjacent → attack
  - visible with path → move toward
  - visible with no path → idle (and does not crash)
  - not visible → idle
  - deterministic processing order defined (spawn order or stable id sort) and tested
- **Inventory**
  - pickup/drop/use/equip
  - capacity enforcement + chosen UX tested (block or swap)

### 5.3 Watchdog / anti-hang requirement (hard)
`RUN_DESCENT_TESTS=1` must enforce a timeout (e.g. 15s) that:
- prints seed + current module/test name
- exits with **1**
- leaves enough logs to reproduce the hang

---

## 6) Multi‑Agent Execution Protocol (Beads + Agent Mail)

### 6.1 Triage (“BV” equivalent)
```bash
bd ready --limit 50 --sort hybrid
bd blocked --limit 50
bd dep cycles
bd lint
```

### 6.2 Claim + status discipline
- Claim and set `in_progress` before editing:
```bash
bd update <ID> --claim --actor "$USER"
bd update <ID> --status in_progress --actor "$USER"
```

### 6.3 Mandatory bead description template (enforced via `bd lint`)
Each bead description must contain:
- **Owned files (exclusive)**
- **Non-owned files (must not edit)**
- **Acceptance criteria (testable)**
- **Commands to run (exact)**
- **Evidence paths**
- **Dependencies / blockers**
- **Rollback notes** (how to revert within the bead’s scope)

### 6.4 Agent Mail reservations (mandatory before edits)
Before editing, reserve exact paths/globs (exclusive), TTL 60–120 minutes; renew if needed.
- Never reserve broad globs like `assets/scripts/**`.
- If you need chokepoints (`core/main.lua`, `ui/main_menu_buttons.lua`), coordinate with the integration agent in-thread first.

### 6.5 Evidence convention (required)
For each bead `<ID>`:
```bash
mkdir -p .sisyphus/evidence/descent/<ID>
```

Required artifacts:
- `.sisyphus/evidence/descent/<ID>/summary.md` (what changed + how verified)
- `.sisyphus/evidence/descent/<ID>/run.log` (or `test.log`) for any test run
- screenshots for UI/FOV behaviors
- list of seeds used (explicit)

Close with evidence:
```bash
bd close <ID> --session "descent-mvp" --actor "$USER"
bd comments add <ID> --file .sisyphus/evidence/descent/<ID>/summary.md --actor "$USER"
```

---

## 7) Rollout / Gating / Rollback (Safe Integration)

### 7.1 Phase 1 — Hidden (default)
- Descent ships inert.
- Entry only appears with `ENABLE_DESCENT=1`.

### 7.2 Phase 2 — Experimental (opt-in label)
Gate: “floors 1–5 + stairs + boss placeholder + endings”.
Merge checklist:
```bash
# If any C++ touched:
just test || (cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j && ctest --test-dir build --output-on-failure)

# Always for Descent:
just build-debug || (cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j)
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template

# If shared UI/layout primitives changed:
just ui-verify
```

### 7.3 Phase 3 — MVP label
Remove “Experimental” only after:
- boss complete (no placeholder behaviors)
- victory/death/error screens complete
- soak evidence complete (H3)
- runtime in 15–20 min target or tuning knobs documented in spec + evidence

### 7.4 One-line rollback plan
Rollback is “hide entry”:
- keep Descent code intact
- gate all routing behind `ENABLE_DESCENT` so disabling flag removes access

---

## 8) Beads Backlog (Parallelizable DAG, Explicit Ownership)

> All bead titles prefixed with `[Descent]`.  
> Labels: `descent` + lane label (`lane:A`, `lane:B`, …).  
> Use `--parent <EPIC_ID>` for every bead after the epic is created.

### 8.1 Create epic
```bash
EPIC_ID="$(bd create "[Descent] MVP" --type epic --status open --priority P1 --labels "descent" --silent --actor "$USER")"
echo "$EPIC_ID"
```

---

### Lane A — Spec + Harness + Evidence (unblocks everything)

#### A1 — Spec snapshot + `spec.lua` mirror
- Owned files: `planning/descent_spec.md`, `assets/scripts/descent/spec.lua`
- Dependencies: none
- Acceptance:
  - all decisions in §3.2 are explicit, with numeric values and clear rules
  - `require("descent.spec")` returns a table of constants used by tests
- Commands:
  - `bd lint`
- Evidence: `.sisyphus/evidence/descent/<ID>/summary.md`

#### A2 — Test runner + `RUN_DESCENT_TESTS` hook + watchdog (chokepoint)
- Owned files: `assets/scripts/tests/run_descent_tests.lua`, `assets/scripts/tests/test_descent_smoke.lua`, `assets/scripts/core/main.lua`
- Dependencies: none
- Acceptance:
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template` exits **0** on green
  - a temporary failing assertion makes it exit **1** (must be removed before close)
  - module load failures print module name + error and exit **1**
  - watchdog timeout exits **1** and prints seed + current test/module
- Commands:
  - build per §1.2 then run §1.5
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

#### A3 — Evidence README + copy/paste log capture
- Owned files: `.sisyphus/evidence/descent/README.md`
- Dependencies: none
- Acceptance:
  - documents required artifacts and exact `tee` commands
  - includes “when UBS is required” rule
- Evidence: `.sisyphus/evidence/descent/<ID>/summary.md`

#### A4 — Optional `just` recipes for Descent tests
- Owned files: `Justfile` (only if adding recipes)
- Dependencies: A2
- Acceptance:
  - `just test-descent` runs §1.5 command
  - optional: `just test-descent-headless` runs xvfb command
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

---

### Lane B — Mode entry + menu routing (single integration agent; chokepoint)

#### B1 — Main menu entry + `ENABLE_DESCENT` gating + `AUTO_START_DESCENT`
- Owned files: `assets/scripts/ui/main_menu_buttons.lua`, `assets/scripts/descent/init.lua`
- Dependencies: A2
- Acceptance:
  - with `ENABLE_DESCENT=1`, menu shows Descent and entering it succeeds
  - without `ENABLE_DESCENT=1`, no visible or accessible Descent route
  - with `AUTO_START_DESCENT=1`, boot goes directly to Descent
  - exiting Descent returns to main menu with cleanup (no lingering timers/UI state)
- Commands:
```bash
just build-debug || (cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j)
ENABLE_DESCENT=1 ./build/raylib-cpp-cmake-template
AUTO_START_DESCENT=1 DESCENT_SEED=123 ./build/raylib-cpp-cmake-template
```
- Evidence: `.sisyphus/evidence/descent/<ID>/seed_and_entry.md`

---

### Lane C — Core loop (parallel after B1)

#### C1 — Turn manager FSM (no AI logic)
- Owned files: `assets/scripts/descent/turn_manager.lua`
- Dependencies: B1, A1, A2
- Acceptance (tests):
  - FSM transitions correct
  - invalid/no-op input consumes 0 turns
  - dt independence: no input for N frames does not advance turns
- Commands: §1.5
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

#### C2 — Map grid + occupancy + transforms
- Owned files: `assets/scripts/descent/map.lua`
- Dependencies: B1, A1, A2
- Acceptance (tests or deterministic scripted run):
  - rectangular maps for all spec sizes
  - occupancy API supports player/enemy/item/stairs without overlaps
  - tile↔screen transform roundtrip for on-screen tiles
  - missing glyph/sprite uses fallback and logs once per missing id
- Evidence: `.sisyphus/evidence/descent/<ID>/map_screenshot.png`

#### C3 — Input + action selection (move vs bump-attack)
- Owned files: `assets/scripts/descent/input.lua`, `assets/scripts/descent/actions_player.lua`
- Dependencies: C1, C2, A1, A2
- Acceptance (tests):
  - legal move consumes exactly 1 turn
  - illegal move consumes 0 turns
  - bump enemy creates melee action (does not double-advance)
  - key repeat debounce defined and tested (1 action per player turn)
- Evidence: `.sisyphus/evidence/descent/<ID>/input_notes.md`

#### C4 — FOV + explored tracking
- Owned files: `assets/scripts/descent/fov.lua`
- Dependencies: C2, A1, A2
- Acceptance (tests):
  - occlusion correct per spec rules
  - bounds safe at edges/corners
  - explored persists after LOS loss
- Evidence: `.sisyphus/evidence/descent/<ID>/fov_screenshot.png`

---

### Lane D — RNG + Procgen + Stairs (determinism-critical; split for parallelism)

#### D1 — RNG adapter + seed plumbing + HUD seed display
- Owned files: `assets/scripts/descent/rng.lua`, `assets/scripts/descent/state.lua`, `assets/scripts/descent/ui/hud.lua`
- Dependencies: B1, A1, A2
- Acceptance (tests):
  - `DESCENT_SEED=123` produces stable RNG sequences across runs
  - HUD always shows seed/floor/turn/pos
  - invalid `DESCENT_SEED` (non-int/overflow) falls back to generated seed and logs a warning
- Evidence: `.sisyphus/evidence/descent/<ID>/seed_screenshot.png`

#### D2a — Pathfinding (deterministic)
- Owned files: `assets/scripts/descent/pathfinding.lua`
- Dependencies: C2, A1, A2, D1
- Acceptance (tests):
  - BFS/A* produces stable path given same map and endpoints
  - neighbor order is explicit and tested (no table iteration nondeterminism)
  - unreachable returns `nil` (or empty path) and callers must handle (tests in E2/D2b)
- Evidence: `.sisyphus/evidence/descent/<ID>/pathfinding_cases.md`

#### D2b — Procgen + validation + fallback layout
- Owned files: `assets/scripts/descent/procgen.lua`
- Dependencies: C2, D1, D2a, A1, A2
- Acceptance (tests; run with ≥10 fixed seeds: `1..10`):
  - walkable start/stairs (floors 1–4)
  - reachable start→stairs (BFS)
  - quotas enforced exactly per spec
  - no overlaps (including stairs not under an entity/item)
  - fallback after `MAX_ATTEMPTS` with log: seed + attempts + reason
  - procgen snapshot hashing defined (e.g., stable string of tiles + placements) and asserted for determinism
- Evidence: `.sisyphus/evidence/descent/<ID>/gen_seeds.md`

#### D3 — Stairs + floor transitions 1→5
- Owned files: `assets/scripts/descent/floor_transition.lua`
- Dependencies: D2b, C3, A1, A2, D1
- Acceptance (tests or scripted deterministic run):
  - stepping on stairs advances floor
  - player state persists: HP/MP/XP/inventory/equipment/god/spells
  - floor-local state resets correctly: enemies/items regenerated; explored tracked per floor per spec
  - floor 5 uses boss floor hook (even if placeholder boss)
- Evidence: `.sisyphus/evidence/descent/<ID>/stairs_walkthrough.md`

---

### Lane E — Combat + Enemies (parallel after D1 + core loop)

#### E1 — Combat math (spec-locked)
- Owned files: `assets/scripts/descent/combat.lua`
- Dependencies: D1, C1, A1, A2
- Acceptance (tests):
  - clamp range matches `descent.spec`
  - damage floors at 0 after armor
  - scripted RNG yields deterministic outcomes
  - negative stats rejected with clear error including entity id/type
- Evidence: `.sisyphus/evidence/descent/<ID>/combat_test_output.md`

#### E2 — Enemy definitions (5) + AI decision function
- Owned files: `assets/scripts/descent/enemy.lua`, `assets/scripts/descent/enemies/*.lua`
- Dependencies: E1, D2a, D2b, C4, A1, A2
- Acceptance (tests):
  - adjacent → attack
  - visible + path → move toward
  - visible + no path → idle
  - not visible → idle
  - deterministic processing order defined and tested (stable id or spawn index)
- Evidence: `.sisyphus/evidence/descent/<ID>/ai_cases.md`

#### E3 — Enemy turn execution (separate module; avoid `turn_manager.lua` conflicts)
- Owned files: `assets/scripts/descent/actions_enemy.lua`
- Dependencies: E2, C1, C2, A2
- Acceptance (tests):
  - no moves into occupied tiles
  - no two enemies occupy same tile after turn
  - iteration order stable and tested
  - pathfinding `nil` handled (idle) with no crash
- Evidence: `.sisyphus/evidence/descent/<ID>/enemy_turn_log.md`

---

### Lane F — Player + Items + Character creation (UI-touching)

#### F1 — Player stats + XP/leveling (spec-locked)
- Owned files: `assets/scripts/descent/player.lua`
- Dependencies: D1, E1, A1, A2
- Acceptance (tests):
  - XP thresholds match spec exactly
  - level-up recalculations match spec
  - emits a “spell selection” event hook (UI may stub until G3 but event must exist)
- Evidence: `.sisyphus/evidence/descent/<ID>/leveling_notes.md`

#### F2 — Items + inventory list UX + equip/use
- Owned files: `assets/scripts/descent/items.lua`, `assets/scripts/descent/ui/inventory.lua`
- Dependencies: C2, D1, A1, A2
- Acceptance (tests):
  - pickup/drop/use/equip works
  - equip modifies combat stats via `player.lua` APIs (no hidden globals)
  - capacity enforcement per spec; swap/block UX explicitly implemented and tested
- Evidence: `.sisyphus/evidence/descent/<ID>/inventory_screenshot.png`

#### F3 — Scroll identification (seeded labels, unique, persistent)
- Owned files: `assets/scripts/descent/items_scrolls.lua`
- Dependencies: F2, D1, A1, A2
- Acceptance (tests):
  - labels randomized per run seed
  - labels unique within run
  - identification persists for run and updates future display
- Evidence: `.sisyphus/evidence/descent/<ID>/scroll_id.md`

#### F4 — Character creation UI (species/background)
- Owned files: `assets/scripts/descent/ui/char_create.lua`
- Dependencies: F1, F2, A1, B1
- Acceptance:
  - cannot start without selecting both
  - starting gear matches spec
  - cancel/back returns to main menu cleanly
- Evidence: `.sisyphus/evidence/descent/<ID>/char_create_screenshot.png`

---

### Lane G — Shops / God / Spells (staggered)

#### G1 — Shop system (floor 1 guaranteed) + buy/sell + reroll
- Owned files: `assets/scripts/descent/shop.lua`, `assets/scripts/descent/ui/shop.lua`
- Dependencies: D2b, F2, D1, A1, A2
- Acceptance (tests):
  - shop appears on floor 1 per spec rule
  - stock deterministic per seed+floor (+ shop instance index if multiple)
  - purchase is atomic (no partial state on failure)
  - reroll cost enforced; reroll deterministic given seed + reroll count
  - inventory-full behavior is defined and tested
- Evidence: `.sisyphus/evidence/descent/<ID>/shop_walkthrough.md`

#### G2 — God system (Trog) + altars + conduct enforcement
- Owned files: `assets/scripts/descent/god.lua`, `assets/scripts/descent/ui/altar.lua`
- Dependencies: D2b, F1, A1, A2
- Acceptance (tests):
  - altars appear per spec floors/odds
  - worship state persists across floors
  - while worshiping Trog, spell cast is blocked with a deterministic message (no turn consumed)
  - altar UI always has cancel/back path
- Evidence: `.sisyphus/evidence/descent/<ID>/trog_altar.md`

#### G3 — Spells (3) + targeting + MP usage
- Owned files: `assets/scripts/descent/spells.lua`, `assets/scripts/descent/ui/targeting.lua`
- Dependencies: F1, E1, C4, D1, G2, A1, A2
- Acceptance (tests):
  - spell selection triggered on level-up (or start if spec says)
  - casts validate MP, LOS, range, targeting rules
  - damage/heal deterministic with scripted RNG
- Evidence: `.sisyphus/evidence/descent/<ID>/spells_demo.md`

---

### Lane H — Boss + Endings + Soak (late; gated)

#### H1 — Boss floor rules + boss AI + phases
- Owned files: `assets/scripts/descent/boss.lua`, `assets/scripts/descent/floor5.lua`
- Dependencies: D3, E1, E3, F1, A1, A2
- Acceptance (tests or scripted run):
  - floor 5 arena spawns per spec
  - boss phases trigger at spec thresholds
  - win condition triggers victory state
  - runtime script error does not hang: transitions to terminal ending screen showing seed + error; exits in test mode
- Evidence: `.sisyphus/evidence/descent/<ID>/boss_seed.md`

#### H2 — Victory + Death + Error screens (seed + stats + return to menu)
- Owned files: `assets/scripts/descent/ui/endings.lua`
- Dependencies: H1, D1, B1
- Acceptance:
  - shows seed, turns, final floor, kills, cause/error
  - return to main menu works and cleanup verified
- Evidence: `.sisyphus/evidence/descent/<ID>/ending_screenshot.png`

#### H3 — 5-run soak + timing evidence
- Owned files: evidence only unless fixes required
- Dependencies: A1–H2 complete
- Acceptance:
  - 5 full runs without crash/hang
  - record ≥3 timed runs (wall clock) and compare to 15–20 min target
  - if out of band: list tuning knobs and propose exact spec changes (enemy HP, floor size, spawn quotas, shop odds)
- Commands (example):
```bash
for seed in 101 102 103 104 105; do
  AUTO_START_DESCENT=1 DESCENT_SEED="$seed" ENABLE_DESCENT=1 ./build/raylib-cpp-cmake-template
done
```
- Evidence: `.sisyphus/evidence/descent/<ID>/soak.md`

---

## 9) Shared Failure Modes + Required Behaviors (Add Tests Where Applicable)

- Procgen cannot place start/stairs: fallback after `MAX_ATTEMPTS`; logs seed/attempts/reason; still produces reachable map.
- Turn deadlock: watchdog triggers; prints seed + current phase; exits 1 in test mode.
- AI pathing returns nil: enemy idles; no crash; deterministic.
- FOV OOB: clamp; explicit corner tests.
- Nondeterminism sources: dt/frame-rate, table iteration, unordered sets → forbidden or explicitly sorted.
- UI modal lock: every modal has cancel/back; invalid input must not soft-lock.
- Malformed data (missing fields, negative stats): validate on load; fail fast with module + id.
- Seed visibility: on death/victory/error, seed/floor/turn must be shown and logged.

---

## 10) Definition of Done (MVP Gate)

MVP is complete only when all are true:
- Char creation (Human/Gladiator) works; cancel-safe.
- Turn-based movement/combat works; invalid/no-op input consumes 0 turns.
- Shadowcasting FOV correct; explored persists per spec.
- 5 floors generate to spec; stairs transitions preserve player state; floor 5 boss encounter completes a win path.
- Items: pickup/equip/use; scroll identification works.
- Shop works (floor 1 guaranteed) including reroll rules.
- Trog worship works; conduct blocks spellcasting with message and no turn consumed.
- 3 spells work with targeting + MP + LOS per spec.
- Victory/death/error screens show seed + stats; return to menu cleanly.
- Test commands are green:
  - `just test` (if any C++ touched) or fallback `ctest` command
  - build + run (§1.2)
  - Descent in-engine tests (§1.5)
  - UBS (`just ui-verify`) if shared UI/layout primitives changed
- Soak evidence recorded under `.sisyphus/evidence/descent/`