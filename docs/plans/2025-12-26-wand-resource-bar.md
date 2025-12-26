# Wand Resource Prediction Bar — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a fixed-position mana bar to the planning UI that shows total mana cost, cast block count, and overuse penalty prediction.

**Architecture:** New UI module `wand_resource_bar_ui.lua` that subscribes to deck change events, runs `simulate_wand()` for preview, and renders a horizontal progress bar with overflow zone.

**Tech Stack:** Lua, UI DSL (`ui_syntax_sugar.lua`), signal system, `card_eval_order_test.simulate_wand()`

---

## Task 1: Create Resource Bar Module Skeleton

**Files:**
- Create: `assets/scripts/ui/wand_resource_bar_ui.lua`

**Step 1: Create the module with basic structure**

```lua
-- wand_resource_bar_ui.lua
-- Planning phase UI showing mana cost prediction and overuse penalty

local signal = require("external.hump.signal")
local dsl = require("ui.ui_syntax_sugar")
local cardEval = require("core.card_eval_order_test")

local M = {}

-- State
local state = {
    uiBoxId = nil,
    visible = false,
    -- Cached simulation results
    totalManaCost = 0,
    maxMana = 100,
    castBlockCount = 0,
    overusePenaltySeconds = 0,
}

-- Configuration
local CONFIG = {
    barWidth = 220,
    barHeight = 16,
    x = 20,  -- Fixed position (will be set during init)
    y = 500,
}

function M.init(x, y)
    CONFIG.x = x or CONFIG.x
    CONFIG.y = y or CONFIG.y
end

function M.show()
    state.visible = true
    -- TODO: Create/show UI
end

function M.hide()
    state.visible = false
    -- TODO: Hide UI
end

function M.update(wandDef, cardPool)
    -- TODO: Run simulation and update display
end

return M
```

**Step 2: Verify file created**

Run: `ls -la assets/scripts/ui/wand_resource_bar_ui.lua`
Expected: File exists

**Step 3: Commit**

```bash
git add assets/scripts/ui/wand_resource_bar_ui.lua
git commit -m "feat(ui): add wand resource bar module skeleton"
```

---

## Task 2: Implement Mana Cost Calculation

**Files:**
- Modify: `assets/scripts/ui/wand_resource_bar_ui.lua`

**Step 1: Add simulation and cost calculation**

Replace the `M.update` function:

```lua
function M.update(wandDef, cardPool)
    if not wandDef or not cardPool then
        state.totalManaCost = 0
        state.castBlockCount = 0
        state.overusePenaltySeconds = 0
        return
    end

    -- Run simulation
    local simResult = cardEval.simulate_wand(wandDef, cardPool)
    if not simResult then return end

    -- Calculate total mana cost from all cards in all blocks
    local totalMana = 0
    for _, block in ipairs(simResult.blocks or {}) do
        for _, card in ipairs(block.cards or {}) do
            totalMana = totalMana + (card.mana_cost or 0)
        end
        -- Also count modifier costs
        for _, mod in ipairs(block.applied_modifiers or {}) do
            if mod.card then
                totalMana = totalMana + (mod.card.mana_cost or 0)
            end
        end
    end

    -- Store results
    state.totalManaCost = totalMana
    state.maxMana = wandDef.mana_max or 100
    state.castBlockCount = #(simResult.blocks or {})

    -- Calculate overuse penalty
    if totalMana > state.maxMana then
        local deficit = totalMana - state.maxMana
        local ratio = deficit / state.maxMana
        local penaltyFactor = wandDef.overheat_penalty_factor or 5.0
        local penaltyMult = 1.0 + (ratio * penaltyFactor)

        -- Estimate base cooldown (cast delay + recharge)
        local baseCooldown = (simResult.total_cast_delay or 0) + (simResult.total_recharge_time or 0)
        baseCooldown = baseCooldown / 1000  -- Convert ms to seconds

        state.overusePenaltySeconds = baseCooldown * (penaltyMult - 1.0)
    else
        state.overusePenaltySeconds = 0
    end
end

-- Getters for UI
function M.getManaCost() return state.totalManaCost end
function M.getMaxMana() return state.maxMana end
function M.getCastBlockCount() return state.castBlockCount end
function M.getOverusePenalty() return state.overusePenaltySeconds end
function M.isOverusing() return state.totalManaCost > state.maxMana end
```

