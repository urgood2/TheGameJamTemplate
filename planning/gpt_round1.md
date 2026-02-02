# Demo Content Spec v3 — Architecture & Feature Revisions (with Git-Diff Hunks)

This document contains proposed revisions to the **Master Implementation Plan — Demo Content Spec v3** to make the project more **robust/reliable**, **deterministic**, **performant**, and **easier to extend and debug**.

Each proposed change includes:
- A **rationale** (why it improves the project)
- A **git-diff style hunk** showing changes versus the original plan

---

## Executive Summary: What to Fix First

The plan is structurally solid (phases, ownership, gates). The primary risk areas are:

1. **Simulation ordering is wrong for auras** (aura damage occurs after `SkillSystem.end_frame()`, so same-frame multi-triggers won't see aura events).
2. **Event payload contracts are underspecified** (will cause subsystem mismatches and nil-field bugs).
3. **Hook lifecycle isn't centralized** (wands/items/forms will leak handlers/timers unless enforced).
4. **Multi-trigger semantics are under-defined** (AND/OR/counting/recursion feedback loops).
5. **Shop inventory generation is conflated with loot** (Stage 3 mentions elite drops inside shop generation).

---

## Change 1 — Add a Content Registry Compiler + Schema Versioning + Numeric Indices

### Why this makes it better
Splitting data into modules avoids merge conflicts, but doesn't address:
- Typos becoming runtime bugs
- Slow hot-path lookups (string keys everywhere)
- Validation being an optional, bolt-on step

A **ContentRegistry compiler** provides:
- Reference linking (wand → cards, starter loadout → items, etc.)
- Stable integer `idx` for runtime arrays (performance)
- Hard fail-fast boot if content is invalid (reliability)

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 ## 1) Goals & Deliverables
 Ship the complete Demo Content Spec v3 as a cohesive, data-driven feature set:
@@
 - **Economy/Progression:** skill points by level + stage-based shop inventory (equipment → wands → artifacts)
+- **Engineering:** compiled content registry + deterministic simulation hooks (seeded RNG, replay/debug ready)
 
 ---
 
 ## 2) Canonical Contracts (Naming, IDs, Events, Update Order)
+
+### 2.0 Content Registry + Schema Versioning (new)
+All data modules (skills/cards/wands/items/statuses/avatars) declare `schema_version = 3` and are loaded through a single compiler:
+- `assets/scripts/core/content_registry.lua`
+  - builds `{ list, by_id, id_to_idx }` per content type
+  - assigns stable integer `idx` for hot-path lookups (arrays), while preserving string IDs for UI/save/debug
+  - performs reference linking (wand templates → card defs, starter loadouts → items, etc.)
+  - hard-fails with actionable errors (no silent nil fall-through)
+- Centralize authored ID strings in one place for code usage:
+  - `assets/scripts/core/ids.lua` (elements, events, status IDs, form IDs, equipment slots, tiers)
 
 ### 2.1 Canonical IDs & Naming
+- IDs are string keys in data/UI, but runtime systems should prefer registry indices (`idx`) once content is compiled.
 - **Elements:** `fire`, `ice`, `lightning`, `void`, `physical`
@@
 ### 5.1 Automated Validation (dev-only script)
 Add a lightweight validator that asserts:
 - Unique IDs across skills/cards/wands/items/statuses
 - All references exist (starter cards, starter gear, form status IDs, shop wand IDs)
 - No missing required fields (e.g., `mana_cost`, `type`, `element` where applicable)
+ - Registry compilation succeeds (no dangling references, no duplicate IDs, no invalid trigger names)
```

---

## Change 2 — Formalize an Event “Envelope” + Stop Passing Live Entity Objects

### Why this makes it better
Passing raw entity tables and vague `damageInfo` shapes will inevitably cause:
- Subsystems expecting different fields
- Handlers holding references to despawned entities
- Unreproducible ordering bugs

Fix by:
- Emitting a stable **event envelope** (`frame`, `seq`, `type`, `payload`)
- Passing **entity IDs/handles** (not object tables)
- Standardizing damage/status payload shapes

Also unlocks:
- deterministic ordering
- replay/event trace logging
- better profiling and debugging

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 ### 2.2 Event Contract (SkillSystem + items depend on this)
 Define and emit a stable set of gameplay events (via existing `signal` system or a thin adapter layer). Payloads are consistent across codebase:
-- `player_hit_enemy(player, enemy, damageInfo)`
-- `damage_dealt(source, target, amount, element, damageInfo)`
-- `enemy_killed(enemy, killer, killInfo)`
-- `player_damaged(player, amount, source, damageInfo)`
-- `status_applied(target, statusId, newStacks, source)`
-- `status_stack_changed(target, statusId, newStacks, oldStacks, source)`
+- All events use a shared envelope:
+  - `Event = { type, frame, seq, t, payload }`
+  - `source_eid` / `target_eid` are stable entity IDs (not live tables)
+  - `payload.damage = { amount, element, is_dot, is_crit, tags[], damage_id, source_kind }`
+  - `payload.status = { id, new_stacks, old_stacks, source_eid }`
+  - EventBus guarantees deterministic per-frame ordering by `seq`
+
+- Canonical events:
+  - `player_hit_enemy(payload)`  -- payload: { player_eid, enemy_eid, hit = { ... } }
+  - `damage_dealt(payload)`      -- payload: { source_eid, target_eid, damage = { ... } }
+  - `enemy_killed(payload)`      -- payload: { enemy_eid, killer_eid, kill = { ... } }
+  - `player_damaged(payload)`    -- payload: { player_eid, source_eid, damage = { ... } }
+  - `status_applied(payload)`    -- payload: { target_eid, status = { ... } }
+  - `status_stack_changed(payload)`
 - `wave_start(waveIndex)`
 - `frame_end(frameNumber)`
 - `form_activated(entity, formId)`
 - `form_expired(entity, formId)`
+
+Optional (dev-only) introspection events (high value for debugging/balance, can be compiled out):
+- `wand_triggered(payload)`      -- { wand_id, owner_eid, trigger_type }
+- `skill_fired(payload)`         -- { skill_id, player_eid, reason = { ... } }
+- `item_procced(payload)`        -- { item_id, owner_eid, reason = { ... } }
```

---

## Change 3 — Fix Update Order so Aura Damage Counts in Same-Frame Multi-Triggers

### Why this makes it better
Current order calls `AuraSystem.update(dt)` **after** `SkillSystem.end_frame()`.
Result: aura-caused `damage_dealt/status_*` events won’t be visible to same-frame multi-trigger skills.

Fix: ensure **any gameplay-causing system runs before `end_frame()`**.

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 ### 2.3 Update Order (single source of truth in main loop)
 Wire the runtime to guarantee deterministic behavior:
-1. Combat resolution (including status ticking/decay)
-2. Emit combat events (`*_hit_*`, `damage_dealt`, `enemy_killed`, etc.)
-3. Skill event capture (SkillSystem listeners append to per-frame buffer)
-4. **Exactly once per frame:** `SkillSystem.end_frame()`
-5. `AuraSystem.update(dt)`
-6. UI
+0. Begin-frame: increment `frame`, reset per-frame buffers, `EventBus.seq = 0`
+1. Movement/physics integration (produces collisions/overlaps but does not apply damage yet)
+2. TriggerSystem update (distance traveled / stand still / timers) -> may enqueue wand triggers
+3. Combat resolution (melee arcs, projectiles, queued wand actions)
+4. Status tick/decay + Aura ticks (must occur BEFORE SkillSystem.end_frame)
+5. Skill event capture happens via EventBus listeners during steps 3–4
+6. **Exactly once per frame:** `SkillSystem.end_frame()` (consumes the frame’s EventBus buffer)
+7. Cleanup (despawn, unregister hooks tied to dead entities, end-of-frame assertions)
+8. UI
+
+Invariant: any system that can cause `damage_dealt`, `status_*`, `enemy_killed` MUST run before step 6.
```

---

## Change 4 — Introduce a Single Hook/Timer Lifecycle Pattern (Stop Leaking Handlers)

### Why this makes it better
Relying on each content author to always unregister timers/signals is how you get:
- effects that persist after unequip/death
- stacking bugs that never clear
- subtle performance degradation over multiple runs

Enforce a single pattern:
- `Lifecycle.bind(owner_eid, handle)`
- Cleanup auto-runs on owner death/despawn/unequip
- No raw `signal.connect` or ad-hoc timer usage in content

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 ## 2) Canonical Contracts (Naming, IDs, Events, Update Order)
@@
+### 2.4 Effect Lifecycle Contract (new; required for reliability)
+All passives/triggers (skills, artifacts, equipment, wand triggers, forms) must register via a single lifecycle manager:
+- `assets/scripts/core/lifecycle.lua`
+  - `Lifecycle.bind(owner_eid, handle)` tracks subscriptions/timers/resources
+  - `Lifecycle.cleanup_owner(owner_eid)` runs automatically on death/despawn/unequip
+  - prevents double-register, supports idempotent re-grant
+Rule: content authors never call raw `signal.connect` / timer APIs directly; they go through Lifecycle.
+
@@
 **6.3 Findable (Shop) Wands (6) + Trigger Types**
@@
-- Implement/extend trigger registration in the wand system (with proper unregister on unequip).
+- Implement/extend trigger registration in the wand system using Lifecycle handles (no raw connects/timers).
@@
 **7.1 Artifacts (15 across 3 tiers)**
@@
-- Require every artifact effect to be:
-  - stat-mod based OR event-hook based with explicit register/unregister
+- Require every artifact effect to be:
+  - stat-mod based OR event-hook based registered through Lifecycle (auto-cleaned)
@@
 **7.2 Equipment (12 across 3 slots)**
@@
-- Ensure equipment system cleanly applies/removes stat mods and hooks.
+- Ensure equipment system applies stat mods and registers any hooks through Lifecycle (auto-cleaned).
```

---

## Change 5 — Define Multi-Trigger Semantics Properly (AND/OR/COUNT + Recursion Rules)

### Why this makes it better
Current spec doesn’t define:
- how to handle multiple occurrences of an event in one frame
- whether multi-trigger means AND vs OR
- whether skill-emitted events can satisfy triggers same-frame (feedback loops)

Proposed:
- a small trigger DSL: `all`, `any`, `count` + optional filters
- 2-phase `end_frame()` (decide → execute)
- events emitted during skill execution default to **next frame** unless explicitly allowed

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 **3.2 Multi-Trigger Resolution (same frame)**
 - Add per-frame event buffer:
   - `SkillSystem.on_event(eventType, eventData)` stores events
-  - `SkillSystem.end_frame()` builds index and resolves multi-trigger skills once per frame
+  - `SkillSystem.end_frame()`:
+    1) builds an indexed frame snapshot (counts + last/first events per type + per-element tallies)
+    2) computes which skills fire from that snapshot (no execution yet)
+    3) executes fired skills in deterministic order (by `priority`, then `skillId`)
+    4) events emitted during skill execution are queued for NEXT frame by default (prevents feedback loops)
 - Ensure `end_frame()` is called exactly once from main loop (Phase 2/0 wiring)
