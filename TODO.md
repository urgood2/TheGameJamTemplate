

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

## 🧠 General Design / Architecture

- [ ] Integrate the new text system with the UI system (as a UI object/component).
- [ ] Determine how to handle automatic layout refresh when text changes (recenter or scale?).

---

## 🧩 UI System

### 🖱️ Interaction & Input

- [ ] Fix clicking + dragging not working unless hover is enabled.
- [ ] Make hover optional for clicking to work.
- [ ] Ensure UI elements are not clickable by default unless specified.
- [ ] Add support for button delay mechanics.
- [ ] Implement controller focus interactivity (e.g., gamepad navigation).
- [ ] Test and refine interactivity: click, drag, hover.
- [ ] Create popup behavior for hover and drag elements.

### 🖼️ Visual / Layout

- [ ] Add support for hover enlargement amount, shake-on-hover, and hover color change.
- [ ] Add ability to scale button or UI box if the text changes in size. (add option to instead change the scaling on the text object instead of enlarging)
- [ ] Support rotation and scale for UI elements (optionally reflected visually).
- [ ] Fix jagged bottom outlines when buttons are scaled down.
- [ ] Fix button layout refresh so buttons realign when their text size updates.

### 🧪 UI Widgets & Behavior

- [ ] Implement more UI element types:
  - [ ] Buttons (with choice, focus args, one-press, etc.)
  - [ ] Sliders (`focus_args = {type = "slider"}`, collision support)
  - [ ] Toggles (`focus_args = {funnel_to = true}`, custom toggle behaviors)
  - [ ] Radio buttons / switch buttons
  - [ ] Checkboxes
- [ ] Implement hover effects like shake and color swap.
- [ ] Create `alert`, `h_popup`, and `d_popup` components.
- [ ] Impplement optional shader support for individual ui elements (or entire ui element trees)

---

## 🧱 Transform System

- [ ] Add support for UI element and box alignment to rotation/scale when bound to transforms.

---

## 🧼 Cleanup / Maintenance

- [ ] Add centralized test args for button and UI interactions.

---

## 🧭 Notes and Later Ideas *(future consideration)*
- [ ] Determine how to programmatically modify frame times for particle animations.
- [ ] Consider using VBOs/IBOs for rendering to improve performance.
- [ ] "LATER: figure out button UIE more precisely"
- [ ] "LATER: bottom outline is sometimes jagged…"
- [ ] "LATER: when clicking nested buttons, outer button triggers hover…"
- [ ] "LATER: use VBO & IBOS for rendering"
- [ ] "LATER: ninepatch?"
- [ ] "LATER: Allow per-animation frame timing configuration in `particle::CreateParticle`.

