# FINAL DEMO IMPLEMENTATION PLAN (REVISED + SHIP GATES)

This revision re-centers the plan on shipping a stable demo. It keeps system reuse intact, integrates demo-polish requirements, reduces skill-tree scope, and adds explicit release gates.

---

## EXECUTIVE SUMMARY

**What already exists and should be reused:**
- Status effects pipeline (data + StatusEngine + status_indicator_system)
- Trigger constants + wand trigger executor (data/triggers.lua + wand/wand_triggers.lua)
- Equipment data + proc wiring (data/equipment.lua + combat_system ItemSystem)
- Avatar system with unlocks, stat buffs, and proc triggers (wand/avatar_system.lua + data/avatars.lua)
- Inventory UI scaffolding (player_inventory.lua, card_inventory_panel.lua, ui_syntax_sugar tabs)
- Shop system framework (core/shop_system.lua)
- Wave manager + spawner + state machine

**Primary gaps to ship demo:**
- Stability blockers: physics jitter, LDtk map integration, WASM leak baseline
- Missing spec content: statuses, wands, artifacts/equipment, gods/classes, limited skills
- Demo polish features (MP bar, E trigger, tutorial skip, pack shop UX, gold display, demo overlay, feedback buttons)
- Acquisition wiring for new content (shop/drop/selection)

**High-level change:**
- Build new content on top of existing systems, and add ship gates for stability and QA.

---

## CONTEXT ALIGNMENT (IMPORTANT)

Before implementation, align with these existing files:
- `assets/scripts/data/status_effects.lua` (status schema, stack modes, particles, shaders)
- `assets/scripts/data/triggers.lua` (canonical trigger strings)
- `assets/scripts/wand/wand_triggers.lua` (event wiring + trigger execution)
- `assets/scripts/wand/avatar_system.lua` (proc handling via signal_group)
- `assets/scripts/data/equipment.lua` (equipment schema with procs + slots)
- `assets/scripts/ui/player_inventory.lua` (tabbed UI, equipment/wands/triggers layout)
- `assets/scripts/core/shop_system.lua` (existing shop framework)

Naming consistency matters: signals currently include both `on_*` and non-prefixed names (e.g., `player_damaged`). Resolve mismatches by aliasing, not renaming.

---

## EVENT/TRIGGER CONTRACT (ENFORCE IT)

This repo has two event systems; treat this as the integration contract so wands/procs don’t silently break:
- Combat internals emit on `ctx.bus` (e.g., `OnHitResolved`, `OnStatusApplied`) in `assets/scripts/combat/combat_system.lua`.
- Gameplay-facing systems (wands, avatars, UI, wave logic) listen on `signal` (hump.signal).
- `assets/scripts/core/event_bridge.lua` forwards selected `ctx.bus` events to `signal` and is attached in `assets/scripts/core/gameplay.lua` via `EventBridge.attach(ctx)`.
- New cross-system combat events should be bridged in `assets/scripts/core/event_bridge.lua` unless the payload requires actor→entity conversion (like `OnDeath`).
- **Source of truth:** status apply signals and per-status `on_apply_*` fan-out are emitted only in StatusEngine.apply; EventBridge does not forward per-status fan-out.
- Wand triggers should subscribe to `signal` events only; if you need a new trigger, either emit it directly as a `signal` event from gameplay code or bridge from a `ctx.bus` event.

**Contract tests required:**
- `player_damaged` and `on_player_damaged` both fire with identical payloads.
- Per-status `on_apply_*` fan-out fires exactly once per successful apply.
- Signal payload shapes are consistent (entity id vs table) across listeners.
- No leaked `signal_group` handlers after reset/end-of-run.

---

## SHIP GATES (NON-NEGOTIABLE)

### GATE 0.5: DEMO STABILITY BASELINE (BEFORE NEW CONTENT)
- LDtk map with colliders integrated into main loop.
  - Primary files: `assets/scripts/examples/ldtk_quickstart.lua`, `assets/scripts/core/gameplay.lua`, `src/systems/ldtk_loader/`
  - Verify: map loads, collisions active, spawn points used.
