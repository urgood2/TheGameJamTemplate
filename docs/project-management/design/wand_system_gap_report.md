# Wand System Integration Gaps (implementation vs. design)

Quick snapshot of what’s not yet wired in the current scripts (`assets/scripts/wand` + `assets/scripts/core`) relative to the wand design docs. Use this before authoring content so you know which systems need finishing.

## High-priority gaps
- **Overheat/resource handling not aligned**  
  - `wand_executor.lua` still blocks casts when `currentMana <= 0` and never consumes `charges`; overheat penalty only affects per-block delay and never recharge, so you can’t “push past zero” as planned.
- **Player stats and cumulative state are mostly inert**  
  - `createExecutionContext` builds a plain table (no `get`), so `WandModifiers.mergePlayerStats` never fires unless manually overridden. Mana cost reductions, crit, cast speed, and CDR are not applied to mana spend/delays, and cumulative per-cycle metrics are barely tracked.
- **Trigger wiring is mismatched**  
  - Registrations use `on_player_attack/on_bump_enemy/...`, but listeners emit `player_pressed_attack/player_bump_enemy/...`, so event triggers never fire. Cooldown trigger is a TODO that always returns true, and block-to-block delay is also left as a TODO.
- **Sub-casts/on-hit branching not executed**  
  - Collision/death child blocks only log; `pendingSubCasts` is unused; inherited modifiers aren’t applied; on-hit never schedules child blocks. Timer/collision branches from the evaluator don’t actually run.
- **Action types are stubs**  
  - Hazards, summons, teleport, meta resource tweaks, knockback, chain lightning, etc., just log. Cards relying on these won’t function in runtime.
- **Deck/tag/Joker bridge is inert**  
  - `TagEvaluator.evaluate_and_apply` is never called on deck changes, so tag breakpoints, tag-based Jokers, and Balatro-style discoveries don’t activate.

## Suggested fix order (to unblock content work)
1. Fix trigger IDs/event names and implement the cooldown trigger check; apply block-to-block delay.
2. Allow casting with negative mana (overheat), consume charges, and apply overheat to recharge as designed.
3. Wire real player stats into `mergePlayerStats` (`get` accessor) and apply cast-speed/CDR/mana-cost/crit to actions and delays; record per-block/per-cycle cumulative state.
4. Execute collision/timer/death sub-casts with inherited modifiers; use `pendingSubCasts` or projectile callbacks to fire them.
5. Implement hazard/summon/teleport/meta/on-hit behaviors (or gate cards that depend on them).
6. Call `TagEvaluator.evaluate_and_apply` when decks change so tag thresholds, Jokers, and discoveries fire.
