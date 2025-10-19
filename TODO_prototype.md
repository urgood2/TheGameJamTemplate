local action_card_defs = 
        id = "fire_basic_bolt"
        id = "leave_spike_hazard",
        id = "temporary_strength_bonus"
trigger_card_defs
        id = "every_N_seconds"
        id = "on_pickup"
        id = "on_distance_moved"
modifier_card_defs 
        id = "double_effect"
        id = "summon_minion_wandering"
        id = "projectile_pierces_twice"
        id = "summons_targtes_detonate"
        id = "reduce trigger interval after this action"
        id = "duplicate action, but both are weakened."
        id = "enhance + damage or + duration"

# Non-stat values:
- player level.
    
# programming side
- reInitializeGame - finish implementing this and test.
- use begin() callback to detect collision between player and enemies, then show an effect + slow time.
- make dashed lines be used only when a trigger + action is valid and active.
- add new stats with 
```lua
add_basic(defs, 'projectile_count')
-- modify
player.stats:add_base('projectile_count', 1)
-- derived stats
player.stats:on_recompute(function(S)
  local p = S:get_raw('physique').base
  local c = S:get_raw('cunning').base
  local s = S:get_raw('spirit').base

  S:derived_add_base('health', 100 + p * 10)
  S:derived_add_base('energy', 50 + s * 5)
  S:derived_add_base('offensive_ability', c * 2)
end)
-- set cooldowns (arbitrary)
if ctx.time:is_ready(player.timers, "attack") then
  shoot_projectile(player)
  ctx.time:set_cooldown(player.timers, "attack", 0.5) -- attack every 0.5s
end
-- access a stat:
local count = math.floor(player.stats:get('projectile_count'))
for i = 1, count do
  shoot_projectile(player)
end
-- custom leveliing logic:
player.level = 1
player.xp = 0

player.stats:on_recompute(function(S)
  local lvl = player.level
  S:derived_add_mul_pct('health', lvl * 5)
  S:derived_add_mul_pct('attack_speed', lvl * 3)
end)
```
- link up the combat stat system with the traps and strength bonus action.
- Collision between player and enemies.
- implement level-ups. just grant +5 to a chosen stat.
- maybe a few example character classes that focus on different stats or have specific set triggers/actions/mods they start with, in addition to having different starting stats, fixed bonuses that they only have, boons?
- add basic triggers, actions, and modifiers and hook them up to gameplay.
- mods projectile_pierces_twice and summon_minion_wandering not implemented. why is minion wandering a mod?
- apply card tag synergies: mobility, defense, hazard, brute
- think up and  apply card upgrades. e.g., bolt -> takes on an element -> pierces 3 times -> explodes on impact. We  need an upgrade resource, and an area where upgrades can be applied.
- also need currency.

# errors
- z orders are not correct when cards overlap for the first time?
- card areas don't shift cards reliably when there are lots of cards in an area, and cards are dragged around inside -> probably a bug in the card area shifting logic.
- stacking cards misbehave in terms of z-order. Sometimes they move when clicked when they shouldn't.
- need a way to nudge colliders inward (or just center them) for better fit for player.
- Make it so when transform is authoritative rotation syncs always to transform rotation. Also, sometimes drag and drop stops working for cards, maybe because physics and transform? The collider seems to become inaccurate.
- Make a timer setting that ensures something gets called every render frame.
- drag & drop with physics bodies & transforms doesn't always work. objects will sometimes become unreactive or the collision shapes for transform change position. not sure why. only solution I've found is to complete remove physics afterward: physics.remove_physics(PhysicsManager.get_world("world"), card, true)

# design questions
- should trigger slots only have one trigger, or multiple?
- what properties do triggers have? delay between activations? chance to activate?
- should there be limits to how many actions and modifiers you can add to a card or area?
- better actions, like varied weapons in survivors such as area attacks, melee, etc.

# ui/ux questions
- should remove area only appear when player drags a card?
- should we show an overlay over an area if it isn't a valid drop target? How would we detect when to show it?
