# ✅ TODOs: Organized by Category

## game design

- [ ] Apply autochess formula to next game? https://a327ex.com/posts/auto_chess_formula
- [ ] add some kind of screen which shares the amount of points scored with other players -> saves to clipboard or something

## technical things to apply next time, when I do a game jam.
- [ ] use set_sync_mode when moving physics synced transforms 
- [ ] get a path from navmesh, use steering to follow it.
- [ ] use hitFX() from [here](assets/scripts/util/util.lua) to simulate hits to entities with transforms and shader pass component.
- [ ] use [headless springs](src/systems/spring/spring_lua.md) to animate custom rendered objects, scores, etc.
- [ ] easier color palette management and color ramping and snapping to nearest color in palette. see [this file](assets/scripts/color/palette.lua). Still have to add to colors.json first.
- [ ] use [headless nodemap](assets/scripts/nodemap/nodemap_headless.lua) to implement tech trees. iterate the nodes to instantiate transform objects for each node, then iterate every frame for updates to the nodes, configure on hover and click from the node data, render only the edges separately using a timer, maybe.
- [ ] use [new monobehavior file](assets/scripts/monobehavior/behavior_script_v2.lua) with game entities, also use this for transitions, etc, temporary rendered things, etc. also direct access to self table is possible now with script component. You can use table initializer to chain method calls:
```lua
HitCircle{ group = main.current.effects, x = self.x, y = self.y, rs = 12, color = self.color }
    :scale_down(0.3)           -- instant shrink
    :change_color(0.5, self.color)  -- tween to self.color over 0.5s
    :attach_ecs()
    :run_custom_function(function(self, eid) self.dead = false end)  -- mark dead when done
    :destroy_when(function(self, eid) return self.dead end) -- destroy when dead
```
- [ ] use this https://github.com/nhartland/forma for random generation in tiled settings, refer to chat gpt for practical use advice
- [ ] 1 bit tilemap - use ascii_sprites.tps for a tileset for a gamejam game, using ldtk
- [ ] copy SNKRX's dead-simple transition thing. Circle with text. 
- [ ] do what SNKRX does and add a sort of dark overlay behind everything else when showing gui -> probably render a rect
- [ ] change image color on hover
- [ ] color-coded tooltips which can be updated on the fly to reflect info-how?
- [ ] dynamic text notifications which can fade, and also contain images.


### Need to implement
- [ ] make sample map with ldtk that has colliders i can base chipmunk on. https://chatgpt.com/share/68bade2c-0d0c-800a-8a5c-25cb6196d612


## TODOS fast
- [ ] check that this can be done from lua:
```cpp
// test scene switch / multi-world toggling
auto& AS = entity_gamestate_management::active_states_instance();
AS.deactivate("state:overworld");
AS.activate  ("state:dungeon");

// Optional hard toggles (e.g., pause physics even if state is active)
PM.enableStep("overworld", false);
PM.enableStep("dungeon",   true);
PM.enableDebugDraw("dungeon", true);

// When you spawn things:
registry.emplace<PhysicsWorldRef>(e, "overworld");
registry.emplace<entity_gamestate_management::StateTag>(e, "state:overworld");
```

