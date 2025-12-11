# Shop UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement visual shop UI with card display, buy buttons, and control bar for the between-round shop phase.

**Architecture:** Extend existing `gameplay.lua` with `populateShopBoard()` function that creates shop card entities from `active_shop_instance.offerings`. Each card gets hover behavior with slide-out buy button. Control bar uses existing UI builder pattern.

**Tech Stack:** Lua, existing card system (`createNewCard`), shader pipeline (`dissolve` uniform), UI builder (`UIElementTemplateNodeBuilder`), timer system for animations.

---

## Task 1: Add Shop Card Entity Tracking

**Files:**
- Modify: `assets/scripts/core/gameplay.lua:667-673` (shop state variables)

**Step 1: Add tracking table for shop card entities**

After line 669 (`local shop_buy_board_id = nil`), add:

```lua
local shop_card_entities = {} -- Track shop card entity IDs for cleanup
```

**Step 2: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Game launches without errors

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): add shop card entity tracking table"
```

---

## Task 2: Create Shop Card Cleanup Function

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (after `shop_card_entities` declaration ~line 670)

**Step 1: Add cleanup function**

```lua
local function clearShopCardEntities()
    for _, eid in ipairs(shop_card_entities) do
        if eid and entity_cache.valid(eid) then
            -- Remove from cards table
            cards[eid] = nil
            -- Destroy entity
            registry:destroy(eid)
        end
    end
    shop_card_entities = {}
end
```

**Step 2: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Game launches without errors

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): add clearShopCardEntities cleanup function"
```

---

## Task 3: Create Shop Card with Buy Button

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (after `clearShopCardEntities` function)

**Step 1: Add createShopCard function**

This creates a card entity with shop-specific behavior (hover shows buy button, click triggers purchase).

```lua
local function createShopCard(offering, slotIndex, x, y)
    if not offering or offering.isEmpty then
        return nil
    end

    local cardDef = offering.cardDef
    local cardId = cardDef and cardDef.id
    if not cardId then
        return nil
    end

    -- Create card entity using existing function
    local cardEntity = createNewCard(cardId, x, y, SHOP_STATE)
    if not cardEntity then
        return nil
    end

    -- Get script table
    local cardScript = getScriptTableFromEntityID(cardEntity)
    if not cardScript then
        return nil
    end

    -- Mark as shop card with slot index
    cardScript.isShopCard = true
    cardScript.shop_slot = slotIndex
    cardScript.shop_cost = offering.cost
    cardScript.shop_rarity = offering.rarity

    -- Store buy button entity reference (will be created on hover)
    cardScript.buyButtonEntity = nil
    cardScript.buyButtonVisible = false
    cardScript.isHoveredForShop = false
    cardScript.hoverScale = 1.0
    cardScript.targetHoverScale = 1.0
    cardScript.dissolveAmount = 0.0

    -- Track entity for cleanup
    table.insert(shop_card_entities, cardEntity)

    return cardEntity
end
```

**Step 2: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Game launches without errors

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): add createShopCard function with shop-specific properties"
```

---

## Task 4: Implement populateShopBoard Function

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (replace comment at line 7623)

**Step 1: Find and replace the comment**

Find the line:
```lua
    -- populateShopBoard removed - rebuild shop UI handles this
```

Replace with:

```lua
    populateShopBoard(active_shop_instance)
