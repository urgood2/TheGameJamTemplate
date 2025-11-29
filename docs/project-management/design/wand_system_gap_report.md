# Wand System Integration Gaps (implementation vs. design)

Quick snapshot of what’s not yet wired in the current scripts (`assets/scripts/wand` + `assets/scripts/core`) relative to the wand design docs. Use this before authoring content so you know which systems need finishing.

## High-priority gaps
- **Overheat/resource handling still incomplete**  
  - Casts now ignore mana gates (you can go negative), charges are consumed/regened, and overheat multiplies both per-block delays and total cooldown when `currentMana < 0`. Mana regen still ignores overheat.
- **Player stats hooked where available**  
  - `createExecutionContext` now wraps stats with `get`, and `mergePlayerStats` feeds cast speed, cooldown reduction, mana cost reduction, and damage % into costs/delays/damage. Cumulative metrics are recorded in `lastExecutionState`.
- **Trigger wiring moved to `on_*` signals, emitters still needed**  
  - Listeners now use `hump.signal` on `on_player_attack/on_bump_enemy/on_dash/on_pickup/on_low_health`, matching trigger IDs. Ensure gameplay emits the same events (e.g., attack/low-health) and avoid double-firing paths.
- **Sub-casts/on-hit branching only partly live**  
  - Timer child blocks execute; collision/death branches just log and never run. `pendingSubCasts` is unused, inherited modifiers aren’t applied to child blocks, and projectile on-hit/destroy callbacks don’t invoke sub-casts.
- **Non-projectile actions still stubs**  
  - Hazards, summons, teleport, meta resource tweaks, knockback impulses, chain lightning, and shield/regen scaffolds mostly log/TODO. Projectile hits can heal/freeze/slow, but the rest of these action types remain inert.
- **Deck/tag/Joker bridge only half-wired**  
  - Per-cast spell-type/tag analysis triggers Jokers and discovery, but `TagEvaluator.evaluate_and_apply` is never called on deck changes, so deck-wide tag thresholds/Jokers/discoveries don’t fire.

## Suggested fix order (to unblock content work)
1. Emit `on_*` signals consistently (attack/low-health especially) and clean up any duplicate trigger paths.
2. Apply overheat penalties to the action phase (use the computed multiplier) and revisit regen behavior if overheat should slow recovery.
3. Execute collision/death sub-casts with inherited modifiers via projectile callbacks (or `pendingSubCasts`) instead of logging.
4. Fill out non-projectile actions/impacts (hazard, summon, teleport, meta resource, knockback, chain lightning, shield) or gate cards that depend on them.
5. Extend player stat plumbing to any remaining offensive stats as needed; keep cumulative tracking intact.
6. Call `TagEvaluator.evaluate_and_apply` on deck changes so deck-wide tag thresholds and Jokers/discoveries activate.




# FInal goal
Make it easy (less hassle, all things in place) to implement the actual behavior of the projectiles, jokers, artifacts, etc.
