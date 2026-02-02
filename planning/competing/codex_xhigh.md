# Implementation Plan — Demo Content Spec v3

## 1) Executive Summary (TL;DR)
Deliver full Demo Content Spec v3 across combat, identity, skills, forms, items, cards, wands, and economy by implementing new combat subsystems (melee arc, aura), extending StatusEngine with decay, building god/class definitions and UI, enforcing skill element lock + multi-trigger logic, and populating all content data tables. The plan sequences system code before content data, with UI and economy integrated after core mechanics. Each task includes acceptance criteria, edge cases, and parallelization guidance.

---

## 2) Architecture Overview

### 2.1 Core Systems & Data Flow
- **Combat Runtime**
  - `assets/scripts/combat/combat_system.lua` (StatusEngine update loop, status application/removal)
  - `assets/scripts/combat/melee_arc.lua` (melee arc line sweep logic; used by wand actions)
  - `assets/scripts/combat/aura_system.lua` (form auras, tick damage/status)
- **Data Definitions**
  - `assets/scripts/data/status_effects.lua` (status configs + forms)
  - `assets/scripts/data/skills.lua` (32 skills)
  - `assets/scripts/data/cards.lua` (modifiers + actions)
  - `assets/scripts/data/artifacts.lua` (15 artifacts)
  - `assets/scripts/data/equipment.lua` (12 equipment)
  - `assets/scripts/data/starter_wands.lua` (starter wands)
  - `assets/scripts/data/avatars.lua` (gods + classes)
- **Gameplay / UI**
  - `assets/scripts/core/skill_system.lua` (element lock, multi-trigger, frame events)
  - `assets/scripts/ui/skills_panel.lua` (element lock UX messaging)
  - `assets/scripts/ui/god_select_panel.lua` (god/class selection)
  - `assets/scripts/core/main.lua` (entry wiring for new UI and run start)
  - `assets/scripts/wand/wand_actions.lua` (action dispatch: ACTION_MELEE_SWING)

### 2.2 Key Interfaces
- **Melee Arc**
  - `executeMeleeArc(caster, config)` called from `wand_actions.lua` action handler.
  - Uses `physics.segment_query` and `dealDamage`, `isEnemy`.
- **StatusEngine**
  - `StatusEngine.update_entity(dt, entityId, statuses)` handles decay using `STATUS_DECAY_RATES`.
- **Skill System**
  - `SkillSystem.learn_skill(player, skillId)` enforces element lock.
  - `SkillSystem.on_event(event_type, event_data)` collects per-frame triggers.
  - `SkillSystem.end_frame()` resolves multi-trigger skills.
- **Aura System**
  - `AuraSystem.update(dt)` ticks aura damage/status on interval.
  - `AuraSystem.tick(entity, config)` resolves AoE damage + status.
- **God Selection**
  - `god_select_panel.lua` displays god cards and class selector, confirm to start run and grant gear.

---

## 3) Phase Breakdown with Numbered Tasks

### Phase 1 — Combat Core Systems (Dependency root for all combat content)

#### 1.1 Implement Melee Arc System (Channeler)
- **Files**
  - New: `assets/scripts/combat/melee_arc.lua`
  - Modify: `assets/scripts/wand/wand_actions.lua`
- **Functions**
  - `executeMeleeArc(caster, config)`
  - `ACTION_MELEE_SWING` action handler in `wand_actions.lua`
- **Data Structures**
  - Melee action config table with `arc_angle`, `range`, `duration`, `damage`, `damage_type`
  - `hitEntities` table keyed by entity id/pointer
- **Acceptance Criteria**
  - A melee action hits enemies within a 90° arc using 8 line sweeps.
  - Each enemy is damaged at most once per swing.
  - Arc damage respects `damage_type` and `damage` from action config.
- **Edge Cases / Failure Modes**
  - Ensure arc doesn’t damage caster or allies.
  - Ensure no error if `physics.segment_query` returns no shapes.
  - Prevent double hits when sweep lines overlap same enemy.
- **Complexity:** M
- **Parallelization Notes**
  - Can be done in parallel with 1.2, 1.3.

#### 1.2 Add Status Decay in StatusEngine
- **Files**
  - Modify: `assets/scripts/combat/combat_system.lua`
  - Modify: `assets/scripts/data/status_effects.lua`