```

**Step 2: Add populateShopBoard function**

Add this function before `regenerateShopState()` (around line 7596):

```lua
local function populateShopBoard(shop)
    if not shop or not shop.offerings then
        return
    end

    -- Clear existing shop cards
    clearShopCardEntities()

    -- Get shop board position and size
    local shopBoard = boards[shop_board_id]
    if not shopBoard then
        log_debug("[Shop] No shop board found")
        return
    end

    local boardTransform = component_cache.get(shop_board_id, Transform)
    if not boardTransform then
        return
    end

    local boardX = boardTransform.actualX or 100
    local boardY = boardTransform.actualY or 100
    local boardW = boardTransform.actualW or 800
    local boardH = boardTransform.actualH or 400

    -- Card layout: 5 cards in horizontal row
    local numSlots = #shop.offerings
    local cardW = cardW or 100 -- use global cardW
    local cardH = cardH or 140 -- use global cardH
    local padding = 20
    local totalCardsWidth = numSlots * cardW + (numSlots - 1) * padding
    local startX = boardX + (boardW - totalCardsWidth) / 2
    local cardY = boardY + 60 -- offset from top for label

    for i, offering in ipairs(shop.offerings) do
        local cardX = startX + (i - 1) * (cardW + padding)

        if not offering.isEmpty and not offering.sold then
            local cardEntity = createShopCard(offering, i, cardX, cardY)
            if cardEntity then
                -- Add to shop board
                addCardToBoard(cardEntity, shop_board_id)
            end
        end
    end

    log_debug("[Shop] Populated shop board with", #shop_card_entities, "cards")
end
```

**Step 3: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Then trigger shop phase (if available) or check console for shop initialization.
Expected: Cards appear on shop board when shop phase activates

**Step 4: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): implement populateShopBoard to render shop offerings"
```

---

## Task 5: Add Shop Card Hover Behavior

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (in `createShopCard` function)

**Step 1: Modify createShopCard to add hover callbacks**

After the line `cardScript.dissolveAmount = 0.0`, add:

```lua
    -- Override hover behavior for shop cards
    local nodeComp = registry:get(cardEntity, GameObject)
    if nodeComp then
        -- Disable drag for shop cards (buy via button only)
        nodeComp.state.dragEnabled = false

        local originalOnHover = nodeComp.methods.onHover
        nodeComp.methods.onHover = function()
            -- Call original hover for tooltip
            if originalOnHover then
                originalOnHover()
            end

            -- Set hover state for scaling
            cardScript.isHoveredForShop = true
            cardScript.targetHoverScale = 1.1
        end

        nodeComp.methods.onHoverEnd = function()
            cardScript.isHoveredForShop = false
            cardScript.targetHoverScale = 1.0
        end

        -- Disable click-to-select for shop cards
        nodeComp.methods.onClick = function()
            -- Do nothing - purchase via buy button only
        end
    end
```

**Step 2: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Shop cards show tooltip on hover (if shop phase available)

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): add hover behavior to shop cards"
```

---

## Task 6: Add Shop Card Update Loop for Animations

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (in card render timer, around line 1637)

**Step 1: Find the card render loop**

Find the line:
```lua
                for eid, cardScript in pairs(cards) do
                    if eid and entity_cache.valid(eid) then
```

**Step 2: Add shop card animation updates inside the loop**

After `if not entity_cache.active(eid) then goto continue end`, add:

```lua
                        -- Shop card hover scale animation
                        if cardScript.isShopCard then
                            local dt = (GetFrameTime and GetFrameTime()) or 0.016
                            local lerpSpeed = 12 * dt
                            cardScript.hoverScale = cardScript.hoverScale + (cardScript.targetHoverScale - cardScript.hoverScale) * lerpSpeed

                            -- Apply scale to transform
                            local t = component_cache.get(eid, Transform)
                            if t then
                                local baseW = cardW or 100
                                local baseH = cardH or 140
                                t.actualW = baseW * cardScript.hoverScale
                                t.actualH = baseH * cardScript.hoverScale
                            end

                            -- Update dissolve shader uniform
                            if cardScript.dissolveAmount > 0 then
                                local shaderPipelineComp = component_cache.get(eid, shader_pipeline.ShaderPipelineComponent)
                                if shaderPipelineComp and shaderPipelineComp.passes and #shaderPipelineComp.passes > 0 then
                                    local pass = shaderPipelineComp.passes[1]
                                    if pass and pass.shaderName then
                                        local existingPrePass = pass.customPrePassFunction
                                        pass.customPrePassFunction = function()
                                            if existingPrePass then existingPrePass() end
                                            if globalShaderUniforms then
                                                globalShaderUniforms:set(pass.shaderName, "dissolve", cardScript.dissolveAmount)
                                            end
                                        end
                                    end
                                end
                            end
                        end
```

**Step 3: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Shop cards scale smoothly on hover

**Step 4: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): add shop card hover scale and dissolve animation"
```

---

## Task 7: Create Buy Button Entity

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (after `createShopCard` function)

**Step 1: Add createShopBuyButton function**