- Physics/transform jitter + drag/drop collider drift resolved.
  - Primary files: `src/ecs/components/transform.cpp`, `src/systems/physics/physics_world.cpp`
  - Verify: drag/drop and collision alignment stable in live run.
- Add reset run debug action (full state clear + script reload).
  - Verify: clears timers/entities and `signal_group` handlers (no leaks after reset).
  - Verify: no duplicate `enemy_killed` emissions after reset.
- Decide batching vs non-batching card render path for slice.
  - Verify: chosen path used consistently in card stack rendering.
- WASM leak baseline run captured (measure even if not yet fixed).
  - Verify: `just build-web` and run a 10-minute session without growth spikes.
- 3 crash-free runs in a row (desktop) after the above.

### GATE 1: INTEGRATION + QA (BEFORE FINAL POLISH)
- End-to-end loop works: start → waves → shop → elite/boss → victory/defeat.
- Minimum enemy roster exists (charger, ranged, hazard dropper, 1 elite/boss pattern).
- 5 crash-free full runs (desktop).
- Controller + mouse parity for core loop.
- No dead content (all new items obtainable in normal play).

---

## DEMO POLISH TRACK (FROM `docs/specs/demo-polish-features.md`)

These are required for the demo experience. Integrate them into phases rather than leaving them as a separate backlog.

**Quick wins (do early):**
- Gold display simplification (icon + number, no border/background).
- Demo overlay (bottom-right, `DEMO vX.Y.Z`).
- Feedback buttons (Discord + Forms, open external browser).

**Mid-complexity:**
- Tutorial skip system (ESC/click to skip step, hold 2s to skip all).
- MP bar on card strip UI (action phase only).
- E-key trigger system (type = "trigger", burst on E press, HUD glyph).

**High complexity:**
- Shop pack system with sequential flip + choose 1 + dissolve unchosen.

---

## SHADER DECISION (RESOLVED)

**Conflict:** vertical slice plan says avoid `3d_skew` on cards, but demo polish spec suggests dissolve via `3d_skew`.

**Decision:** Use a known-safe dissolve shader (`assets/shaders/uieffect_transition_dissolve.fs`) or a non-shader fallback for unchosen cards. Do not depend on `3d_skew` for core shop UX.

---

## REVISED PHASE PLAN

### PHASE 0: PRE-FLIGHT ALIGNMENT (1–2 hours)
Verify which systems currently emit:
- `on_player_attack`, `enemy_killed`, `on_bump_enemy`
- `on_player_damaged` and/or `player_damaged`
- `on_stand_still` (required for Frost Anchor)

**Output:** a short verification note (where emitted, payload shape).

#### Verified Emitters (Codebase Scan)
- `on_stand_still`: emitted in `assets/scripts/core/gameplay.lua:10231`
  - `signal.emit("on_stand_still", survivorEntity, { idle_time = playerIdleTime })`
- `on_bump_enemy`: emitted in `assets/scripts/core/gameplay.lua:8873`
  - `signal.emit("on_bump_enemy", enemyEntity, { position = bumpPosition, entity = enemyEntity })`
- `enemy_killed`: emitted in two places
  - `assets/scripts/core/gameplay.lua:6353`
  - `assets/scripts/combat/enemy_factory.lua:379`
- `player_damaged`: emitted in `assets/scripts/combat/combat_system.lua:2476`
  - `signal.emit("player_damaged", tgt.entity_id, { amount = dealt, damage_type = primary_type, source = src.entity_id })`
- `on_player_damaged`: not emitted anywhere yet

Done when:
- Signal payload shapes are confirmed for events wands depend on
- A single alias point is chosen for `player_damaged` vs `on_player_damaged`

---

### PHASE 1: STATUS EFFECTS + TRIGGER SIGNALS (CRITICAL)

**Goal:** finish missing effects and ensure signals exist for wand triggers and passive procs.

1) Add missing status effects in `assets/scripts/data/status_effects.lua`:
- `arcane_charge` (buff, stack_mode=count)
- `focused` (buff, stack_mode=replace, timed)
- `fireform`, `iceform`, `stormform`, `voidform` (buff + aura + shader + particles)

