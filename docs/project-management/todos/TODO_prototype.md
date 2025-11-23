

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

# Genre analysis
https://chatgpt.com/share/69192a61-8814-800a-8e04-eb8fb8001d38


# stat ideas
- triggers and actions as part of a bigger wand (item? artifact?) that you can move around and replace? maybe  a deck that can be clicked to expand it (for better ux.) decks could have fixed triggers & sometimes always casts (or shuffle) and variations in max card slot size, cast block size, cast speed, wand cooldown,  etc to make things more interesting.
- Maybe give wand equip requirements? triggers as well?
- Some basic stats:
    - physique: health, armor, knockback resistance
    - cunning: damage, critical chance, attack speed
    - spirit: cooldown reduction, luck

# Non-stat values:
- player level. 
    
# programming side
- nothing rendring, check past commit and command buffer change.
- continue testing checklist, finish refactor, test the projectiles, test ldtk, get ready for gameplay impelementation.

- I need to continue with "testing_checklist." starting with projectile system.
- got to also test the new batching queue system.
- issue error on closing via x again.

- highlight mod cards as well in the simulator. use the same color highlight for each cast block, to make it easier to see.
- add an option to stop the ticking noise.

- after that, make it so cards which are above the wand total are marked with an X
- cards which are not used should also be marked with an X 

- add uibox layer specification back in without brekaing anything please.


- more variation in coin collect sounds
- make dash distance stat-based, and vary particle effects based on that.
- make trigger area accept only one card.


- test shaders: item_glow, fireworks
- only vaccum collapse seems to work so far. fireworks also works, but I need to know the right values for the uniforms.
- glow doesn't seem to blend with background. why?
- test new stingers for lootbox open.
- [ ] Do fireworks, then the rush thing when you get an item. 

- Need to make tooltips smaller and more readable. how?



- [ ] cursor hover doesn't work fully correctly when controller (points to wrong card sometimes)
- [ ] Move health bar to player and hide when not in use. Show health bars for enemies too. 
- [ ] add stamina ticker to player that vanishes after a few seconds of not dashing.

- start wand evaluation mechanism.

- Make main menu navigatble with controller. check that cursor teleports to selected button when using controller.
- add prompts, left trigger + direction to drag card left or right. left and right bumpers to switch areas. also teleport mouse to selected card when controller nav used. disable mouse clicking with controller.
- implmement needsResort flag for card dragging (card needs to konw which board it belongs to)

- use the new itch assets to indicate icons for wands & when they are on cooldown.
- exp drops, leveling, stat integration. start with hp and basic enemy attacks. also currency (gold? what will monsters drop?) + complete autobattle loop with interest.
- Make a vertical alice with several chosen cards, 1 trigger, some enemy waves, and shop



- buttons of some kind to quickly press to send card up to wand or back to inventory, maybe popping out of card?

- need to add cumulative wand state per cycle, as well as per cast block state that adds together stats from the cards in that block. -> probably do this in the execution phase.
- implement card evaluation order using actual cards to see how it behaves.
- make a couple of artifacts that add additional trigger + effects, which can be equipped & upgraded.


- Add card 3d rotation for when initially dropped?
- behaviors I can visualize for objects: homing, orbiting. Just alter collider position and speed.
- make dashed lines be used only when a trigger + action is valid and active.
- add new stats with below:
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
- mods projectile_pierces_twice and summon_minion_wandering not implemented. 
- apply card tag synergies: mobility, defense, hazard, brute
- think up and  apply card upgrades. e.g., bolt -> takes on an element -> pierces 3 times -> explodes on impact. We  need an upgrade resource, and an area where upgrades can be applied.
- also need currency.

# errors
- there's a memory leak in the wasm version.
- starry_tunnel shader not working.
- Using 3d_skew shader on cards makes player invisible. why?
- rendeirng background sometimes goes translucent. not sure why?
- ui strings in tooltips overlap bounds for some reason.
- entities not getting filtured porperly, camera not always kicking in.
- boards stop updating when I change state. why?
- test that transform lerping to body is working.
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
- Consider making a draw command injector and hand-coding shader start/end for pipeline instead of using pipeline as it stands if there are many sprites (like skew for cards) this will prevent texture ping-pong.
- Use luajit. It doesn't work ATM. (doens't work for web anyway, skip?)
- make timers state-sensitive by using cached games state, with optional parameter when creating timer to indicate this.
- Continue profiling.
- Consider using luajit for release.

