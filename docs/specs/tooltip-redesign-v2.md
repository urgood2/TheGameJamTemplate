# Tooltip System Redesign V2

## Overview

Complete replacement of the existing tooltip system with a new 3-box vertical stack design. Tooltips appear adjacent to anchor entities, never covering them, with smart positioning that keeps them in bounds.

## Visual Structure

### 3-Box Architecture

Tooltips consist of **3 visually separate floating boxes** stacked vertically with 4px gaps:

```
┌─────────────────────────┐
│       CARD NAME         │  ← Box 1: Name (title only, larger font + wobble entrance effect)
└─────────────────────────┘
           4px gap
┌─────────────────────────┐
│                         │
│   Effect description    │  ← Box 2: Description (effect text, supports [text](color) markup)
│   text goes here...     │
│                         │
└─────────────────────────┘
           4px gap
┌─────────────────────────┐
│ Damage: 25    Mana: 12  │  ← Box 3: Info (stats grid + tag pills)
│ [Fire] [Projectile]     │
└─────────────────────────┘
```

### Box Specifications

| Property | Value |
|----------|-------|
| **Width** | Fixed 280px for all 3 boxes |
| **Gap** | 4px between boxes |
| **Background** | Equal visual weight (same bg color for all boxes) |
| **Outline** | Same 2px outline, same color for all 3 boxes |
| **Connector** | None (clean floating boxes, no arrows) |
| **Visibility** | All 3 boxes always show (even if content is empty) |

### Content Mapping

| Box | Content | Typography |
|-----|---------|------------|
| **Name** | Card title only | Larger/bolder font |
| **Description** | Effect text only (supports `[text](color=X)` markup) | Standard body font |
| **Info** | Stats grid (Damage, Mana, Cooldown, etc.) + tag pills ([Fire], [Projectile], etc.) | Stats: label/value pairs, Tags: colored pills |

### Text Effects

- **Name box**: Entrance-only wobble/pop effect when tooltip appears, then becomes static
- **Description box**: Standard text, no animation
- **Info box**: Standard text, no animation

## Positioning System

### Placement Priority

**Prefer right-side placement** (cards are tall/narrow, right-side maximizes visibility).

### Fallback Order

```
1. RIGHT of anchor entity
2. LEFT of anchor entity
3. ABOVE anchor entity
4. BELOW anchor entity
```

At each step, check if tooltip fits in bounds. If not, try next position.

### Vertical Alignment

- **Primary**: Top of tooltip aligns with top of anchor entity
- **Fallback**: If top-alignment causes clipping, shift down to fit

### Boundary Rules

1. **Never cover anchor entity** - tooltip must be fully outside anchor bounds
2. **Never go out of screen bounds** - if a position would clip, try next fallback
3. **Flip before clamp** - prefer switching sides over clamping/drifting from anchor
4. **Minimum edge gap**: 12px from screen edges

### Rotation Handling

- **Ignore rotation** - position based on axis-aligned bounding box
- Rotated cards (fanned hand) use AABB for simpler calculation

## Animation

### Entrance

- All 3 boxes appear **simultaneously**
- Name box has entrance effect (wobble/pop), then settles to static
- Description and Info boxes fade/appear with no special effect

### Dismiss

- Standard behavior: tooltip hides when mouse leaves anchor entity
- No delay, no hover-over-tooltip extension

## Caching Strategy

- **Cache entire 3-box assembly** per card ID
- Reuse cached tooltip on subsequent hovers
- Invalidate on:
  - Language change
  - Font reload
  - `TOOLTIP_FONT_VERSION` change

## Content Growth

- **Info box grows unbounded** to fit all content
- No maximum height, no scrolling, no truncation
- Tags wrap to multiple rows if needed
- Stats grid expands vertically for all stat rows

## API Changes

### Scope

**Full replacement** - this system replaces ALL tooltips:
- Cards
- Enemies
- Relics/Jokers
- UI elements
- Any entity with hover tooltips

### New Functions (replacing old API)

```lua
-- Create and show tooltip
showTooltipV2(anchorEntity, {
    name = "Fireball",
    description = "Deal [25](color=red) fire damage to target enemy",
    info = {
        stats = {
            { label = "Damage", value = 25 },
            { label = "Mana", value = 12 },
        },
        tags = { "Fire", "Projectile", "AoE" }
    }
})

-- Hide tooltip
hideTooltipV2(anchorEntity)

-- Card-specific helper (builds from card_def)
showCardTooltipV2(anchorEntity, cardDef)
```

### EntityBuilder Integration

```lua
EntityBuilder.create({
    sprite = "card",
    position = { 100, 200 },
    interactive = {
        hover = {
            name = "Fireball",
            description = "Deal [25](color=red) fire damage",
            info = { stats = {...}, tags = {...} }
        }
    }
})
```

## Implementation Phases

### Phase 1: Core Structure
- [ ] Create new tooltip builder for 3-box layout
- [ ] Implement fixed-width box rendering
- [ ] Add 4px gap spacing between boxes

### Phase 2: Positioning
- [ ] Implement right-side preferred placement
- [ ] Add fallback cascade (Right → Left → Above → Below)
- [ ] Implement top-alignment with shift-down fallback
- [ ] Add boundary clamping with flip-before-clamp logic

### Phase 3: Styling
- [ ] Configure equal background colors for all boxes
- [ ] Add consistent 2px outline to all boxes
- [ ] Implement larger/bolder font for Name box
- [ ] Add wobble entrance effect to Name box

### Phase 4: Content
- [ ] Implement Name box (title only)
- [ ] Implement Description box with markup support
- [ ] Implement Info box with stats grid + tag pills
- [ ] Handle empty content (show minimal-height placeholder)

### Phase 5: Integration
- [ ] Add caching for complete 3-box assemblies
- [ ] Update EntityBuilder API
- [ ] Migrate card tooltips
- [ ] Migrate other entity types (enemies, relics, etc.)

### Phase 6: Polish
- [ ] Fine-tune entrance animation timing
- [ ] Test edge cases (screen corners, rotated cards, many tags)
- [ ] Performance optimization

## Migration Notes

### From Old API

| Old | New |
|-----|-----|
| `makeSimpleTooltip(title, body, opts)` | `showTooltipV2(entity, { name, description, info })` |
| `makeCardTooltip(cardDef, opts)` | `showCardTooltipV2(entity, cardDef)` |
| `showSimpleTooltipAbove(key, ...)` | `showTooltipV2(entity, ...)` |
| `hideSimpleTooltip(key)` | `hideTooltipV2(entity)` |
| `centerTooltipAboveEntity(...)` | Handled internally by new positioning system |

### Backwards Compatibility

Old API functions should log deprecation warnings and delegate to new system during transition period.

## Visual Reference

```
                    ┌─────────────────────────┐
     ┌────────┐     │      FIREBALL           │
     │        │     └─────────────────────────┘
     │  CARD  │     ┌─────────────────────────┐
     │ IMAGE  │     │ Deal [25] fire damage   │
     │        │     │ to target enemy         │
     │        │     └─────────────────────────┘
     └────────┘     ┌─────────────────────────┐
                    │ Damage: 25   Mana: 12   │
                    │ [Fire] [Projectile]     │
                    └─────────────────────────┘

    ← anchor         ← tooltip (right side, top-aligned)
```