@@
 ## Phase 4 — Skills Content (32 skills)
@@
 - Each skill defines:
@@
-  - `triggers` (string or array) and `execute(player, eventData)`
+  - `triggers` DSL (explicit semantics):
+    - `triggers = { all = {...}, any = {...}, count = { event="damage_dealt", n=3, filter={element="fire"} } }`
+    - optional `filter = { element, status_id, source_kind, is_dot, tags[] }`
+  - `execute(player, frameSnapshot)` (frameSnapshot includes tallies + representative events)
```

---

## Change 6 — Unify Statuses, Forms, and Reactions Under One Definition Model

### Why this makes it better
To keep content authors from inventing one-off stacking/refresh rules, define status behavior centrally:
- stacking rules (`max_stacks`, refresh vs replace)
- decay (`interval`, `stacks_per_tick`)
- tags used for immunities

Add a small **ReactionSystem** (2–3 reactions total) for big gameplay payoff without lots of new content:
- freeze + heavy physical hit → shatter bonus damage
- charge + lightning damage → overload extra tick
- doom at max stacks → detonate

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 ### 2.1 Canonical IDs & Naming
@@
-- **Statuses (stacks with decay):** `scorch`, `freeze`, `charge`, `doom`, `inflame`
+- **Statuses (stacking model):** `scorch`, `freeze`, `charge`, `doom`, `inflame`
+  - Each status definition includes: `max_stacks`, `stack_mode` (add/refresh/replace), `decay{interval, stacks_per_tick}`, `tags[]`
 - **Forms (timed):** `fireform`, `iceform`, `stormform`, `voidform`
@@
 **5.1 Form Status Definitions**
@@
-  - each has: `duration` (30–60s), `stat_mods`, `aura{radius, tick_interval, effects[]}`, `visuals`, `decay_immune=true`
+  - each has: `type="buff"`, `duration` (30–60s), `stat_mods`, `aura{radius, tick_interval, effects[]}`, `visuals`, `immunities{ status_tags[] }`
   - `on_apply` emits `form_activated`; `on_expire/on_remove` emits `form_expired`
+
+**5.4 ReactionSystem (new; small scope, big payoff)**
+- Add `assets/scripts/combat/reaction_system.lua`:
+  - listens to `status_applied`, `status_stack_changed`, `damage_dealt`
+  - applies a small set of data-driven reactions (2–3 total for v3)
+  - emits a `reaction_triggered` dev-only event for debugging/balance
```

