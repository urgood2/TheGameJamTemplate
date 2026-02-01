# GOAP AI System Improvement Plan

This plan is revised to fit the current codebase and correct known pitfalls.
It focuses on adding complexity without hurting usability or performance.

## Executive Summary

Keep the current bitset GOAP core and grow capability via:
- Correctness guardrails (fix reactive replan diffs, versioning, atom cap)
- Debugging visibility (trace + inspector)
- Performance (plan reuse, cache, scheduling)
- Usability (action helpers, safe defaults)
- Optional advanced layers (hierarchy, parallel goals)

This avoids rewriting the planner and preserves Lua-first workflows.

## Current Strengths (Preserve)

- Declarative Lua actions (`pre/post/cost`, coroutine `update`).
- Goal selection with bands + hysteresis in `assets/scripts/ai/goal_selector_engine.lua`.
- Watch masks for reactive replans (`src/systems/ai/goap_utils.hpp`).
- Per-entity AI definitions via deep-copy in `initGOAPComponent()`.
- Blackboard for continuous values.

## Phase 0: Correctness Guardrails (Do First)

### 0.1 Fix reactive replan diff

Problem: `update_goap()` computes changed bits after action postconditions and worldstate updaters run. This can cause spurious replans at action boundaries.

Fix:
1) After `execute_current_action(entity)`, snapshot `state_after_actions`.
2) Run `runWorldStateUpdaters()`.
3) Compute `changed = current_state ^ state_after_actions` (ignore dontcare).
4) Only use `changed` for reactive replans.

Files:
- `src/systems/ai/ai_system.cpp` (`update_goap`)

### 0.2 Separate cached state semantics

Add distinct snapshots:
- `last_tick_state`: for per-tick diff.
- `plan_start_state` (optional): for drift checks from plan creation.

Files:
- `src/components/components.hpp`

### 0.3 Atom count cap

`bfield_t` uses signed shifts (`1LL << idx`). Shifting near the sign bit is undefined. Enforce `ap.numatoms <= 62` unless planner is migrated to `uint64_t`.

Add load-time validation in:
- `load_actions_from_lua()`
- `load_worldstate_from_lua()`

### 0.4 Actionset + atom schema versioning

Plan caches and reuse are unsafe without explicit versions.

Add to `GOAPComponent`:
- `uint32_t actionset_version`
- `uint32_t atom_schema_version`

Increment on action reload or overrides.

### 0.5 Add `replan_to_goal`

Add a function that replans for an explicit goal without invoking goal selectors. This is required for hierarchical actions later.

Files:
- `src/systems/ai/ai_system.hpp`
- `src/systems/ai/ai_system.cpp`

## Phase 1: Debugging and Visibility

### 1.1 AI trace ring buffer

Add per-entity trace buffer (last 100-200 events).

Event types:
- GOAL_SELECTED (scores + winner)
- PLAN_BUILT (steps + cost)
- ACTION_START / ACTION_FINISH / ACTION_ABORT
- WORLDSTATE_CHANGED (changed bits)
- REPLAN_TRIGGERED (reason)

Files:
- `src/components/components.hpp`
- `src/systems/ai/ai_system.cpp`

### 1.2 Goal selection breakdown

Update `goal_selector_engine.lua` to report:
- per-goal desire + persist + score
- chosen goal id
- band

Add a C++ binding like `ai.report_goal_selection(...)`.

Files:
- `assets/scripts/ai/goal_selector_engine.lua`
- `src/systems/ai/ai_system.cpp`

### 1.3 Inspector UI

Expose trace data and key state for debugging.
Minimum viable panel:
- current goal + band
- plan steps and current action
- worldstate bits (names + values)
- recent trace events

File location depends on current debug UI system.

## Phase 2: Performance

### 2.1 Plan reuse / prefix validation

Before full replan, validate that the current plan still applies:
- Check preconditions for the next action against current state.
- If valid, keep plan; otherwise replan.

Do not rely only on watch masks.

Files:
- `src/systems/ai/ai_system.cpp`

### 2.2 Plan cache (per type + versioned)

Cache only if:
- same type
- same `actionset_version` and `atom_schema_version`
- same start state and goal

Cache key:
```
(type, actionset_version, atom_schema_version,
 start.values, start.dontcare,
 goal.values, goal.dontcare,
 optional target_id)
```

On cache hit, validate preconditions of the first 1-2 actions.

Files:
- `src/systems/ai/ai_system.cpp`
- new `src/systems/ai/plan_cache.hpp` (optional)

### 2.3 Scheduling and LOD

Separate heavy sensing from cheap worldstate derivation:
- Heavy sensors update blackboard on a slower cadence.
- `worldstate_updaters.lua` stays light and runs each AI tick.

If staggering:
- track per-entity elapsed time
- pass actual dt to updates

Files:
- `src/systems/ai/ai_system.cpp`
- `assets/scripts/ai/worldstate_updaters.lua`

## Phase 3: Numeric Worldstate Extension

### 3.1 Threshold compilation

Add a schema that maps numeric blackboard values to boolean atoms.
Example (new file): `assets/scripts/ai/numeric_thresholds.lua`

Rules:
- Keep thresholds coarse (2-4 per numeric)
- Enforce atom cap at load

Update AI init to apply thresholds before other updaters.

### 3.2 Diagnostics

On startup, count atoms and warn when near cap.

## Phase 4: Usability Improvements

### 4.1 Action helpers

Add `assets/scripts/ai/action_helpers.lua` with:
- `instant()`
- `timed()`
- `moveTo()` (if movement helpers exist)

### 4.2 Safe defaults

If action table is missing:
- `start` or `finish`: no-op
- `update`: instant success

### 4.3 Auto-watch defaults

If `watch` not provided:
- default to precondition keys
- allow explicit overrides

Files:
- `src/systems/ai/goap_utils.hpp`

## Phase 5: Hierarchical GOAP (Optional)

Add abstract actions with `decompose()` returning a subgoal.

Execution flow:
- when an abstract action starts, push parent goal
- call `replan_to_goal(subgoal)`
- finish when subgoal achieved, then resume parent

Add goal stack depth limit to prevent recursion.

## Phase 6: Parallel Goals (Optional)

Avoid true parallel execution initially.
Use:
- background interrupt monitors (SURVIVAL goals)
- soft goal composition when compatible

## Lua Binding Safety Notes

- Do not cache `sol::function` or `sol::table` across Lua resets.
- Avoid holding raw `Blackboard*` pointers in Lua for long periods.
- Consider adding `ai.has_worldstate_atom(e, key)` to distinguish nil from false.

## Success Metrics

- Replan rate: <10% of AI ticks trigger full A*.
- Debugging time: <30s to diagnose wrong decision.
- 100 entities: AI update time <2ms on target hardware.
- Action boilerplate: 50% fewer LOC per new action using helpers.

## Files to Add or Modify

New:
- `docs/systems/ai-behavior/GOAP_IMPROVEMENT_PLAN.md`
- `assets/scripts/ai/numeric_thresholds.lua`
- `assets/scripts/ai/action_helpers.lua`

Modify:
- `src/systems/ai/ai_system.cpp`
- `src/systems/ai/ai_system.hpp`
- `src/components/components.hpp`
- `src/systems/ai/goap_utils.hpp`
- `assets/scripts/ai/goal_selector_engine.lua`
- `assets/scripts/ai/worldstate_updaters.lua`

## Rollout Order

1) Phase 0 correctness fixes
2) Phase 1 debug tooling
3) Phase 2 performance
4) Phase 3 numeric thresholds
5) Phase 4 usability helpers
6) Phase 5-6 advanced features (optional)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