2) Alias spec names to existing effects:
- `StatusEffects.scorch = StatusEffects.burning`
- `StatusEffects.freeze = StatusEffects.frozen`

3) Emit status-related signals in StatusEngine.apply (only source of truth):
- Per-status fan-out (`on_apply_burn`, etc.) emitted in StatusEngine.apply after `on_apply_status`.
- EventBridge does not forward per-status fan-out to prevent double emission.

4) Standardize player-damaged signal name:
- Emit both `player_damaged` and `on_player_damaged` from a single source.

5) Update `status_indicator_system.lua` only if form icons need scale/position changes.

**Verification:** extend `assets/scripts/tests/test_status_engine.lua`:
- `on_apply_status` and per-status fan-out
- stack_mode behaviors (`count`, `replace`)
- alias policy for `player_damaged`/`on_player_damaged`

Done when:
- New status defs load without errors and apply/remove cleanly
- Fan-out fires exactly once per successful apply
- Both damaged signals fire with identical payload

---

### PHASE 2: WANDS + TRIGGERS + CORE DEMO POLISH (HIGH)

### PHASE 2.5: ENEMY ROSTER (REQUIRED FOR GATE 1)

**Goal:** ensure the minimum enemy set exists and is wired into spawners.

Tasks:
- Implement charger, ranged, hazard dropper, and 1 elite/boss pattern in enemy data/factory.
- Wire behaviors into spawner tables and wave configs.
- Ensure `enemy_killed` emission is not duplicated across emitters (de-dupe or unify).

Primary files:
- `assets/scripts/combat/enemy_factory.lua`
- `assets/scripts/combat/enemy_spawner.lua`
- `assets/scripts/combat/wave_manager.lua`
- `assets/scripts/data/creatures.json` or existing enemy data files

Done when:
- All 4 enemy types spawn in normal waves
- Elite/boss spawns on final wave
- `enemy_killed` fires exactly once per enemy death


**Goal:** ensure trigger events are wired, add spec wands, and implement key demo polish features tied to triggers/UI.

1) Extend `wand/wand_triggers.lua` event subscriptions:
- Add `on_apply_burn`, `on_apply_freeze`, `on_apply_doom`
- Add `on_player_damaged`
- Add `on_stand_still`

2) Add findable wands (WandTemplates in `assets/scripts/core/card_eval_order_test.lua`):
- Rage Fist (every_N_seconds)
- Storm Walker (on_bump_enemy)
- Frost Anchor (on_stand_still)
- Soul Siphon (enemy_killed)
- Pain Echo (on_distance_traveled)
- Ember Pulse (every_N_seconds + AoE action)

3) Demo polish integration:
- MP bar on card strip UI (`assets/scripts/ui/trigger_strip_ui.lua`)
- E-key trigger system (card type `trigger`, E press emits trigger burst)
- HUD glyph for E trigger

**Acquisition wiring:**
- Ensure wands show up in existing shop/loot flow (define drop/offer tables as needed).

**Verification:** run `assets/scripts/tests/wand_system_integration_test.lua` and confirm trigger strip UI behavior.

Done when:
- All new triggers fire in live run
- Wand defs load via `WandExecutor.loadWand`
- Trigger UI still updates correctly

---

### PHASE 3: GODS + CLASSES VIA AVATAR SYSTEM (HIGH)

**Approach:** extend AvatarSystem, do not create new system.

Implementation:
- Add gods/classes as entries in `assets/scripts/data/avatars.lua` with `type` field.
- Add `blessing` effect type in AvatarSystem.
- Input handling (E-key) lives in gameplay/input layer, not AvatarSystem.
- Track cooldown on player state (`player.blessing_cd_until` or per-blessing map).

**UI:** reuse tab patterns in `assets/scripts/ui/player_inventory.lua`.

**Acquisition wiring:**
- Decide selection timing: run start selection or shop unlock.
- Ensure selection path is in normal run (not debug-only).

**Verification:** ensure stat changes apply/revert deterministically and signal handlers are cleaned.