# shaders to add
- [ ] https://godotshaders.com/shader/2dradial-shine-2/
- [ ] https://godotshaders.com/shader/2dfireworks/
- [ ] https://godotshaders.com/shader/2dstarry-tunnel/
- [ ] The above three for item scenes.
- [ ] For cyclic ui: https://godotshaders.com/shader/double-sided-transparent-gradient/
- [ ] sprite occlusion: https://godotshaders.com/shader/occlusion-outline-for-godot-4/ (maybe)
- [ ] black hole effect for spells: https://godotshaders.com/shader/polar-coordinate-black-hole/
- [ ] really nice vanishing/appear effect https://godotshaders.com/shader/vacuum-collapse/
- [ ] backgrounds belwo:
- [ ] https://godotshaders.com/shader/liquid-plasma-swirl/
- [ ] https://godotshaders.com/shader/abstract-3d/
- [ ] rotating progress display clockwise for icons https://godotshaders.com/shader/clockwise-pixel-outline-progress-display/
- [ ] edge gradient color for cards, etc. https://godotshaders.com/shader/edge-gradient-border-shader/
- [ ] Add glow to specfiic sprites: https://godotshaders.com/shader/item-pulse-glow/

# polish phase
- [ ] disable decel on arrival 
- [ ] turn pickups into sensors?
- [ ] drop shadow implementation (do lua side, avoid bugs)
- [ ] be sure to use camera rotation jiggle on polish
- [ ] Record scratching sound for when time slow?
- [ ] give initial impulse when spawning items.

- [ ] slow time slightly when player gets too close to an enemy?
- [ ] add after() to each particle method that allows chaining another particle effect after the first one ends.
- [ ] function to give ui a bump, as well as flash for a moment, as well as vanish. as well as ambient rotate. -> it works, but needs some work, since buttons that contain images, etc. can't do this yet.
- [ ] Some ambient movement (rocking) to items/ui
- [ ] integrate new music from eagle folder.
- [ ] Some bg or shader overlay effects for individual sprites  / map\
- normalize sound effects?
- layer particle effects of different colors
- limit camera movement to not go certain distance beyond center?
- size boing not working fo rplayer on hit.
- add a physics sync mode that completey desyncs rotation. then test using it with the skellies.
- juice the ui bars with springs.
- add per-card 3d skew shader pass, disabled when card interacted with. also change 3d skew shader to make card tilt toward mouse, right now it's not facing mouse.
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


# potential soundtracks (ask for permission first)
- https://smiletron.bandcamp.com/album/self-titled (4/5)
- https://smiletron.bandcamp.com/album/signals (3/5)
- https://smiletron.bandcamp.com/album/solstice (4/5)
- https://soundcloud.com/biggiantcircles/the-glory-days-sevcon-full?si=405318c952a14c879be01f1c9d926b9f&utm_source=clipboard&utm_medium=text&utm_campaign=social_sharing -> (4/5)

# release & testing
- clean up web builds to not include .mds and stuff
- Enable github actions + auto loading to itch.io on new release.
- Explore ways to cleanly remove tracy instrumentation from lua scripts & c++ for release builds.
- Clean up build files so that no docs or unnecessary source files are included.
- Playtest and get feedback from friends.


# particle polish considerations
- [ ] Chromatic abberation on hit. 
- [ ] Particles that dwindle in size iregularly (pixelation + rotation) + gravity
- [ ] Same colored expanding circle outline
- [ ] Flash with filled circle
- [ ] Diamond hit fx centered on impact point& roatated to face the point + dwindling after
- [ ] The sprite itself changing size in hit and going back to normal
- [ ] Spreading circular ripple - irregular shape + fading
- [ ] Multiple-point shader distortion (ripple)
- [ ] Pulsing points of light as sources for lightning
- [ ] Particles in area traveling toward center & concentric circles traveling toward center & causing wobble + growing circle size + exploding with fat particles, directin
- [ ] Lightning lines from a to b