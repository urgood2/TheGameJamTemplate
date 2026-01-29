# Demo Polish Features Specification

## Overview
Seven features to polish the demo experience: mana visualization, E-key triggers, tutorial skip, shop UI, simplified gold display, demo overlay, and feedback buttons.

---

## 1. MP Bar for Wands (Card Strip UI)

### System Design
- **Independent mana pools per wand** - each wand tracks its own MP and regenerates independently

### Visual Design
- **Position:** Vertical bar on the **right edge** of each card in the action phase card strip
- **Visibility:** Hides when MP is full (fades out at 100%)
- **Animation:** Smooth continuous fill during regeneration (not discrete ticks)
- **Low MP:** Only the bar indicates low MP state - no card dimming/greying

### Technical Notes
- Affects card strip UI in action phase only (not planning phase hand)
- Bar should be thin enough not to obscure card art

---

## 2. Action Button (E) Trigger System

### Mechanics
- **Behavior:** Single burst - press E to fire all trigger-type cards once
- **Cooldown:** None - player can press E freely
- **Card type:** New card type `type = "trigger"` (alongside "action", "mod")
- **Integration:** Hooks into existing trigger signal system

### Visual Feedback
- **Trigger cards flash** briefly when fired by E press
- **HUD indicator:** 'E' key glyph positioned at **center-bottom** of screen
- **Animation:** Continuous subtle pulse while available, flash/brighten on press

---

## 3. Tutorial Skip System

### Controls
- **Skip step:** Press **ESC** key or **mouse click** to advance one dialogue/step
- **Skip all:** Hold ESC/click for **2 seconds** to skip entire remaining tutorial
- **Visual:** Text hint on screen (e.g., "Press ESC to skip") - no dedicated button widget

---

## 4. Shop System

### Access
- Shop phase already exists in codebase
- Triggers **after completing a stage** (which consists of multiple waves)

### Pack Structure
- **3 pack types:** Trigger Pack, Mod Pack, Action Pack
- **Price:** 25 gold each (fixed, all same price)
- **Cards per pack:** 3 cards
- **Card selection:** Curated subsets per pack type (defined in new `shop.lua` file)

### Pack Opening UX
1. Player clicks pack to purchase
2. **Sequential flip animation** - cards reveal one at a time with delay
3. Player **picks exactly 1 card** to keep
4. Unchosen cards **dissolve** (use `dissolve` uniform in 3d_skew shaders) and return to card pool

### Edge Cases
- **Can't afford:** Packs look normal; show "Not enough gold!" error on click attempt
- Cards returned to pool may appear in future packs

---

## 5. Gold Display Simplification

### Design
- **Format:** Icon + number only (e.g., `🪙 150`)
- **Icon asset:** `b2873.png`
- **Style:** Remove all borders and background
- **Position:** Keep current screen position

---

## 6. Demo Overlay

### Design
- **Position:** Bottom-right corner of screen
- **Format:** `DEMO v{X.Y.Z}` (semantic versioning)
- **Opacity:** 60-70% (clearly readable but not distracting)
- **Behavior:** Static text, no interactivity

---

## 7. Feedback Buttons

### Design
- **Visibility:** Always visible icons
- **Position:** Bottom-right corner (near demo overlay)
- **Icons:** 2 separate icons - Discord and Google Forms

### Links
- **Discord:** https://discord.gg/rp6yXxKu5z
- **Google Forms:** https://forms.gle/YZFWQ41JnBNpzYSa7

### Behavior
- **Direct open** in system default browser (no confirmation popup)

---

## Implementation Priority

Suggested order based on dependencies and complexity:

1. **Gold Display** - Simple, no dependencies
2. **Demo Overlay** - Simple, no dependencies
3. **Feedback Buttons** - Simple, just needs icon assets
4. **Tutorial Skip** - Modifies existing system
5. **MP Bar** - Modifies card strip UI
6. **E Trigger** - New card type + HUD element + signal integration
7. **Shop UI** - Most complex, needs pack data, animations, card selection flow

---

## File References (Likely Locations)

| Feature | Likely Files |
|---------|--------------|
| MP Bar | `assets/scripts/ui/trigger_strip_ui.lua`, card strip rendering |
| E Trigger | `assets/scripts/wand/`, card type definitions, input handling |
| Tutorial Skip | `assets/scripts/tutorial/dialogue/` |
| Shop | New `assets/scripts/data/shop.lua`, shop phase UI |
| Gold Display | HUD/UI files, asset reference |
| Demo Overlay | HUD/UI overlay system |
| Feedback | HUD/UI, system browser call |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