---

### PHASE 4: SKILLS (REDUCED FOR DEMO)

**Goal:** a minimal skill layer that adds build variety without a complex tree.

1) Data: create `assets/scripts/data/skills.lua` with 8–10 skills (2 per element).
2) Skill runtime: `assets/scripts/core/skill_system.lua` to track learned skills and apply stat changes.
3) UI: add a Skills tab to `assets/scripts/ui/player_inventory.lua` (no separate window).
4) Save/load: optional for demo; if added, store only minimal learned-skill flags with version number.

**Acquisition wiring:**
- Use existing level-up or shop hooks to grant skill points.

**Verification:** learn 4–6 skills, see stats change, reset run and ensure cleanup.

---

### PHASE 5: ARTIFACTS + EQUIPMENT (MEDIUM)

1) Artifacts:
- Implement in `assets/scripts/data/artifacts.lua` using Joker schema (`calculate(self, context)`).
- Reuse joker UI presentation patterns.

2) Equipment:
- Add 12 spec items to `assets/scripts/data/equipment.lua` using existing schema.

**Acquisition wiring:**
- Artifacts and equipment appear in the same acquisition flows as existing items.

**Verification:** equip/unequip applies and removes stats cleanly; proc triggers do not duplicate.

---

### PHASE 6: POLISH + BALANCE (LOW)

- Tutorial skip system.
- Shop pack system (Trigger/Mod/Action packs, 25g each, sequential flip, choose 1, dissolve unchosen with safe shader).
- Audio pass (dash/loot variations, volume normalization, tick toggle).
- Tooltips readability fixes.
- Controller polish.

**Done when:**
- No dead content (all new content obtainable)
- Short playtest shows each trigger category firing

---

## DEPENDENCY GRAPH (UPDATED)

```
Gate 0.5 (Stability Baseline)
    ↓
Phase 1 (Status + Signals)
    ↓
Phase 2 (Wands + Triggers + Core Demo Polish)
    ↓
Phase 3 (Gods/Classes)
    ↓
Phase 4 (Skills - Reduced)
    ↓
Phase 5 (Artifacts + Equipment)
    ↓
Gate 1 (Integration + QA)
    ↓
Phase 6 (Polish + Balance)
```

---

## SCOPE CUT (IF 50% REDUCTION REQUIRED)

**Keep:**
- Phase 1 (Status + Signals)
- Phase 2 (Wands + Triggers + MP bar + E trigger)
- Gold display + Demo overlay + Feedback buttons
- Minimal gods/classes (AvatarSystem reuse)

**Cut/Defer:**
- Full skill tree (keep 4–6 skills max or remove entirely)
- Shop pack dissolve sequence (keep basic shop)
- Large artifact/equipment set (ship a smaller curated subset)

---

## FILE IMPACT SUMMARY (REVISED)

**New files:**
- `assets/scripts/data/skills.lua`
- `assets/scripts/core/skill_system.lua`
- `assets/scripts/data/artifacts.lua`
- `assets/scripts/data/shop.lua` (pack definitions)

**Modified files:**
- `assets/scripts/data/status_effects.lua`
- `assets/scripts/combat/combat_system.lua`
- `assets/scripts/core/event_bridge.lua`
- `assets/scripts/wand/wand_triggers.lua`
- `assets/scripts/core/card_eval_order_test.lua`
- `assets/scripts/data/equipment.lua`
- `assets/scripts/ui/player_inventory.lua`
- `assets/scripts/ui/trigger_strip_ui.lua`
- `assets/scripts/ui/currency_display.lua`

---

## RISKS AND MITIGATIONS

- Signal naming mismatch: emit both `player_damaged` and `on_player_damaged` until migrations complete.
- Per-status fan-out duplication: emit exactly once in StatusEngine.apply.
- Missing trigger subscriptions: add `on_stand_still` or Frost Anchor fails.
- UI scope creep: reuse existing tabs; no new skills window for demo.
- Shader conflicts: avoid `3d_skew` in shop dissolve.
- Acquisition gaps: every new content item must appear in a normal run.