- test item modifiers:
```lua
-- Quick usage examples

-- Item granting fire pen + global DR:
local CinderCharm = {
  id='cinder_charm', slot='amulet',
  mods = {
    { stat='penetration_fire_pct', add_pct = 20 },
    { stat='damage_taken_reduction_pct', add_pct = 8 },
  }
}

-- Status that raises max cold cap by 15% for 6s:
Effects.modify_stat { id='ice_skin', name='max_cold_resist_cap_pct', add_pct_add=15, duration=6 }

-- Boss aura with per-type DR:
Effects.modify_stat { id='boss_hide', name='damage_taken_physical_reduction_pct', add_pct_add=30, duration=10 }

```
- test BloodMender, RingOfWard
- test:
```lua
Items.upgrade(ctx, hero, Flamebrand, {
  level_up = 1,
  add_mods = { { stat='fire_modifier_pct', add_pct=5 } }
})

```
- test:
```lua
local Scorched = Effects.status{
  id = 'scorched', duration = 5, stack = { mode='time_extend' },
  apply = function(e) e.stats:add_add_pct('fire_resist_pct', -10) end,
  remove= function(e) e.stats:add_add_pct('fire_resist_pct', +10) end,
}
-- Use it in any effect chain:
-- Effects.seq { Effects.deal_damage{...}, Scorched }
```
- test: single unified hook API for ad-hoc gameplay code:
```lua
    local un = Core.hook(ctx, 'OnHitResolved', {
        icd = 0.5,
        filter = function(ev) return ev and ev.did_damage and ev.source == hero end,
        run = function(ctx, ev) Effects.heal{flat=(ev.damage or 0)*0.05}(ctx, ev.source, ev.source) end
})
-- call `un()` to remove
```
- test: (Example proc that keys off reason and damage:)
    > Arbitrary item effects (full freedom) + pass ev into item procs
```lua
local ReactiveBalm = {
  id='reactive_balm', slot='medal',
  procs = {
    {
      trigger = 'OnHitResolved',
      chance  = 100,
      filter  = function(ev) return ev and ev.target and ev.did_damage end,
      effects = function(ctx, wearer, _, ev)
        if ev.reason == 'weapon' and (ev.damage or 0) > 50 then
          -- big hits apply an instant heal for 10% of the damage received
          Effects.heal { flat = (ev.damage or 0) * 0.10 } (ctx, wearer, wearer)
        end
      end
    }
  }
}

```





- [ ] take progressBar9Patch example in ui_definitions.hpp, expose the features to lua, and document for future use.
- [ ] how to do layer-localized shader effects -> test using Layer.postProcessShaders
- [ ] lua access to input component, acccessing text & setting callback
- [ ] expose  from uiconfig builder to lua, expose.
- [ ] tilemap + test physics integration + above mentioned upgrades + giant tech tree screen (completey different screen, not just window)



















