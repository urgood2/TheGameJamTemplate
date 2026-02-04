# Game #4 “Bargain” — Engineering Plan (v18: contract-driven sim, CI-reproducible, parallel workstreams)

## 0) Outcome & constraints

### 0.1 MVP outcome
Ship an MVP that always produces a terminal outcome for a deterministic, replayable **7-floor run**, where **Bargains are the primary progression mechanic**.

### 0.2 Hard success criteria (all must be true)
- **Determinism:** same `(seed, script_id)` ⇒ same `run_state` and same `digest` (byte-for-byte).
- **Termination:** every run ends in `victory` or `death` (no softlocks), enforced by deterministic caps.
- **CI repro:** any failure prints **exactly one** single-line JSON object on stdout with enough info to replay locally (and nothing else JSON-shaped).

### 0.3 Explicit non-goals (for MVP)
- Balance tuning beyond “downside is measurable”.
- UI polish/juice (VFX, SFX, particles, animations).
- Multiple classes/builds, meta-progression, save/load, mid-run persistence.

---

## 1) One proof command (local + CI)

### 1.1 Required command sequence
1. Build: `just build-debug-fast`
2. Run headless tests: `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`

### 1.2 Pass/fail contract
**Pass =** exit code `0`, and:
- **Headless guarantee:** no window created; no render loop entered.
- All Bargain test suites pass.

**Fail =** exit code non-zero, and:
- stdout contains **exactly one** JSON repro line (see §9), and nothing else “JSON-shaped”.

### 1.3 Decision gate (non-negotiable)
If Lua scripts cannot run before window init, implement the `RUN_BARGAIN_TESTS` early-exit in the **C++ entrypoint** (before any raylib/window calls).

---

## 2) CI shape & objective gates

### 2.1 CI jobs (fast + isolating)
- **Job 1: build** — `just build-debug-fast`
- **Job 2: bargain-headless** — `RUN_BARGAIN_TESTS=1 ./build-debug/raylib-cpp-cmake-template`
- (Optional later) **Job 3: smoke-run** — minimal runtime check (still headless), keeps UI out of CI.

### 2.2 Gates (each must map to named tests)
| Gate | What it proves | Exact check | Must be enforced by |
|---|---|---|---|
| A Determinism | reruns match | run each case twice; `digest` strings equal | `digest_spec.lua`, `run_scripts_spec.lua` |
| B Termination | no softlocks | `run_state ∈ {"victory","death"}` for all scripts | `contracts_spec.lua`, `run_scripts_spec.lua` |
| C Deals catalog | stable IDs + complete set | exactly `21` deals; unique IDs; `7 sins × 3` coverage | `deals_loader_spec.lua` |
| D Downside enforcement | every deal has measurable downside | baseline vs applied flips ≥1 downside metric | `deals_downside_spec.lua` |
| E No sim nondeterminism | no hidden randomness/ordering drift | static scan + runtime invariants | `determinism_static_spec.lua`, `contracts_spec.lua` |
| F Repro fidelity | failures actionable | exactly one JSON repro line; schema-valid | `repro_schema_spec.lua` |

---

## 3) Architecture boundaries (enables parallel delivery)

### 3.1 Layer boundary (hard rule)
- **Sim layer (deterministic):** world state, RNG, rules, deals, AI, procgen, FOV, digest, scripts/replay.
- **UI/engine layer (nondeterminism allowed):** rendering, input collection, audio, frame timing.

**Rule:** UI can only emit `input` into `step(world, input)`; UI must never mutate sim state directly.

### 3.2 “Hot files” policy (minimize merge collisions)
Only these two files should be frequently touched:
- `assets/scripts/core/main.lua`
- `assets/scripts/tests/run_bargain_tests.lua`

Everything else must land in stream-owned directories (see §8).

---

## 4) Frozen contracts (versioned; expand carefully)

> Freeze the smallest surface area that unblocks parallel work. Any expansion must be additive and test-backed.

### 4.1 `step(world, input)` API (frozen)
Accepted inputs:
- `{type="move", dx=0|±1, dy=0|±1}`
- `{type="attack", dx=0|±1, dy=0|±1}`
- `{type="wait"}`
- `{type="deal_choose", deal_id="..."}`
- `{type="deal_skip"}`

Return shape:
- `{ok=true, events={...}, world=world}` or `{ok=false, err="...", events={...}, world=world}`

