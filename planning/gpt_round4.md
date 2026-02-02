# Review & Proposed Revisions — Demo Content Spec v3 Master Plan

This is a straight, engineering-focused review of the plan you provided, followed by concrete revisions that improve **robustness**, **determinism**, **performance**, **authoring safety**, and **player-facing clarity**.  
For every change below you get:

- **What** to change (architecture / feature / contract)
- **Why** it makes the project better (rationale + risk reduction)
- **How** to implement (practical notes)
- A **git-diff style patch** against the original plan text

> Scope note: I’m not rewriting the full plan end-to-end; instead, I’m proposing surgical plan changes that preserve your intent while removing failure modes and making the spec more scalable. If you apply every patch, you effectively get a v3.1 plan.

---

## Executive Summary — Biggest Risks in the Current Plan

1. **Float-time drift & timer ambiguity**  
   You store `t` as a float and express cooldowns/intervals as seconds. This will eventually cause edge-case “why did it proc a frame later” bugs (even on the same build), and it makes Tier B determinism much harder later.

2. **CommandStream still leaks float noise**  
   Capturing `aim`/`move` as raw numbers without a quantization rule makes replay determinism fragile across DPI/mouse sampling, camera transforms, and UI-to-world conversions.

3. **Event causality is hard to debug without a correlation ID**  
   You have `damage_id`, but there’s no general “proc/correlation id” that ties together: wand trigger → multiple hits → status applications → reaction → resulting DOT ticks.

4. **EventBus can runaway**  
   “Emit during dispatch is deferred” solves re-entrancy, but you still need **hard guards** to prevent infinite event cascades from blowing up the frame.

5. **Special-case event names create consistency risk**  
   Events like `player_hit_enemy` and `player_damaged` are easy to emit inconsistently across different attack types unless you strictly centralize emission in one place.

6. **Status mutation paths need stricter ownership**  
   If any system applies/decays statuses outside a single authoritative StatusEngine API, you’ll get “missing status events” or divergent trigger behavior.

7. **Determinism checks should locate the first divergence faster**  
   Event trace hashes are good, but the practical debugging loop improves massively if you also hash a quantized world-state snapshot and RNG stream states.

---

# Proposed Revisions (v3.1)

## Change 1 — Switch sim-time to integer ticks; compile seconds → frames

### What changes
- Treat **sim time as integer ticks** (`frame` already exists; use it as the authoritative time unit).
- Convert authored seconds fields (`cooldown_s`, `tick_interval`, `duration`, `decay.interval`, etc.) into **integer frame counts** at content compile time.
- Keep float seconds only as **derived** for UI/telemetry.

### Why it makes things better
- Eliminates float rounding edge cases in timers, cooldown comparisons, and “interval tick loops”.
- Makes determinism tooling and replay debugging cleaner (no epsilon noise).
- Creates a clean on-ramp for Tier B determinism later (you’re already mostly fixed-step).

### Implementation notes
- Add `Time.frames(seconds)` conversion function in the compiler using a **declared rounding policy**:
  - For cooldowns/timers: usually `ceil(seconds / sim_dt)` to avoid firing early.
  - For decay intervals: also `ceil`.