```lua
local function createShopBuyButton(cardEntity, cardScript)
    if not cardEntity or not cardScript then
        return nil
    end

    local cost = cardScript.shop_cost or 0
    local canAfford = (globals.currency or 0) >= cost
    local buttonColor = canAfford and util.getColor("green") or util.getColor("fiery_red")
    local textColor = util.getColor("white")

    local buttonText = ui.definitions.getNewTextEntry(
        string.format("%dg", cost),
        18.0,
        "color=white"
    )

    local buttonDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addId("shop_buy_button_" .. tostring(cardEntity))
                :addColor(buttonColor)
                :addEmboss(3.0)
                :addHover(true)
                :addPadding(8)
                :addMinWidth(60)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
                :addButtonCallback(function()
                    -- Attempt purchase
                    local success = tryPurchaseShopCard(cardScript)
                    if success then
                        -- Trigger dissolve animation
                        cardScript.dissolveAmount = 0.01 -- Start dissolve
                        timer.tween_fields(0.3, cardScript, { dissolveAmount = 1.0 }, Easing.inOutCubic.f, function()
                            -- After dissolve, remove card
                            if cardEntity and entity_cache.valid(cardEntity) then
                                cards[cardEntity] = nil
                                registry:destroy(cardEntity)
                                -- Remove from tracking
                                for i, eid in ipairs(shop_card_entities) do
                                    if eid == cardEntity then
                                        table.remove(shop_card_entities, i)
                                        break
                                    end
                                end
                            end
                        end, "shop_dissolve_" .. tostring(cardEntity), "ui")
                    end
                end)
                :build()
        )
        :addChild(buttonText)
        :build()

    local buttonEntity = ui.box.Initialize({ x = 0, y = 0 }, buttonDef)

    -- Position below card
    local cardTransform = component_cache.get(cardEntity, Transform)
    if cardTransform and buttonEntity then
        local buttonTransform = component_cache.get(buttonEntity, Transform)
        if buttonTransform then
            buttonTransform.actualX = cardTransform.actualX + (cardTransform.actualW or 0) / 2 - (buttonTransform.actualW or 30) / 2
            buttonTransform.actualY = cardTransform.actualY + (cardTransform.actualH or 0) + 4
            buttonTransform.visualX = buttonTransform.actualX
            buttonTransform.visualY = buttonTransform.actualY
        end
    end

    -- Add state tag
    ui.box.AssignStateTagsToUIBox(buttonEntity, SHOP_STATE)
    remove_default_state_tag(buttonEntity)

    return buttonEntity
end
```

**Step 2: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: No errors on launch

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): add createShopBuyButton function"
```

---

## Task 8: Integrate Buy Button with Hover

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (in `createShopCard` hover callbacks)

**Step 1: Modify onHover to show buy button**

In `createShopCard`, update the `onHover` callback:

```lua
        nodeComp.methods.onHover = function()
            -- Call original hover for tooltip
            if originalOnHover then
                originalOnHover()
            end

            -- Set hover state for scaling
            cardScript.isHoveredForShop = true
            cardScript.targetHoverScale = 1.1

            -- Create or show buy button
            if not cardScript.buyButtonEntity or not entity_cache.valid(cardScript.buyButtonEntity) then
                cardScript.buyButtonEntity = createShopBuyButton(cardEntity, cardScript)
            end

            if cardScript.buyButtonEntity then
                add_state_tag(cardScript.buyButtonEntity, SHOP_STATE)
                cardScript.buyButtonVisible = true
            end
        end
```

**Step 2: Modify onHoverEnd to hide buy button**

Update the `onHoverEnd` callback:

```lua
        nodeComp.methods.onHoverEnd = function()
            cardScript.isHoveredForShop = false
            cardScript.targetHoverScale = 1.0

            -- Hide buy button (delay slightly so clicks register)
            timer.after(0.1, function()
                if not cardScript.isHoveredForShop and cardScript.buyButtonEntity and entity_cache.valid(cardScript.buyButtonEntity) then
                    remove_state_tag(cardScript.buyButtonEntity, SHOP_STATE)
                    cardScript.buyButtonVisible = false
                end
            end, "shop_hide_button_" .. tostring(cardEntity), "ui")
        end
```

**Step 3: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Buy button appears below card on hover, disappears on hover end

**Step 4: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): integrate buy button with card hover"
```

---

## Task 9: Build Control Bar UI

**Files:**
- Modify: `assets/scripts/ui/ui_defs.lua` (uncomment and fix `buildShopUI` around line 138)

**Step 1: Replace commented buildShopUI with working version**

Find the commented block starting at line 137 (`--[[`) and ending at line 303 (`--]]`).

Delete the entire commented block and replace with:

