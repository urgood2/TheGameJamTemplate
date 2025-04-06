

- [] Need to integrate new text system with movable
- [] math.cpp needs cleanup
- [] controller.lua functionality
- [] ui functionaltiy from card game
- [] how to insert image into text? https://chatgpt.com/share/6781d2e2-6654-800a-a76d-bd14921b469f
- [] shader TODOs

LATER: (not needed immediately)
- [] spine rendering + layer integration https://chatgpt.com/share/67766376-ac24-800a-8711-f6fd64a6d733


# ✅ TODOs: Organized by Category

---

## Done today
- [ ] Got basic hover/drag window logic in place, just needs to be implemented.

## 🧠 General Design / Architecture

- [ ] Integrate the new text system with the UI system (as a UI object/component). Also add animated sprites

---
### 🖱️ Interaction & Input

- [ ] Implement controller focus interactivity (e.g., gamepad navigation). 
    - [ ] funnel_to: "When navigating focus, skip me and send it to this node instead."
    - [ ] funnel_from: "I'm a proxy node, but real input focus is handled by the node I'm representing."
    - They give you control over controller focus routing, especially in complex UI layouts where a wrapper/box shouldn't receive focus, but its child (or a specific element) should. (probably rename these)
    - [ ] change funnel_to -> redirect_focus_to
    - [ ] change funnel_from -> claim_focus_from 

### 🖼️ Visual / Layout

- [ ] A function to not have a predefined width or height for dynamic text

### 🧪 UI Widgets & Behavior

- [ ] Implement more UI element types:
  - [ ] Buttons (with choice, focus args, one-press, delay, etc.)
    - [ ] Add support for button delay mechanics.
  - [ ] Sliders (`focus_args = {type = "slider"}`)
    - focus_args = {type = 'slider'} is used to integrate with controller input logic (e.g., dpad left/right).
    - The refresh_movement = true flag indicates this should refresh every frame 
    - the slider methods runs when the slider component is being dragged (TODO: how to enable dragging in ui components without actually moving them?)
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
  - [x] Pips (for controller button) -> just a root component with a button sprite + text describing that action, made a child to the parent ui box 
  - [x] Tooltips -> ui boxes with rows/columns with backgrounds + text of varying colors + sometimes dynamic text for effect
  - [x] Highlights (like card highligts) -> just a uibox that is an empty outline, attached to another uibox.


## 🧼 Cleanup / Maintenance

- [ ] Add centralized test args for button and UI interactions.

---

## Immediate laters

- [ ] Add support for UI element and box alignment to rotation/scale when bound to transforms.
- [ ] Need to apply individual sprite atlas uv change to every shader that will be used with sprites & create web versions
- [ ] Fix clicking + dragging not working unless hover is enabled.
- [ ] Make hover optional for clicking to work.
- [ ] Ensure UI elements are not clickable by default unless specified.
- [ ] rect shapes are made clickable by default in game.cpp. why do nested ones not click?
- [ ] UIbox should align itself again if its size changes. right now it does not.
- [ ] Impplement optional shader support for individual ui elements (or entire ui element trees)

## 🧭 Later later laters *(future consideration)*
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