- **Functions**
  - `StatusEngine.update_entity(dt, entityId, statuses)`
- **Data Structures**
  - `STATUS_DECAY_RATES = { scorch={interval, amount}, ... }`
  - Per-status `data.decayTimer`
- **Acceptance Criteria**
  - Each decayable status loses stacks on its interval.
  - Stacks do not drop below 0.
  - Status auto-removes at 0 stacks.
- **Edge Cases / Failure Modes**
  - Handle missing `data.stacks` gracefully (treat as 0).
  - Avoid double-removal if status already removed mid-loop.
- **Complexity:** S
- **Parallelization Notes**
  - Can be done in parallel with 1.1, 1.3.

#### 1.3 Define Starter Wands and Hook Into Templates
- **Files**
  - New: `assets/scripts/data/starter_wands.lua`
  - Modify: `assets/scripts/core/card_eval_order_test.lua`
- **Data Structures**
  - `WandTemplates.VOID_EDGE`, `WandTemplates.SIGHT_BEAM`
- **Acceptance Criteria**
  - Starter wands load without errors.
  - Starting cards match spec.
  - Wands are selectable/assigned at run start.
- **Edge Cases / Failure Modes**
  - Missing card ids should not crash; fail with clear log.
  - Ensure mana and timing fields match expected units (ms vs seconds).
- **Complexity:** S
- **Parallelization Notes**
  - Can be done in parallel with 1.1, 1.2.

---

### Phase 2 — Gods & Classes (Identity + Run Start)

#### 2.1 Implement God Definitions
- **Files**
  - Modify: `assets/scripts/data/avatars.lua`
- **Functions**
  - God `blessing.effect(player)`
  - God `passive.effect(target)`
- **Data Structures**
  - `Avatars.pyr`, `Avatars.glah`, `Avatars.vix`, `Avatars.nil`
- **Acceptance Criteria**
  - Each god has blessing (cooldown, effect) and passive (trigger).
  - Starter equipment and artifact ids are set for each god.
- **Edge Cases / Failure Modes**
  - `sumAllEnemyStacks` returns 0 if no enemies; damage should be 0.
  - Blessing should no-op safely if world or enemies are missing.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 2.2, 2.3 (if data structure shapes are shared).

#### 2.2 Implement Class Definitions
- **Files**
  - Modify: `assets/scripts/data/avatars.lua`
- **Functions**
  - `channeler.passive.update(player)`
  - `channeler.triggered.effect(player)`
  - `seer` class setup similarly
- **Data Structures**
  - `Avatars.channeler`, `Avatars.seer`
- **Acceptance Criteria**
  - Channeler passive damage bonus scales with nearby enemies (cap 25%).
  - Channeler triggered mechanic grants +100% damage at 10 charges.
  - Seer starter wand assigned correctly.
- **Edge Cases / Failure Modes**
  - Ensure `player.arcane_charges` initialized.
  - Ensure modifiers don’t stack permanently without reset.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 2.1, 2.3.

#### 2.3 Build God Selection UI & Run Start Hook
- **Files**
  - New: `assets/scripts/ui/god_select_panel.lua`
  - Modify: `assets/scripts/core/main.lua`
- **Functions**
  - `GodSelectPanel.render()`
  - `GodSelectPanel.on_confirm()`
- **Acceptance Criteria**
  - UI shows 4 god cards with name, blessing, passive.
  - Shows starter equipment + artifact preview.
  - Class selector for Channeler/Seer.
  - Confirm grants god gear, class starter wand, and starts run.
- **Edge Cases / Failure Modes**
  - Handle selection without class chosen (disable confirm).
  - Missing asset icons should fallback gracefully.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 2.1, 2.2 once avatar data shape agreed.

---

### Phase 3 — Skills System (Element Lock + Multi-Trigger + 32 Skills)

#### 3.1 Element Lock Enforcement
- **Files**
  - Modify: `assets/scripts/core/skill_system.lua`
  - Modify: `assets/scripts/ui/skills_panel.lua`
- **Functions**
  - `SkillSystem.learn_skill(player, skillId)`
- **Data Structures**
  - `player.elements_invested` (set of element strings)
- **Acceptance Criteria**
  - 3rd element is allowed; 4th element is rejected with message.
  - UI displays lock reason when blocked.
- **Edge Cases / Failure Modes**
  - Respec or skill removal should update `elements_invested` correctly (define behavior).
  - Reject duplicate element investment cleanly.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 3.2, 3.3.