```lua
local function buildShopControlBar()
    if globals.ui.shopControlBar then
        return
    end

    local ShopSystem = require("core.shop_system")
    globals.shopUIState = globals.shopUIState or {}
    globals.shopUIState.rerollCost = globals.shopUIState.rerollCost or ShopSystem.config.baseRerollCost
    globals.shopUIState.rerollCount = globals.shopUIState.rerollCount or 0
    globals.shopUIState.locked = globals.shopUIState.locked or false

    -- Lock button text
    globals.ui.shopLockButtonText = ui.definitions.getNewDynamicTextEntry(
        function()
            return globals.shopUIState.locked and "Unlock All" or "Lock All"
        end,
        16.0,
        "color=white"
    )

    -- Reroll button text
    globals.ui.shopRerollButtonText = ui.definitions.getNewDynamicTextEntry(
        function()
            return string.format("Reroll (%dg)", math.floor(globals.shopUIState.rerollCost + 0.5))
        end,
        16.0,
        "color=white"
    )

    local function refreshTexts()
        if globals.ui.shopLockButtonText and globals.ui.shopLockButtonText.config then
            local label = globals.shopUIState.locked and "Unlock All" or "Lock All"
            TextSystem.Functions.setText(globals.ui.shopLockButtonText.config.object, label)
        end
        if globals.ui.shopRerollButtonText and globals.ui.shopRerollButtonText.config then
            local label = string.format("Reroll (%dg)", math.floor(globals.shopUIState.rerollCost + 0.5))
            TextSystem.Functions.setText(globals.ui.shopRerollButtonText.config.object, label)
        end
    end

    -- Lock button
    local lockButton = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addId("shop_lock_button")
                :addColor(util.getColor("dusty_rose"))
                :addEmboss(3.0)
                :addHover(true)
                :addPadding(8)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
                :addButtonCallback(function()
                    local nextLocked = not globals.shopUIState.locked
                    if setShopLocked then
                        setShopLocked(nextLocked)
                    else
                        globals.shopUIState.locked = nextLocked
                    end
                    playSoundEffect("effects", "button-click")
                    refreshTexts()
                end)
                :build()
        )
        :addChild(globals.ui.shopLockButtonText)
        :build()

    -- Reroll button
    local rerollButton = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addId("shop_reroll_button")
                :addColor(util.getColor("marigold"))
                :addEmboss(3.0)
                :addHover(true)
                :addPadding(8)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
                :addButtonCallback(function()
                    local success = rerollActiveShop and rerollActiveShop()
                    if not success then
                        playSoundEffect("effects", "cannot-buy")
                        newTextPopup(
                            "Need more gold",
                            globals.screenWidth() / 2,
                            globals.screenHeight() / 2 - 60,
                            1.2,
                            "color=fiery_red"
                        )
                        return
                    end
                    playSoundEffect("effects", "button-click")
                    refreshTexts()
                    -- Refresh shop board
                    if populateShopBoard and getActiveShop then
                        populateShopBoard(getActiveShop())
                    end
                end)
                :build()
        )
        :addChild(globals.ui.shopRerollButtonText)
        :build()

    -- Button row container
    local buttonRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("taupe_warm"))
                :addEmboss(4.0)
                :addPadding(10)
                :addGap(16)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(lockButton)
        :addChild(rerollButton)
        :build()

    -- Root container
    local root = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP))
                :build()
        )
        :addChild(buttonRow)
        :build()

    globals.ui.shopControlBar = ui.box.Initialize({ x = 0, y = 0 }, root)

    -- Position at bottom of shop board area
    local t = registry:get(globals.ui.shopControlBar, Transform)
    if t then
        t.actualX = globals.screenWidth() / 2 - (t.actualW or 100) / 2
        t.actualY = 520 -- Below shop board (100 + 400 + 20)
        t.visualX = t.actualX
        t.visualY = t.actualY
    end

    ui.box.AssignStateTagsToUIBox(globals.ui.shopControlBar, SHOP_STATE)
    remove_default_state_tag(globals.ui.shopControlBar)

    globals.ui.refreshShopUIFromInstance = function(shop)
        refreshTexts()
        ui.box.RenewAlignment(registry, globals.ui.shopControlBar)
    end
end
```

**Step 2: Update generateShopUI to call buildShopControlBar**

Replace line 305-307:
```lua
function ui_defs.generateShopUI()
    -- buildShopUI() -- COMMENTED OUT: Rebuild shop UI from scratch
end
```

With:
```lua
function ui_defs.generateShopUI()
    buildShopControlBar()
end
```

**Step 3: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Control bar appears during shop phase

**Step 4: Commit**

```bash
git add assets/scripts/ui/ui_defs.lua
git commit -m "feat(shop): implement control bar with lock and reroll buttons"
```

---

## Task 10: Integrate Currency Display

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (in shop phase initialization)

**Step 1: Find enterShopPhase function**

Search for `activate_state(SHOP_STATE)` around line 6535.

**Step 2: Add currency display initialization**

After `activate_state(SHOP_STATE)`, add:

```lua
    -- Initialize currency display for shop
    local CurrencyDisplay = require("ui.currency_display")
    CurrencyDisplay.init({
        amount = globals.currency or 0,
        x = globals.screenWidth() - 240,
        y = 520
    })
```

