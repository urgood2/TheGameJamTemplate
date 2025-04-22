




# ✅ TODOs: Organized by Category

---


## 🧠 General Design / Architecture

- [ ] higher shadow on hovered items, draw above everything else. How? -> add height offset to shadow I guess -> use layer z-order for this

- [ ] sprite rendering not working over ui?
- [ ] shadows for sprites with shader pipeline, these need to be integrated with the shaders themselves (or use separate shadow pass) -> just render the final image twice with tint, should work
- [ ] change dissove on foil, etc. shaders, can't be a copy of balatro's

- Add shader variations:
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

- [ ] add kenney borders & rounded rect logic 
    - Add logic to fetch sprite & automatically nine-patch close to the center
    - dividers go on each side of the text or element and the second one is mirrored (first one is not), should be scaled down probably by some factor of the line height
    - added the images, now need to set up the list of sprite names to access (maybe a text file or just code comments) for the dividers and panel backgrounds on ui config.
    - ui config feature to either use the classic rounded rect, raylib rounded rect, or a custom nine-path image (provide sprite uuid). the dividers can just be added in as animations into the current ui setup.


---
### 🖱️ Interaction & Input



### 🧪 UI Widgets & Behavior

- [ ] Actually implement the ui now.

- [ ] Implement more UI element types:
  - [x] Buttons (with choice, focus args, one-press, delay, etc.)
    - one_press -> ensures button only pressed once per lifetime.
    - button delay disables button for X seconds after ui is created. (in ui element setValues)
    - in update, this value is updated so callback which is backed up will be restored
  - [x] Sliders (`focus_args = {type = "slider"}`)
    - use UIConfig.noMovementWhenDragged to disable dragging movement
    - Just need to make a function that uses reflection to fetch whatever is being manipulated, based on the following
      ```lua
      function G.FUNCS.slider(e)
        local c = e.children[1]
        e.states.drag.can = true
        c.states.drag.can = true
        if G.CONTROLLER and G.CONTROLLER.dragging.target and
        (G.CONTROLLER.dragging.target == e or
        G.CONTROLLER.dragging.target == c) then
          local rt = c.config.ref_table
          rt.ref_table[rt.ref_value] = math.min(rt.max,math.max(rt.min, rt.min + (rt.max - rt.min)*(G.CURSOR.T.x - e.parent.T.x - G.ROOM.T.x)/e.T.w))
          rt.text = string.format("%."..tostring(rt.decimal_places).."f", rt.ref_table[rt.ref_value])
          c.T.w = (rt.ref_table[rt.ref_value] - rt.min)/(rt.max - rt.min)*rt.w
          c.config.w = c.T.w
          if rt.callback then G.FUNCS[rt.callback](rt) end
        end
      end
      ```
    - has a function that sets sliding to true, updates the stored value depending on mouse movement
    - focus_args = {type = 'slider'} is used to integrate with controller input logic (e.g., dpad left/right).
    - The refresh_movement = true flag indicates this should refresh every frame (update should be called every frame)
    - the slider methods runs when the slider component is being dragged
    - Updates the value in a reference table (ref_table[ref_value]) based on cursor position
    - Adjusts the width of the inner bar (c) to visually match the value
    - Updates the text label to show the new value
    - Optionally calls a callback function after the value changes
  - [x] Cycles (radio buttons)
    - Displays a current selection (current_option_val)
    - Has left/right buttons to cycle through a list of args.options
    - args.focus_args.type = 'cycle' allows d-pad and shoulder input to be utilized
    - Visually indicates the current position with pips (unless args.no_pips) -> pips are just tiny rects, given unique ids (pip1, pip2), and change color depending on whether they are selected or not. They are added to a row component. Then the row added below the text
    - Binds to an external data value in ref_table[ref_value]
    - Can trigger a callback when changed
    - Supports keyboard/controller interaction and shoulder button overlays
  - [x] Checkboxes -> just a button with an image. The image is set to invisible whenbutton is pressed. Funnel_to and from are used for the container of the checkbox, etc.
  - [x] Alerts -> just ui boxes with a dynamic text component that has a moving exclamation mark.
  - [x] Pips (for controller button) -> just a uibox component with a button sprite + text describing that action, made a child to the parent ui box 
  - [x] Tooltips -> ui boxes with rows/columns with backgrounds + text of varying colors + sometimes dynamic text for effect. There are drag, hover tooltips, each of which should be tested. Also don't make them be re-created every time, just cache them with the owner entity and destroy them later
  - [x] Highlights (like card selection highlights) -> just a uibox that is an empty outline, attached to another uibox.
- [ ] Utilize controller focus interactivity focus funneling in the above ui
    - [ ] redirect_focus_to: "When navigating focus, skip me and send it to this node instead."
    - [ ] claim_focus_from: "I'm a proxy node, but real input focus is handled by the node I'm representing."
- [ ] Text input (with cursor displayed, etc, software keyboard)

---

## Immediate laters
- [ ] Some shaders don't work with the multi-pass system I have. 
- [ ] rounded rect needs testing - outline doesn't seem to work right all the time
- [ ] simple lighting shader with normal maps
- [ ] AddDrawTransformEntityWithAnimationWithPipeline needs to be tested.
- [ ] Some shaders, simple ones, which can be layered fro sprites and serve as a backbone for other additions later on. (drop shadow, holoram, 3d skew, sheen)
- [ ] button presses need to shift down text as well (dynamic text)
- [ ] Add support for UI element and box alignment to rotation/scale when bound to transforms.
- [ ] Need to apply individual sprite atlas uv change to every shader that will be used with sprites & create web versions
- [ ] Fix clicking + dragging not working unless hover is enabled.
- [ ] Make hover optional for clicking to work.
- [ ] Ensure UI elements are not clickable by default unless specified.
- [ ] rect shapes are made clickable by default in game.cpp. why do nested ones not click?
- [ ] UIbox should align itself again if its size changes. right now it does not.
- [ ] Impplement optional shader support for individual ui elements (or entire ui element trees)
- [ ] outline interiors look too square
- [ ] Dynamic text has a problem where center/right alignment breaks ui element placement. Keep it as left aligned and use the ui element alightment, and you should be fine
- [ ] UI objects in ui elements might call renew alignment on ui box every time. need to check this.

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