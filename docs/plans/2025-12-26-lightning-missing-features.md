# Lightning System Missing Features Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete the lightning system by implementing visual status indicators, self-applied marks, and defensive mark integration.

**Architecture:** Status indicators render via draw commands each frame, tracking icon entities per status. Defensive marks hook into the existing `Effects.deal_damage` defense calculation phase. Self-applied marks are a simple card property check in wand_actions.

**Tech Stack:** Lua, command_buffer draw API, ShaderBuilder, existing MarkSystem/StatusIndicatorSystem

---

## Task 1: Implement Floating Icon Rendering

**Files:**
- Modify: `assets/scripts/systems/status_indicator_system.lua:224-227`

**Step 1: Add helper function for icon position calculation**

Add after line 206 (after `getStatuses` function):

```lua
--- Calculate icon position above entity
--- @param transform table Entity's Transform component
--- @param indicator_data table Indicator data with bob_phase
--- @param icon_index number Which icon (0-indexed) for horizontal offset
--- @param total_icons number Total icons being rendered
--- @return number, number x, y position
local function calculateIconPosition(transform, indicator_data, icon_index, total_icons)
    local def = StatusEffects.get(indicator_data.status_id)
    local icon_offset = def and def.icon_offset or { x = 0, y = 0 }

    -- Entity center
    local cx = transform.actualX + (transform.actualW or 0) * 0.5
    local cy = transform.actualY

    -- Base offset above entity
    local base_y = cy + StatusIndicatorSystem.BAR_OFFSET_Y + (icon_offset.y or 0)

    -- Bob animation
    local bob = math.sin(indicator_data.bob_phase) * StatusIndicatorSystem.ICON_BOB_AMPLITUDE

    -- Horizontal spread for multiple icons (16px spacing, centered)
    local spacing = 16
    local total_width = (total_icons - 1) * spacing
    local start_x = cx - total_width * 0.5
    local x = start_x + icon_index * spacing + (icon_offset.x or 0)

    return x, base_y + bob
end
```

**Step 2: Implement showFloatingIcons function**

Replace the TODO stub at line 224-227:

```lua
--- Show floating icons (1-2 statuses)
function StatusIndicatorSystem.showFloatingIcons(entity, indicators)
    local transform = component_cache.get(entity, Transform)
    if not transform then return end

    -- Count and collect indicators
    local indicator_list = {}
    for status_id, data in pairs(indicators) do
        table.insert(indicator_list, data)
    end
    local total = #indicator_list

    -- Render each icon
    for i, data in ipairs(indicator_list) do
        local def = StatusEffects.get(data.status_id)
        if not def then goto continue end

        local x, y = calculateIconPosition(transform, data, i - 1, total)
        local icon_size = 16

        -- Try to render sprite, fallback to colored circle
        local sprite_id = def.icon
        if sprite_id and sprites and sprites[sprite_id] then
            command_buffer.queueDrawSprite(layers.ui_world, function(c)
                c.sprite = sprite_id
                c.x = x - icon_size * 0.5
                c.y = y - icon_size * 0.5
                c.w = icon_size
                c.h = icon_size
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        else
            -- Fallback: colored circle based on status type
            local color = StatusIndicatorSystem.getStatusColor(data.status_id)
            command_buffer.queueDrawCircle(layers.ui_world, function(c)
                c.x = x
                c.y = y
                c.radius = icon_size * 0.4
                c.color = color
                c.filled = true
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        end

        -- Stack count (if applicable)
        if def.show_stacks and data.stacks > 1 then
            command_buffer.queueDrawText(layers.ui_world, function(c)
                c.text = tostring(data.stacks)
                c.x = x + 6
                c.y = y + 4
                c.fontSize = 10
                c.color = util.getColor("WHITE")
            end, z_orders.status_icons + 1, layer.DrawCommandSpace.World)
        end

        ::continue::
    end
end
```

**Step 3: Add color helper function**

Add after the `calculateIconPosition` function:

```lua
--- Get color for status type (fallback when no sprite)
--- @param status_id string Status effect ID
--- @return table Color
function StatusIndicatorSystem.getStatusColor(status_id)
    local color_map = {
        electrocute = "CYAN",
        static_charge = "CYAN",
        static_shield = "BLUE",
        burning = "RED",
        frozen = "ICE",
        exposed = "YELLOW",
        heat_buildup = "ORANGE",
        oil_slick = "PURPLE",
    }
    local color_name = color_map[status_id] or "WHITE"
    return util.getColor(color_name)
end
```

**Step 4: Add z_orders.status_icons constant**