**Step 2: Test calculation logic manually**

Run the game, open Lua console, test:
```lua
local bar = require("ui.wand_resource_bar_ui")
local testWand = { id = "test", mana_max = 50, overheat_penalty_factor = 5.0 }
local testCards = { { mana_cost = 20 }, { mana_cost = 40 } }
-- Note: Full test requires actual card pool from gameplay
```

**Step 3: Commit**

```bash
git add assets/scripts/ui/wand_resource_bar_ui.lua
git commit -m "feat(ui): add mana cost calculation to resource bar"
```

---

## Task 3: Implement Bar Rendering

**Files:**
- Modify: `assets/scripts/ui/wand_resource_bar_ui.lua`

**Step 1: Add UI creation function**

Add after CONFIG definition:

```lua
local function createBarUI()
    -- Destroy existing if present
    if state.uiBoxId then
        ui.box.DestroyUIBox(state.uiBoxId)
        state.uiBoxId = nil
    end

    local function getFillRatio()
        if state.maxMana <= 0 then return 0 end
        return math.min(state.totalManaCost / state.maxMana, 1.0)
    end

    local function getOverflowRatio()
        if state.maxMana <= 0 then return 0 end
        local overflow = math.max(0, state.totalManaCost - state.maxMana)
        return math.min(overflow / state.maxMana, 1.0)  -- Cap at 100% overflow
    end

    local function getBarColor()
        if state.totalManaCost > state.maxMana then
            return "orange"
        elseif state.totalManaCost >= state.maxMana * 0.9 then
            return "yellow"
        else
            return "cyan"
        end
    end

    local function getStatsText()
        local text = string.format("%d/%d mana  ·  %d cast blocks",
            state.totalManaCost, state.maxMana, state.castBlockCount)

        if state.overusePenaltySeconds > 0 then
            text = text .. string.format("  ·  +%.1fs Overuse Penalty", state.overusePenaltySeconds)
        end

        return text
    end

    local barUI = dsl.root {
        config = { padding = 4, background = "dark_panel" },
        children = {
            dsl.vbox {
                config = { gap = 4 },
                children = {
                    -- Main mana bar
                    dsl.hbox {
                        config = { gap = 0 },
                        children = {
                            -- Fill portion
                            dsl.box {
                                config = {
                                    minWidth = function()
                                        return CONFIG.barWidth * getFillRatio()
                                    end,
                                    minHeight = CONFIG.barHeight,
                                    background = getBarColor,
                                },
                            },
                            -- Empty portion (up to capacity)
                            dsl.box {
                                config = {
                                    minWidth = function()
                                        return CONFIG.barWidth * (1.0 - getFillRatio())
                                    end,
                                    minHeight = CONFIG.barHeight,
                                    background = "dark_gray",
                                },
                            },
                            -- Capacity marker
                            dsl.box {
                                config = {
                                    minWidth = 2,
                                    minHeight = CONFIG.barHeight + 4,
                                    background = "white",
                                },
                            },
                            -- Overflow zone
                            dsl.box {
                                config = {
                                    minWidth = function()
                                        return CONFIG.barWidth * 0.5 * getOverflowRatio()
                                    end,
                                    minHeight = CONFIG.barHeight,
                                    background = function()
                                        return getOverflowRatio() > 0 and "red" or "transparent"
                                    end,
                                },
                            },
                        },
                    },
                    -- Stats text
                    dsl.text(getStatsText, { fontSize = 12, color = "white" }),
                },
            },
        },
    }

    state.uiBoxId = dsl.spawn({ x = CONFIG.x, y = CONFIG.y }, barUI)
    ui.box.AssignStateTagsToUIBox(state.uiBoxId, PLANNING_STATE)

    return state.uiBoxId
end
```