---

## Change 7 — Precompile Wands/Card Pipelines at Equip-Time (Performance + Determinism)

### Why this makes it better
If modifier/action pipelines are re-evaluated every trigger:
- you’ll get CPU spikes with fork/pierce/chain etc.
- you’ll risk nondeterminism from table iteration order
- debugging order becomes hard

Instead:
- compile `wand.exec_plan` on equip/deck change
- runtime triggers simply execute the plan

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 - **Agent D — Cards + Wands Content**
@@
-  - `assets/scripts/core/card_eval_order_test.lua`
+  - `assets/scripts/core/card_pipeline.lua` (new: compile cards -> execution plan)
+  - `assets/scripts/core/card_eval_order_test.lua`
@@
 **6.1 Modifier Cards (12)**
@@
 - Validate stacking behavior via `assets/scripts/core/card_eval_order_test.lua`
+ - Validate compile output determinism via `CardPipeline.compile(wand)` snapshots
@@
 **6.3 Findable (Shop) Wands (6) + Trigger Types**
@@
-- Implement/extend trigger registration in the wand system (with proper unregister on unequip).
+- Wand runtime uses compiled plans:
+  - on equip / deck change: `CardPipeline.compile(wand)` -> `wand.exec_plan`
+  - on trigger: execute `wand.exec_plan` (no per-trigger rebuild)
```

---

## Change 8 — Split Shop Inventory From Loot Drops + Add Seeded Generation + Reroll

### Why this makes it better
Stage 3 currently mixes “shop inventory generation” with “elite drops.” That leads to confusion and bugs.

Also: balancing shops without deterministic seeds is painful.

Proposed:
- shops: deterministic rolls from `run_seed + stage + shopVisitIndex`
- loot: separate table (elite artifact drop chance)
- add one **reroll** option per shop for agency (gold sink)

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 **8.2 Shop Stage Timeline**
-- Implement stage-based shop inventory generation:
+- Implement stage-based shop inventory generation (SHOP ONLY; loot handled separately):
   - Stage 1: equipment only
   - Stage 2: equipment + 1–2 wands
-  - Stage 3: equipment + 1–2 wands + artifact (elite drop / chance)
-  - Stage 4: equipment + 1–2 wands + artifact (guaranteed)
+  - Stage 3: equipment + 1–2 wands
+  - Stage 4: equipment + 1–2 wands + 1 artifact (guaranteed)
   - Stage 5: boss (no shop)
-- Enforce: starter wands never appear for sale; shop wands priced 25–50g.
+- Loot table (separate from shop):
+  - Elite enemies can drop an artifact at Stage 3+ (chance-based)
+
+- Deterministic generation:
+  - shop stock rolls use `run_seed + stageIndex + shopVisitIndex` (replayable/debuggable)
+- Player agency:
+  - add 1 reroll option per shop (cost scales, e.g. 10g then 20g)
+
+Enforce: starter wands never appear for sale; shop wands priced 25–50g.
```

