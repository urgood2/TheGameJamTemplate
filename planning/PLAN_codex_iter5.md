# Descent (DCSS‑Lite) — Engineering Plan v5 (Multi‑Agent, Beads‑Executable)

> **Last verified:** 2026-02-01  
> **Validated against repo:** `Justfile` + `CMakeLists.txt` default `CMAKE_BUILD_TYPE=RelWithDebInfo` when unset.  
> **Chokepoints (single integration agent only):** `assets/scripts/core/main.lua`, `assets/scripts/ui/main_menu_buttons.lua`, `assets/scripts/tests/run_descent_tests.lua` (if conflicts arise).

---

## 0) Outcome, Scope, Non‑Goals

### 0.1 Target Outcome (MVP)
Ship a **traditional, DCSS‑faithful roguelike mode** (“Descent”) with:

- Turn-based action economy (**frame dt / FPS must not affect turn outcomes**).
- Shadowcasting FOV with **visible vs explored** state per floor.
- **5 floors** with deterministic procgen and stairs transitions **1→5**.
- **Boss encounter on floor 5** with a complete win path (placeholder allowed only until H1 is complete).
- Typical run time **15–20 minutes** on default tuning (document knobs if outside).
- **Reproducible runs via seed** (seed shown on HUD + on death/victory/error; seed logged on any error).

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

### 1.1 Tooling checks
```bash
cmake --version
c++ --version || clang++ --version || g++ --version
bd --version
just --version || true
```

### 1.2 Build + run (native)
**Compatibility path (produces `./build/raylib-cpp-cmake-template` used by UBS + many recipes):**
```bash
just build-debug
./build/raylib-cpp-cmake-template
```

**Fast debug path (produces `./build-debug/raylib-cpp-cmake-template`):**
```bash
just build-debug-fast
./build-debug/raylib-cpp-cmake-template
```

**Fallback (no `just`, produces `./build/raylib-cpp-cmake-template`):**
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_UNIT_TESTS=OFF
cmake --build build -j
./build/raylib-cpp-cmake-template
```

### 1.3 C++ unit tests (gtest)
**Preferred:**
```bash
just test
```

**Fallback (matches `Justfile:test` behavior):**
```bash
cmake -B build -DENABLE_UNIT_TESTS=ON
cmake --build build --target unit_tests -j
./build/tests/unit_tests --gtest_color=yes
```

### 1.4 UI Baseline Suite (“UBS”) — required when shared UI/layout primitives change
**Capture baselines (run before UI refactors):**
```bash
just build-debug
just ui-baseline-capture | tee /tmp/ui_baseline_capture.log
```

**Verify baselines (run after changes):**
```bash
just build-debug
just ui-verify | tee /tmp/ui_verify.log
```

### 1.5 Descent in-engine Lua tests (hard requirement once A2 is merged)
```bash
just build-debug || (cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_UNIT_TESTS=OFF && cmake --build build -j)

AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
echo "exit=$?"
```

**Linux headless fallback (requires Xvfb):**
```bash
command -v xvfb-run
xvfb-run -a env AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
echo "exit=$?"
```

**Exit code contract (must be enforced by implementation)**
- Exit **0**: all Descent tests passed
- Exit **1**: any Descent test failed, timed out, or any Descent test module failed to load

---

## 2) Feature Flags + Determinism Contract (Hard Requirements)

### 2.1 Environment flags (single source of truth)
- `ENABLE_DESCENT=1`: show Descent entry in main menu (default hidden)
- `AUTO_START_DESCENT=1`: boot directly into Descent (bypasses menu; for soak + debugging)
- `RUN_DESCENT_TESTS=1`: run Descent test runner and exit 0/1
- `DESCENT_SEED=<int>`: force deterministic seed (if unset, generate and display)
- `AUTO_EXIT_AFTER_TEST=1`: ensures test runs terminate (used by existing UBS patterns)

### 2.2 Determinism rules (must be enforced by tests + lint commands)
- All randomness flows through `assets/scripts/descent/rng.lua`; **no `math.random`** in Descent modules.
  - Verification command:
    ```bash
    rg -n "math\\.random" assets/scripts/descent || true
    ```
- No reliance on Lua table iteration order:
  - ordered collections must be arrays
  - if ordering depends on keys, sort explicitly with comparator and test it
- Deterministic tie-breaks must be defined and tested for:
  - pathfinding neighbor order
  - enemy processing order
  - procgen placement ordering
  - shop stock ordering and reroll sequencing
- HUD and terminal screens must show:
  - always: `seed`, `floor`, `turn`, `player(x,y)`
  - death/victory/error: `seed`, `final_floor`, `turns`, `kills`, `cause` (or error string)
- dt independence:
  - no input for N frames must not advance turns
  - simulation tick must be “turn-driven” (input/actions), not “time-driven”

### 2.3 “No side effects on require” (testability rule)
Every `assets/scripts/descent/**` module must be safe to `require()`:
- No timers registered at require-time
- No global state mutation at require-time
- No rendering calls at require-time

---

## 3) Spec Snapshot (Single Source of Gameplay Truth)

### 3.1 Required spec artifacts
- `planning/descent_spec.md`: human-readable spec (explicit values, no TODOs)
- `assets/scripts/descent/spec.lua`: code mirror used by runtime + tests

### 3.2 Mandatory decisions (must be explicit in spec + mirrored in `descent.spec`)
- Movement: 4-way vs 8-way, key bindings, diagonal corner-cutting rules.
- Turn costs: move, melee, spell cast, item use, stairs.
- FOV: algorithm variant, radius, opacity rules, diagonal/corner blocking rules.
- Combat: hit chance formula, clamps, damage formula, armor, rounding.
- HP/MP + XP: starting stats, per-level gains, thresholds.
- Floors: sizes per floor, quotas, guaranteed placements (start, stairs, boss arena), max attempts.
- Inventory: capacity, pickup/drop rules, equip slots, overflow policy (block vs swap).
- Scroll identification: label pool size, uniqueness, persistence and reveal rules.
- Boss: arena rules, phase thresholds, abilities, win condition, post-win behavior.
- Backtracking: explicitly allowed or explicitly forbidden; tests must enforce.

### 3.3 Change policy (enforced)
- Any change to `planning/descent_spec.md` **must** update `assets/scripts/descent/spec.lua` in the **same bead**.
- Tests assert against `require("descent.spec")`; tests must not duplicate constants.

---

## 4) Architecture, Ownership, and Conflict Minimization

### 4.1 Folder layout (required)
All Descent Lua code lives under:
- `assets/scripts/descent/**`

Recommended file boundaries (optimize parallel work; each bead should own a small set):
- Core: `descent/init.lua`, `descent/state.lua`, `descent/spec.lua`, `descent/rng.lua`
- World: `descent/map.lua`, `descent/procgen.lua`, `descent/floor_transition.lua`
- Visibility/Movement: `descent/fov.lua`, `descent/pathfinding.lua`, `descent/input.lua`
- Turns/Actions: `descent/turn_manager.lua`, `descent/actions_player.lua`, `descent/actions_enemy.lua`
- Entities: `descent/player.lua`, `descent/enemy.lua`, `descent/enemies/*.lua`
- Systems: `descent/combat.lua`, `descent/items.lua`, `descent/items_scrolls.lua`, `descent/shop.lua`, `descent/god.lua`, `descent/spells.lua`
- UI: `descent/ui/*` (hud, inventory, shop, altar, char_create, endings, targeting)

### 4.2 Chokepoint files (single integration agent)
Only the designated integration agent edits these (unless a bead explicitly assigns otherwise):
- `assets/scripts/core/main.lua` (env hooks + `RUN_DESCENT_TESTS` + `AUTO_START_DESCENT`)
- `assets/scripts/ui/main_menu_buttons.lua` (menu entry wiring)
- `assets/scripts/tests/run_descent_tests.lua` (to avoid runner conflicts; tests themselves are not chokepoints)

---

## 5) Test Strategy (Automatable, Non‑Flaky, Seeded)

### 5.1 Test locations (required)
- Runner: `assets/scripts/tests/run_descent_tests.lua`
- Tests: `assets/scripts/tests/test_descent_*.lua`

Runner requirements:
- `TestRunner.reset()` before loading tests
- `TestRunner.run_all()` returns pass/fail
- Prints (always):
  - active seed (resolved seed after parsing/generation)
  - currently-running test name
  - summary: passed/failed count
- Module load failures:
  - print module name + error + stack (if available)
  - exit code **1**

### 5.2 Watchdog / anti-hang requirement (hard)
`RUN_DESCENT_TESTS=1` must enforce a timeout (choose one and implement exactly):
- **Wall-clock timeout** (recommended): 15s total for all tests
- On timeout:
  - print seed + current test name (or “loading <module>”)
  - exit code **1**

### 5.3 Deterministic snapshot hashing (hard; used by procgen + determinism tests)
Define and use a single canonical snapshot function (document in spec + implement once):
- Canonical string format (must be identical across platforms):
  - `version=<int>\n`
  - `seed=<int>\nfloor=<int>\nsize=<w>,<h>\n`
  - `tiles:\n` followed by exactly `h` lines of exactly `w` characters
  - `entities:\n` sorted by `entity_id` ascending; one per line:
    - `<id> <type> <x>,<y> <hp>/<maxhp> <flags>\n`
  - `items:\n` sorted by `(y,x,item_id)`; one per line:
    - `<item_id> <kind> <x>,<y> <qty> <identified>\n`
- Hash:
  - Use a pure-Lua stable hash (e.g., FNV-1a 32-bit) over UTF-8 bytes of the canonical string.
  - Tests must assert hash equality, not raw string, to keep logs readable.

### 5.4 Mandatory test categories (minimum set)
- RNG determinism: same seed → identical sequences; scripted sequence → deterministic combat/AI.
- Dungeon validity:
  - start and stairs walkable on floors 1–4
  - start→stairs reachable (BFS with deterministic neighbor order)
  - no overlaps: walls/entities/items/stairs
  - quotas enforced exactly (spec-defined)
  - fallback after `MAX_ATTEMPTS`:
    - logs seed + attempts + reason
    - produces a reachable map (even if “boring”)
- FOV/explored:
  - player tile visible
  - walls occlude per spec
  - bounds safe (corners/edges)
  - explored persists after leaving LOS
  - backtracking policy enforced (if forbidden, assert stairs only go forward and prior floors are unreachable)
- Turn manager:
  - `PLAYER_TURN → ENEMY_TURN → PLAYER_TURN`
  - invalid/no-op input consumes 0 turns
  - dt independence: N frames with no input does not advance turns
  - safe iteration when enemies die/spawn mid-loop
- Combat:
  - hit chance clamps to spec
  - damage floors at 0 after armor
  - invalid negative stats fail fast with entity id/type
- AI:
  - adjacent → attack
  - visible + path → move toward
  - visible + no path → idle (no crash)
  - not visible → idle
  - stable processing order (stable id or spawn index) and tested
- Inventory:
  - pickup/drop/use/equip
  - capacity enforcement + UX (block vs swap) explicitly tested
- Error handling:
  - any runtime Lua error in Descent mode must route to an error ending screen with seed + message (and in test mode must exit 1)

---

## 6) Multi‑Agent Execution Protocol (Beads + Agent Mail)

### 6.1 Beads triage (run before claiming)
```bash
bd ready --limit 50 --sort hybrid
bd blocked --limit 50
bd dep cycles
bd lint
```

### 6.2 Claim discipline (single command; atomic)
```bash
bd update <ID> --claim --actor "$USER"
```

### 6.3 Mandatory bead description template (enforced by `bd lint`)
Each bead must include these sections (verbatim headings recommended):

- **Owned files (exclusive)**
- **Non-owned files (must not edit)**
- **Dependencies**
- **Acceptance criteria (testable)**
- **Commands run (exact)**
- **Evidence (paths)**
- **Rollback plan (within bead scope)**

### 6.4 Agent Mail reservations (mandatory before edits)
Before editing, reserve exact paths/globs (exclusive), TTL 60–120 minutes; renew if needed.
- Never reserve broad globs like `assets/scripts/**`.
- If you need chokepoints, coordinate with the integration agent in-thread before touching.

**MCP tool call shape (example; exact paths per bead):**
```json
{
  "tool": "mcp__mcp_agent_mail__file_reservation_paths",
  "arguments": {
    "project_key": "/data/projects/roguelike-1",
    "agent_name": "<YourAgentName>",
    "paths": ["assets/scripts/descent/map.lua"],
    "exclusive": true,
    "ttl_seconds": 7200,
    "reason": "Bead <ID>: implement map grid + occupancy"
  }
}
```

### 6.5 Evidence convention (required)
For each bead `<ID>`:
```bash
mkdir -p .sisyphus/evidence/descent/<ID>
```

Required artifacts:
- `.sisyphus/evidence/descent/<ID>/summary.md`
- `.sisyphus/evidence/descent/<ID>/run.log` (or `test.log`) for any test run (use `tee`)
- screenshots for UI/FOV behaviors (if applicable)
- explicit list of seeds used

Close with evidence attached:
```bash
bd close <ID> --session "descent-mvp" --actor "$USER"
bd comments add <ID> --file .sisyphus/evidence/descent/<ID>/summary.md --actor "$USER"
```

---

## 7) Rollout / Gating / Rollback

### 7.1 Phase 1 — Hidden (default)
- Descent code can merge early.
- No user-visible entry unless `ENABLE_DESCENT=1`.

### 7.2 Phase 2 — Experimental (opt-in label)
Gate criteria:
- Floors 1–5 generate + stairs work + boss placeholder + endings exist.
- `RUN_DESCENT_TESTS=1` is green.

Merge checklist (run locally; attach logs to bead evidence):
```bash
# If any C++ touched:
just test | tee /tmp/unit_tests.log

# Always for Descent:
just build-debug
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log

# If shared UI/layout primitives changed:
just ui-verify | tee /tmp/ui_verify.log
```

### 7.3 Phase 3 — MVP label
Remove “Experimental” only after:
- boss complete (no placeholder behavior)
- victory/death/error screens complete and return to menu cleanly
- 5-run soak evidence complete (H3)
- runtime in 15–20 min target OR tuning knobs documented + spec changes proposed as explicit diffs

### 7.4 Rollback (one-line, always available)
Rollback is “hide entry”:
- keep Descent code intact
- gate all routing behind `ENABLE_DESCENT` so disabling flag removes access

---

## 8) Work Breakdown (Parallelizable DAG; Beads with Dependencies)

> All bead titles prefixed with `[Descent]`.  
> Labels: `descent` + lane label (`lane:A`, `lane:B`, …).  
> Each bead must list owned files explicitly; avoid overlapping ownership.  
> **Integration agent owns:** A2, B1 (and A4 if added).

### 8.1 Bootstrap: create epic + beads (scriptable)
```bash
EPIC_ID="$(bd create "[Descent] MVP" --type epic --status open --priority P1 --labels "descent" --silent --actor "$USER")"
echo "EPIC_ID=$EPIC_ID"
```

Optional: create all beads and print IDs (fill out descriptions afterward with the template):
```bash
A1="$(bd create "[Descent] A1 Spec snapshot + spec.lua mirror" --type task --status open --priority P1 --labels "descent,lane:A" --parent "$EPIC_ID" --silent --actor "$USER")"
A2="$(bd create "[Descent] A2 Descent test runner + core hook + watchdog" --type task --status open --priority P0 --labels "descent,lane:A" --parent "$EPIC_ID" --silent --actor "$USER")"
A3="$(bd create "[Descent] A3 Evidence README (Descent)" --type task --status open --priority P2 --labels "descent,lane:A" --parent "$EPIC_ID" --silent --actor "$USER")"
B0="$(bd create "[Descent] B0 Mode init (no menu) + AUTO_START_DESCENT" --type task --status open --priority P0 --labels "descent,lane:B" --parent "$EPIC_ID" --silent --actor "$USER")"
B1="$(bd create "[Descent] B1 Menu entry + ENABLE_DESCENT gating" --type task --status open --priority P0 --labels "descent,lane:B" --parent "$EPIC_ID" --silent --actor "$USER")"
echo "A1=$A1 A2=$A2 A3=$A3 B0=$B0 B1=$B1"
```

Then wire dependencies explicitly:
```bash
bd dep add "$B0" "$A1"
bd dep add "$B0" "$A2"
bd dep add "$B1" "$B0"
```

---

### Lane A — Spec + Harness + Evidence (unblocks everything)

#### A1 — Spec snapshot + `spec.lua` mirror
- Owned files: `planning/descent_spec.md`, `assets/scripts/descent/spec.lua`
- Dependencies: none
- Acceptance:
  - all decisions in §3.2 are explicit with numeric values and defined rounding/tie-breaks
  - `require("descent.spec")` returns a table; tests import only this for constants
- Commands run:
  - `bd lint`
- Evidence:
  - `.sisyphus/evidence/descent/<ID>/summary.md` includes explicit “decision list” and seeds reserved for determinism tests

#### A2 — Test runner + `RUN_DESCENT_TESTS` hook + watchdog (chokepoint)
- Owned files: `assets/scripts/tests/run_descent_tests.lua`, `assets/scripts/tests/test_descent_smoke.lua`, `assets/scripts/core/main.lua`
- Dependencies: none
- Acceptance:
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template` exits **0** on green
  - introduce a temporary failing assertion → exits **1** (failure removed before close)
  - module load failure prints module + error and exits **1**
  - watchdog timeout exits **1** and prints seed + current test/module
  - runner does not require `ENABLE_DESCENT=1` (tests must run even when menu is hidden)
- Commands run:
  - build per §1.2 then run §1.5
- Evidence:
  - `.sisyphus/evidence/descent/<ID>/run.log` (via `tee`)

#### A3 — Evidence README
- Owned files: `.sisyphus/evidence/descent/README.md`
- Dependencies: none
- Acceptance:
  - documents required artifacts and exact `tee` commands
  - includes “when UBS is required” rule and exact `just ui-verify` command
- Evidence:
  - `.sisyphus/evidence/descent/<ID>/summary.md`

#### A4 — Optional `just` recipes for Descent tests (chokepoint if edited)
- Owned files: `Justfile` (only if adding recipes)
- Dependencies: A2
- Acceptance:
  - `just test-descent` runs §1.5
  - optional: `just test-descent-headless` runs xvfb command (Linux only; prints a helpful error if `xvfb-run` missing)
- Evidence:
  - `.sisyphus/evidence/descent/<ID>/run.log`

---

### Lane B — Mode entry + menu routing (integration split)

#### B0 — Mode init (no menu) + `AUTO_START_DESCENT` plumbing
- Owned files: `assets/scripts/descent/init.lua`
- Non-owned: `assets/scripts/ui/main_menu_buttons.lua` (must not edit)
- Dependencies: A1, A2
- Acceptance:
  - `AUTO_START_DESCENT=1 DESCENT_SEED=123 ./build/raylib-cpp-cmake-template` boots Descent directly
  - exiting Descent returns to main menu with cleanup (no lingering timers/UI state)
  - Descent init is require-safe and creates no timers at require-time
- Commands run:
  ```bash
  just build-debug
  AUTO_START_DESCENT=1 DESCENT_SEED=123 ./build/raylib-cpp-cmake-template
  AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
  ```
- Evidence:
  - `.sisyphus/evidence/descent/<ID>/seed_and_entry.md` with screenshot + seed

#### B1 — Main menu entry + `ENABLE_DESCENT` gating (chokepoint)
- Owned files: `assets/scripts/ui/main_menu_buttons.lua`
- Dependencies: B0
- Acceptance:
  - with `ENABLE_DESCENT=1`, menu shows Descent and entering it succeeds
  - without `ENABLE_DESCENT=1`, no visible or accessible Descent route
- Commands run:
  ```bash
  just build-debug
  ENABLE_DESCENT=1 ./build/raylib-cpp-cmake-template
  ```
- Evidence:
  - `.sisyphus/evidence/descent/<ID>/menu_screenshot.png`

---

### Lane C — Core loop (parallel after A1+A2+B0)

#### C1 — Turn manager FSM (no AI logic)
- Owned files: `assets/scripts/descent/turn_manager.lua`
- Dependencies: A1, A2, B0
- Acceptance (tests):
  - FSM transitions correct
  - invalid/no-op input consumes 0 turns
  - dt independence: no input for N frames does not advance turns
- Commands run: §1.5
- Evidence: `.sisyphus/evidence/descent/<ID>/run.log`

#### C2 — Map grid + occupancy API
- Owned files: `assets/scripts/descent/map.lua`
- Dependencies: A1, A2, B0
- Acceptance (tests or deterministic scripted run):
  - rectangular maps for all spec sizes
  - occupancy prevents overlaps between player/enemy/item/stairs
  - coordinate conversion helpers are deterministic and bounds-safe
- Commands run: §1.5
- Evidence: `.sisyphus/evidence/descent/<ID>/map_screenshot.png`

#### C3 — Input + player action selection (move vs bump-attack)
- Owned files: `assets/scripts/descent/input.lua`, `assets/scripts/descent/actions_player.lua`
- Dependencies: C1, C2, A1, A2, B0
- Acceptance (tests):
  - legal move consumes exactly 1 turn
  - illegal move consumes 0 turns
  - bump enemy creates melee action (no double-advance)
  - key repeat policy: exactly 1 action per player turn (test by simulating held input across frames)
- Evidence: `.sisyphus/evidence/descent/<ID>/input_notes.md`

#### C4 — FOV + explored tracking
- Owned files: `assets/scripts/descent/fov.lua`
- Dependencies: C2, A1, A2, B0
- Acceptance (tests):
  - occlusion correct per spec rules
  - bounds safe at edges/corners
  - explored persists after LOS loss
- Evidence: `.sisyphus/evidence/descent/<ID>/fov_screenshot.png`

---

### Lane D — RNG + Procgen + Stairs (determinism-critical)

#### D1 — RNG adapter + seed parsing + HUD seed display
- Owned files: `assets/scripts/descent/rng.lua`, `assets/scripts/descent/ui/hud.lua`
- Dependencies: A1, A2, B0
- Acceptance (tests):
  - `DESCENT_SEED=123` produces stable RNG sequences across runs
  - invalid `DESCENT_SEED` (non-int/out of range) falls back to generated seed and logs a warning once
  - HUD always shows seed/floor/turn/pos
- Evidence: `.sisyphus/evidence/descent/<ID>/seed_screenshot.png`

#### D2a — Pathfinding (deterministic)
- Owned files: `assets/scripts/descent/pathfinding.lua`
- Dependencies: C2, A1, A2, B0
- Acceptance (tests):
  - BFS/A* returns stable path given same map and endpoints
  - neighbor order is explicit and tested
  - unreachable returns `nil` (or empty path); callers handle without crash (covered again in E2/E3)
- Evidence: `.sisyphus/evidence/descent/<ID>/pathfinding_cases.md`

#### D2b — Procgen + validation + fallback layout + snapshot hash
- Owned files: `assets/scripts/descent/procgen.lua`
- Dependencies: C2, D1, D2a, A1, A2, B0
- Acceptance (tests; fixed seeds `1..10`):
  - walkable start/stairs (floors 1–4)
  - reachable start→stairs (BFS)
  - quotas enforced exactly per spec
  - no overlaps (stairs not under entity/item)
  - fallback after `MAX_ATTEMPTS` with log: seed + attempts + reason
  - deterministic snapshot hash implemented per §5.3; same seed produces same hash
- Evidence: `.sisyphus/evidence/descent/<ID>/gen_seeds.md`

#### D3 — Stairs + floor transitions 1→5
- Owned files: `assets/scripts/descent/floor_transition.lua`
- Dependencies: D2b, C3, A1, A2, B0
- Acceptance (tests or scripted deterministic run):
  - stepping on stairs advances floor exactly once per player turn
  - player state persists: HP/MP/XP/inventory/equipment/god/spells
  - floor-local state resets correctly: enemies/items regenerated; explored stored per floor (or forbidden per spec)
  - floor 5 triggers boss floor hook (even if placeholder boss until H1)
- Evidence: `.sisyphus/evidence/descent/<ID>/stairs_walkthrough.md`

---

### Lane E — Combat + Enemies

#### E1 — Combat math (spec-locked)
- Owned files: `assets/scripts/descent/combat.lua`
- Dependencies: D1, C1, A1, A2, B0
- Acceptance (tests):
  - clamp range matches `descent.spec`
  - damage floors at 0 after armor
  - scripted RNG yields deterministic outcomes
  - negative stats rejected with clear error including entity id/type
- Evidence: `.sisyphus/evidence/descent/<ID>/combat_test_output.md`

#### E2 — Enemy definitions (5) + AI decision function
- Owned files: `assets/scripts/descent/enemy.lua`, `assets/scripts/descent/enemies/*.lua`
- Dependencies: E1, D2a, D2b, C4, A1, A2, B0
- Acceptance (tests):
  - adjacent → attack
  - visible + path → move toward
  - visible + no path → idle
  - not visible → idle
  - deterministic processing order defined and tested
- Evidence: `.sisyphus/evidence/descent/<ID>/ai_cases.md`

#### E3 — Enemy turn execution (separate module; avoid `turn_manager.lua` conflicts)
- Owned files: `assets/scripts/descent/actions_enemy.lua`
- Dependencies: E2, C1, C2, A2, B0
- Acceptance (tests):
  - no moves into occupied tiles
  - no overlaps after enemy phase
  - iteration order stable and tested
  - pathfinding `nil` handled (idle) with no crash
- Evidence: `.sisyphus/evidence/descent/<ID>/enemy_turn_log.md`

---

### Lane F — Player + Items + Character creation (UI-touching)

#### F1 — Player stats + XP/leveling (spec-locked)
- Owned files: `assets/scripts/descent/player.lua`
- Dependencies: D1, E1, A1, A2, B0
- Acceptance (tests):
  - XP thresholds match spec exactly
  - level-up recalculations match spec
  - emits a deterministic “spell selection” event hook (UI may stub until G3, but event must exist)
- Evidence: `.sisyphus/evidence/descent/<ID>/leveling_notes.md`

#### F2 — Items + inventory list UX + equip/use
- Owned files: `assets/scripts/descent/items.lua`, `assets/scripts/descent/ui/inventory.lua`
- Dependencies: C2, D1, A1, A2, B0
- Acceptance (tests):
  - pickup/drop/use/equip works
  - equip modifies combat stats via `player.lua` APIs (no hidden globals)
  - capacity enforcement per spec; swap/block UX explicitly implemented and tested
- Evidence: `.sisyphus/evidence/descent/<ID>/inventory_screenshot.png`

#### F3 — Scroll identification (seeded labels, unique, persistent)
- Owned files: `assets/scripts/descent/items_scrolls.lua`
- Dependencies: F2, D1, A1, A2, B0
- Acceptance (tests):
  - labels randomized per run seed
  - labels unique within run
  - identification persists for run and updates future display
- Evidence: `.sisyphus/evidence/descent/<ID>/scroll_id.md`

#### F4 — Character creation UI (species/background)
- Owned files: `assets/scripts/descent/ui/char_create.lua`
- Dependencies: F1, F2, A1, A2, B0
- Acceptance:
  - cannot start without selecting both
  - starting gear matches spec
  - cancel/back returns to main menu cleanly
- Evidence: `.sisyphus/evidence/descent/<ID>/char_create_screenshot.png`

---

### Lane G — Shops / God / Spells

#### G1 — Shop system (floor 1 guaranteed) + buy/sell + reroll
- Owned files: `assets/scripts/descent/shop.lua`, `assets/scripts/descent/ui/shop.lua`
- Dependencies: D2b, F2, D1, A1, A2, B0
- Acceptance (tests):
  - shop appears on floor 1 per spec rule
  - stock deterministic per seed+floor (+ shop instance index if multiple)
  - purchase is atomic (no partial state on failure)
  - insufficient gold shows message and consumes 0 turns (or spec-defined)
  - reroll cost enforced; reroll deterministic given seed + reroll count
  - inventory-full behavior defined and tested
- Evidence: `.sisyphus/evidence/descent/<ID>/shop_walkthrough.md`

#### G2 — God system (Trog) + altars + conduct enforcement
- Owned files: `assets/scripts/descent/god.lua`, `assets/scripts/descent/ui/altar.lua`
- Dependencies: D2b, F1, A1, A2, B0
- Acceptance (tests):
  - altars appear per spec floors/odds
  - worship state persists across floors
  - while worshiping Trog, spell cast is blocked with deterministic message and consumes 0 turns
  - altar UI always has cancel/back path
- Evidence: `.sisyphus/evidence/descent/<ID>/trog_altar.md`

#### G3 — Spells (3) + targeting + MP usage
- Owned files: `assets/scripts/descent/spells.lua`, `assets/scripts/descent/ui/targeting.lua`
- Dependencies: F1, E1, C4, D1, G2, A1, A2, B0
- Acceptance (tests):
  - spell selection triggered on level-up (or start if spec says)
  - casts validate MP, LOS, range, targeting rules
  - damage/heal deterministic with scripted RNG
- Evidence: `.sisyphus/evidence/descent/<ID>/spells_demo.md`

---

### Lane H — Boss + Endings + Soak

#### H1 — Boss floor rules + boss AI + phases
- Owned files: `assets/scripts/descent/boss.lua`, `assets/scripts/descent/floor5.lua`
- Dependencies: D3, E1, E3, F1, A1, A2, B0
- Acceptance (tests or scripted run):
  - floor 5 arena spawns per spec
  - boss phases trigger at spec thresholds
  - win condition triggers victory state
  - any runtime script error routes to error ending screen with seed + error; in test mode exits 1
- Evidence: `.sisyphus/evidence/descent/<ID>/boss_seed.md`

#### H2 — Victory + Death + Error screens (seed + stats + return to menu)
- Owned files: `assets/scripts/descent/ui/endings.lua`
- Dependencies: H1, D1, A1, A2, B0
- Acceptance:
  - shows seed, turns, final floor, kills, cause/error
  - return to main menu works and cleanup verified
- Evidence: `.sisyphus/evidence/descent/<ID>/ending_screenshot.png`

#### H3 — 5-run soak + timing evidence
- Owned files: evidence only unless fixes required
- Dependencies: A1–H2 complete, B1 optional
- Acceptance:
  - 5 full runs without crash/hang
  - record ≥3 timed runs (wall clock) and compare to 15–20 min target
  - if out of band: list tuning knobs and propose exact spec changes (as diffs against `planning/descent_spec.md`)
- Commands:
```bash
just build-debug
for seed in 101 102 103 104 105; do
  AUTO_START_DESCENT=1 DESCENT_SEED="$seed" ./build/raylib-cpp-cmake-template
done
```
- Evidence: `.sisyphus/evidence/descent/<ID>/soak.md`

---

## 9) Required Failure Modes + Behaviors (Add Tests Where Applicable)

- Procgen cannot place start/stairs:
  - fallback after `MAX_ATTEMPTS`
  - log seed/attempts/reason
  - still produces reachable map
- Turn deadlock/hang during tests:
  - watchdog triggers
  - prints seed + current phase/test/module
  - exits 1
- AI pathing returns nil:
  - enemy idles
  - deterministic
  - no crash
- FOV out-of-bounds:
  - clamp; explicit corner tests
- Nondeterminism sources:
  - dt/frame-rate, table iteration, unordered sets → forbidden or explicitly sorted
- UI modal lock:
  - every modal has cancel/back
  - invalid input must not soft-lock
- Malformed data:
  - validate on load; fail fast with module + id
- Seed visibility:
  - on death/victory/error, seed/floor/turn must be shown and logged

---

## 10) Definition of Done (MVP Gate)

MVP is complete only when all are true:

- Char creation (Human/Gladiator) works; cancel-safe.
- Turn-based movement/combat works; invalid/no-op input consumes 0 turns.
- Shadowcasting FOV correct; explored persists per spec.
- 5 floors generate to spec; stairs transitions preserve player state; floor 5 boss encounter completes a win path.
- Items: pickup/equip/use; scroll identification works.
- Shop works (floor 1 guaranteed) including reroll rules.
- Trog worship works; conduct blocks spellcasting with message and 0 turns consumed.
- 3 spells work with targeting + MP + LOS per spec.
- Victory/death/error screens show seed + stats; return to menu cleanly.
- Test commands green (attach logs to evidence):
  - `just test` (if any C++ touched)
  - `AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template`
  - `just ui-verify` if shared UI/layout primitives changed
- Soak evidence recorded under `.sisyphus/evidence/descent/`