**Step 2: Update show/hide functions**

```lua
function M.show()
    state.visible = true
    if not state.uiBoxId then
        createBarUI()
    end
end

function M.hide()
    state.visible = false
    if state.uiBoxId then
        ui.box.DestroyUIBox(state.uiBoxId)
        state.uiBoxId = nil
    end
end

function M.refresh()
    if state.visible and state.uiBoxId then
        -- UI DSL handles dynamic updates via functions
        -- Force redraw by destroying and recreating
        createBarUI()
    end
end
```

**Step 3: Commit**

```bash
git add assets/scripts/ui/wand_resource_bar_ui.lua
git commit -m "feat(ui): add bar rendering to resource bar"
```

---

## Task 4: Integrate with Planning Phase

**Files:**
- Modify: `assets/scripts/core/gameplay.lua`

**Step 1: Add require at top of gameplay.lua**

Find the require block (around line 1-50) and add:

```lua
local wandResourceBar = require("ui.wand_resource_bar_ui")
```

**Step 2: Initialize bar during planning UI setup**

Find where board sets are created (around line 5145-5175). After board creation, add:

```lua
-- Initialize wand resource bar below the boards
wandResourceBar.init(leftAlignValueTriggerBoardX, runningYValue + 10)
```

**Step 3: Show/hide bar on state transitions**

Find the planning state enter/exit handlers. Add to planning enter:

```lua
wandResourceBar.show()
```

Add to planning exit:

```lua
wandResourceBar.hide()
```

**Step 4: Subscribe to deck change events**

Find where deck_changed signal is emitted or handled. Add handler:

```lua
signal.register("deck_changed", function(data)
    -- Get current wand and card pool
    local wandDef = getCurrentWandDef()  -- You may need to implement/find this
    local cardPool = getCurrentCardPool()  -- You may need to implement/find this

    wandResourceBar.update(wandDef, cardPool)
    wandResourceBar.refresh()
end)
```

**Step 5: Commit**

```bash
git add assets/scripts/core/gameplay.lua assets/scripts/ui/wand_resource_bar_ui.lua
git commit -m "feat(ui): integrate resource bar with planning phase"
```

---

## Task 5: Test and Polish

**Files:**
- Modify: `assets/scripts/ui/wand_resource_bar_ui.lua` (as needed)

**Step 1: Run game and enter planning phase**

Expected: Resource bar appears at configured position

**Step 2: Add cards to wand**

Expected: Bar updates live, showing mana fill

**Step 3: Add cards until over capacity**

Expected:
- Bar shows overflow in red
- Penalty text appears: "+X.Xs Overuse Penalty"

**Step 4: Remove cards to go under capacity**

Expected:
- Overflow zone disappears
- Penalty text disappears

**Step 5: Exit planning phase**

Expected: Bar hides

**Step 6: Final commit**

```bash
git add -A
git commit -m "feat(ui): complete wand resource prediction bar"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Module skeleton | `wand_resource_bar_ui.lua` (create) |
| 2 | Mana calculation | `wand_resource_bar_ui.lua` |
| 3 | Bar rendering | `wand_resource_bar_ui.lua` |
| 4 | Planning integration | `gameplay.lua`, `wand_resource_bar_ui.lua` |
| 5 | Test and polish | Both files as needed |

## Notes

- The UI DSL may need adjustment based on how dynamic width boxes behave
- Position (CONFIG.x, CONFIG.y) may need tuning based on actual planning UI layout
- If deck_changed signal doesn't exist, you may need to emit it from card add/remove handlers