## physics LATERS
- [ ] check planet orbiting code next time. enable_inverse_square_gravity_to_body and enable_inverse_square_gravity_to_point both work, as does set_circular_orbit_velocity
- [ ] add point cloud manipulation code + render texture updating so we can use it for terrain rendering
- [ ] Predictive flight path rendering via angrychipmunks demo.
- [ ] Final updates to physics world for ease of use https://chatgpt.com/share/688a4653-d110-800a-90e1-8506e26f3653
= [ ] how to color in only the ground? shader?
= [ ] how to know which part is in the ground, and which isnt?
- [ ] apply autogeometry manipulation methods: (also debug)
```cpp

void DeformableDemo::leftMouse(const cpVect& pos) {
    // carve only where density is high enough
    if(_sampler->sample(pos) < 0.25f) return;
    cpBB dirty = _pointCloud.addPoint(pos, 32.0f, 0.5f);
    _tiles.markDirtyRect(dirty);
}

void DeformableDemo::rightMouse(const cpVect& pos) {
    // spawn a ball only where density is low (i.e. empty space)
    if(_sampler->sample(pos) > 0.5f) return;
    
    cpFloat mass   = 1.0f;
    cpFloat radius = 10.0f;
    cpFloat moment = cpMomentForCircle(mass, 0.0f, radius, cpvzero);
    
    // create body + shape via your C++ wrappers
    auto *body = ChipmunkBody::BodyWithMassAndMoment(mass, moment);
    _space->add(body);
    body->setPosition(pos);
    
    auto *shape = ChipmunkCircleShape::CircleWithBody(body, radius, cpvzero);
    _space->add(shape);
    shape->setFriction(0.7f);
}

```
- [ ] tweak pointcloudsampler so it's feature complete: https://chatgpt.com/share/68865127-f880-800a-a33b-745a7bc5a793
- [ ] compare all objective c files except image sampler (won't be using it) against originals for missing features
- [ ] do a pass through of objective c port of chipmunk so that I can use shared ptr instead of new() operator.
- Deformable Chipmunk2D demo from http://chipmunk-physics.net/documentation.php#examples is what I want to copy (second demo in the app) if I want deformable terrain.
- add steering stuff in from snkrx
- add navmesh so it can work with chipmunk auto tile colliders + a ldtk loader implementatino
- [ ] more chipmunk2d (mostly terrain stuff) examples to extract modules from: http://chipmunk-physics.net/documentation.php#examples

- [ ] note that chipmunk2d uses center of gravity as the location for an ojbect's coordinates.
- [ ] how to do rounded rectangles for collision shapes?
- [ ] how to do arbitrary deformable maps like in bouncy hexagons demo?
- [ ] how to do orbiting like in planet demo?
- [ ] curshing detection & weight measrement in contact graph demo
- [ ] sticky surfaces demo for sticky collisions
- [ ] simple sensor based fluids demo for simple 2d objects floating in a fluid.
- [ ] slice demo for 2d slicing.
- [ ] convex demo for changing the shape of an object on the fly (convex polygon)
- [ ] pump demo for engine-like pump machinery simulation
- [ ] breakable chains demo for chains which break when force is applied
- [ ] crane demo for wall world type resource clustering 
- [ ] fabric-like springs (maybe use for gui at some point?) in the springies demo
- [ ] one-way pass thorugh platforms - one way platforms demo
- [ ] how are joints moved in tank demo? how does it steer? 
- [ ] diffent types of joints, springs, constraints, etc, like pinball flappers, vehicle wheels, turbines, balls connected in various ways, etc. in Joints and Constraints demo





## Things to fix/implement later
- [ ] right now, cameras are bound to specific layers, and you can't freely attach speicific cameras to specific rendering calls. is this a problem?
- [ ] make get/set blackboard methods return lua nil if invalid instead of throwing error
- [ ] understand & implement working copies of files in the todo_from_snkrx folder


## Bug fixes

- [ ] text update not applying for text that is in the middle of typing? reset typing when text is set (including coroutine state?), as well as effects?
- [ ] test edge_effect shader

    - uniforms:
```cpp
// update every frame:
shaders::registerUniformUpdate("edge_shader", [](Shader &sh) {
    globalShaderUniforms.set("edge_shader", "iTime", static_cast<float>(GetTime()));
});

// one-time setup of all the other edge params:
globalShaderUniforms.set("edge_shader", "edgeMode",                1);        // 0:none,1:plain,2:shiny
globalShaderUniforms.set("edge_shader", "edgeWidth",               1.0f);
globalShaderUniforms.set("edge_shader", "edgeColorFilter",         1);        // e.g. 1=Multiply
globalShaderUniforms.set("edge_shader", "edgeColor",               Vector4{1,1,1,1});
globalShaderUniforms.set("edge_shader", "edgeColorGlow",           0.0f);
globalShaderUniforms.set("edge_shader", "edgeShinyWidth",          0.2f);
globalShaderUniforms.set("edge_shader", "edgeShinyAutoPlaySpeed",  1.0f);

// if you need resolution/unscaled time, register those too:
globalShaderUniforms.set("edge_shader", "iResolution", 
    Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});

```
- [ ] figure out how to do outline/border shaders done  here with arbitrary sprites https://github.com/mob-sakai/UIEffect -> shader code is in UIEffect.cginc, also scrape textures too /  want: pattern background overlay, edge shiny, transition (dissolve), 
    - [ ] Sampling Filter 
    - [ ] Transition filter
    - [ ] Shadow Mode
    - [ ] Edge mode

- [ ] unexplored option: 1 bit or simple shapes + global shadow shader like with SNKRX
- [ ] unexplored option: static sprites with jitter + noise as in shader_todos.md for visual uniformity & style

- [ ] lua libraries to use later for my game dev
    - https://github.com/love2d-community/awesome-love2d?tab=readme-ov-file
    - behavior tree & state machine libs for love might be interesting to explore @ later point if necessary

- [ ] update the gamejam 50 branch with the new branch, then test
- [ ] have all shadows for sprites, text, etc. in the same layer, below the sprites, text, etc.

- [ ] Dont update text and ui that is out of bounds 

- [ ] way to keep track of y-values for successive test mesages so they don't overlap




## Shaders
- [ ] use this as a base for future shaders: https://chatgpt.com/share/68521752-7898-800a-8d76-d30affc26ca0  / or "gamejam" shader in shader folder
- [ ] make variations of texture shaders based on voucher sheen/polychrome
- [ ] implement voucher sheen -> use new overlay draw system to do it

- [ ] inventory drag & drop broken
- [ ] highlight outline size is wrong. how to fix?
- [ ] link onscreen keyboard with text input -> click text field -> show keyboard -> link keyboard buttons with string stored -> enter pressed, close keyboard -> https://www.raylib.com/examples/text/loader.html?name=text_input_box / use this example for text input gui

- [ ] Implement more UI element types:
  
  - [ ] Cycles (radio buttons)
    - Displays a current selection (current_option_val)
    - Has left/right buttons to cycle through a list of args.options
    - args.focus_args.type = 'cycle' allows d-pad and shoulder input to be utilized
    - Visually indicates the current position with pips (unless args.no_pips) -> pips are just tiny rects, given unique ids (pip1, pip2), and change color depending on whether they are selected or not. They are added to a row component. Then the row added below the text
    - Binds to an external data value in ref_table[ref_value]
    - Can trigger a callback when changed
    - Supports keyboard/controller interaction and shoulder button overlays
  - [ ] Alerts -> just ui boxes with a dynamic text component that has a moving exclamation mark.
  - [ ] Tooltips -> ui boxes with rows/columns with backgrounds + text of varying colors + sometimes dynamic text for effect. There are drag, hover tooltips, each of which should be tested. Also don't make them be re-created every time, just cache them with the owner entity and destroy them later
- [ ] make particle system a little easier to use on the go
- [ ] Text input (with cursor displayed, etc, software keyboard)


### MISC. RENDERING
- [ ] higher shadow on hovered items, draw above everything else. How? -> add height offset to shadow I guess -> use layer z-order for this

### LAUNCH CODE
- [ ] Shader materials, choose 2 or 3 and make them work for sprites (apply sprite sheet scaling) - including maybe an overall shadow pass like in snkrx?
- [ ] Participate in game jam or do a little test game jam on my own to make everything ready

---

## Game data extraction
- siralim data is here: [folder](<assets/siralim_data>)
- [ ] extract what I can from siralim: tack on this rule system, then test with actual siralim rules: https://chatgpt.com/share/68a46896-78bc-800a-a14f-73605890a8a3
- [ ] chronicon data https://github.com/gabriel-dehan/chronicondb-client/tree/main/src/engine/data

## Immediate laters

- text updating wrong. not easy to configure updates with on update method for some reason?
- [ ] blinking cursor doesn't always show for text input component
- [ ] use posthog for analytics? learn how randy does it.
- auto sprite order sorting so what's behind somehting can properly go behind, etc.
- use hump.gamestate. How to hook with raylib?
- [ ] how to improve web launcher? -> this might work https://github.com/cn04/emscripten-webgl-loader?tab=readme-ov-file
- [ ] how to request a new GOAP plan and run it from lua?
- [ ] Utilize controller focus interactivity focus funneling in the above ui
    - [ ] redirect_focus_to: "When navigating focus, skip me and send it to this node instead."
    - [ ] claim_focus_from: "I'm a proxy node, but real input focus is handled by the node I'm representing."
- [ ] Context handling for modal dialogs (controller focus saving between windows) & controller run-through for the various ui types implemented (support for shoulder buttons, dpad, etc. when relevant) -> maybe do controller later, just implement modality / layers
- [ ] shake not working, scramble not working. Slight stall when the app loads on windows, not sure why.
- [ ] some new text effects https://chatgpt.com/share/6809c567-486c-800a-a0db-e2dd955643aa
- Function to expand only a part of the ninepatch image (left corner for text, etc.). For use with kenney ui
- [ ] Option to set images for hover/ not hover/ clicked separately instead of using hover colors (one or the other). 
- [ ] Option to draw something over the button for select marker (instead of chosen circle bob)
- [ ] text tag documentation (img, anim) -> static ui / (img) -> dynamic text
- [ ] Rendering for animated entities should respect uiconfig's color variable for tint if the master entity has a uiconfig (is a uielement OBJECT type)
- [ ] shadows for sprites with shader pipeline, these need to be integrated with the shaders themselves (or use separate shadow pass) -> just render the final image twice with tint, should work
- [ ] change dissove on foil, etc. shaders, can't be a copy of balatro's
- [ ] tween colors for inventory ui, show hover indicator with draw() function
- [ ] Skill tree, refer to bytepath
- [ ] Text highlight efect - show same text overlaid, which vanishes upwa
- [ ] Use simple art style + scale down technique for visual prettiness
- [ ] something to replace current dissolve effect?
- [ ] some particle ideas:
  - [ ] particles - appear, move to a certain point via tweening, disappear
  - [ ] particles - wavering trail of rectangles behind a moving object + circle that flashes into view
  - [ ] particles - basic shapes changing size or other properties
  - [ ] particles- spinnig segmented circle which flahses then vanishes
  - [ ] particles - lightning-shaped irregular lines branching out all at once, then vanishing
- [ ] Some shaders don't work with the multi-pass system I have. 
- [ ] rounded rect needs testing - outline doesn't seem to work right all the time
- [ ] simple lighting shader with normal maps
- [ ] AddDrawTransformEntityWithAnimationWithPipeline needs to be tested.
- [ ] Some shaders, simple ones, which can be layered fro sprites and serve as a backbone for other additions later on. (drop shadow, holoram, 3d skew, sheen)
- [ ] button presses need to shift down text as well (dynamic text)
- [ ] Add support for UI element and box alignment to rotation/scale when bound to transforms.
- [ ] Highlights (like card selection highlights) -> just a uibox that is an empty outline, attached to another uibox. -> do for controller input later
- [ ] Need to apply individual sprite atlas uv change to every shader that will be used with sprites & create web versions
- [ ] Fix clicking + dragging not working unless hover is enabled.
- [ ] Make hover optional for clicking to work.
- [ ] Ensure UI elements are not clickable by default unless specified.
- [ ] rect shapes are made clickable by default in game.cpp. why do nested ones not click?
- [ ] UIbox should align itself again if its size changes. right now it does not.
- [ ] Impplement optional shader support for individual ui elements (or entire ui element trees)
- [ ] outline interiors look too square
- [ ] UI context switching for controller context savving (which button was focused, excluding butons from context in the presence of an overlay)
- [ ] Dynamic text has a problem where center/right alignment breaks ui element placement. Keep it as left aligned and use the ui element alightment, and you should be fine
- [ ] UI objects in ui elements might call renew alignment on ui box every time. need to check this.
- [ ] Add shader variations:
Suggestions for Gloss/Shine Shader Variations
🔷 Material-Focused Shines
    Brushed Metal – directional highlights with anisotropic streaks based on tangents.
    Velvet Sheen – edge-based soft highlights with fuzzy falloff (rim lit, but diffused).
    Lacquer/Plastic – hard specular with sharp, clean falloff + slight clear coat shine.
    Worn Metal – gloss modulated by grunge/noise masks; procedural wear and tear.
    Pearlescent – multi-layered interference hues depending on view angle and light angle.
    Holographic – shifting diffraction-like rainbow highlights from camera angle.
🔷 Stylized/Procedural Effects
    Ramp-based Specular (Toon Shine) – non-linear specular ramping using a 1D texture or math step function.
    Anime Glint – animated diagonal lines or sparkles that pulse across edges.
    Sheen Lines (Vista Glow) – trailing glow point that animates around a border (like high-end foil cards).
    Moving Bokeh Reflection – light spots (fake lens bokeh) that flow across the surface.
🔷 Overlay/Multipass Ideas
    Environment Map Reflection – even without actual environment maps, use fake cubemap glint swipes.
    Dynamic Bloom Outline – bright specular zones that spill light (bloom) and pulse.
    Double Coat Shader – simulate a thin transparent glossy coat over a rough underlayer.
    Scanline Sparkle – thin traveling scanline that causes strong sparkle on intersect.
🔷 Noise/Distortion Driven
    Distorted Shine – use noise to break up highlights into irregular reflections.
    Liquid Shine – sine-driven ripple effect modulating specular zones.
    Time-based Wave Gloss – sin(time + pos) driven specular strength shifting.
    Fractal Shine Veins – highlights that follow perlin/fractal veins.
    Edge Pulse Gloss – gloss increases along UV edges or silhouette outlines.

## 🧭 Later later laters *(future consideration)*
- [ ] make debug window that has debugDraw toggle
- [ ] some text effects randomly freeze, rotation seems off with renderscale other than 1
- [ ] optimize text implementation
- [ ] Determine how to programmatically modify frame times for particle animations.
- [ ] Consider using VBOs/IBOs for rendering to improve performance.
- [ ] "LATER: figure out button UIE more precisely"
- [ ] "LATER: bottom outline is sometimes jagged…"
- [ ] "LATER: when clicking nested buttons, outer button triggers hover…"
- [ ] "LATER: use VBO & IBOS for rendering"
- [ ] "LATER: ninepatch?"
- [ ] "LATER: Allow per-animation frame timing configuration in `particle::CreateParticle`.
- [ ] Determine how to handle automatic layout refresh when text changes (recenter or scale?).
- [ ] Add support for hover color change.
- [ ] rotation for ui elements & permanent attachment needs looking into, offsets don't work properly. 
- [ ] make color coding function for ui boxes (to generate color-coded tooltips)
- [ ] shadows for sprites using the sprites themselves (grayed out version)
- [ ] Fix jagged bottom outlines when buttons are scaled down.
- [ ] Controller input does not work on the mac.
- [ ] focus menu layers for controller not tested. It's simply used to save the previously focused node before opening something that will hog all the focus (onscreen keyboard for instance), which can then be restored after the thing is closed again. Mostly it's under_overlay that's used to mark buttons as being under overlay and mark them as not part of focusable list. Overlays are not implemented/tested and need to be debugged.
- [ ] focus navigation selection box should be a rounded rect, not a straight out rect
- [ ] probably make shadows stay in place vertically when shifting characters around in fancy text
- [ ] math.cpp needs cleanup
- [ ] refactoring input functionality
- [ ] shader TODOs
- [ ] spine rendering + layer integration https://chatgpt.com/share/67766376-ac24-800a-8711-f6fd64a6d733



# Done

- [x] adding animations for static text types (not for dynamic text)

- [ ] need to optimize, in order: drawsteppedroundedrectangle (self time), movewithmaster
- [ ] try this optimization https://chatgpt.com/share/68444854-ba0c-800a-aa4f-e91c616c7ee1
- [ ] disabling box::move and box::drag for now, not in use
- [ ] do optimization for quad tree
- [ ] optimize updatesystems with this; https://chatgpt.com/c/683ef4e3-bc90-800a-8478-9788d51b3d6f  Also consider optimizing by caching parent components when recursing by frame?
- [ ] use cached variables for transform values? single-component groups don't work.