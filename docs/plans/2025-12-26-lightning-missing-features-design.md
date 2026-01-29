# Lightning System: Missing Features Design

**Date:** 2025-12-26
**Branch:** feature/lightning-system
**Status:** Ready for implementation

## Overview

Complete the lightning system by implementing three missing features:
1. Visual status indicators (floating icons, status bar, shaders)
2. Defensive mark integration (hook into combat defense pipeline)
3. Self-applied marks (cards that mark the caster)

## Feature 1: Visual Status Indicators

### 1.1 Floating Icons (1-2 statuses)

Render icon sprites above entities using draw commands (not entity-based).

**Positioning:**
- Base: entity center X, entity top Y
- Offset: `BAR_OFFSET_Y` (-24px) + per-status `icon_offset.y`
- Bob animation: `sin(bob_phase) * ICON_BOB_AMPLITUDE`
- Multiple icons: 16px horizontal spacing, centered

**Stack display:**
- Small text below icon when `def.show_stacks = true` and `stacks > 1`
- Uses `command_buffer.queueDrawText()`

**Missing sprite fallback:**
- Render colored circle if sprite not found
- Color from status type (cyan=electric, red=fire, etc.)

### 1.2 Status Bar (3+ statuses)

Condensed horizontal bar when entity has 3+ active statuses:
- Mini icons: `BAR_ICON_SIZE` (12px)
- Spacing: `BAR_SPACING` (2px)
- Centered above entity
- No bob animation

### 1.3 Shader Integration

Use existing `ShaderBuilder` API:

```lua
function StatusIndicatorSystem.applyShader(entity, status_id, def, stacks)
    if not def.shader then return end

    local uniforms = def.shader_uniforms or {}
    if def.shader_uniforms_per_stack and stacks then
        local idx = math.min(stacks, #def.shader_uniforms_per_stack)
        uniforms = def.shader_uniforms_per_stack[idx]
    end

    ShaderBuilder.for_entity(entity)
        :add(def.shader, uniforms)
        :apply()
end
```

Track applied shaders per-status for removal on hide.

## Feature 2: Defensive Mark Integration

### Hook Location

Integrate into `Effects.deal_damage` defense calculation phase (around line 2202-2229), alongside block/dodge checks.

### Implementation

```lua
-- After dodge check, before damage loop:
local defensive_mark_block = 0
local defensive_mark_effects = {}

local tgt_entity = tgt.entity
if tgt_entity then
    local MarkSystem = require("systems.mark_system")
    local defensive = MarkSystem.checkDefensiveMarks(
        tgt_entity,
        damage_type,
        pre_defense_damage,
        src.entity
    )

    defensive_mark_block = defensive.block
    defensive_mark_effects = defensive.effects
end

-- In per-type damage loop:
block_amt = block_amt + defensive_mark_block
```

### Effect Processing

After damage resolves, process `defensive_mark_effects`:
- `type = "chain"`: Chain lightning counter-attack
- `type = "apply_to_attacker"`: Apply mark to attacker
- Reflect damage queued as separate damage event

## Feature 3: Self-Applied Marks

### Card Property

Cards with `apply_to_self = "mark_id"` apply that mark to the caster.

Example:
```lua
Cards.STATIC_SHIELD = {
    id = "STATIC_SHIELD",
    type = "action",
    apply_to_self = "static_shield",
    self_mark_stacks = 1,
    -- ...
}
```

### Implementation in wand_actions.lua

```lua
-- After existing apply_mark logic in handleProjectileHit or executeEffectAction:
if actionCard and actionCard.apply_to_self then
    local mark_id = actionCard.apply_to_self
    local stacks = actionCard.self_mark_stacks or 1
    MarkSystem.apply(context.playerEntity, mark_id, {
        stacks = stacks,
        source = context.playerEntity
    })
end
```

## Files to Modify

| File | Changes |
|------|---------|
| `assets/scripts/systems/status_indicator_system.lua` | Implement rendering functions |
| `assets/scripts/combat/combat_system.lua` | Hook defensive marks into defense pipeline |
| `assets/scripts/wand/wand_actions.lua` | Add apply_to_self handling |
| `assets/scripts/data/cards.lua` | Update Static Shield with apply_to_self |

## Testing Plan

1. **Visual indicators**: Apply electrocute to enemy, verify icon appears and bobs
2. **Stack display**: Apply multiple static_charge stacks, verify count shows
3. **Status bar**: Apply 4+ statuses, verify condensed bar renders
4. **Defensive marks**: Cast Static Shield, take damage, verify counter-attack fires
5. **Self-applied marks**: Cast Static Shield, verify mark appears on player

## Known Limitations

- Shader effects require shaders to exist (electric_crackle, static_buildup, etc.)
- Missing icon sprites will use colored circle fallback
- No hover tooltips for status bar (future enhancement)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
