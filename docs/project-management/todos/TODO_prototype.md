

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
- everything casts via triggers. artifacts hold triggers, and so do wands. artifacts should have more far-reaching or global effects, while wands mostly do projectile and other in game actions. 
- what actions matter? dash, touching enemy, killing enemy... put together a list of triggers we can use, and let's arrive at three stats we can boil them down to. then we will tie the attack, defense, attack speed, and other stats that we will be allowing the player to upgrade upon level up.
- triggers and actions as part of a bigger wand (item? artifact?) that you can move around and replace? maybe  a deck that can be clicked to expand it (for better ux.) decks could have fixed triggers & sometimes always casts (or shuffle) and variations in max card slot size, cast block size, cast speed, wand cooldown,  etc to make things more interesting.
- Maybe give wand equip requirements? triggers as well?
- Some basic stats:
    - physique: health, armor, knockback resistance
    - cunning: damage, critical chance, attack speed
    - spirit: cooldown reduction, luck
- make dash distance stat-based, and vary particle effects based on that.

# Non-stat values:
- player level. 

# Things to do in downtime.
- web build resuming visibility is terrible. also disable telemetry for now until we do a demo.
- intermittent flicker when projectiles are wiped? not sure why.
- got to also test the new batching queue system.
- give execution preview simple tooltips so I know what each one is. > buggy though.
- give trigger cards tooltips.
    
# programming side



- enemy knockback on projectile collision, direction-facing particles when theyc collide with wall. recoil when launching (or at least show animatino, as well as shot vfx)
- make achievements show one by one even if there are multiple so I can play sound fx
- tag evaluation should show current active tag combos on right side of screen.
- isolate shop ui to shop state only. also needs work. where is the gold, the jokers, etc?
- shop ui is terrible needs rework. put example jokers & avatars in the shop.

- Display a simple tutorial text on the background whne spawning in for first time (entering action state). Just text that shows keys (or controller) to press for movement and dash.
- Mouse aim indicator (triangle), option to enable auto-aim nearest enemy with a key. (display key image (both for controller and keyboard) on bottom right)
- destrutible objects that spawn from time to time and give resources?
- Make enemies actually die when they reach 0 hp and spawn exp drops, remove auto drops for exp.

- let's show three entities basic rects for now, which can be clicked, (pausing the game of course), to choose what stat to improve. a tooltip (refer to card tooltips) should explain what each stat does. jiggle them on hover, and when they first appear, they should smoothly tween in one by one.
- we should show current level number somewhere on the actoin phase screen.
- we need a button that will show current stats of the player (those that are relevant.)
- we need small rectangles with numbers 1-4 in them for the wand slots. when hovered, they should show a tooltip with the relevant stats for the wands.
- we need to add gold to the shop and gold screen.


- we need a transition which animates the current gold, then shows in a jiggle how much interest was earned, then closes the transition.

- we need a generic queue for rectangles with messages in them as well as an icon (animation or sprite) on the bottom right corner. we'll test it with test sprite and a test message from time to time. this will be used to show achievements or other relevant data.

- we need to flesh out the shop. let's extend how it looks now. there should be a rounded rect for showing 3 shop offers (just cards)
- A button for removing a card.
- a button for locking the offers of the shop. when lock is in place, a sprite should be rendered above each item offered by the shop to indicate it is locked.
- A button for rerolling the shop, at escalating cost (initial cost is 5 gold)
- A dynamic text for showing current gold balance (gold is decimal internally, round for display)
- a rounded rect area for purchasing jokers.
- a fancy dynamic text for "SHOP" somewhere prominent. 
- please suggest other features from shop_system.lua


- right now, moving after dash is infinite, might want to make a mechanic from that.

- refer to balatro_analysis folder for design elements.

- cast combo ui: just show cast feed ui in both action and planning state.
- discovery tags: we need to show this with toasts sort of thing.
- Display the tags in the card ui.
- make card tooltips appear next to cards.
- Get basic systems like wand executor, discovery, most importantly cast events firing and the ui showing, up so I can get started.


- refer to wand_cast_feed_integration_steps.md for wand → cast feed integration steps.
- maybe pause game before starting action phase to evaluate cards once, show discoveries, etc?
- lag at start may have to do with the tests. gotta make sure.

- need to make level up screen. instead of doing ui, let's spawn something on the center of the map - three choices that player can select, a pip pops up for input when player gets close, of the three stats.
- then player progresses through 3 stages, the last of which is extra hard.


- also need currency. display it somewhere on the screen in the shop and planning phases.


- flesh out shop. display currency with dynamic text, add reroll and lock buttons. we should probably have a way to preview player's belongings & wands & inventory. as well as a return to planning button, and a go button for action.
- Avatar slot. leave empty for now. maybe use stencil to have a rectangle area that has stripes animated through it.
- Relic slot. Maybe ROR like bar which can be filled. 


- brainstorm how best to visualize the execution order of the cards to the player. maybe use arrows?

- exp drops, leveling, stat integration. start with hp  also currency (gold? what will monsters drop?) + complete autobattle loop with interest.


- need to add cumulative wand state per cycle, as well as per cast block state that adds together stats from the cards in that block. -> probably do this in the execution phase.

- make a couple of artifacts that add additional trigger + effects, which can be equipped & upgraded.

- implement level-ups. just grant +5 to a chosen stat.
- maybe a few example character classes that focus on different stats or have specific set triggers/actions/mods they start with, in addition to having different starting stats, fixed bonuses that they only have, boons?
- add basic triggers, actions, and modifiers and hook them up to gameplay.
- mods projectile_pierces_twice and summon_minion_wandering not implemented. 
- apply card tag synergies: mobility, defense, hazard, brute
- think up and  apply card upgrades. e.g., bolt -> takes on an element -> pierces 3 times -> explodes on impact. We  need an upgrade resource, and an area where upgrades can be applied.

# errors
- toasts show icon below the bg rectangle.
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
- buttons of some kind to quickly press to send card up to wand or back to inventory, maybe popping out behind card? what would this look like?
- color code wand slots + trigger area + card area so that it's easy to swap between them.
- Then have a button that pops up when you click a card (or a pip if it's controller) that says "to wand" or (if already in wand) "to inven". Shortcut keys to swap to trigger inventory or card inventory.
- web - why do the scanline things disappear on web?
- [ ] cursor hover doesn't work fully correctly when controller (points to wrong card sometimes)
- [ ] Move health bar to player and hide when not in use. Show health bars for enemies too. 
- [ ] add stamina ticker to player that vanishes after a few seconds of not dashing.
- Add card 3d rotation for when initially dropped?
- make dashed lines be used only when a trigger + action is valid and active.
- Make main menu navigatble with controller. check that cursor teleports to selected button when using controller.
- add prompts, left trigger + direction to drag card left or right. left and right bumpers to switch areas. also teleport mouse to selected card when controller nav used. disable mouse clicking with controller.


- use the new itch assets to indicate icons for wands & when they are on cooldown.
- more variation in coin collect sounds
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