Invalid input semantics (frozen):
- returns `{ok=false, err=...}`
- consumes the actor’s turn
- never crashes; preserves invariants; deterministic

### 4.2 Phase machine (frozen, table-driven)
Canonical phases:
`DEAL_CHOICE → PLAYER_INPUT → PLAYER_ACTION → ENEMY_ACTIONS → END_TURN → PLAYER_INPUT`

Rules:
- forced offers pin `DEAL_CHOICE` until resolved
- enemy order: `speed desc`, tie-break `id asc`
- canonical direction order: `N, E, S, W` (no diagonals for MVP)

### 4.3 World minimum schema (frozen subset)
Required fields:
- `world.seed`
- `world.rng` (single authoritative RNG state)
- `world.turn` (integer)
- `world.floor_num` (1..7)
- `world.phase` (enum string)
- `world.run_state` (`"running"|"victory"|"death"`)
- `world.caps_hit` (bool)
- `world.player_id`
- `world.grid` (deterministic structure)
- `world.entities` (stable IDs; deterministic iteration rules)
- `world.deal_state` (offers + chosen deals + constraints)
- `world.stats` (downside metrics, see §7)

### 4.4 Deals interface (frozen)
- Deal metadata: `{id, sin, name, desc, tags, requires, offers_weight?}`
- Hooks: at minimum `on_apply(world)`, plus any phase-specific hooks via a single dispatch table (no ad-hoc calls).
- Offer generation: deterministic ordering + deterministic weights (if used).

### 4.5 Digest interface (frozen)
- `digest_version` (string constant, e.g. `"bargain.v1"`)
- `digest(world)` returns a stable string for comparisons and goldens.
- Serialization rules: stable key ordering; no raw table iteration order dependency.

---

## 5) Determinism & termination enforcement (sim-only)

### 5.1 RNG rule (hard)
Only `world.rng` may be used for sim randomness.

Forbidden in sim scope:
- `math.random`, time-based seeds, `os.time`, frame `dt`, engine globals
- iteration-order-dependent logic (`pairs()`/`next()` on gameplay-critical tables)

### 5.2 Iteration rule (hard)
Gameplay-critical collections must be:
- arrays with fixed append order, or
- sorted explicitly with deterministic comparator + tie-break.

### 5.3 Caps (terminal on breach)
Contract constants:
- `MAX_INTERNAL_TRANSITIONS = 64`
- `MAX_STEPS_PER_RUN = 5000`
- capped procgen attempts per floor, with deterministic fallback

On any cap trip:
- set `world.caps_hit = true`
- force terminal `world.run_state = "death"` (default)
- emit repro JSON (§9)

---

## 6) Test strategy (CI-first, contract-heavy)

### 6.1 Runner contract
Entry: `assets/scripts/tests/run_bargain_tests.lua`
- stable stdout
- on failure prints **exactly one** repro JSON line
- exit `0` on success; non-zero on any failure

### 6.2 Required suites (each gate owns at least one suite)
**Contracts & harness**
- `assets/scripts/tests/bargain/contracts_spec.lua`
  - schema validation, phase rules, invalid-input semantics, cap behavior, termination contract
- `assets/scripts/tests/bargain/determinism_static_spec.lua`
  - bans nondeterministic APIs + bans `pairs()` in sim-critical scopes (with explicit allowlist)
- `assets/scripts/tests/bargain/digest_spec.lua`
  - digest stability across reruns + digest versioning rules
- `assets/scripts/tests/bargain/repro_schema_spec.lua`
  - forced failure path validates “exactly one JSON line” + schema shape

**Core behavior**
- `assets/scripts/tests/bargain/sim_smoke_spec.lua`
  - tiny fixed map: move/attack loop terminates; digest stable
- `assets/scripts/tests/bargain/ai_spec.lua`
  - deterministic targeting + tie-breaks + action order

**Worldgen & visibility**
- `assets/scripts/tests/bargain/floors_spec.lua`
  - bounded seed list: reachability invariants + deterministic fallback on cap
- `assets/scripts/tests/bargain/fov_spec.lua`
  - golden visible-set tests on canonical maps

**Deals**
- `assets/scripts/tests/bargain/deals_loader_spec.lua`
  - exactly 21 deals, unique IDs, sins×3 coverage
