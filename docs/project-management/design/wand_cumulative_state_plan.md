# Cumulative Wand & Cast Block State Plan

## Objectives
- Track cumulative wand state per cycle (cast delay, recharge, mana use, overload) and per cast block (action-level stats, modifier context).
- Ensure cast block execution reflects both card-derived modifiers and external player stats/buffs.
- Provide enough resolved data per block/card to drive individual projectile/behavior implementations without re-deriving state.

## Baseline Notes
- `card_eval_order_test.simulate_wand` already emits `block.total_cast_delay`, `block.total_recharge`, per-action `card_delays`, applied/remaining modifiers, children for triggers/timers, overload ratio, and card execution status.
- Block execution (`wand_executor`) aggregates modifiers per block and applies them uniformly via `WandModifiers.applyToAction`; player stats are currently unused.
- Attempted to run `wand_test_examples.runAllTests` via `lua ...`; failed early because engine module `registry` (required by `assets/scripts/task/task.lua`) is absent in this environment. No runtime signal yet for wand executor correctness.

## Data to Emit from Evaluation
- Per-block aggregation (raw, pre-player):
  - `base_mana_cost`: sum of action `mana_cost`.
  - `base_cast_delay`, `base_recharge`: already present.
  - `modifier_cards`: ordered list applied at block start (include inherited/global).
  - `action_cards`: ordered list with card-level stats (damage, speed, lifetime, spread, triggers, multicast count, mana_cost, cast_delay, recharge_time).
  - `children`: retain existing trigger/timer sub-block references.
- Per-cycle aggregation:
  - `overload_ratio`, `total_weight`, `wand_base_cast_delay/recharge`, `block_count`.
  - `card_execution` map (already present).
- Keep raw cards (not baked) so runtime can re-evaluate with player stats.

## Execution-Time Computation
1. **Execution context**: extend to include `playerStats` snapshot (damage, speed, crit, spread, mana buffs, etc.).
2. **Runtime merge**: new helper (e.g., `WandModifiers.mergePlayerStats(agg, playerStats)`) to apply player buffs to the aggregated block modifiers.
3. **Per-block runtime state**:
   - Aggregate block modifiers (`WandModifiers.aggregate` on `modifier_cards`).
   - Merge player stats into the aggregate.
   - Resolve each action’s final properties (damage, speed, lifetime, spread, crit, triggers, multicast) via an extended `applyToAction` that accepts player stats and wand base stats.
   - Compute `blockRuntime` totals: mana spent (respecting player mana cost buffs if any), cast delay/recharge (base + card), projectile count (from multicast), spread pattern.
4. **Execution**: drive `WandActions.execute` with resolved per-action properties so projectiles reflect both card and player stats; pass inherited runtime modifiers to sub-casts.
5. **Cumulative tracking**: accumulate per-cycle totals (delay, recharge, mana, projectile count) into a `lastExecutionState` alongside `lastEvaluationResult` for debugging/telemetry.

## Testing & Validation
- Headless Lua harness: add a lightweight test that constructs a wand + cards + synthetic `playerStats`, runs evaluation and a stubbed execution path, and asserts resolved damage/speed/lifetime and cumulative delays. Use local stubs/mocks to avoid engine dependencies.
- If engine modules remain unavailable (`registry`), keep tests sandboxed to pure Lua (no engine components) and document the gap; rerun `wand_test_examples` when engine modules are present.

## Open Questions / Assumptions
- Player stat shape: assume additive bonuses (damage, mana cost reduction, spread tweaks) plus multipliers; will define a minimal schema when implementing.
- Mana handling: assume block/action mana costs should incorporate player reductions and sufficient-mana checks per action (already in executor) should use resolved cost.
- Sub-cast inheritance: assume sub-casts inherit parent runtime modifiers + player stats unchanged unless card explicitly alters them.
