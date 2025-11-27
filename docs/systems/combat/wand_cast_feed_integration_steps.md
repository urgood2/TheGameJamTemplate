# Wand → Cast Feed Integration Steps

Practical checklist to wire the wand execution stack to the Cast Feed UI (events → signal bus → UI).

## 1) Boot / Lifecycle
- Require once: `local WandExecutor = require("wand.wand_executor")`, `local CastFeedUI = require("ui.cast_feed_ui")`.
- During game startup (before gameplay begins), call:
  - `WandExecutor.init()` (sets up triggers, projectile system, state tables).
  - `CastFeedUI.init()` (registers hump.signal listeners).
- Every frame tick: `WandExecutor.update(dt)` to drive triggers/projectiles/cooldowns, and `CastFeedUI.update(dt)` followed by `CastFeedUI.draw()` while the HUD is visible. Mirror this in both Planning and Action HUD loops if you want the feed in both states.

## 2) Deck changes (to emit tag discoveries)
- Whenever a deck/board changes, call `TagEvaluator.evaluate_and_apply(player, deck_snapshot, ctx)`.
  - This emits `tag_threshold_discovered` via `hump.signal` and stores discoveries on the player.
  - Keep `player.tag_counts` updated so discoveries and synergies stay in sync with the UI.

## 3) Casting path (to emit spell/joker events)
- Ensure wands are loaded with `WandExecutor.loadWand(wandDef, cardPool, triggerDef)` and that the active trigger calls `WandExecutor.execute(...)`.
- The execute path already:
  - Identifies `spell_type` via `SpellTypeEvaluator`.
  - Triggers jokers via `JokerSystem.trigger_event`.
  - Emits:
    - `on_spell_cast` with `{ spell_type, tag_analysis?, actions? }`
    - `on_joker_trigger` with `{ joker_name, message? }`
    - `spell_type_discovered` when `TagDiscoverySystem.checkSpellType` returns new.

## 4) UI wiring expectations
- CastFeedUI consumes signals only; no direct calls needed after `init`.
- Event payloads the UI expects:
  - `on_spell_cast`: `spell_type` (string), optional `tag_analysis`, `actions`.
  - `on_joker_trigger`: `joker_name` (string), optional `message`.
  - `tag_threshold_discovered`: `tag` (string), `threshold` (number), `count` (number).
  - `spell_type_discovered`: `spell_type` (string).
- Keep a single shared `external.hump.signal` instance (avoid multiple copies of the module path).

## 5) Minimal code sketch (for your main gameplay loop)
```lua
-- One-time setup
local WandExecutor = require("wand.wand_executor")
local CastFeedUI   = require("ui.cast_feed_ui")
WandExecutor.init()
CastFeedUI.init()

-- Frame tick (in the HUD-visible states)
function update(dt)
    WandExecutor.update(dt)
    CastFeedUI.update(dt)
    CastFeedUI.draw()
end
```

## 6) Validation / smoke tests
- Headless script: `lua assets/scripts/wand/test_cast_feed_runner.lua` (wand execute → signals).
- UI listener script: `lua assets/scripts/ui/test_cast_feed_discoveries.lua` (signals → UI items list).
- In-game: perform a cast that yields a known spell type (e.g., Twin Cast) and a Joker trigger; verify the feed shows the spell type, the joker message, and any new tag/spell discoveries.