- `assets/scripts/tests/bargain/deals_downside_spec.lua`
  - 21 rows; each asserts ≥1 downside metric flips (see §7)

**End-to-end determinism**
- `assets/scripts/tests/bargain/run_scripts_spec.lua`
  - scripted full runs + golden digests; double-run determinism; terminal outcome

### 6.3 Golden policy (minimize churn)
Goldens under `assets/scripts/tests/bargain/goldens/**`
- Golden updates must include:
  - updated golden file(s)
  - a 1-line rationale adjacent to the golden
  - proof requirement: two consecutive runs match for same `(seed, script_id)`

---

## 7) Deals catalog contract (stable IDs + downside metrics)

### 7.1 IDs and cardinality
- ID format: `<sin>.<index>` (e.g. `wrath.1`)
- Exactly `7 sins × 3 deals = 21`
- After Gate C is green: **append-only** (no renames; additions only beyond MVP)

### 7.2 Downside metrics (stored in `world.stats`, asserted by tests)
For each deal, compare two deterministic runs of the same script:
- baseline: never apply
- applied: apply at earliest legal moment

Assert ≥1 metric flips:
- `hp_lost_total`
- `turns_elapsed`
- `damage_dealt_total` and/or `damage_taken_total`
- `forced_actions_count` / `denied_actions_count`
- `visible_tiles_count` (FOV)
- `resources_spent_total` (if you introduce any resource)

---

## 8) Parallel workstreams (low-collision ownership)

### 8.1 Streams & owned paths
| Stream | Owns | Produces | Depends on |
|---|---|---|---|
| Integrator (I) | `assets/scripts/core/main.lua`, `assets/scripts/tests/run_bargain_tests.lua` | headless early-exit + runner wiring + repro emission | none |
| Core Sim (C) | `assets/scripts/bargain/sim/**` | `step()`, caps, invariants, event model | I contracts |
| Digest/Scripts (R) | `assets/scripts/bargain/sim/digest/**`, tests + `goldens/**` | digest + replay scripts + goldens | C schema |
| Floors/FOV (F/V) | `assets/scripts/bargain/floors/**`, `assets/scripts/bargain/fov/**` | procgen + FOV + invariants + goldens | C schema |
| Deals (D) | `assets/scripts/bargain/data/deals/**`, `assets/scripts/bargain/deals/**` | offer gen + apply hooks + 21 deals + downside metrics | C + R |
| Enemies/Boss (A) | `assets/scripts/bargain/enemies/**`, `assets/scripts/bargain/ai/**` | enemy templates + AI + boss + victory | C |
| UI Bridge (UI) | UI layer only | deal modal + HUD + victory/death screens -> inputs | C input API |

### 8.2 Merge discipline
1. Land **contracts + stubs + harness** first (tests green with stubbed behavior).
2. Each stream stays inside owned paths; only Integrator touches hot files.
3. Cross-stream changes require either:
   - additive interface extension + contract tests, or
   - an Integrator wiring PR that updates hot files.

---

## 9) Failure repro bundle (single JSON line)

### 9.1 Output contract
On any test failure or cap breach:
- print **exactly one** JSON object on a single stdout line
- exit non-zero

### 9.2 Minimum payload (must replay deterministically)
- `seed`, `script_id`, `floor_num`, `turn`, `phase`, `run_state`
- `last_input`, `pending_offer`
- `last_events` (<= 20; deterministic order)
- `digest`, `digest_version`
- `caps_hit` (bool)
- optional `world_snapshot_path` (only if deterministic serialization is guaranteed)

### 9.3 Snapshot rules (only if enabled)
- deterministic filename from `(seed, script_id, turn)`
- serializer enforces stable key ordering (no raw table iteration order)

### 9.4 Example repro line (shape only)
```json
{"seed":123,"script_id":"S1","floor_num":3,"turn":87,"phase":"ENEMY_ACTIONS","run_state":"death","last_input":{"type":"move","dx":1,"dy":0},"pending_offer":null,"last_events":[{"type":"damage","src":"e.goblin.2","dst":"p.1","amount":3}],"digest_version":"bargain.v1","digest":"...","caps_hit":false,"world_snapshot_path":null}
```

---

## 10) Milestones (each ends with Gate(s) proven CI-green)

