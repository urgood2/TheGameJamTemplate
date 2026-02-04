# Game #4 “Bargain” — Engineering Plan (v15: CI-proofed determinism + parallel streams)

## 1) Goal + Constraints

**Ship an MVP with a deterministic, replayable 7-floor run** where **Bargains are the primary progression mechanic**, and every run ends in **victory** or **death** (no softlocks), proven by a **single CI-gated command**.

### Non-negotiables
- **Determinism:** Same `(seed, script)` ⇒ identical terminal outcome + identical digest.
- **Replayability:** Any CI failure yields **one machine-parseable repro payload**.
- **Headless correctness:** In test mode **no window**, **no render loop**, **no frame-dt dependence**.
- **Termination:** No infinite loops; caps are deterministic and produce a terminal run state.

### Explicit non-goals (MVP)
- Inventory/shops/save-load/meta progression
- Balance polish beyond “not broken”
- Advanced pathfinding beyond deterministic chase/attack

---

## 2) Definition of Done (DoD)

### 2.1 One proof command (local + CI)
**Command sequence**
1. Build: `just build-debug-fast`
2. Headless tests: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

**Pass criteria**
- Exit code `0`
- **Headless mode:** no window created, no render loop entered
- All Bargain suites pass
- On failure: exit non-zero and print **exactly one** JSON repro line (see §8)

### 2.2 CI gates (hard requirements)
| Gate | Requirement | Exact check (CI) |
|---|---|---|
| A Determinism | same seed+script → identical digest | run each case twice; compare digest strings |
| B Termination | run ends in `victory` or `death` | assert `run_state ∈ {"victory","death"}` |
| C Deals catalog | exactly 21 deals, stable IDs | count=21; IDs unique; sins×3 complete |
| D Downside enforcement | every deal has measurable downside | baseline vs applied must flip ≥1 metric |
| E No nondeterminism | banned APIs + unstable iteration forbidden | static scan + runtime guardrails |
| F Repro fidelity | one failing test → one repro bundle | stdout contains exactly one JSON line |

---

## 3) Architecture Boundary (enables parallel work)

### 3.1 Two-layer rule (enforced)
- **Sim layer (deterministic):** owns world state, RNG, rules, deals, AI, procgen/FOV, digest.
- **UI/engine layer (nondeterminism allowed):** renders and collects input only.

**Rule:** UI emits `input` to `step(world, input)` and must never mutate `world` directly.

### 3.2 “Hot” shared files (integrator-owned)
Minimize concurrent edits by restricting cross-stream wiring to:
- `assets/scripts/core/main.lua` (early `RUN_BARGAIN_TESTS` hook before any engine/window init)
- `assets/scripts/tests/run_bargain_tests.lua` (suite registration, runner, repro emission, exit code)

Everything else should land in low-collision zones (see §7).

---

## 4) Frozen Interfaces (contract-tested)

### 4.1 World schema (minimum)
Required, stable fields:
- `world.grid`
- `world.entities` (map `id -> entity`)
- `world.player_id`
- `world.turn` (integer, deterministic increments)
- `world.phase` (string enum)
- `world.floor_num` (1..7)
- `world.run_state` (`"playing"|"victory"|"death"`)
- `world.rng` (the only RNG)
- `world.deals.applied` (map `deal_id -> true`)
- `world.deals.history` (append-only array)
- `world.deals.pending_offer` (`nil | offer`)
- `world.caps_hit` (bool)

Allowed append-only debug channels (must not affect outcomes):
- `world.events`
- `world.messages`

### 4.2 Entity schema (minimum)
- `id`, `kind` (`"player"|"enemy"|"boss"`)
- `x`, `y`
- `hp`, `hp_max`
- `atk`, `def`, `speed`, `fov_radius`
- `xp`, `level`
- `flags` (deterministically serialized set)
- `hooks` (`hook_name -> array`, stable order)

### 4.3 Offer schema (stable order; no unordered iteration)
`world.deals.pending_offer`:
- `kind ∈ {"floor_start","level_up"}`
- `offers: [deal_id...]` (deterministic order)
- `must_choose: bool`
- `can_skip: bool`

### 4.4 Input API (exact set)
`step(world, input)` supports:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

**Error semantics (frozen)**
- Invalid input returns `{ok=false, err="..."}`
- Consumes actor’s turn
- Must not crash; must remain deterministic; must preserve invariants

### 4.5 Phase machine (table-driven)
Phases:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- Forced offers pin `DEAL_CHOICE` until choice made
- Enemy action order: `speed desc`, tie-break `id asc`
- Canonical direction order: `N, E, S, W` (no diagonals for MVP)

---

## 5) Determinism + Termination Rules (enforced)

### 5.1 RNG rules
- Only `world.rng` may generate randomness
- Forbidden in sim: `math.random`, time-based seeds, frame `dt`, engine globals, unordered iteration affecting outcomes

