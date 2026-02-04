# Game #4 “Bargain” — Engineering Plan (rewrite: more specific, testable, parallel-first)

## 0) Scope, Assumptions, and Non‑Goals

### One shippable vertical slice
A deterministic, replayable 7‑floor run loop:
- Floors 1–6: explore/combat → reach stairs
- Floor 7: boss (“Sin Lord”) → victory on defeat
- Death → game over → restart → new seeded run
- Target run length: 10–15 minutes (balance last)

### Locked gameplay constraints
- Turn-based, grid-based, FOV-limited exploration/combat
- Player verbs: `Move` (4‑way), `Attack` (directional), `Wait`
- Enemy AI: deterministic chase + attack (no A* required; BFS/distance-field OK)

### Non-goals (explicitly out of scope)
- No inventory/items/shops
- No save/load
- No meta-progression

### Engineering constraints (determinism-first)
- All gameplay rules in **pure Lua sim**: no engine globals, rendering, IO, time, frame dt
- UI is a thin adapter: render from `world`, translate input → sim actions
- All randomness via **one injected RNG** owned by sim (`world.rng`); no `math.random`, no OS/time

---

## 1) Ship Gates (hard Definition of Done)

### Gate A — “No crash / no softlock”
For seeds `S1,S2,S3`:
- A full run always reaches **victory or death**
- **0 crashes**, **0 softlocks** (including “stuck in modal”, “no valid actions”, “phase never advances”)

### Gate B — Deal offer rules (blocking correctness)
- At **every floor start**: a **forced** deal is shown  
  - `must_choose=true`, `can_skip=false`
  - sim cannot advance until a deal is chosen
- At **every level-up**: an **optional** deal is shown  
  - `must_choose=false`, `can_skip=true`
  - skipping continues play

### Gate C — Content completeness + stable IDs
- Exactly **21 deals** exist (7 sins × 3)
- Deal IDs are stable and unique (no dupes, no missing sin category)

### Gate D — Downside enforcement (automated, regression-proof)
- **21/21 deals have at least one automated assertion** proving a downside exists
- The assertion must fail if the downside is removed (no “just checks field exists” tests)

### Gate E — Determinism
- `seed + scripted inputs` produces a stable **digest**
- Two consecutive runs on the same machine match
- (Stretch) Digest matches across machines (if feasible for this repo’s environment)

---

## 2) Repo Wiring (single integrator touch-points)

### Run modes
- `AUTO_START_BARGAIN=1` → auto-enter Bargain loop (highest precedence)
- Manual entry remains: `require("bargain.game").start()`

### Test runner integration (binary-driven, early exit)
- Reuse `assets/scripts/tests/test_runner.lua`
- Add `RUN_BARGAIN_TESTS=1` hook in `assets/scripts/core/main.lua`:
  - runs early
  - `os.exit(0)` on pass, `os.exit(1)` on failure
  - invokes `require("tests.run_bargain_tests").run()`

Command contract:
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

### Hot-file ownership rule (merge-conflict prevention)
- Only the **Integrator** bead edits:
  - `assets/scripts/core/main.lua`
  - `assets/scripts/tests/test_runner.lua` (if needed)
- Everyone else works under:
  - `assets/scripts/bargain/**`
  - `assets/scripts/tests/**` (new files OK; shared runner stays integrator-owned)

---

## 3) Contract Freeze (M0: lock interfaces so lanes can work in parallel)

### World schema (required keys; tested)
Required:
- `world.grid`
- `world.entities` (id → entity)
- `world.player_id`
- `world.turn` (int)
- `world.phase` (enum string)
- `world.floor_num` (1–7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (single RNG instance; only source of randomness)
- `world.deals.applied` (deal_id → true)
- `world.deals.history` (ordered entries `{deal_id, kind, floor_num, turn}`)
- `world.deals.pending_offer` (nil or offer struct)

Recommended (adopt once → frozen):
- `world.stairs` (`{x,y}` or nil)
- `world.messages` (append-only deterministic structs)
- `world.debug_flags` (tests only; must not affect release determinism)

### Deal offer struct (frozen; no table iteration)
`world.deals.pending_offer`:
- `kind` ∈ `{ "floor_start", "level_up" }`
- `offers` = array of deal IDs (stable order)
- `must_choose` (bool)
- `can_skip` (bool)

### Entity schema (frozen)
Required:
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`, `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministic map)
- `hooks` (hook_name → array of callbacks; callback order stable)

### Action encoding + invalid action policy (frozen; tested)
- Move: `{type="move", dx=0|±1, dy=0|±1}`
- Attack: `{type="attack", dx=0|±1, dy=0|±1}`
- Wait: `{type="wait"}`

