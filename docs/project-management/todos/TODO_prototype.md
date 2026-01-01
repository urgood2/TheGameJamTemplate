# TODO Prototype - Organized Status Report
> Last verified: Dec 29, 2025


- remove click to enable card skew.
- extract description to new box under tooltip. 
- give name of card special effect.
- put rest in compact box.
- 

- ogg transition utility stops sound from working. some sounds work though. not sure why.
- make sure cast from event is working.

- need to test particle stencil working.
- get all three special items working properly.
- fill areas for panels + card areas. 
- sound effect for notification still not playing.
- tooltips should appear right next to the object they represent, never covering it, never going out of bounds, and vertically/laterally cnetered when possible in terms of alignment.
- new wave, stage completed, elite spawn, monster spawn sounds. 


- shader a la rocket rats -> we may want to just layer a shader that adds bubbly rainbow particles over the image.
- why is outline shader not working?
- card packs for each card type, opening sequence, choose 3 cards.
- state of enemy behaviors and ai setup>
- experiemnt with few-frame talking sprite character for tutorial.
- prettier tooltips, proper descriptions, textbuilder text.

---

## Projectiles

| Status | Item |
|--------|------|
| ~~DONE~~ | ~~Basic test projectile~~ |
| ~~DONE~~ | ~~Fast, accurate projectile~~ |
| ~~DONE~~ | ~~Slow orb with medium damage~~ |
| ~~DONE~~ | ~~Explosive fire projectile~~ |
| ~~DONE~~ | ~~Ricochets off surfaces~~ |
| ~~DONE~~ | ~~Heavy gravity-affected object projectile~~ |
| **STUB** | Sucks in other projectiles & creatures (data defined, logic NOT IMPL) |

---

## Modifiers

| Status | Item |
|--------|------|
| ~~DONE~~ | ~~Seeks enemies (MOD_HOMING, MOD_SEEKING)~~ |
| ~~DONE~~ | ~~Increases projectile speed (MOD_SPEED_UP)~~ |
| ~~DONE~~ | ~~Decreases projectile speed (MOD_SPEED_DOWN, MOD_BIG_SLOW)~~ |
| ~~DONE~~ | ~~Reduces spread angle (MOD_REDUCE_SPREAD)~~ |
| ~~DONE~~ | ~~Increases projectile damage (MOD_DAMAGE_UP)~~ |
| ~~DONE~~ | ~~Shortens projectile lifetime (MOD_SHORT_LIFETIME)~~ |
| ~~DONE~~ | ~~Casts next spell on hit - Add trigger (MOD_TRIGGER_ON_HIT)~~ |
| ~~DONE~~ | ~~Casts next spell after delay - Add timer (MOD_TRIGGER_TIMER)~~ |
| ~~DONE~~ | ~~Triggers next spell on projectile death (MOD_TRIGGER_ON_DEATH)~~ |

---

## Multicasts

| Status | Item |
|--------|------|
| ~~DONE~~ | ~~Casts next two spells at the same time (MULTI_DOUBLE_CAST)~~ |
| ~~DONE~~ | ~~Casts next three spells (MULTI_TRIPLE_CAST)~~ |
| ~~DONE~~ | ~~Casts next five projectiles in circular formation (MULTI_CIRCLE_FIVE_CAST)~~ |

---

## Utilities

| Status | Item |
|--------|------|
| **STUB** | Moves caster to impact point (UTIL_TELEPORT_TO_IMPACT - data exists, logic stub) |
| **PARTIAL** | Creates healing area at current location (UTIL_HEAL_AREA - self-heal works, AoE stub) |
| **STUB** | Creates a shield bubble at current location (UTIL_SHIELD_BUBBLE - data exists, logic stub) |
| **STUB** | Summons an ally entity (UTIL_SUMMON_ALLY - data exists, spawning logic stub) |

---

## Super Recasts & Meta

| Status | Item |
|--------|------|
| **NOT IMPL** | Recasts first spell in wand (META_RECAST_FIRST - flag exists, no executor logic) |
| **NOT IMPL** | Applies all modifiers in wand to next projectile (META_APPLY_ALL_MODS_NEXT - flag exists, no logic) |
| **PARTIAL** | Casts all spells in wand at once (META_CAST_ALL_AT_ONCE - works via multicast_count=999, flag ignored) |
| **NOT IMPL** | Converts encumbrance into damage (META_CONVERT_WEIGHT_TO_DAMAGE - flag exists, no logic) |