Check if `z_orders.status_icons` exists in `assets/scripts/core/z_orders.lua`. If not, add:

```lua
status_icons = 850,  -- Above entities, below UI
```

**Step 5: Call showFloatingIcons from update loop**

In `StatusIndicatorSystem.update(dt)`, after the expiration processing loop (around line 323), add rendering call:

```lua
    -- Render indicators for all entities
    for entity, indicators in pairs(StatusIndicatorSystem.active_indicators) do
        if registry:valid(entity) then
            local count = 0
            for _ in pairs(indicators) do count = count + 1 end

            if count <= StatusIndicatorSystem.MAX_FLOATING_ICONS then
                StatusIndicatorSystem.showFloatingIcons(entity, indicators)
            else
                StatusIndicatorSystem.showStatusBar(entity, indicators)
            end
        end
    end
```

**Step 6: Build and test visually**

Run: `just build-debug`
Test: Apply electrocute to an enemy (via chain lightning), verify cyan circle appears above them.

**Step 7: Commit**

```bash
git add assets/scripts/systems/status_indicator_system.lua assets/scripts/core/z_orders.lua
git commit -m "feat(status): implement floating icon rendering for status indicators"
```

---

## Task 2: Implement Status Bar (3+ statuses)

**Files:**
- Modify: `assets/scripts/systems/status_indicator_system.lua:230-233`

**Step 1: Implement showStatusBar function**

Replace the TODO stub:

```lua
--- Show condensed status bar (3+ statuses)
function StatusIndicatorSystem.showStatusBar(entity, indicators)
    local transform = component_cache.get(entity, Transform)
    if not transform then return end

    -- Entity center
    local cx = transform.actualX + (transform.actualW or 0) * 0.5
    local cy = transform.actualY + StatusIndicatorSystem.BAR_OFFSET_Y

    -- Collect indicators
    local indicator_list = {}
    for status_id, data in pairs(indicators) do
        table.insert(indicator_list, data)
    end
    local total = #indicator_list

    -- Calculate bar dimensions
    local icon_size = StatusIndicatorSystem.BAR_ICON_SIZE
    local spacing = StatusIndicatorSystem.BAR_SPACING
    local total_width = total * icon_size + (total - 1) * spacing
    local start_x = cx - total_width * 0.5

    -- Render each mini icon
    for i, data in ipairs(indicator_list) do
        local def = StatusEffects.get(data.status_id)
        if not def then goto continue end

        local x = start_x + (i - 1) * (icon_size + spacing) + icon_size * 0.5
        local y = cy

        -- Try sprite, fallback to mini colored circle
        local sprite_id = def.icon
        if sprite_id and sprites and sprites[sprite_id] then
            command_buffer.queueDrawSprite(layers.ui_world, function(c)
                c.sprite = sprite_id
                c.x = x - icon_size * 0.5
                c.y = y - icon_size * 0.5
                c.w = icon_size
                c.h = icon_size
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        else
            local color = StatusIndicatorSystem.getStatusColor(data.status_id)
            command_buffer.queueDrawCircle(layers.ui_world, function(c)
                c.x = x
                c.y = y
                c.radius = icon_size * 0.35
                c.color = color
                c.filled = true
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        end

        ::continue::
    end
end
```

**Step 2: Build and test**

Run: `just build-debug`
Test: Apply 4+ statuses to same enemy (may need debug command), verify horizontal bar appears.

**Step 3: Commit**

```bash
git add assets/scripts/systems/status_indicator_system.lua
git commit -m "feat(status): implement condensed status bar for 3+ effects"
```

---

## Task 3: Implement Shader Integration

**Files:**
- Modify: `assets/scripts/systems/status_indicator_system.lua:236-252`

**Step 1: Add shader tracking table**

Add to the module table at the top (around line 26):

```lua
    -- Track applied shaders per entity per status
    -- { [entity_id] = { [status_id] = shader_name } }
    applied_shaders = {},
```

**Step 2: Implement applyShader function**

Replace the TODO stub at line 236-239:

```lua
--- Apply shader effect to entity
function StatusIndicatorSystem.applyShader(entity, status_id, def, stacks)
    if not def.shader then return end

    local ShaderBuilder = require("core.shader_builder")

    -- Determine uniforms (stack-based or default)
    local uniforms = def.shader_uniforms or {}
    if def.shader_uniforms_per_stack and stacks then
        local idx = math.min(stacks, #def.shader_uniforms_per_stack)
        uniforms = def.shader_uniforms_per_stack[idx]
    end

    -- Apply shader
    ShaderBuilder.for_entity(entity)
        :add(def.shader, uniforms)
        :apply()

    -- Track for removal
    if not StatusIndicatorSystem.applied_shaders[entity] then
        StatusIndicatorSystem.applied_shaders[entity] = {}
    end
    StatusIndicatorSystem.applied_shaders[entity][status_id] = def.shader
end
```