---

## Change 9 — Add Determinism + Debugging as First-Class QA (Replay, Event Trace, Leak Checks)

### Why this makes it better
Manual smoke is necessary but not sufficient. You want:
- reproducible bug reports (seed + trace)
- leak detection (subscriptions/timers growth)
- nondeterminism detection (checksum/counters drift)

### Git diff (vs original plan)
```diff
diff --git a/docs/demo_content_spec_v3_plan.md b/docs/demo_content_spec_v3_plan.md
--- a/docs/demo_content_spec_v3_plan.md
+++ b/docs/demo_content_spec_v3_plan.md
@@
 **0.1 Combat/Status/Wand/UI Audit**
@@
 - Output: a short “Integration Notes” doc + confirmed event adapter plan.
+ - Also confirm:
+   - how entity IDs/handles work (or add them if missing)
+   - whether we can inject a `run_seed` at run start
@@
 ### 5.1 Automated Validation (dev-only script)
@@
 - No missing required fields (e.g., `mana_cost`, `type`, `element` where applicable)
+ - Determinism smoke (dev-only):
+   - fixed seed -> run N frames headless -> checksum key counters (kills, damage totals, gold)
+ - Hook leak checks (dev-only):
+   - equip/unequip wands repeatedly -> assert no growth in active subscriptions/timers
@@
 ### 5.2 Manual Smoke Checklist (must pass)
@@
 - Trigger at least one form and observe aura ticks + expiry cleanup
+- Enable event trace logging for one run; confirm trace is stable for same seed
 - Buy and use at least 2 shop wands; confirm triggers work and stop after unequip
 - Equip 3 equipment slots + 2 artifacts; confirm stats/effects apply and remove cleanly
```

---

## Optional Additions (High Value / Low Chaos)

These aren’t required for robustness, but they make the demo more compelling with minimal scope.

### Optional Feature A — “Daily Seed” + Shareable Run Code
- Players can share a run seed and compare builds.
- Works well with deterministic shop generation and event traces.

### Optional Feature B — Simple Wand Upgrade Sink
A single gold sink keeps shops meaningful:
- upgrade wand once: +1 slot **or** -10% mana cost (cap per wand)

---

## If You Only Do One Thing
**Fix update order so aura ticks happen before `SkillSystem.end_frame()`** (Change 3).  
Otherwise same-frame multi-triggers will behave inconsistently depending on damage source.