Invalid action behavior:
- Return `{ok=false, err="..."}` **and consume the actor’s turn**

### Phase machine (frozen; tested)
Phases:
- `DEAL_CHOICE` → `PLAYER_INPUT` → `PLAYER_ACTION` → `ENEMY_ACTIONS` → `END_TURN` → `PLAYER_INPUT`

Deterministic processing rules:
- If `pending_offer.must_choose=true`, sim stays in `DEAL_CHOICE` until chosen
- Enemy order deterministic: sort by `speed` desc, tie-break by `id` asc

---

## 4) Module Contracts (explicit exports; each ships with tests)

Each bead implements one module + tests that define semantics.

### Core sim API (recommended minimal surface; freeze by tests in M0)
- `bargain/sim/world.lua`
  - `new_run(seed, opts) -> world`
  - `clone_for_test(world) -> world` (optional; must preserve determinism)
- `bargain/sim/step.lua`
  - `step(world, input) -> {world=world, events={}, ok=true|false, err?}`
  - `input` covers: player action, deal choice, deal skip

### Modules (ownership + semantics)
- `bargain/sim/grid.lua`
  - occupancy, bounds, stable neighbor order (e.g., `N,E,S,W`)
  - tests: collision, swap rules, determinism of neighbor iteration
- `bargain/sim/turn_system.lua`
  - phase stepping, turn consumption, offer gating
  - tests: forced offer blocks progression; invalid action consumes turn
- `bargain/sim/combat.lua`
  - frozen damage semantics (RNG only via `world.rng`)
  - tests: known outcomes with stub RNG; armor/def behavior stable
- `bargain/sim/fov.lua`
  - occlusion + memory (`VISIBLE → SEEN`)
  - tests: line-of-sight corner cases; stable iteration order
- `bargain/sim/floors.lua` + `bargain/data/floors.lua`
  - `generate_floor(world, floor_num) -> world` (or return grid/entities)
  - tests: invariants only (reachable stairs, bounded loops, stable seed behavior)
- `bargain/sim/enemy_ai.lua` + `bargain/data/enemies.lua`
  - deterministic chase/attack with explicit tie-breaks
  - tests: tie-break resolution; no nondeterministic target selection
- `bargain/sim/deals.lua` + `bargain/data/sins/*.lua`
  - offer rules: floor-start forced; level-up optional
  - apply rules: stable IDs; effects implemented via stats/flags/hooks
  - tests: 21 IDs present; no dupes; 21/21 downside enforcement

Integrator-owned bridge:
- `bargain/game.lua`
  - orchestrates sim + UI; must not add hidden randomness/time
  - optional debug hooks must be disabled by default and must not affect digest in normal runs

---

## 5) Test Strategy (fast, deterministic, downside-enforcing)