- Store both:
  - `*_frames` (authoritative)
  - `*_s` (optional, UI only)

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
-Event = {
-    type = "event_name",
-    frame = number,      -- sim frame number
-    seq = number,        -- per-frame sequence for deterministic ordering
-    t = number,          -- sim time (accumulated fixed-step time)
-    phase = string,      -- optional: system phase for trace/debug
-    payload = { ... }    -- event-specific data
-}
+Event = {
+    type = "event_name",
+    frame = integer,     -- sim tick; authoritative timebase
+    seq = integer,       -- per-frame sequence for deterministic ordering
+    t = number,          -- derived (frame * sim_dt), debug/UI only; excluded from trace hash
+    phase = string,      -- optional: system phase for trace/debug
+    payload = { ... }    -- event-specific data
+}
@@
-Define determinism tier up front to avoid false expectations:
+Define determinism tier up front to avoid false expectations:
@@
-- Tier A (required for v3): deterministic within the same engine build + same content_build + same replay_version
+- Tier A (required for v3): deterministic within the same engine build + same content_build + same replay_version
+  - Tier A requires integer-tick gameplay timing (cooldowns/intervals expressed in frames internally)
```

---

## Change 2 — Add an explicit “Determinism Contract” section with quantization rules

### What changes
Introduce a small, explicit contract specifying:
- **Quantization of replayed floats** (aim vectors, positions if recorded, etc.)
- **Physics query sorting requirements** (already implied, but make it explicit and testable)
- **Tie-breaking rules** (same-distance targets, etc.)

### Why it makes things better
- Determinism isn’t just “seed + dt”: it’s also “how do we compare/round floats?”.
- You prevent accidental regressions where someone changes camera math or mouse scaling and silently breaks replay stability.

### Implementation notes
- Quantize command inputs at record time (or normalize at consume time, but record-time is easier for debugging).
- Define a “deterministic float pack” (e.g., Q16.16 fixed-point) for trace/state hashing.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ## 1.1 Determinism Tier (explicit)
@@
 - **Tier B (nice-to-have later):** deterministic across engine builds (requires stricter floating-point/physics constraints)
+
+### 1.2 Determinism Contract (Tier A details)
+Tier A determinism requires the following additional rules:
+- **Input quantization:** all replayed command floats are quantized (e.g., Q16.16 or fixed 1/1024 units).
+- **Physics query ordering:** results from physics overlap/segment/raycast queries must be sorted by stable keys:
+  - primary: `target_eid`
+  - secondary tie-break: distance along sweep/raycast (quantized)
+- **Timer semantics:** all gameplay timing uses integer frames internally (cooldowns, durations, tick intervals).
+- **No hidden time sources:** do not use real-time clocks or render dt for gameplay decisions.
```

---

## Change 3 — Split “GameSim” from UI/render; make sim a pure consumer of commands

### What changes
- Introduce a clear boundary: `GameSim.step(frame_commands)` runs **only deterministic gameplay**.
- UI collects raw input → emits semantic commands into CommandStream.
- Replays bypass UI completely and feed commands directly.

### Why it makes things better
- Removes accidental non-determinism from UI states, focus, input sampling, and render-order quirks.
- Makes headless simulation and CI deterministic runs dramatically simpler.

### Implementation notes
- `main.lua` becomes a thin driver:
  - accumulate dt → run fixed steps → each step:
    - `commands = CommandStream.get_frame_commands()`
    - `GameSim.step(commands)`
- GameSim owns the “mandatory per-frame order” list (the plan already defines it; just enforce it in one place).

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 2.3 Update Order (single source of truth in main loop) — CRITICAL
@@
-0.5 CommandStream.begin_frame(frame); map raw input/UI → semantic commands; store in command buffer
+0.5 CommandStream.begin_frame(frame); UI maps raw input → semantic commands (outside sim)
+0.6 GameSim.step(CommandStream.get_frame_commands()) consumes commands (sim is UI-agnostic)
@@
-8.  UI (render-only)
+8.  UI (render-only, never mutates sim directly; only emits commands)
```

---

## Change 4 — Harden CommandStream: normalization, quantization, and schema versioning

### What changes
- Add a strict normalization step for every command:
  - clamp vectors
  - quantize floats
  - validate enums and indices
- Add `command_schema_version` included in replay metadata.
- Provide record/replay helpers (small “ReplayIO” module).

### Why it makes things better
- Prevents “same seed, same build, different mouse DPI” divergences.
- Makes replays resilient to small code changes in input mapping, while still failing fast on true incompatibilities.

### Implementation notes
- Normalize `aim` and `move` into either:
  - **unit direction + magnitude** (quantized)
  - or world-space target position (quantized)
- Favor storing **intent** not raw screen coordinates.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 2.5 Command Contract (NEW, replay-critical)
@@
 - `assets/scripts/core/command_stream.lua`
   - `CommandStream.begin_frame(frame)` — reset per-frame buffer
   - `CommandStream.push(cmd)` — assigns `(frame, seq)` and stores in per-frame buffer
   - `CommandStream.get_frame_commands()` — returns stable-ordered list (by seq)
+  - `CommandStream.normalize(cmd)` — clamps + quantizes numeric fields (Tier A determinism)
+  - dev-only: `CommandStream.validate(cmd)` strict schema validation
+
+Add:
+- `assets/scripts/core/replay_io.lua`
+  - serialize/deserialize replay metadata + per-frame command lists
+  - includes `command_schema_version`
@@
-cmd = { type="aim", x=number, y=number }
+cmd = { type="aim", x=number, y=number } -- quantized to fixed grid in normalize()
@@
-**Replay rule:** record CommandStream (plus run_seed + content_build + sim_dt + replay_version), not raw input device states.
+**Replay rule:** record normalized CommandStream (plus run_seed + content_build + sim_dt + replay_version + command_schema_version).
```

