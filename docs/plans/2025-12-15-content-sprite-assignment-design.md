# Content Sprite Assignment Design

**Date:** 2025-12-15
**Status:** Approved

## Overview

Streamline the process of assigning individual sprite names to cards, avatars, and jokers by adding an optional `sprite` field to each content type's data definition.

## Approach

**Pure Data + Lazy Validation:**
- Add `sprite` field to card/joker/avatar definitions
- Validation happens at render time — if sprite doesn't exist, use placeholder
- No build step, no preprocessing, no new tooling

## Data Schema Changes

### Cards (`assets/scripts/data/cards.lua`)

```lua
Cards.MY_FIREBALL = {
    id = "MY_FIREBALL",
    type = "action",
    mana_cost = 12,
    sprite = "fireball_icon",  -- NEW: optional sprite name
    -- ... rest of fields
}
```

### Jokers (`assets/scripts/data/jokers.lua`)

```lua
pyromaniac = {
    id = "pyromaniac",
    name = "Pyromaniac",
    sprite = "joker_pyromaniac",  -- NEW: optional sprite name
    -- ... rest of fields
}
```

### Avatars (`assets/scripts/data/avatars.lua`)

```lua
wildfire = {
    name = "Avatar of Wildfire",
    sprite = "avatar_wildfire",  -- NEW: optional sprite name
    -- ... rest of fields
}
```

## Field Behavior

- If `sprite` is present and valid → use that sprite
- If `sprite` is present but invalid → use placeholder (no warning logged for now)
- If `sprite` is absent → use default placeholder

## Integration Points

### 1. Cards (`gameplay.lua:1496`)

```lua
-- BEFORE:
local imageToUse = "sample_card.png"

-- AFTER:
local card_def = WandEngine.card_defs[id] or {}
local imageToUse = card_def.sprite or "sample_card.png"
```

### 2. Avatars (`avatar_joker_strip.lua:174`)

```lua
-- BEFORE:
local entity = createSprite(a, AvatarJokerStrip.layout.avatarSprite, colors.avatarAccent)

-- AFTER:
local entity = createSprite(a, a.sprite or AvatarJokerStrip.layout.avatarSprite, colors.avatarAccent)
```

### 3. Jokers (`avatar_joker_strip.lua:187`)

```lua
-- BEFORE:
local entity = createSprite(j, AvatarJokerStrip.layout.jokerSprite, colors.jokerAccent)

-- AFTER:
local entity = createSprite(j, j.sprite or AvatarJokerStrip.layout.jokerSprite, colors.jokerAccent)
```

## Default Fallbacks

| Content Type | Default Sprite |
|--------------|----------------|
| Cards | `sample_card.png` |
| Avatars | `avatar_sample.png` |
| Jokers | `joker_sample.png` |

## Implementation Checklist

1. [ ] Add `sprite` field to `cards.lua` schema (example card)
2. [ ] Add `sprite` field to `jokers.lua` schema (example joker)
3. [ ] Add `sprite` field to `avatars.lua` schema (example avatar)
4. [ ] Update `gameplay.lua:1496` to use `card_def.sprite or "sample_card.png"`
5. [ ] Update `avatar_joker_strip.lua:174` to use `a.sprite or layout.avatarSprite`
6. [ ] Update `avatar_joker_strip.lua:187` to use `j.sprite or layout.jokerSprite`
7. [ ] Test: create a card/joker/avatar with custom sprite, verify it renders
8. [ ] Test: verify fallback works when sprite field is absent

## Future Enhancements (Not In Scope)

- Startup validation to catch all missing sprites at once
- Build-time validation script for CI
- Warning logging for invalid sprite names
