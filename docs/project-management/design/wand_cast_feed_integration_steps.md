# Wand → Cast Feed Integration Steps

Practical checklist to wire the wand execution stack to the Cast Feed UI (events → signal bus → UI).

## 1) Boot / Lifecycle (what to require and when)
- Require once: `local WandExecutor = require("wand.wand_executor")`, `local ProjectileSystem = require("combat.projectile_system")`, `local CastFeedUI = require("ui.cast_feed_ui")`.
- Startup (before gameplay): call `WandExecutor.init()`, `ProjectileSystem.init()`, `CastFeedUI.init()`.
- Per-frame tick:
  - Always: `WandExecutor.update(dt)` (drives triggers, cooldowns, jokers; orchestrates cast flow).
  - Always: `ProjectileSystem.update(dt)` (moves projectiles, runs collision/lifetime).
  - When HUD visible (planning or action): `CastFeedUI.update(dt)` then `CastFeedUI.draw()`. If the feed should appear in both planning and combat, call these in both HUD loops.

## 2) Deck changes (tag discoveries and synergies)
- On any deck/board change: `TagEvaluator.evaluate_and_apply(player, deck_snapshot, ctx)`.
  - Emits `tag_threshold_discovered` via `hump.signal`.
  - Keeps `player.tag_counts` current for other systems (jokers, spell typing, procs).
  - Applies/removes tag bonuses on the player (stats/procs).

## 3) Casting path (spell/joker/discovery emits)
- Load wands with `WandExecutor.loadWand(wandDef, cardPool, triggerDef)`; triggers must call `WandExecutor.execute(wandId, triggerType)`.
- Execution pipeline already does:
  - Spell typing via `SpellTypeEvaluator`.
  - Joker hooks via `JokerSystem.trigger_event`.
  - Discoveries via `TagDiscoverySystem.checkSpellType`.
  - Emits (all on `hump.signal`):
    - `on_spell_cast`: `{ spell_type, tag_analysis?, actions? }`
    - `on_joker_trigger`: `{ joker_name, message? }`
    - `spell_type_discovered`: `{ spell_type }`

## 4) Projectile system fit
- Source: `assets/scripts/combat/projectile_system.lua`.
- Inputs: `WandActions.execute` passes card + modifier data into `ProjectileSystem.spawn` (movement type, collision behavior, damage, homing targets, pierce/bounce/explode counts, callbacks).
- Outputs (signals):
  - `projectile_spawned` (entity, data)
  - `projectile_hit` (projectileEntity, hitData)
  - `projectile_exploded` (projectileEntity, hitData)
  - `projectile_destroyed` (entity, data)
- Use these signals for downstream effects (e.g., on-hit procs, chained casts) without coupling UI to projectile internals.

## 5) UI wiring expectations
- CastFeedUI is read-only: it only listens to signals and renders.
- Required payload shapes:
  - `on_spell_cast`: `spell_type` (string); optional `tag_analysis`, `actions`.
  - `on_joker_trigger`: `joker_name` (string); optional `message`.
  - `tag_threshold_discovered`: `tag` (string), `threshold` (number), `count` (number).
  - `spell_type_discovered`: `spell_type` (string).
- Keep a single shared `external.hump.signal` instance (consistent require path).

## 6) Minimal code sketch (HUD-aware)
```lua
-- One-time setup
local WandExecutor     = require("wand.wand_executor")
local ProjectileSystem = require("combat.projectile_system")
local CastFeedUI       = require("ui.cast_feed_ui")

WandExecutor.init()
ProjectileSystem.init()
CastFeedUI.init()

-- Frame tick
function update(dt)
    WandExecutor.update(dt)
    ProjectileSystem.update(dt)
    if hud_is_visible then
        CastFeedUI.update(dt)
        CastFeedUI.draw()
    end
end
```

## 7) Validation / smoke tests
- Headless wand → signal: `lua assets/scripts/wand/test_cast_feed_runner.lua`.
- UI listener: `lua assets/scripts/ui/test_cast_feed_discoveries.lua`.
- In-game: perform a cast that yields a known spell type (e.g., Twin Cast) and a Joker trigger; confirm feed shows spell type, joker message, and any new tag/spell discoveries; ensure projectiles appear and hit callbacks fire without breaking the feed.

## 8) Structural overview (where things live)
- UI: `assets/scripts/ui/cast_feed_ui.lua` (signal listeners, animations, draw).
- Wand core: `assets/scripts/wand/` (`wand_executor`, `wand_triggers`, `wand_actions`, `wand_modifiers`, `spell_type_evaluator`, `joker_system`, `tag_evaluator`, `tag_discovery_system`; docs/tests alongside).
- Projectiles: `assets/scripts/combat/projectile_system.lua` (spawn/update/collide/signals).
- Glue points in gameplay loop: `assets/scripts/core/gameplay.lua` (already requires `CastFeedUI`, calls `init/update/draw`; mirror in action HUD as needed). 

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