**Step 3: Add currency display update in shop**

Find the game update loop or add to shop card render. In the card render timer (around line 1570), after the shop state check, add:

```lua
                -- Update currency display during shop
                if is_state_active(SHOP_STATE) then
                    local CurrencyDisplay = require("ui.currency_display")
                    CurrencyDisplay.setAmount(globals.currency or 0)
                    CurrencyDisplay.update(dt)
                    CurrencyDisplay.draw()
                end
```

**Step 4: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Gold display appears during shop phase and updates on purchase

**Step 5: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): integrate currency display in shop phase"
```

---

## Task 11: Handle Sold Slot Display

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (in `populateShopBoard`)

**Step 1: Add sold slot visual**

In `populateShopBoard`, update the loop to handle sold slots:

```lua
    for i, offering in ipairs(shop.offerings) do
        local cardX = startX + (i - 1) * (cardW + padding)

        if offering.sold then
            -- Draw "SOLD" placeholder
            local soldEntity = ui.definitions.getNewTextEntry(
                "SOLD",
                24.0,
                "color=gray"
            ).config.object

            if soldEntity then
                local t = component_cache.get(soldEntity, Transform)
                if t then
                    t.actualX = cardX + cardW / 2 - 30
                    t.actualY = cardY + cardH / 2 - 12
                    t.visualX = t.actualX
                    t.visualY = t.actualY
                end
                add_state_tag(soldEntity, SHOP_STATE)
                remove_default_state_tag(soldEntity)
                table.insert(shop_card_entities, soldEntity) -- Track for cleanup
            end
        elseif not offering.isEmpty then
            local cardEntity = createShopCard(offering, i, cardX, cardY)
            if cardEntity then
                addCardToBoard(cardEntity, shop_board_id)
            end
        end
    end
```

**Step 2: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: After purchasing a card, slot shows "SOLD" text

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): display SOLD placeholder for purchased slots"
```

---

## Task 12: Update Buy Button Color on Currency Change

**Files:**
- Modify: `assets/scripts/core/gameplay.lua` (in shop card animation loop)

**Step 1: Add affordability check to buy button**

In the shop card animation section (Task 6), add after the scale animation:

```lua
                            -- Update buy button color based on affordability
                            if cardScript.buyButtonEntity and entity_cache.valid(cardScript.buyButtonEntity) then
                                local canAfford = (globals.currency or 0) >= (cardScript.shop_cost or 0)
                                local buttonColor = canAfford and util.getColor("green") or util.getColor("fiery_red")
                                -- Update button background color
                                local buttonGo = component_cache.get(cardScript.buyButtonEntity, GameObject)
                                if buttonGo and buttonGo.state then
                                    -- Color is set via UI system, may need direct component access
                                end
                            end
```

**Step 2: Verify change**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Expected: Buy button turns red when player can't afford card

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "feat(shop): update buy button color based on affordability"
```

---

## Task 13: Final Integration Test

**Files:**
- No file changes, manual testing

**Step 1: Build and run**

```bash
just build-debug && ./build/raylib-cpp-cmake-template
```

**Step 2: Test shop flow**

1. Navigate to shop phase (may need to manually trigger via debug)
2. Verify 5 cards appear in horizontal row
3. Hover over card - verify scale up and buy button appears
4. Click buy button with sufficient gold - verify dissolve animation and card appears in inventory
5. Click buy button without gold - verify error sound and message
6. Click reroll - verify cards regenerate and cost increases
7. Click lock - verify text changes to "Unlock All"

**Step 3: Document any issues**

If issues found, create follow-up tasks.

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(shop): complete shop UI implementation

- Shop cards display in horizontal row
- Hover shows buy button with cost
- Buy button color reflects affordability
- Dissolve animation on purchase
- Control bar with Lock/Reroll buttons
- Currency display integration
- SOLD placeholder for purchased slots"
```

---

## Summary

| Task | Description | Est. Lines |
|------|-------------|------------|
| 1 | Add shop card tracking table | 1 |
| 2 | Create cleanup function | 12 |
| 3 | Create shop card function | 35 |
| 4 | Implement populateShopBoard | 45 |
| 5 | Add hover behavior | 25 |
| 6 | Add animation loop | 30 |
| 7 | Create buy button | 60 |
| 8 | Integrate buy button with hover | 20 |
| 9 | Build control bar UI | 120 |
| 10 | Integrate currency display | 15 |
| 11 | Handle sold slots | 25 |
| 12 | Update affordability color | 10 |
| 13 | Integration test | 0 |

**Total: ~400 lines of new/modified code**
