# Wand System Integration Gaps (implementation vs. design)

Quick snapshot of what’s not yet wired in the current scripts (`assets/scripts/wand` + `assets/scripts/core`) relative to the wand design docs. Use this before authoring content so you know which systems need finishing.

## High-priority gaps
- **Player/context hooks still stubs**  
  - `getPlayerEntity/getPlayerScript` rely on globals, `findNearestEnemy` is unimplemented, and homing/auto-aim/projectile spawns all default to `{0,0}` until wired to the real player/enemy data.
- **Overheat/resource handling still incomplete**  
  - `canCast` ignores mana/flux, overheat only multiplies block delay and total cooldown when `currentMana < 0`, regen ignores overheat, and sub-casts don’t spend mana or add delay/cooldown at all.
- **Trigger wiring moved to `on_*` signals, emitters still needed**  
  - Listeners now use `hump.signal` with queued execution for `on_player_attack/on_bump_enemy/on_dash/on_pickup/on_low_health`, but gameplay still doesn’t emit them; hook the real events and avoid duplicate trigger paths.
- **Sub-casts/on-hit branching now executes collision/death but stays free**  
  - Timer/collision/death children enqueue and run with inherited modifiers/context; projectiles carry child refs and `pendingSubCasts` is processed outside physics. By design, child casts currently ignore mana/delay/overheat—adjust if downstream balance needs them to pay costs.
- **Non-projectile actions/on-hit effects still stubs**  
  - Hazards, summons, teleport, meta resource tweaks, knockback impulses, chain lightning, AOE heal/shield, and on-death triggers are scaffolded but don’t touch combat/physics beyond logs; projectile hits only cover basic heal/freeze/slow.
- **Deck/tag/Joker bridge only half-wired**  
  - Per-cast spell-type/tag analysis triggers Jokers and discovery signals, but `TagEvaluator.evaluate_and_apply` is never called on deck changes, so deck-wide tag thresholds/procs/Joker/discovery effects never fire.

## Suggested fix order (to unblock content work)
1. Wire execution context to the real player/enemy data (entity ID, transform, facing, nearest-enemy queries) so spawns, homing, and chain logic use live positions.
2. Emit the `on_*` signals from gameplay (attack/bump/dash/pickup/low-health) to feed WandTriggers’ listeners/queueing and avoid duplicate pathways.
3. Execute collision/death sub-casts via projectile callbacks: attach child refs to projectiles, apply inherited modifiers, and charge mana/delay/cooldown for child blocks.
4. Normalize resource/overheat rules (decide gating vs. negative mana), extend penalties to regen if desired, and ensure sub-casts respect the same rules.
5. Flesh out non-projectile/on-hit actions (hazard, summon, teleport, meta resource, knockback, chain lightning, shield/AOE heal, on-death) against combat/physics systems.
6. Call `TagEvaluator.evaluate_and_apply` on deck changes so deck-wide tag thresholds, Jokers, and discovery hooks activate.




# Final goal
Make it easy (less hassle, all things in place) to implement the actual behavior of the projectiles, jokers, artifacts, etc.