#### 3.2 Multi-Trigger Skill Resolution (ALL triggers same frame)
- **Files**
  - Modify: `assets/scripts/core/skill_system.lua`
- **Functions**
  - `SkillSystem.on_event(event_type, event_data)`
  - `SkillSystem.end_frame()`
- **Data Structures**
  - `frame_events = { {type, data}, ... }`
  - `skill.triggers` array
- **Acceptance Criteria**
  - Skills with multiple triggers fire only when all triggers occurred in same frame.
  - Single-trigger skills still work unchanged.
- **Edge Cases / Failure Modes**
  - Multiple events of same type in frame should count as “present.”
  - Frame events reset reliably each frame.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 3.1, 3.3.

#### 3.3 Implement 32 Skills (Data + Effects)
- **Files**
  - Modify: `assets/scripts/data/skills.lua`
- **Data Structures**
  - 32 skill entries (8 per element)
  - Fields: `id`, `name`, `element`, `cost`, `triggers`, `effect`
- **Acceptance Criteria**
  - All skills defined and loadable.
  - Each skill effect matches spec (damage, healing, summons, form trigger).
  - Fire Form and other form skills apply correct status effect.
- **Edge Cases / Failure Modes**
  - Skills with thresholds (e.g., 100 Fire damage) must track correctly on player.
  - Avoid nil access if trigger data missing.
- **Complexity:** L
- **Parallelization Notes**
  - Can split by element across agents if shared template agreed.

---

### Phase 4 — Transformation Forms & Aura System

#### 4.1 Implement Form Status Effects
- **Files**
  - Modify: `assets/scripts/data/status_effects.lua`
- **Data Structures**
  - `StatusEffects.fireform`, `iceform`, `lightningform`, `voidform`
  - Each with `duration`, `stat_mods`, `aura` config, `on_apply`, `on_remove`
- **Acceptance Criteria**
  - Forms apply for 30–60 seconds (per spec, e.g., 45s default).
  - Form aura fields are present and consumed by AuraSystem.
  - On removal, relevant threshold counters reset.
- **Edge Cases / Failure Modes**
  - If form re-applied during active duration, refresh or ignore consistently.
  - Ensure `on_remove` handles missing counters safely.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 4.2.

#### 4.2 Implement Aura Tick System
- **Files**
  - New: `assets/scripts/combat/aura_system.lua`
- **Functions**
  - `AuraSystem.update(dt)`
  - `AuraSystem.tick(entity, config)`
- **Data Structures**
  - `active_auras[entity][auraId] = { config, tickTimer }`
- **Acceptance Criteria**
  - Aura damage applies at `tick_interval`.
  - Aura applies status stacks if configured.
  - Auras respect radius and only target enemies.
- **Edge Cases / Failure Modes**
  - Ensure aura list cleanup when entity removed.
  - Handle zero enemies in area gracefully.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 4.1.

---

### Phase 5 — Cards & Wands (Full Pool)

#### 5.1 Add 12 Modifier Cards
- **Files**
  - Modify: `assets/scripts/data/cards.lua`
- **Acceptance Criteria**
  - All 12 modifier cards present with correct mana and effects.
  - Effects applied consistently in spell resolution order.
- **Edge Cases / Failure Modes**
  - Stacking modifiers should not produce negative values (e.g., AoE radius).
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 5.2, 5.3.

#### 5.2 Add 16 Action Cards (Elemental)
- **Files**
  - Modify: `assets/scripts/data/cards.lua`
- **Acceptance Criteria**
  - 16 actions (4 per element) with correct effects and damage types.
- **Edge Cases / Failure Modes**
  - Ensure action ids are unique and referenced correctly by wands.
- **Complexity:** L
- **Parallelization Notes**
  - Can be parallel with 5.1, 5.3.

#### 5.3 Add 6 Findable Wands (Shop-only)
- **Files**
  - Modify: `assets/scripts/core/card_eval_order_test.lua`
- **Acceptance Criteria**
  - Wands appear in shop only (no drops unless specified).
  - Prices match spec.
- **Edge Cases / Failure Modes**
  - Ensure no price conflict with economy tables.
- **Complexity:** S
- **Parallelization Notes**
  - Can be parallel with 5.1, 5.2.

---