---

## Stats System

| Status | Item |
|--------|------|
| ~~DONE~~ | ~~Physique: health (100 + Physique*10)~~ |
| ~~DONE~~ | ~~Physique: health regen~~ |
| **NOT IMPL** | Physique: armor derivation |
| **NOT IMPL** | Physique: knockback resistance derivation |
| ~~DONE~~ | ~~Cunning: damage modifiers (physical_modifier_pct, pierce_modifier_pct)~~ |
| **NOT IMPL** | Cunning: critical chance derivation |
| **NOT IMPL** | Cunning: attack speed derivation |
| ~~DONE~~ | ~~Spirit: energy/energy regen~~ |
| **NOT IMPL** | Spirit: cooldown reduction derivation |
| **NOT IMPL** | Spirit: luck derivation |
| ~~DONE~~ | ~~Stat-based dash distance (+2 per Physique)~~ |
| ~~DONE~~ | ~~Player level system~~ |
| **MISMATCH** | Level-up grants stat bonus (currently +2, TODO says +5) |
| ~~DONE~~ | ~~Character classes/Origins with starting stats (origins.lua)~~ |

---

## Genre Analysis & Design Notes

- Reference: https://chatgpt.com/share/69192a61-8814-800a-8e04-eb8fb8001d38

### Stat Ideas (Design Notes - Not Code TODOs)
- Everything casts via triggers. Artifacts hold triggers, wands do projectile actions.
- Triggers and actions as part of bigger wand/deck with fixed triggers, shuffle, max slots, cast block size, cast speed, wand cooldown.
- Maybe give wand equip requirements? Triggers as well?
- Basic stats: physique (health, armor, knockback), cunning (damage, crit, atk speed), spirit (CDR, luck)

### Non-stat values
- Player level (DONE)

---

## Things to Do in Downtime

| Status | Item |
|--------|------|
| **OPEN** | Web build resuming visibility is terrible |
| **OPEN** | Disable telemetry for now until demo |
| **OPEN** | Intermittent flicker when projectiles are wiped |
| **OPEN** | Test the new batching queue system |
| **OPEN** | Performance pass with Tracy & profiling necessary |

---

## Programming Side

| Status | Item |
|--------|------|
| ~~FIXED~~ | ~~Enemies spawning outside arena bounds~~ |
| **DONE** | When alt key is down, bring hovered card to front |
| ~~DONE~~ | ~~Tooltip needs to never cover the card (positioned to right with gaps)~~ |
| **OPEN** | How will player know when a mod works with an action card or not? |
| ~~DONE~~ | ~~Add descriptor strings for each card, as well as an icon~~ |
| ~~DONE~~ | ~~Make tooltip text smaller, display next to card~~ |
| **OPEN** | How to use crit feature in combat system with chain lightning and change the damage numbers to show? |
| **PARTIAL** | SFX: enemy impact, critical hit, bleed (self), heal, lightning (impact/heal/lightning done, bleed missing) |
| ~~DONE~~ | ~~Make enemies blink/flash on hit (hitfx.lua)~~ |
| **PARTIAL** | Flip a card to see upgrade level & tags (upgrade stars done, flip animation missing) |
| ~~DONE~~ | ~~Add stars to background, pulsing particles~~ |
| **OPEN** | Text builders still need some debugging |
| **OPEN** | Use new aseprite workflow to design own versions of cards |
| ~~DONE~~ | ~~Make shop a simple three-card thing~~ |
| **OPEN** | Consider using cute UI sounds |
| **OPEN** | Add other versions of JetBrains font |
| **OPEN** | Dropped frame issue with imgui & graphics commands lua side |
| **OPEN** | Get things ready to add content |
| **OPEN** | Sometimes the tutorial buttons are translucent, sometimes solid |
| ~~DONE~~ | ~~Move execution preview out of its window, place under card inventories~~ |
| ~~DONE~~ | ~~Treasure opening sequence (darken, chest shake, shader bg, escalations, particles)~~ |
| **OPEN** | Find assets, start designing better card graphics |
| **OPEN** | Use non-serif font for reading, serifs for titles, good contrast |
| **OPEN** | Apply texture shader overlay to UI |
| **OPEN** | Replace card sprites with real ones |
| **OPEN** | After UI/functionality in place, ensure easy ways to add interactions/items |
| **OPEN** | Sound pass to make interactions juicy, add music from ovani |
| **OPEN** | Make a prompt guideline based on current scripts |
| **OPEN** | Destructible objects that spawn and give resources |
| ~~DONE~~ | ~~Show current level number on action phase screen~~ |
| **OPEN** | Button to show current player stats |