### 5.2 Stable iteration rules
- No gameplay-critical `pairs()`/`next()` in sim-critical modules
- Any “order matters” collection must be:
  - arrays in fixed order, or
  - explicitly sorted with deterministic comparator + tie-breakers

### 5.3 Caps (deterministic failure mode)
Constants (contract-tested; tune later):
- `MAX_INTERNAL_TRANSITIONS = 64`
- `MAX_STEPS_PER_RUN = 5000`
- procgen attempt caps per floor with deterministic fallback

**On cap trip**
- `world.caps_hit=true`
- set terminal `world.run_state` (default `"death"`)
- emit repro payload (§8)

---

## 6) Test & CI Strategy (failure-localizing)

### 6.1 Runner contract
Entry: `assets/scripts/tests/run_bargain_tests.lua`
- Uses existing runner (`describe/it/expect`)
- Stable stdout: normal suite output; on failure prints **exactly one** JSON line
- Exit `0` on success; non-zero on any failure

### 6.2 Required suites (deliverable-sized)
**Contracts & harness**
- `assets/scripts/tests/bargain/contracts_spec.lua`
  - schema validation, phase rules, invalid-input semantics, cap behavior
- `assets/scripts/tests/bargain/determinism_static_spec.lua`
  - static scan: ban nondeterministic APIs + ban `pairs()` in sim-critical scopes
- `assets/scripts/tests/bargain/digest_spec.lua`
  - digest stability across reruns; digest versioning rules; stable serialization checks