### Phase 6 — Artifacts & Equipment

#### 6.1 Add 15 Artifacts (Tiered)
- **Files**
  - Modify: `assets/scripts/data/artifacts.lua`
- **Acceptance Criteria**
  - 5 per tier: common/uncommon/rare.
  - Effects implemented per spec.
- **Edge Cases / Failure Modes**
  - Rarity weights applied consistently in shop/loot systems.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 6.2.

#### 6.2 Add 12 Equipment Items (Slots)
- **Files**
  - Modify: `assets/scripts/data/equipment.lua`
- **Acceptance Criteria**
  - 4 each for chest, gloves, boots with correct stats.
- **Edge Cases / Failure Modes**
  - Ensure slot conflicts resolved (one per slot).
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 6.1.

---

### Phase 7 — Economy & Progression

#### 7.1 Implement Skill Point Grants by Level
- **Files**
  - Modify: `assets/scripts/core/progression.lua` (or relevant level system file)
- **Data Structures**
  - `SKILL_POINTS_BY_LEVEL = { [2]=2, [3]=2, ... }`
- **Acceptance Criteria**
  - Points granted at levels 2–6 per table.
  - Cumulative points match spec.
- **Edge Cases / Failure Modes**
  - Level skipping should grant all missing points.
- **Complexity:** S
- **Parallelization Notes**
  - Can be parallel with 7.2.

#### 7.2 Shop Timeline Integration
- **Files**
  - Modify: `assets/scripts/core/shop.lua` (or relevant shop system)
- **Acceptance Criteria**
  - Stage 1: equipment only.
  - Stage 2: equipment + wand (1–2).
  - Stage 3: equipment + artifact via elite drop.
  - Stage 4: equipment + wand + artifact.
- **Edge Cases / Failure Modes**
  - If shop inventory is empty for a category, fallback to equipment.
- **Complexity:** M
- **Parallelization Notes**
  - Can be parallel with 7.1.

---

## 4) Critical Path and Dependencies

### 4.1 Critical Path
1. **Phase 1** (Melee Arc + Status Decay + Starter Wands)
2. **Phase 2** (God/Class definitions + God selection UI)
3. **Phase 3** (Skill system mechanics + 32 skills)
4. **Phase 4** (Forms + Aura system)
5. **Phase 5** (Cards + Wands)
6. **Phase 6** (Artifacts + Equipment)
7. **Phase 7** (Economy)

### 4.2 Dependency Notes
- **Skills → Forms**: Form skills require forms defined in `status_effects.lua` and `aura_system.lua`.
- **God/Class UI → Data**: UI requires avatar definitions and starter gear ids to exist.
- **Wands → Cards**: Wand `starting_cards` must reference defined card ids.
- **Economy → Shop**: Shop timeline depends on artifact/equipment/wand entries existing.

---

## 5) Risk Mitigation

- **Risk: Status decay breaks existing status logic**
  - Mitigation: Gate decay to explicit `STATUS_DECAY_RATES` entries only.
- **Risk: Multi-trigger logic changes single-trigger behavior**
  - Mitigation: Guard multi-trigger handling with `#skill.triggers > 1`.
- **Risk: UI selection path incomplete**
  - Mitigation: Disable confirm until god + class selected; default selections optional.
- **Risk: Missing data ids cause runtime errors**
  - Mitigation: Add validation checks when loading data tables; log missing ids.
- **Risk: Aura system performance**
  - Mitigation: Use coarse interval ticks and limit radius checks; avoid per-frame AoE.
- **Risk: Element lock UX confusion**
  - Mitigation: Show a clear “Element locked at 3” tooltip in `skills_panel.lua`.

---

## Parallel Execution Guidance (Multi-Agent)
- **Agent A:** Phase 1.1 + 1.2 (combat systems)  
- **Agent B:** Phase 2.1 + 2.2 (avatars data)  
- **Agent C:** Phase 3.1 + 3.2 (skill system mechanics)  
- **Agent D:** Phase 3.3 (skills data, split by element)  
- **Agent E:** Phase 4.1 + 4.2 (forms + aura system)  
- **Agent F:** Phase 5 (cards + wands)  
- **Agent G:** Phase 6 (artifacts + equipment)  
- **Agent H:** Phase 7 (economy + shop timeline)

Each agent should coordinate shared data structures (ids, fields) before implementing to avoid schema conflicts.