---

## Change 5 — Add “origin” to the Event envelope + an origin stack helper

### What changes
- Move `origin="skill"` from ad-hoc payload tagging into a **first-class envelope field**:
  - `origin = { domain="skill", id="SKILL_*", proc_id=... }`
- Add `EventBus.with_origin(origin, fn)` helper to reliably stamp all events from a system action.

### Why it makes things better
- Makes traces *readable* and diffable.
- Makes feedback-loop prevention systematic (SkillSystem can ignore any event where origin.domain == "skill").
- Enables better QA assertions (e.g., “no reaction triggers a reaction in the same proc chain”).

### Implementation notes
- Implement origin as a small table reused from a pool (or intern strings) to reduce GC in release builds.
- If you want maximum performance, store origin as:
  - `origin_domain_idx` (small int)
  - `origin_id_idx`
  - `proc_id` (int)

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 Event = {
     type = "event_name",
     frame = number,
     seq = number,
     t = number,
     phase = string,
+    origin = { domain=string, id=string, proc_id=integer } or nil,
     payload = { ... }
 }
@@
 - `EventBus.emit(type, payload)`
@@
-  - constructs `Event = { type, frame, seq, t, phase, payload }`
+  - constructs `Event = { type, frame, seq, t, phase, origin, payload }`
@@
+Add:
+- `EventBus.with_origin(origin, fn)` — pushes origin on a stack for nested calls; emits inherit current origin
```

---

## Change 6 — Introduce a universal `proc_id` (correlation id) for every effect chain

### What changes
- Add a monotonic `proc_id` generator (per run).
- Every wand trigger, skill proc, item proc, and reaction uses a proc_id.
- Damage instances can keep `damage_id`, but also include `proc_id` for chain correlation.

### Why it makes things better
- Debugging becomes fast: you can filter a trace down to “everything caused by proc 812”.
- You can implement robust proc guards (“no more than N reactions per proc chain”) without relying on frame-level limits only.
- Reduces false positives in determinism debugging (you see causality).

### Implementation notes
- Put generator in a `Proc` module:
  - `Proc.next("skill", skill_id, owner_eid)`
- Stamped into `Event.origin.proc_id`.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 2.2.3 Standard Payload Shapes
@@
 payload.damage = {
@@
-    damage_id = string,  -- unique per damage instance
+    damage_id = string,  -- unique per damage instance
+    proc_id = integer,   -- correlation id for the parent chain (wand/skill/item/reaction)
@@
 }
@@
 **Dev-Only Introspection Events (can be compiled out):**
@@
-- `skill_fired` — `{ skill_id, player_eid, reason = { ... } }`
+- `skill_fired` — `{ skill_id, player_eid, proc_id, reason = { ... } }`
```

---

## Change 7 — EventBus guardrails: max events per frame + safe flush

### What changes
- Add a per-frame **event limit** (dev-only hard fail; release soft cap + warning).
- Replace recursive dispatch with an explicit queue loop:
  - `while queue not empty do dispatch next end`
- Add `EventBus.flush()` used at the end of each phase (optional but helps localize bugs).

