# Wand System Integration Gaps (implementation vs. design)

Quick snapshot of what's not yet wired in the current scripts (`assets/scripts/wand` + `assets/scripts/core`) relative to the wand design docs. Use this before authoring content so you know which systems need finishing.

## High-priority gaps
- **Player context/homing still partial**  
  - Gameplay now overrides `getPlayerEntity/createExecutionContext` to use `survivorEntity` and combat stats, but the base helpers still fall back to globals and `findNearestEnemy` is empty, so homing/auto-aim/chain lightning revert to straight shots and facing still uses a mouse-only fallback.
- **Resource/overheat rules still inconsistent**  
  - `canCast` never blocks on mana (intentional), regen ignores overheat/negative mana (also intentional), but meta cards such as `add_mana_amount` are stubs and child casts execute without paying mana/delay/overheat so overcast builds only see the parent block penalties.
- **Upgrades/stats not merged into runtime casts**  
  - Card upgrade data exists (shop calls `CardUpgrade`) and player stat leveling exists (`core.stat_system`), but wand execution never merges player stats into modifier aggregates (see `wand_cumulative_state_plan.md`) and custom upgrade behaviors are never consulted, so upgraded cards and stat gains only affect raw card fields—no behavior hooks or stat buffs flow into cast resolution.
- **Trigger emit coverage is incomplete/mixed**  
  - `on_bump_enemy`/`on_pickup` now emit via `hump.signal` and `on_dash` calls `WandTriggers.handleEvent`, but `on_player_attack` and `on_low_health` never fire and we're mixing direct handler calls vs. signal emission.
- **Non-projectile + special on-hit actions are still stubs**  
  - Hazards, summons, teleport, meta resource tweaks, AOE heal/shield, knockback impulses, chain lightning, and on-death branches log or no-op instead of touching combat/physics.
- **Deck/tag/Joker bridge still missing deck-change hook**  
  - Per-cast spell-type/tag analysis triggers Jokers and discovery signals, but nothing calls `TagEvaluator.evaluate_and_apply` on deck/board changes so tag thresholds, player `tag_counts`, Joker scalers, and tag discoveries never update in play.

## Suggested fix order (to unblock content work)
1. Finish player/enemy context: wire `findNearestEnemy` and consistent facing/position helpers so homing/auto-aim/chain effects target live enemies in-game and in tests.
2. Standardize trigger emission: fire `on_player_attack` and `on_low_health`, and choose one pathway (signal or direct `handleEvent`) to avoid duplicated trigger plumbing.
3. Lock down resource/overheat rules (gating vs. negative mana), make regen respect overheat if desired, and charge mana/delay/cooldown on child casts; hook meta `add_mana_amount` into wand state.
4. Call `TagEvaluator.evaluate_and_apply` whenever decks/boards change or wands load so tag thresholds, Joker scalers, and tag discovery events stay current.
5. Flesh out non-projectile/on-hit actions (hazard, summon, teleport, meta resource, knockback, chain lightning, shield/AOE heal, on-death) against combat/physics systems.
6. Wire avatar unlock/equip: `avatar_system.lua` now exists and is invoked from `TagEvaluator`; feed it runtime metrics (kills, distance, damage blocked) and expose equip/active avatar into wand/joker logic.




# Final goal
Make it easy (less hassle, all things in place) to implement the actual behavior of the projectiles, jokers, artifacts, etc.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