**Core behavior**
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`
  - tiny fixed map: move/attack/turn loop; terminates; digest stable
- `assets/scripts/tests/bargain/ai_spec.lua`
  - deterministic targeting, tie-breakers, action order

**World-gen & visibility**
- `assets/scripts/tests/bargain/floors_spec.lua`
  - bounded seed set: stairs reachable/connectivity/spawn invariants; deterministic fallback on cap hit
- `assets/scripts/tests/bargain/fov_spec.lua`
  - golden visible-set tests on canonical maps

**Deals**
- `assets/scripts/tests/bargain/deals_loader_spec.lua`
  - exactly 21 deals, unique IDs, sins×3 coverage
- `assets/scripts/tests/bargain/deals_downside_spec.lua`
  - 21 table rows; each asserts ≥1 downside metric flips

**End-to-end determinism**
- `assets/scripts/tests/bargain/run_scripts_spec.lua`
  - scripted full runs + golden digests; double-run determinism; terminal state assertion

### 6.3 Golden protocol (minimize churn)
Goldens under `assets/scripts/tests/bargain/goldens/**`
- Any golden change must include:
  - updated golden file(s)
  - a **1-line rationale** adjacent to each golden
  - proof: two consecutive runs match for same `(seed, script)`

---

## 7) Parallel Streams (owned paths + clear handoffs)

### 7.1 Workstream table
| Stream | Owns (exclusive edit zone) | Produces | Depends on |
|---|---|---|---|
| Integrator (I) | `assets/scripts/core/main.lua`, `assets/scripts/tests/run_bargain_tests.lua` | headless hook, runner wiring, repro bundle emission | none |
| Core Sim (C) | `assets/scripts/bargain/sim/**` + `sim_smoke_spec.lua` | `step()`, combat loop, caps wiring, events/messages, invariants | I contracts |
| Digest/Scripts (R) | `assets/scripts/bargain/sim/digest/**`, `digest_spec.lua`, `run_scripts_spec.lua`, `goldens/**` | stable digest + replay scripts + goldens | C |
| Floors/FOV (F/V) | `assets/scripts/bargain/floors/**`, `assets/scripts/bargain/fov/**` + `floors_spec.lua`, `fov_spec.lua` | procgen + FOV with invariants + goldens | C world schema |
| Deals (D) | `assets/scripts/bargain/data/deals/**`, `assets/scripts/bargain/deals/**` + deals specs | offers + apply hooks + 21 deals + downside metrics | C+R |
| Enemies/Boss (A) | `assets/scripts/bargain/enemies/**`, `assets/scripts/bargain/ai/**` + `ai_spec.lua` | enemy templates + AI + boss + victory condition | C |
| UI Bridge (UI) | UI layer only | deal modal + HUD + victory/death screens mapping to inputs | C step API |

### 7.2 Merge strategy (keeps streams unblocked)
1. Land **interfaces + contract tests** first (stubs acceptable)
2. Streams implement behind interfaces without touching other streams’ zones
3. Integrator only resolves cross-stream wiring in the two hot files

---

## 8) Failure Repro Bundle (single JSON line)

### 8.1 Output contract
On any failure:
- Print **exactly one** JSON object (single line) to stdout
- Exit non-zero

### 8.2 Payload fields (minimum)
- `seed`, `script_id`, `floor_num`, `turn`, `phase`, `run_state`
- `last_input`, `pending_offer`
- `last_events` (<= 20; deterministic order)
- `digest`, `digest_version`
- `caps_hit` (bool)
- optional: `world_snapshot_path` (only if deterministic)

### 8.3 Snapshot rules (if used)
- filename deterministic from `(seed, script_id, turn)`
- serializer enforces stable key ordering (no raw table iteration order)

---

## 9) Milestones (dependency-ordered; each ends green)

### M0 — Harness + contracts (CI-critical)
**Deliverables**
- `RUN_BARGAIN_TESTS` early-exit (no window/render loop)
- test runner + repro emission
- `contracts_spec` + minimal `sim_smoke_spec` green

**Exit criteria**
- Proof command passes locally and in CI
- Headless guarantee validated by test (explicit assertion that window init not called)

### M1 — Core sim loop + digest baseline
**Deliverables**
- deterministic `step()` loop + combat + caps
- digest v1 + stable serialization rules

**Exit criteria**
- `sim_smoke_spec` covers: move/attack/enemy acts/terminal outcome
- `digest_spec` passes: same case twice ⇒ same digest

### M2 — Floors + FOV invariants
**Deliverables**
- procgen with reachability guarantee or deterministic cap+fallback
- FOV with canonical golden maps

**Exit criteria**
- `floors_spec` green on bounded seed list (fixed, committed)
- `fov_spec` goldens green

### M3 — Deals system + 21 deals + downside enforcement
**Deliverables**
- offer generation at `floor_start` + `level_up`
- deal apply plumbing (hooks)
- deals catalog (21) + loader + downside metrics

**Exit criteria**
- `deals_loader_spec`: 21 unique IDs, sins×3 coverage
- `deals_downside_spec`: 21/21 flip ≥1 metric

### M4 — Enemies + boss + explicit victory/death
**Deliverables**
- deterministic enemy templates + chase/attack AI
- boss encounter and victory condition on floor 7

**Exit criteria**
- scripted tests hit both `victory` and `death`
- `ai_spec` asserts ordering and tie-breakers

### M5 — Minimal UI bridge (sim unchanged)
**Deliverables**
- deal UI modal maps to `deal_choose` / `deal_skip`
- HUD + victory/death screen + restart

**Exit criteria**
- manual smoke checklist on a known seed
- static scan ensures no sim logic in UI scope (scope-defined allowlist)

### M6 — Full-run scripts + determinism goldens
**Deliverables**
- scripts `S1,S2,S3` (fixed input sequences + terminal outcomes)
- golden digests for each `(seed, script)`

**Exit criteria**
- `run_scripts_spec` green
- CI gates A+B green for all cases (double-run + terminal state)

---

## 10) Deals Catalog Contract (stable IDs + downside proof)

### 10.1 IDs and cardinality
- ID format: `<sin>.<index>` (e.g., `wrath.1`)
- Exactly `7 sins × 3 deals = 21`
- After Gate C is green: **append-only** (no renames/remaps)

### 10.2 Downside standard (testable)
For each deal, run the same deterministic script twice:
- baseline (not applied)
- applied (applied at earliest legal moment)

Assert ≥1 metric flips (definitions must be precise and shared by tests):
- `hp_lost_total`
- `turns_elapsed`
- `damage_dealt_total` / `damage_taken_total`
- `kills_required` (when relevant)
- `visible_tiles_count` (FOV)
- `forced_actions_count` / `denied_actions_count` (input constraints)

---

## 11) Risks → Mitigations (must be test-backed)
- Lua iteration nondeterminism → ordered-iteration helpers + `determinism_static_spec`
- Hidden randomness/time in bridge/UI → headless suite never boots UI; static scan bans time/RNG in sim scopes
- Procgen infinite loops/unreachable stairs → attempt caps + invariant specs + deterministic fallback + repro payload
- “Downside is toothless” → downside metrics must flip per deal
- Golden churn → digest versioning + rationale-per-change + double-run proof

---

## 12) Beads workflow mapping (operational)
For each milestone, create bead-sized units with an **exit test** named explicitly (suite + file):
- M0 beads: headless hook; runner+repro; `contracts_spec` baseline; `sim_smoke_spec` baseline
- M1 beads: `step()`+caps; digest v1; digest spec
- M2 beads: procgen invariants; FOV goldens
- M3 beads: offers plumbing; deals loader; downside metrics + spec rows
- M4 beads: enemy templates; AI ordering; boss + victory
- M5 beads: deal UI modal; end screens
- M6 beads: scripts S1–S3; goldens + run_scripts spec

Each bead must:
- reserve owned paths (exclusive)
- land code + tests together
- close bead with a short Agent Mail note: touched contracts, suites to rerun, golden changes (if any)