### Why it makes things better
- Prevents infinite cascades from locking the game/hanging CI.
- When something goes wrong, you get an actionable error pointing at the type+origin that exploded.

### Implementation notes
- Default `max_events_per_frame` could be 4096 in dev; 16384 in release with warnings.
- When exceeded: include most common event types and last origin in the crash report.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 - `EventBus.begin_frame(frame, t)`
   - resets `seq=0`
   - resets per-frame buffers (if used)
+  - resets `events_emitted=0`
@@
 - `EventBus.emit(type, payload)`
@@
   - increments `seq`
+  - increments `events_emitted`; if over `max_events_per_frame` -> fail fast (dev) / warn+drop (release)
@@
 - if called during dispatch: event is queued and dispatched after current event completes
+ - if called during dispatch: event is queued; dispatch uses an explicit queue loop (no recursion)
+
+Add:
+- `EventBus.flush()` — dispatch all deferred events now (dev asserts that flush points are deterministic)
```

---

## Change 8 — Consolidate “hit” and “damage” semantics; centralize emission in DamageSystem

### What changes
- Add a **canonical** `hit` event emitted by DamageSystem (not by individual weapons).
- Treat specialized events (`player_hit_enemy`, `player_damaged`) as:
  - either derived convenience events emitted *inside DamageSystem*, or
  - removed in favor of filters in Skill DSL.

### Why it makes things better
- You guarantee consistency across melee/projectiles/aura/reaction damage.
- You eliminate duplicated emission points (which cause subtle “some skills don’t trigger on aura hits” bugs).

### Implementation notes
- DamageSystem.apply should accept an optional `hit` payload:
  - position, knockback, tags
- DamageSystem emits events in a strict order:
  1. `hit`
  2. `damage_dealt`
  3. `damage_taken`
  4. `player_damaged` (if applicable)
  5. `enemy_killed` (if applicable)

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 #### 2.2.4 Canonical Events (envelope-only)
@@
-- `player_hit_enemy` — `{ source_eid, target_eid, hit = { ... } }`
+- `hit` — `{ source_eid, target_eid, hit = { ... } }` *(canonical; emitted by DamageSystem for all damage routes)*
+- `player_hit_enemy` — *(optional derived convenience event; emitted only inside DamageSystem if you keep it)*
@@
 ### 1.1 Melee Arc System + ACTION_MELEE_SWING
@@
-  - `EventBus.emit("player_hit_enemy", ...)`
-  - `DamageSystem.apply(...)`
+  - `DamageSystem.apply(...)` (passes hit data; DamageSystem emits `hit` and derived events)
```

---

## Change 9 — Use fixed-point integers for HP/damage internally (Tier A now, Tier B later)

### What changes
- Represent HP, damage, and additive modifiers as integers in a fixed scale:
  - e.g., `1.0` HP == `1000` milli-HP.
- Expose float only in UI.

### Why it makes things better
- Removes the biggest class of cross-platform FP inconsistencies.
- Prevents “0.30000000004” style issues in stacking modifiers.
- Makes balance math more stable and predictable.