### M0 — Harness + contracts (unblocks all streams)
Deliverables:
- Headless early-exit path (`RUN_BARGAIN_TESTS`) before any window init
- Test runner + repro JSON emission
- `contracts_spec.lua` + minimal `sim_smoke_spec.lua` green (even with sim stubs)
- `repro_schema_spec.lua` proves single-line JSON rule

Exit criteria:
- proof command passes
- dedicated test proves “no window init in headless mode”
- forced-failure test validates “exactly one JSON repro line”

### M1 — Core sim loop + caps + digest v1 baseline
Deliverables:
- deterministic `step()` loop with caps + terminal enforcement
- digest v1 + stable serialization rules
- determinism static checks wired to sim scope

Exit criteria:
- Gate B + Gate E pass on a bounded seed list
- `sim_smoke_spec.lua` covers move/attack/enemy act/terminal outcome
- `digest_spec.lua` proves same-case reruns match

### M2 — Floors + FOV invariants
Deliverables:
- procgen with reachability guarantee or deterministic fallback on cap
- FOV implementation + canonical goldens

Exit criteria:
- `floors_spec.lua` green on committed bounded seed list
- `fov_spec.lua` goldens green (and stable across double-run)

### M3 — Deals system + 21 deals + downside enforcement
Deliverables:
- offer generation at `floor_start` + `level_up`
- deal apply plumbing (hook dispatch)
- 21 deals with stable IDs + measurable downsides via `world.stats`

Exit criteria:
- Gate C + Gate D green
- `deals_loader_spec.lua`: 21 unique IDs, sins×3
- `deals_downside_spec.lua`: 21/21 flips ≥1 downside metric

### M4 — Enemies + boss + explicit victory/death
Deliverables:
- deterministic enemy templates + chase/attack AI
- boss + victory condition on floor 7

Exit criteria:
- scripted tests include at least one `victory` and one `death`
- `ai_spec.lua` asserts ordering + tie-breakers

### M5 — Minimal UI bridge (sim unchanged)
Deliverables:
- deal UI modal maps to `deal_choose` / `deal_skip`
- HUD + victory/death screen + restart

Exit criteria:
- manual smoke checklist on a known `(seed, script_id)`
- static scan/allowlist proves no sim logic leaks into UI scope

### M6 — Full-run scripts + determinism goldens
Deliverables:
- scripts `S1,S2,S3` (fixed inputs; each hits meaningful mechanics)
- golden digests for each `(seed, script_id)`

Exit criteria:
- Gate A + Gate B green across all cases (double-run + terminal)
- `run_scripts_spec.lua` green

---

## 11) Risk register (mitigations must be test-backed)
- Lua iteration nondeterminism → ordered iteration helpers + `determinism_static_spec.lua`
- Hidden randomness/time in UI/engine → headless suite never boots UI; static scan bans time/RNG in sim scopes
- Procgen infinite loops/unreachable stairs → attempt caps + invariants tests + deterministic fallback + repro payload
- “Downside is toothless” → downside metric flip required for every deal
- Golden churn → digest versioning + per-golden rationale + double-run proof requirement

---

## 12) Beads (bd) workflow integration (operational)
For each milestone, split into bead-sized units with a named exit test (suite + file). Each bead must:
1. BV triage what’s ready
2. Claim bead (set `in_progress`)
3. Implement + tests
4. Close bead + notify via Agent Mail (contracts touched, suites to rerun, golden changes)

Per-bead rules:
- Reserve owned paths (exclusive) before edits
- Land code + tests together
- Keep PRs atomic to one stream unless it’s Integrator wiring

Suggested bead breakdown (parallel-friendly):
- **M0-I1:** headless early-exit + “no window” test
- **M0-I2:** runner wiring + repro JSON schema validator test
- **M0-C1:** sim skeleton + `contracts_spec.lua` green with stubs
- **M1-C2:** caps + terminal enforcement + cap-repro test
- **M1-R1:** digest v1 + `digest_spec.lua`
- **M2-F1:** floor gen reachability + `floors_spec.lua` seed list
- **M2-V1:** FOV + `fov_spec.lua` goldens
- **M3-D1:** deals loader + catalog test
- **M3-D2:** downside metrics plumbing + downside test matrix
- **M4-A1:** AI determinism + `ai_spec.lua`
- **M4-A2:** boss + victory/death scripted cases
- **M5-UI1:** UI deal modal → input mapping (manual checklist)
- **M6-R2:** scripted runs + golden digests + double-run determinism assertions