**Step 3: Implement removeShader function**

Replace the TODO stub at line 242-244:

```lua
--- Remove shader effect from entity
function StatusIndicatorSystem.removeShader(entity, status_id)
    if not StatusIndicatorSystem.applied_shaders[entity] then return end

    local shader_name = StatusIndicatorSystem.applied_shaders[entity][status_id]
    if not shader_name then return end

    local ShaderBuilder = require("core.shader_builder")

    -- Remove the specific shader
    ShaderBuilder.for_entity(entity)
        :remove(shader_name)
        :apply()

    StatusIndicatorSystem.applied_shaders[entity][status_id] = nil

    -- Cleanup empty entity entry
    if next(StatusIndicatorSystem.applied_shaders[entity]) == nil then
        StatusIndicatorSystem.applied_shaders[entity] = nil
    end
end
```

**Step 4: Implement updateShaderForStacks function**

Replace the TODO stub at line 247-252:

```lua
--- Update shader uniforms based on stacks
function StatusIndicatorSystem.updateShaderForStacks(entity, status_id, def, stacks)
    if not def.shader_uniforms_per_stack then return end

    local idx = math.min(stacks, #def.shader_uniforms_per_stack)
    local uniforms = def.shader_uniforms_per_stack[idx]

    local ShaderBuilder = require("core.shader_builder")
    ShaderBuilder.for_entity(entity)
        :update(def.shader, uniforms)
        :apply()
end
```

**Step 5: Clean up shaders in hideAll**

In `hideAll` function (around line 150-156), add shader cleanup:

```lua
function StatusIndicatorSystem.hideAll(entity)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    for status_id, _ in pairs(StatusIndicatorSystem.active_indicators[entity]) do
        StatusIndicatorSystem.hide(entity, status_id)
    end

    -- Cleanup shader tracking
    StatusIndicatorSystem.applied_shaders[entity] = nil
end
```

**Step 6: Build and test**

Run: `just build-debug`
Test: Apply static_charge to enemy, verify shader tinting changes with stacks (if shader exists).

**Step 7: Commit**

```bash
git add assets/scripts/systems/status_indicator_system.lua
git commit -m "feat(status): implement shader integration for status effects"
```

---

## Task 4: Implement Self-Applied Marks

**Files:**
- Modify: `assets/scripts/wand/wand_actions.lua`
- Modify: `assets/scripts/data/cards.lua`

**Step 1: Add self-mark handling in executeEffectAction**

In `wand_actions.lua`, in the `executeEffectAction` function (around line 764), add at the start:

```lua
function WandActions.executeEffectAction(actionCard, modifiers, context)
    -- Handle self-applied marks
    if actionCard.apply_to_self then
        local mark_id = actionCard.apply_to_self
        local stacks = actionCard.self_mark_stacks or 1
        if context.playerEntity then
            MarkSystem.apply(context.playerEntity, mark_id, {
                stacks = stacks,
                source = context.playerEntity
            })
        end
    end

    -- Healing (existing code continues...)
    if actionCard.heal_amount then
```

**Step 2: Update Static Shield card definition**

In `assets/scripts/data/cards.lua`, find or add the Static Shield card:

```lua
Cards.STATIC_SHIELD = {
    id = "STATIC_SHIELD",
    name = "Static Shield",
    type = "action",
    mana_cost = 8,
    damage_type = "lightning",
    tags = { "Lightning", "Buff", "Defensive" },

    -- Self-applied mark
    apply_to_self = "static_shield",
    self_mark_stacks = 1,

    -- Visual
    sprite = "card-static-shield.png",
    description = "Surround yourself with crackling energy. Counter-attacks with lightning when hit.",
}
```

**Step 3: Build and test**

Run: `just build-debug`
Test: Cast Static Shield card, verify static_shield mark appears on player (cyan indicator above player).

**Step 4: Commit**

```bash
git add assets/scripts/wand/wand_actions.lua assets/scripts/data/cards.lua
git commit -m "feat(marks): implement self-applied marks for defensive cards"
```

---

## Task 5: Integrate Defensive Marks into Combat System

**Files:**
- Modify: `assets/scripts/combat/combat_system.lua:2202-2230`

