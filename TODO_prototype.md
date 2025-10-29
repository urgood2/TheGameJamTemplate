- Projectiles
Basic test projectile
Fast, accurate projectile
Slow orb with medium damage
Explosive fire projectile
Ricochets off surfaces
Heavy gravity-affected object projectile
Sucks in other projectiles & creatures

- Modifiers
Seeks enemies
Increases projectile speed
Decreases projectile speed
Reduces spread angle
Increases projectile damage
Shortens projectile lifetime
Casts next spell on hit (Add trigger)
Casts next spell after delay (Add timer)
Triggers next spell on projectile death

- Multicasts
Casts next two spells at the same time
Casts next three spells
Casts next five projectiles in circular formation

- Utilities
Moves caster to impact point
Creates healing area at current location
Creates a shield bubble at current location
Summons an ally entity

- Super recasts & meta
Recasts first spell in wand
Applies all modifiers in wand to next projectile
Casts all spells in wand at once
Converts encumbrance into damage


# stat ideas
- Maybe give wand equip requirements? triggers as well?


# Non-stat values:
- player level.
    
# programming side
- add some basic music to battle scene & planning scene.
- Make main menu navigatble with controller.
- Some edge behavior when controller navigates to either edge of card area.
- implement switching between areas. bumper + direction for switching between areas. dpad or analog stick for navigating inside area.. when gamepad connected, draw gamepad nav hints on screen. with sprites. Y for send to trigger, b for send to action area. show a border around the selected card. make cursor move to the selected card (not working atm for some reason.)
- implmement needsResort flag for card dragging (card needs to konw which board it belongs to)
- test new controller nav.
- lua timer state guard (entity state management, optional)
- caching of scripts per entity to avoid repeated loads, also delete from cache on entity deletion. also cache transform calls.
- make card area shift cards to left and right of new card.

- apply the new assets, including some music and ui.
- explore performance optimizations to existing code for a bit, with tracy.
- particles that are more random in distance and lifetime. and maybe smaller. randomized colors too.
- controller nav https://chatgpt.com/share/68fc7589-3a60-800a-afb0-ffa4fba94e0a
- use the new itch assets to indicate icons for wands & when they are on cooldown.
- controller input pass so I can seamlessly control ui & cards with only controller. probably make a system for that.
- Add transition like in snkrx. how does that work? use whoosh.
- exp drops, leveling, stat integration. start with hp and basic enemy attacks. also currency (gold? what will monsters drop?) + complete autobattle loop with interest.
- Make a vertical alice with several chosen cards, 1 trigger, some enemy waves, and shop



- buttons of some kind to quickly press to send card up to wand or back to inventory, maybe popping out of card?

- need to add cumulative wand state per cycle, as well as per cast block state that adds together stats from the cards in that block. -> probably do this in the execution phase.
- implement card evaluation order using actual cards to see how it behaves.
- make a couple of artifacts that add additional trigger + effects, which can be equipped & upgraded.

- puzzle: Way to inject draw calls queue so they happen inside a transform’s shader? Doing it via lua callback is too demanding. 

- controler input: Sets of objects that can be selected, maybe by tag. Method to toggle between them, possibly merging. Dpad and axis movement detection to allow selection. Got to be compatible with existing ui input system, maximally extensible. Toggle to turn the system on and off. 

- Add card 3d rotation for when initially dropped?
- behaviors I can visualize for objects: homing, orbiting. Just alter collider position and speed.
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
- implement level-ups. just grant +5 to a chosen stat.
- maybe a few example character classes that focus on different stats or have specific set triggers/actions/mods they start with, in addition to having different starting stats, fixed bonuses that they only have, boons?
- add basic triggers, actions, and modifiers and hook them up to gameplay.
- mods projectile_pierces_twice and summon_minion_wandering not implemented. why is minion wandering a mod?
- apply card tag synergies: mobility, defense, hazard, brute
- think up and  apply card upgrades. e.g., bolt -> takes on an element -> pierces 3 times -> explodes on impact. We  need an upgrade resource, and an area where upgrades can be applied.
- also need currency.

# errors
- enemies move too slowly?
- cards to immeidate left & right jitter when pushed aside for selection.
- probably make a physics timer that runs every physics step, instead of relying on main loop timer. how to do this with lua, though? callbacks are slow. physics is jerking from place to place. why is that? jumping back and forth.
- transforms sometimes get jerky. why? -> take a look at sync between physics and transform.
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

# performance considerations
- make timers state-sensitive by using cached games state, with optional parameter when creating timer to indicate this.
- Continue profiling.
- Consider using luajit for release.

# polish phase
- graphics need to coalesce. snkrx looks nice. how to replicate?
- particles with a specific arc (like splashing in a certain direction)
- experiment with glowing background behind a card to show selection/effect (colorful, glowing, random)
- some nice ui https://www.youtube.com/watch?v=Rkd5SYT10UQ as reference
- add glow to crt as well, and add proper scanlines.
- integrate proper hit fx, with blinking.
- make steering face direction of movement.
- mmake sprites blink upon hit fx. 
- [ ] buttons with a scrolling background.
- [ ] Need to apply the crossed lines for crt.
- [ ] glow for selected sprites. Also, do a background, noise based and squiggly, and make it glow with rainbow coolors.
- [ ] just images - cards. Attach numbwers to them. Then show color-coded text to the side, with Icons.
- sound effects.
- steering should turn toward direction it is going.
- music.
- make sprites blink for effect, like dying or damage.
- shader pass for legibility (change crt maybe)

# release & testing
- Enable github actions + auto loading to itch.io on new release.
- Explore ways to cleanly remove tracy instrumentation from lua scripts & c++ for release builds.
- Clean up build files so that no docs or unnecessary source files are included.
- Playtest and get feedback from friends.