### Implementation notes
- Choose a scale (100 or 1000). For action-RPG style numbers, `100` is usually enough; `1000` if you want finer-grain DOTs.
- Keep percentages as rational operations:
  - `final = base + (base * pct // 10000)` (where pct is in basis points)

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 1.0 DamageSystem (NEW foundation, pipeline architecture)
@@
-- builds an immutable `DamageContext` for deterministic modifiers
+- builds an immutable `DamageContext` for deterministic modifiers
+  - `amount` stored as fixed-point integer (e.g., milli-damage) internally; UI converts to float
@@
 payload.damage = {
-    amount = number,
+    amount = integer,    -- fixed-point scaled damage (authoritative)
```

---

## Change 10 — Make StatusEngine the *only* place that mutates statuses (transaction + delta)

### What changes
- Add StatusEngine API that is the single authoritative mutation path:
  - `apply_status(target_eid, status_id, delta_stacks, source_eid, reason)`
  - `set_status_stacks(...)`
  - `remove_status(...)`
- Return a `StatusDelta` describing the change (old/new, did_apply, did_remove).
- Emit events only inside StatusEngine.

### Why it makes things better
- Prevents missing or duplicated `status_*` events.
- Makes decay/cleanse/expire consistent and traceable.
- Simplifies ReactionSystem and Skills (they observe events, never mutate ad hoc).

### Implementation notes
- Store statuses in a deterministic structure:
  - array by status `idx` (not hash map), or map + sorted iteration helper
- Decay step uses integer frames, not seconds.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 1.2 Status Stack Decay (centralized in StatusEngine)
@@
-Implement decay for `scorch`, `freeze`, `doom`, `charge`, `inflame`:
+Implement decay for `scorch`, `freeze`, `doom`, `charge`, `inflame` inside StatusEngine only:
@@
-- accumulator (`decayTimer += dt`) with bounded tick loops for large `dt`
+- integer-frame timer (`decay_timer_frames += 1`) with bounded tick loops
@@
-**Rule:** Content authors never call raw `signal.connect` / timer APIs directly; they go through Lifecycle.
+**Rule:** Systems and content never write status tables directly; they only call StatusEngine APIs.
```

---

## Change 11 — Improve RNG discipline: track stream state + draw counts; add “RNG audit” tooling

### What changes
- In dev builds, track per-stream:
  - draw_count
  - current internal state hash
- On determinism failure, print the first stream that diverged.

### Why it makes things better
- Most determinism bugs are “someone used the wrong RNG stream or drew an extra random”.  
  This makes that bug immediately obvious.

### Implementation notes
- Implement `rng:checkpoint()` returning a small hash.
- Record stream checkpoints at frame boundaries in trace metadata (dev-only).

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 2.6 RNG Contract (NEW, determinism-critical)
@@
 - `assets/scripts/core/rng.lua`
   - implements deterministic algorithm (PCG32 or xoroshiro128+)
   - **forbid `math.random` in gameplay code** (dev-only runtime check via global hook)
+  - dev-only: `rng.draw_count` + `rng:checkpoint_hash()` for determinism audits
@@
 **Determinism smoke (dev-only):**
 - fixed seed → run N sim frames headless → checksum key counters (kills, damage totals, gold)
+ - additionally assert per-stream `draw_count` and `checkpoint_hash` match between record and replay
```

---

## Change 12 — SkillSystem scaling: build a trigger index and only evaluate candidate skills

### What changes
- Compile triggers into:
  - predicate function
  - list of required event types
- Build an index: `event_type -> skills_that_reference_it`.
- At end_frame, only evaluate:
  - skills that have *any* required event observed in the window.

### Why it makes things better
- 32 skills today is fine; 200 later becomes a per-frame cost. Indexing costs little and scales.
- Makes “explain why blocked” and “explain why didn’t fire” tooling more efficient (you know which skills were even considered).

### Implementation notes
- During compilation, compute `skill.required_events`.
- During frame capture, keep a `seen_event_types` bitset or boolean map.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 3.2 Multi-Trigger Resolution (same sim frame)
@@
 - `SkillSystem.end_frame()`:
+ - `SkillSystem.end_frame()`:
   1. build frame snapshot (counts + first/last per type + per-element tallies)
-  2. compute which skills fire from snapshot (no execution yet)
+  2. compute candidate skills via `TriggerIndex` (event_type -> skills); evaluate only candidates
   3. execute fired skills in deterministic order:
      - by `priority` then `skillId`
```

---

## Change 13 — Make feedback-loop prevention systematic: “domains to ignore” vs ad-hoc origin strings

### What changes
- SkillSystem snapshot excludes events based on envelope origin:
  - `ignore_origin_domains = { "skill" }` by default
- ReactionSystem can similarly ignore:
  - `{ "reaction" }` to avoid recursion
- Items/forms/wands can opt into ignore lists for their own logic if needed.

### Why it makes things better
- It’s robust: nobody forgets to manually tag payload origin.
- It’s consistent: all systems use the same mechanism.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
-4. events emitted during skill execution are tagged with `origin="skill"`
-   - snapshot that triggered evaluation excludes `origin="skill"` events (prevents feedback loops)
+4. events emitted during skill execution inherit `Event.origin = { domain="skill", ... }`
+   - snapshot that triggered evaluation excludes events where `origin.domain` is in `ignore_origin_domains` (default: {"skill"})
```

---

## Change 14 — Add a deterministic “Scheduler” for delayed actions (replaces ad-hoc timers)

### What changes
Introduce a tiny deterministic scheduler for sim-tick callbacks:
- `Scheduler.after_frames(n, fn, owner_eid, name/domain)`
- Implemented using integer frames and Lifecycle-managed handles.

### Why it makes things better
- Lets content implement “after 0.25s explode” without relying on engine timers (which often use real time or have drift).
- Makes replay determinism much easier (all timing decisions occur on integer ticks).

### Implementation notes
- Use a min-heap keyed by `due_frame`, with tie-break by `insert_seq`.
- Scheduler runs in a defined phase (e.g., `cleanup` or `combat` depending on semantics).

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 2.4 Effect Lifecycle Contract (required for reliability)
@@
 - Content authors never call raw `signal.connect` / timer APIs directly; they go through Lifecycle.
+ - Content authors never call raw `signal.connect` / timer APIs directly; they go through Lifecycle.
+ - Prefer deterministic `Scheduler.after_frames()` over engine timers for gameplay.
+
+Add:
+- `assets/scripts/core/scheduler.lua` — deterministic tick scheduler integrated with Lifecycle
```

---

## Change 15 — CardPipeline: compile to an opcode list to reduce GC and improve determinism testing

### What changes
- Instead of compiling to a nested graph of closures, compile to an **array of opcodes**:
  - `{ op="select_target", ... }`
  - `{ op="apply_modifier", id=... }`
  - `{ op="action", id=... }`
- Execution is a tight loop.

### Why it makes things better
- Fewer allocations per trigger → less GC stutter.
- Easier to hash/diff the compiled plan (your “IR snapshot” becomes trivial).
- A big win if wands trigger frequently (distance triggers, auras, rapid actions).

### Implementation notes
- You can still keep the current IR; just add a final lowering pass to opcodes.
- `deck_hash` caching becomes even more valuable (opcodes are immutable arrays).

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 **CardPipeline determinism requirements:**
@@
-- pipeline emits IR snapshot (dev-only) for diff tests
+- pipeline emits IR snapshot (dev-only) for diff tests
+- pipeline lowers IR to immutable opcode list (release path) to minimize per-trigger allocations
```

---

## Change 16 — Aura tick staggering: derive phase from eid + aura_id (no manual phase field)

### What changes
- Instead of storing a manually assigned `phase`, compute it:
  - `phase = hash(owner_eid, aura_id) % interval_frames`
- That ensures stable spreading and no “all auras tick same frame” spikes.

### Why it makes things better
- Deterministic and automatic.
- Reduces authoring burden and makes performance behavior consistent.

### Implementation notes
- Use the same hash combiner you already plan for seeds.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 **Perf + fairness constraints:**
-- tick staggering: each aura has `phase` so not all auras tick the same sim frame
+- tick staggering: compute `phase_offset` deterministically: `hash(owner_eid, aura_id) % interval_frames`
```

---

## Change 17 — ReactionSystem: proc-chain guards (stronger than per-frame only)

### What changes
- Keep per-frame guards, but also add per-`proc_id` limits:
  - e.g., max 1 reaction chain per proc_id per target
- Tag reaction-emitted events with `origin.domain="reaction"` and include `proc_id`.

### Why it makes things better
- Prevents pathological loops that can happen across multiple frames (especially with DOT interactions).
- Debugging becomes very clear in traces.

### Implementation notes
- Track `(target_eid, proc_id, reaction_id)` in a small per-frame/per-window cache.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 **Proc guards (deterministic safety):**
 - `max_reactions_per_target_per_frame` (default 1–2)
 - per-reaction `cooldown_frames` (default 1–10)
+- per-proc guard: at most 1 trigger of `(reaction_id)` per `(target_eid, proc_id)` chain
```

---

## Change 18 — ContentRegistry build hash: make it reproducible and explainable

### What changes
- Define build hash inputs explicitly:
  - sorted list of `(content_type, id, stable_fields_hash)`
  - schema_version
  - sim_dt config
  - card_pipeline_version
- Store per-content `content_hash` for “what changed?” diagnostics.

### Why it makes things better
- Prevents “hash changed but why?” confusion.
- Makes it safer to invalidate cached plans.
- Makes replay invalidation messages more actionable (“skill FIREBALL changed”).

### Implementation notes
- Hash should exclude purely cosmetic fields if you want cosmetic-only changes not to invalidate replays; or keep strict (your call). If strict, document it.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 - emits `content_build = { schema_version, build_hash, id_maps, sim_dt, engine_build }`
+ - emits `content_build = { schema_version, build_hash, id_maps, sim_dt, engine_build, per_type_hashes, per_id_hashes }`
+ - build_hash is reproducible:
+   - computed from sorted (type,id) plus a stable hash of deterministic fields
```

---

## Change 19 — Add “Stable iteration helpers” as a first-class module

### What changes
Introduce `assets/scripts/core/stable.lua`:
- `Stable.sort_eids(list)`
- `Stable.iter_map_sorted(map, key_fn)` (dev-only or used sparingly)
- `Stable.assert_sorted(list, key_fn)` (dev-only)

### Why it makes things better
- Your plan relies heavily on “sort before applying”. A helper avoids copy-paste bugs and makes code review easier.
- Central point to add instrumentation later (e.g., count how often you sort large lists).

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ### 2.3.2 Stable iteration rule (critical in Lua)
@@
 Any time gameplay applies effects to a set/map of entities, order MUST be deterministic:
 - sort by stable `eid` or registry `idx`, OR
 - accumulate into array then sort before applying.
+
+Add:
+- `assets/scripts/core/stable.lua` helper utilities for deterministic ordering + dev assertions
```

---

## Change 20 — Determinism checks: add world-state hash alongside event trace hash

### What changes
- In addition to event trace hashing, compute a compact **WorldStateHash** per frame:
  - sorted entities: `(eid, kind, hp, position_quantized, active_status_stacks, ... )`
- Store world hash in trace log.

### Why it makes things better
- Event traces can miss divergence causes when:
  - events are equal but some state drifted due to physics ordering or rounding
- World hash lets you binary-search divergence quickly by frame.

### Implementation notes
- Quantize positions (e.g., 1/256 units) to avoid float noise.
- Keep the world hash limited to determinism-critical state.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 **Event trace hash spec:**
@@
 - exclude non-deterministic/visual fields (positions if float noise is expected)
+
+**World-state hash (dev-only, HIGH VALUE):**
+- per frame, hash a quantized snapshot of critical sim state:
+  - sorted `(eid, kind, hp_fixed, pos_qx, pos_qy, status_stacks_by_idx, active_form_id, ...)`
+- trace_diff prints the first frame where world hash diverges, then shows event mismatch context
```

---

## Change 21 — Replay validation messages: make failures actionable

### What changes
When failing replay compatibility, print:
- what mismatched (build hash, sim_dt, pipeline_version, command_schema_version)
- and the *first differing frame* (if you attempt to run anyway in dev mode)

### Why it makes things better
- Saves time. Devs don’t want “replay invalid” — they want “why”.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 **Replay format versioning:**
@@
 - replay invalid if `content_build.build_hash` mismatches (fail fast with message)
 - replay invalid if `sim_dt` or `max_sim_steps_per_render` mismatch (fail fast with message)
+ - failure messages must include which field mismatched + both values + remediation hint (record new replay / switch branch)
+ - dev-only: allow "attempt run anyway" to compute first divergent frame hash for debugging
```

---

## Change 22 — Economy: pick a gold sink now (don’t defer the decision)

### What changes
Select the gold sink **in the plan** to avoid a late-stage design stall.  
Recommendation for v3 scope: **Card Removal Service** (lowest systemic coupling, biggest immediate benefit).

### Why it makes things better
- “Choose one implementation” sounds easy, but in practice it delays UI and shop plumbing decisions.
- Card removal is easy to implement deterministically and adds meaningful agency.

### Implementation notes
- Deterministic UI: player selects wand slot + card index (sorted by deck order).
- Removal should update `deck_hash` and recompile exec plan.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 - **add minimal gold sink (choose one implementation):**
-  - **Card Removal Service:** remove 1 card from a chosen wand deck (cost scales, e.g., 15g → 25g → 40g)
-  - **Wand Polish:** small permanent stat bump on a chosen wand (tiered, capped at 3 upgrades per wand)
-  - *(prevents "reroll until perfect" degenerate strategy)*
+ - **Gold sink (v3 choice): Card Removal Service**
+   - remove 1 card from a chosen wand deck (cost scales: 15g → 25g → 40g)
+   - deterministic selection UI (choose wand slot + card index)
+   - updates `deck_hash` and recompiles exec plan
+   - *(prevents "reroll until perfect" degenerate strategy)*
```

---

## Change 23 — Add an end-of-run “Run Summary” screen (player value + QA value)

### What changes
Add a lightweight summary UI:
- seed
- selected god/class
- total damage dealt/taken
- kills
- most-procced skill/item
- time survived / waves cleared

### Why it makes things better
- Player-facing: makes the demo feel “complete” and shareable.
- Dev-facing: gives you quick sanity metrics for balance/determinism smoke tests.

### Implementation notes
- All metrics already exist or can be accumulated deterministically in one place (e.g., `RunStats`).

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 ## 1) Goals & Deliverables
@@
 - **UX:** Codex UI (skills/cards/items/statuses/forms) + surfaced run_seed for sharing/debug
+ - **UX:** End-of-run Run Summary (seed + loadout + key stats) for player feedback and QA
```

---

## Change 24 — CI determinism gate: add a “fuzz replay” test (small but powerful)

### What changes
- Add a CI test that generates a pseudo-random (seeded) command stream under constraints (move/aim/trigger).
- Record it once, replay it twice, assert hashes match.

### Why it makes things better
- Catches determinism regressions that golden replay doesn’t cover (because golden replay is only one path).
- Still deterministic because the command generator itself is seeded and constrained.

### Implementation notes
- Keep it short (e.g., 300–600 frames) and headless.

### Patch
```diff
diff --git a/MASTER_IMPLEMENTATION_PLAN.md b/MASTER_IMPLEMENTATION_PLAN.md
--- a/MASTER_IMPLEMENTATION_PLAN.md
+++ b/MASTER_IMPLEMENTATION_PLAN.md
@@
 - Add **"golden replay" gate** (dev-only OK for v3): at least 1 short replay must pass determinism checks on CI.
+ - Add **"fuzz replay" gate** (dev-only OK for v3): generate a seeded command stream under constraints; record+replay must match hashes.
```

---

# Recommended Priority Order (If Time Is Tight)

If you can’t do everything, do these first because they eliminate the most expensive failure modes:

1. **Change 1 (integer ticks)**
2. **Change 4 (CommandStream quantization + schema version)**
3. **Change 5–7 (Event origin + proc_id + EventBus guardrails)**
4. **Change 10 (StatusEngine is authoritative)**
5. **Change 20 (WorldStateHash)**
6. **Change 22 (pick gold sink)**
7. Everything else

---

# Notes on Compatibility With Your Current v3 Plan

- None of these changes invalidate your multi-agent decomposition; they mostly strengthen cross-module contracts.
- These changes reduce the risk that Agent A/C/D implement content systems that *almost* work but later fail determinism CI for subtle reasons.

---

# Appendix — Quick “Diff Pack” (single combined patch)

If you prefer a single patch for the plan, you can combine the hunks above. I kept them separated per change so you can apply selectively.