---

## Shop System

| Status | Item |
|--------|------|
| ~~DONE~~ | ~~Rounded rect for 3 shop offers~~ |
| **UI DISABLED** | Button for removing a card (logic in shop_system.lua:449, UI commented out) |
| **UI DISABLED** | Button for locking shop offers (logic in shop_system.lua:368, UI commented out) |
| ~~DONE~~ | ~~Lock sprite indicator (buildLockIcon in ui_defs.lua)~~ |
| **UI DISABLED** | Button for rerolling shop at escalating cost (logic exists, UI commented out) |
| ~~DONE~~ | ~~Dynamic text for current gold balance~~ |
| ~~DONE~~ | ~~Rounded rect area for purchasing jokers (Joker Shelf)~~ |
| ~~DONE~~ | ~~Fancy dynamic text for "SHOP" header~~ |

---

## Testing New Features

| Status | Item |
|--------|------|
| **OPEN** | Test the new shader implementation with player sprite |
| **OPEN** | Test the new LDtk impl |
| **OPEN** | Test the new UI impl (won't use this time) |

---

## Gameplay Mechanics

| Status | Item |
|--------|------|
| **OPEN** | Moving after dash is infinite - might make a mechanic from that |
| **OPEN** | Refer to balatro_analysis folder for design elements |
| ~~DONE~~ | ~~Cast combo UI: show cast feed UI in both action and planning state~~ |
| **OPEN** | Discovery tags: show with toasts |
| **OPEN** | Display the tags in the card UI |
| ~~DONE~~ | ~~Make card tooltips appear next to cards~~ |
| ~~DONE~~ | ~~Get basic wand executor, discovery, cast events firing and UI showing~~ |
| **OPEN** | Player progresses through 3 stages, last is extra hard |
| **OPEN** | Flesh out shop: preview player belongings/wands/inventory, return to planning, go button |
| **OPEN** | Avatar slot (empty for now, maybe stencil with animated stripes) |
| **OPEN** | Relic slot (maybe RoR-like bar) |
| **OPEN** | Brainstorm visualization of execution order (arrows?) |
| **OPEN** | Exp drops, leveling, stat integration, currency + autobattle loop with interest |
| ~~DONE~~ | ~~Make tooltips jump to full size instead of tweening~~ |
| **OPEN** | Cumulative wand state per cycle, per cast block state |
| **OPEN** | Make artifacts that add trigger + effects, equippable & upgradeable |
| ~~DONE~~ | ~~Implement level-ups (currently +2, intended +5)~~ |
| **OPEN** | Character classes focusing on different stats with specific triggers/actions/mods |
| **OPEN** | Add basic triggers, actions, modifiers and hook to gameplay |
| **OPEN** | mods projectile_pierces_twice and summon_minion_wandering not implemented |
| **OPEN** | Apply card tag synergies: mobility, defense, hazard, brute |
| **OPEN** | Think up and apply card upgrades (e.g., bolt -> element -> pierces -> explodes) |

---

## Errors / Bugs

| Status | Item |
|--------|------|
| ~~FIXED~~ | ~~Toasts show icon below bg rectangle (z-order +100 fix applied)~~ |
| **OPEN** | Memory leak in WASM version (fix proposed, not applied) |
| **OPEN** | starry_tunnel shader not working |
| **OPEN** | Using 3d_skew shader on cards makes player invisible |
| ~~FIXED~~ | ~~Rendering background sometimes goes translucent (ClearTextures fix applied)~~ |
| **OPEN** | UI strings in tooltips overlap bounds (wrapTextToWidth proposed, not applied) |
| ~~FIXED~~ | ~~Entities not getting filtered properly, camera not always kicking in~~ |
| **OPEN** | Boards stop updating when I change state |
| **OPEN** | Transform lerping to body issues (fix proposed, not applied) |
| **OPEN** | Enemies move too slowly? |
| **OPEN** | Cards to immediate left & right jitter when pushed aside for selection |
| **OPEN** | Physics timer / physics jerking issues |
| **OPEN** | Transforms sometimes get jerky (physics-transform sync) |
| **OPEN** | Z-orders not correct when cards overlap first time (fix proposed, not applied) |
| **OPEN** | Card areas don't shift cards reliably with many cards (fix proposed, not applied) |
| **OPEN** | Stacking cards z-order misbehavior |
| **OPEN** | Need way to nudge colliders inward for better player fit |
| **OPEN** | Make transform authoritative rotation sync always to transform rotation |
| **OPEN** | Make a timer setting that ensures something gets called every render frame |
| **OPEN** | Drag & drop with physics bodies doesn't always work (fix proposed, not applied) |

---

## Design Questions (Not Code TODOs)

- Should trigger slots only have one trigger, or multiple?
- What properties do triggers have? Delay? Chance?
- Should there be limits to actions/modifiers per card/area?
- Better actions like varied weapons (area attacks, melee, etc.)

---

## UI/UX Questions (Not Code TODOs)

- Should remove area only appear when player drags a card?
- Should we show overlay over invalid drop targets? How to detect?

---

## Performance Considerations

| Status | Item |
|--------|------|
| **OPEN** | Consider draw command injector for shader start/end to prevent texture ping-pong |
| **SKIP** | Use LuaJIT (doesn't work for web) |
| **OPEN** | Make timers state-sensitive with cached game state |
| **OPEN** | Continue profiling |
| **OPEN** | Consider LuaJIT for release (non-web) |

---

## Shaders to Add

| Status | Shader | Source |
|--------|--------|--------|
| ~~DONE~~ | ~~2dradial-shine-2 (radial_shine_2d)~~ | godotshaders.com |
| ~~DONE~~ | ~~2dfireworks (fireworks_2d)~~ | godotshaders.com |
| ~~DONE~~ | ~~2dstarry-tunnel (starry_tunnel) - EXISTS but BROKEN~~ | godotshaders.com |
| **NOT IMPL** | double-sided-transparent-gradient (cyclic UI) | godotshaders.com |
| **NOT IMPL** | occlusion-outline (sprite occlusion) | godotshaders.com |
| **NOT IMPL** | polar-coordinate-black-hole (spell effect) | godotshaders.com |
| ~~DONE~~ | ~~vacuum-collapse (vanish/appear effect)~~ | godotshaders.com |
| **NOT IMPL** | liquid-plasma-swirl (background) | godotshaders.com |
| **NOT IMPL** | abstract-3d (background) | godotshaders.com |
| ~~DONE~~ | ~~clockwise-pixel-outline-progress-display (cooldown_pie)~~ | godotshaders.com |
| **NOT IMPL** | edge-gradient-border-shader (cards) | godotshaders.com |
| ~~DONE~~ | ~~item-pulse-glow (item_glow)~~ | godotshaders.com |

---

## Polish Phase

| Status | Item |
|--------|------|
| ~~DONE~~ | ~~Quick buttons to send card to wand/inventory (right-click, alt-click)~~ |
| ~~DONE~~ | ~~Color-code wand slots + trigger area + card area~~ |
| **OPEN** | Web - scanline things disappear on web |
| **OPEN** | Cursor hover doesn't work fully correctly with controller |
| ~~DONE~~ | ~~Move health bar to player and hide when not in use~~ |
| ~~DONE~~ | ~~Show health bars for enemies~~ |
| ~~DONE~~ | ~~Add stamina ticker that vanishes after not dashing~~ |
| ~~DONE~~ | ~~Card 3D rotation for when initially dropped~~ |
| ~~DONE~~ | ~~Dashed lines only for valid trigger+action~~ |
| **NOT IMPL** | Main menu navigable with controller (infrastructure exists, not integrated) |
| **NOT IMPL** | Controller prompts (L trigger + direction, bumpers) - assets exist, not integrated |
| ~~DONE~~ | ~~Wand cooldown icons from itch assets (cooldown_pie shader)~~ |
| **NOT IMPL** | More variation in coin collect sounds |
| ~~DONE~~ | ~~Disable decel on arrival (disableArrival flag)~~ |
| ~~DONE~~ | ~~Turn pickups into sensors~~ |
| ~~DONE~~ | ~~Drop shadow implementation~~ |
| ~~DONE~~ | ~~Camera rotation jiggle~~ |
| **OPEN** | Record scratching sound for time slow |
| **OPEN** | Give initial impulse when spawning items |
| **DISABLED** | Slow time slightly when player gets too close to enemy (logic exists, disabled) |
| **OPEN** | Add after() to each particle method for chaining |
| **OPEN** | Function to give UI bump, flash, vanish, ambient rotate |
| ~~DONE~~ | ~~Some ambient movement (rocking) to items/UI~~ |
| **NOT IMPL** | Integrate new music from eagle folder |
| **OPEN** | Some bg or shader overlay effects for sprites/map |
| **OPEN** | Normalize sound effects |
| **OPEN** | Layer particle effects of different colors |
| **OPEN** | Limit camera movement beyond center |
| **OPEN** | Size boing not working for player on hit |
| **OPEN** | Add physics sync mode that completely desyncs rotation |
| **OPEN** | Juice UI bars with springs |
| **OPEN** | Per-card 3D skew shader pass (disabled when interacted) |
| **OPEN** | Graphics need to coalesce (SNKRX reference) |
| **OPEN** | Particles with specific arc (directional splashing) |
| **OPEN** | Glowing background behind card for selection |
| **OPEN** | Nice UI reference: https://www.youtube.com/watch?v=Rkd5SYT10UQ |
| **OPEN** | Add glow to CRT and proper scanlines |
| ~~DONE~~ | ~~Integrate proper hit fx with blinking~~ |
| **OPEN** | Make steering face direction of movement |
| ~~DONE~~ | ~~Make sprites blink upon hit fx~~ |
| **OPEN** | Buttons with scrolling background |
| **OPEN** | Need to apply crossed lines for CRT |
| **OPEN** | Glow for selected sprites, noise-based squiggly rainbow background |
| **OPEN** | Just images - cards with numbers, color-coded text with icons |
| **OPEN** | Sound effects pass |
| **OPEN** | Steering should turn toward direction |
| **NOT IMPL** | Music integration |
| ~~DONE~~ | ~~Make sprites blink for dying/damage effect~~ |
| **OPEN** | Shader pass for legibility (change CRT maybe) |

---

## Potential Soundtracks (Ask Permission First)

- https://smiletron.bandcamp.com/album/self-titled (4/5)
- https://smiletron.bandcamp.com/album/signals (3/5)
- https://smiletron.bandcamp.com/album/solstice (4/5)
- https://soundcloud.com/biggiantcircles/the-glory-days-sevcon-full (4/5)

---

## Release & Testing

| Status | Item |
|--------|------|
| **PARTIAL** | Clean up web builds to not include .mds (docs/ excluded, no global *.md filter) |
| ~~DONE~~ | ~~Enable GitHub Actions + auto loading to itch.io on new release~~ |
| **PARTIAL** | Remove Tracy instrumentation for release (forced OFF for web, manual for native) |
| ~~DONE~~ | ~~Clean up build files (no docs/unnecessary source)~~ |
| ~~DONE~~ | ~~Playtest feedback system (web shell with bug report, clipboard, JSON download)~~ |

---

## Particle Polish Considerations

| Status | Item |
|--------|------|
| **OPEN** | Chromatic aberration on hit |
| **OPEN** | Particles that dwindle irregularly (pixelation + rotation + gravity) |
| **OPEN** | Same colored expanding circle outline |
| **OPEN** | Flash with filled circle |
| **OPEN** | Diamond hit fx centered on impact & rotated + dwindling |
| **OPEN** | Sprite size change on hit and back to normal |
| **OPEN** | Spreading circular ripple - irregular + fading |
| **OPEN** | Multiple-point shader distortion (ripple) |
| **OPEN** | Pulsing points of light as sources for lightning |
| **OPEN** | Particles traveling toward center + concentric circles + wobble + exploding |
| **OPEN** | Lightning lines from A to B |

---

## Summary Statistics

| Category | Done | Partial/Stub | Open/Not Impl |
|----------|------|--------------|---------------|
| Projectiles | 6 | 1 | 0 |
| Modifiers | 9 | 0 | 0 |
| Multicasts | 3 | 0 | 0 |
| Utilities | 0 | 1 | 3 |
| Super Recasts | 0 | 1 | 3 |
| Stats System | 8 | 0 | 7 |
| Shaders | 6 | 0 | 6 |
| Errors/Bugs | 3 | 0 | 16 |
| Shop System | 5 | 0 | 3 (UI disabled) |
| Polish | ~18 | 1 | ~25 |
| Release | 3 | 2 | 0 |