**Step 1: Add MarkSystem require at top of combat_system.lua**

Near the top of the file with other requires:

```lua
local MarkSystem = require("systems.mark_system")
```

**Step 2: Add defensive mark check in deal_damage**

In `Effects.deal_damage`, after the dodge check (around line 2200) and before the block calculation, add:

```lua
    -- Defensive marks check
    local defensive_mark_result = { block = 0, reflect = 0, counter_damage = 0, effects = {} }
    local tgt_entity = tgt.entity  -- Get entity ID from combat actor
    if tgt_entity and MarkSystem then
        -- Calculate pre-defense damage estimate for defensive mark triggers
        local pre_defense_total = 0
        for _, c in ipairs(comps) do
            pre_defense_total = pre_defense_total + (c.amount or 0)
        end
        pre_defense_total = pre_defense_total * crit_mult

        -- Determine primary damage type
        local primary_damage_type = "physical"
        local max_amt = 0
        for _, c in ipairs(comps) do
            if c.amount > max_amt then
                max_amt = c.amount
                primary_damage_type = c.type
            end
        end

        local src_entity = src.entity
        defensive_mark_result = MarkSystem.checkDefensiveMarks(
            tgt_entity,
            primary_damage_type,
            pre_defense_total,
            src_entity
        )
    end
```

**Step 3: Apply defensive mark block in the block calculation**

Find the block calculation section (around line 2215) and add defensive mark block:

```lua
    -- Original block calculation
    if ctx.time:is_ready(tgt.timers, 'block')
        and math.random() * 100 < blk_chance then
      blocked    = true
      block_amt  = tgt.stats:get('block_amount')
      -- ... existing block code ...
    end

    -- Add defensive mark block (stacks with shield block)
    block_amt = block_amt + (defensive_mark_result.block or 0)
```

**Step 4: Process defensive mark effects after damage**

After the damage is applied (after the `ctx.bus:emit('OnHitResolved', ...)` call), add effect processing:

```lua
    -- Process defensive mark effects
    if defensive_mark_result.effects and #defensive_mark_result.effects > 0 then
        for _, effect in ipairs(defensive_mark_result.effects) do
            if effect.type == "chain" and src then
                -- Counter-attack chain lightning
                local chain_damage = defensive_mark_result.counter_damage or effect.damage or 25
                Effects.deal_damage {
                    components = {{ type = "lightning", amount = chain_damage }},
                    reason = "counter",
                    tags = { counter = true, defensive_mark = true }
                }(ctx, tgt, src)
            elseif effect.type == "apply_to_attacker" and effect.target then
                -- Apply mark to attacker
                MarkSystem.apply(effect.target, effect.status, { stacks = 1, source = tgt_entity })
            end
        end
    end

    -- Reflect damage
    if defensive_mark_result.reflect > 0 and src then
        Effects.deal_damage {
            components = {{ type = primary_damage_type or "physical", amount = defensive_mark_result.reflect }},
            reason = "reflect",
            tags = { reflect = true, defensive_mark = true }
        }(ctx, tgt, src)
    end
```

**Step 5: Build and test**

Run: `just build-debug`
Test:
1. Apply static_shield mark to player (via Static Shield card)
2. Take damage from enemy
3. Verify counter lightning damage fires back at attacker
4. Verify block amount reduced incoming damage

**Step 6: Commit**

```bash
git add assets/scripts/combat/combat_system.lua
git commit -m "feat(combat): integrate defensive marks into damage pipeline"
```

---

## Task 6: Final Integration Test

**Step 1: Run full build**

```bash
just build-debug
```

**Step 2: Manual test checklist**

- [ ] Electrocute enemy with Chain Lightning → cyan icon appears, bobs gently
- [ ] Apply 2 statuses → both icons show, spaced horizontally
- [ ] Apply 4+ statuses → condensed bar appears
- [ ] Stack static_charge 3x → stack count shows "3"
- [ ] Cast Static Shield → mark appears on player
- [ ] Take damage with Static Shield → counter-attack fires

**Step 3: Commit integration verification**

```bash
git add -A
git commit -m "test: verify lightning system missing features integration"
```

---

## Summary

| Task | Description | Complexity |
|------|-------------|------------|
| 1 | Floating icon rendering | Medium |
| 2 | Status bar (3+ effects) | Low |
| 3 | Shader integration | Medium |
| 4 | Self-applied marks | Low |
| 5 | Defensive marks in combat | High |
| 6 | Integration testing | Low |

**Total estimated time:** 45-60 minutes

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