### How tests run (single command gate)
- `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

### Required test files (minimum)
- `assets/scripts/tests/test_bargain_grid.lua`
- `assets/scripts/tests/test_bargain_turn_system.lua`
- `assets/scripts/tests/test_bargain_combat.lua`
- `assets/scripts/tests/test_bargain_fov.lua`
- `assets/scripts/tests/test_bargain_enemy_ai.lua`
- `assets/scripts/tests/test_bargain_floors.lua`
- `assets/scripts/tests/test_bargain_data_loading.lua`
- `assets/scripts/tests/test_bargain_deals.lua`
- `assets/scripts/tests/test_bargain_game_smoke.lua`
- `assets/scripts/tests/test_bargain_determinism.lua`
- `assets/scripts/tests/run_bargain_tests.lua`

### Fixture rules (keep tests stable)
- Unit tests use tiny hand-authored maps (no procgen snapshots)
- Procgen tests are invariants-only over bounded seeds
- No rendering, no frame timing, no OS/time calls

### Downside enforcement pattern (table-driven; 21 rows)
For each deal:
- Arrange: minimal `world + player`, deterministic RNG
- Act: apply deal; run 1–3 steps/actions
- Assert: observable downside (must change an outcome or block an action), examples:
  - stat penalty flips combat outcome within a fixed script
  - per-turn drain triggers after `END_TURN`
  - action restriction returns `{ok=false,...}` and consumes turn
  - self-damage triggers on move/attack
  - XP penalty changes level-up timing in a fixed script

---

## 6) Determinism Digest Spec (precise, test-owned)

### Digest contents (stable order, no table iteration)
Serialize in fixed order:
- `floor_num`, `turn`, `phase`, `run_state`
- player: `(x,y,hp,hp_max,xp,level,atk,def,speed,fov_radius)`
- entities: sorted by `id`, serialize `(id,kind,x,y,hp,flags_subset)`
- applied deal IDs: sorted lexicographically

### Determinism rules (tests enforce)
- Never rely on Lua table iteration for offers/digest/processing
- Explicit ordering for: offers, AI tie-breaks, enemy processing, hook callback order
- Only `world.rng` provides randomness (no `math.random`, no time, no OS)

### Scripted input determinism test (gated)
- Provide action lists (50–200 actions) that include deal choices when prompted
- Gate: `seed + actions → digest == expected` for `S1,S2,S3`
- Procedure to update expected digests is explicit: only after intentional rule changes

---

## 7) Milestones (deliverables + acceptance checks)

### M0 — Wiring + Contract Freeze (unblocks parallel work)
Deliver:
- `RUN_BARGAIN_TESTS=1` hook + `run_bargain_tests.lua`
- stubs with correct exports
- contract tests for: world schema, action encoding, phase machine, offer gating
Accept:
- test command exits `0` on pass, `1` on fail
- two consecutive runs of the test binary are identical

### M1 — Core Sim Loop on tiny fixed map
Deliver:
- grid movement/collision, phase loop, combat resolution
Accept:
- `grid/turn/combat` tests pass
- smoke: fixed 5×5 map, player kills one enemy, no desync

### M2 — FOV + Floors invariants (deterministic bounded gen)
Deliver:
- FOV occlusion + memory
- floor generator meets invariants for floors 1–7
Accept:
- `fov/floors` tests pass
- generation has bounded loops and is deterministic per seed

### M3 — Deals (21) + 21/21 downside tests (content ship gate)
Deliver:
- forced floor-start offer; optional level-up offer
- all 21 deals implemented with benefits + test-visible downsides
- 21-row downside enforcement table
Accept:
- data loading proves 21 stable IDs, no dupes, all sins present
- deal tests prove offer rules + 21/21 downside enforcement

### M4 — Enemies + Boss + Win/Lose
Deliver:
- enemy templates + deterministic chase/attack
- boss on floor 7
- victory/death transitions + restart
Accept:
- AI tests pass
- boss defeat → `run_state="victory"`
- player HP ≤ 0 → `run_state="death"`

### M5 — UI Flows + Minimal UX
Deliver:
- deal modal (forced vs optional skip)
- HUD (HP/stats/deals/floor/turn)
- victory/death screens + restart
Accept:
- manual checklist recorded (small, explicit steps; no “seems fine”)

### M6 — Determinism Hardening (digest gate)
Deliver:
- stable orchestrator in `bargain/game.lua` (no hidden time/randomness)
- full-run scripted tests for `S1,S2,S3` with expected digests
Accept:
- full-run scripted tests pass for `S1,S2,S3`

### M7 — Balance Pass (time-to-complete target)
Deliver:
- `data/balance.lua` as the single tuning surface
- 3 timed seeded runs recorded (seed + inputs + outcome + duration)
Accept:
- average completion time ~10–15 minutes
- at least one seed is winnable without debug hooks

---

## 8) Parallel Work Breakdown (Beads-ready, low-conflict)

### Work lanes (clear ownership)
- Integrator/Wiring: main hook, test aggregator, `bargain/game.lua` bridge
- Sim Core: `grid`, `turn_system`, `combat`
- Procgen/FOV: `fov`, `floors` invariants + generator
- AI/Enemies: `enemy_ai`, `enemies` data
- Deals/Content: `deals` core + 7 sin beads (3 deals each)
- Determinism Harness: digest + scripted input helpers + determinism tests
- UI: deal modal + HUD + screens (after contracts are frozen)

### Bead definitions (what “done” means)
- Module bead: implement module + its dedicated test file(s)
- Sin bead: implement `bargain/data/sins/<sin>.lua` (3 deals) + 3 downside assertions in `test_bargain_deals.lua`
- Floors bead: add/adjust invariants + generator changes + invariants tests
- UI bead: one UX flow + checklist entry (optional smoke automation)

### Dependency graph
- M0 → (Sim Core, Deals scaffold, FOV/Floors, AI, Digest harness) in parallel
- (Sim Core + Deals + Floors + AI) → smoke run → determinism gate
- UI after core semantics stabilize
- Balance last

---

## 9) Coordination Rules (multi-agent workflow compliance)

- Use BV to identify ready beads; claim bead status `in_progress` before coding
- Reserve files (exclusive) before edits; avoid integrator hot-files unless you are the integrator bead
- Contract changes: update tests first → module updates → integrator updates → notify dependents via Agent Mail
- Keep beads small and mergeable: “one module / one sin / one UI feature”
- Run UBS before committing (when commits are made)