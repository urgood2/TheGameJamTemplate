


-- contains code limited to gameplay logic for organizational purposes

local z_orders = require("core.z_orders")
local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script
local palette = require("color.palette")
local TimerChain = require("core.timer_chain")
local Easing = require("util.easing")

--  let's make some card data
local action_card_defs = {
    {
        id = "fire_basic_bolt", -- at target, or in direction if no target
    },
    {
        id = "leave_spike_hazard",
    },
    {
        id = "temporary_strength_bonus"
    }
    
}
local trigger_card_defs = {
    {
        id = "every_N_seconds"
    },
    {
        id = "on_pickup"
    },
    {
        id = "on_distance_moved"
    }
}
local modifier_card_defs = {
    {
        id = "double_effect"
    },
    {
        id = "summon_minion_wandering"
    },
    {
        id = "projectile_pierces_twice"
    }
}


-- save game state strings
PLANNING_STATE = "PLANNING"
ACTION_STATE = "SURVIVORS"

survivorEntity = nil
boards = {}
trigger_board_id = nil

function addCardToBoard(cardEntityID, boardEntityID)
    if not cardEntityID or cardEntityID == entt_null or not registry:valid(cardEntityID) then return end
    if not boardEntityID or boardEntityID == entt_null or not registry:valid(boardEntityID) then return end
    local board = boards[boardEntityID]
    if not board then return end
    board.cards = board.cards or {}
    table.insert(board.cards, cardEntityID)
    log_debug("Added card", cardEntityID, "to board", boardEntityID)
end

function removeCardFromBoard(cardEntityID, boardEntityID)
    if not cardEntityID or cardEntityID == entt_null or not registry:valid(cardEntityID) then return end
    if not boardEntityID or boardEntityID == entt_null or not registry:valid(boardEntityID) then return end
    local board = boards[boardEntityID]
    if not board then return end
    board.cards = board.cards or {}
    for i, eid in ipairs(board.cards) do
        if eid == cardEntityID then
            table.remove(board.cards, i)
            break
        end
    end
end

function resetCardStackZOrder(rootCardEntityID)
    local rootCardScript = getScriptTableFromEntityID(rootCardEntityID)
    if not rootCardScript or not rootCardScript.cardStack then return end
    local baseZ = z_orders.card
    
    -- give root entity the base z order
    layer_order_system.assignZIndexToEntity(rootCardScript:handle(), baseZ)
    
    -- now for every card in the stack, give it a z order above the root
    for i, stackedCardEid in ipairs(rootCardScript.cardStack) do
        if stackedCardEid and registry:valid(stackedCardEid) then
            local stackedTransform = registry:get(stackedCardEid, Transform)
            local zi = baseZ + (i) -- root is baseZ, first stacked card is baseZ + 1, etc
            layer_order_system.assignZIndexToEntity(stackedCardEid, zi)
        end
    end
end

function createNewBoard(x, y, w, h) 
   
    local board = Node{}
    board.z_orders = { bottom = z_orders.card, top = z_orders.card + 1000 } -- save specific z orders for the card in the board.
    board.z_order_cache_per_card = {} -- cache for z orders per card entity id.
    board.cards = {} -- no starting cards
    board.update = function(self, dt)
        local eid = self:handle()
        if not eid or not registry:valid(eid) then return end

        local area = registry:get(eid, Transform)

        local cards = self.cards or {}
        local n = #cards
        if n == 0 then return end

        -- probe card size
        local cardW, cardH = 100, 140
        for _, cardEid in ipairs(cards) do
            if cardEid and registry:valid(cardEid) and cardEid ~= entt_null then
                local ct = registry:get(cardEid, Transform)
                if ct and ct.actualW and ct.actualH and ct.actualW > 0 and ct.actualH > 0 then
                    cardW, cardH = ct.actualW, ct.actualH
                    break
                end
            end
        end

        -- layout
        local padding = 20
        local availW = math.max(0, area.actualW - padding * 2)
        local minGap = 12

        local spacing, groupW
        if n == 1 then
            spacing = 0
            groupW  = cardW
        else
            local fitSpacing = (availW - cardW) / (n - 1)
            spacing = math.max(minGap, fitSpacing)
            groupW  = cardW + spacing * (n - 1)
            if groupW > availW then
                spacing = math.max(0, fitSpacing)
                groupW  = cardW + spacing * (n - 1)
            end
        end

        local startX  = area.actualX + padding + (availW - groupW) * 0.5
        local centerY = area.actualY + area.actualH * 0.5

        -- z-order cache (per card)
        self.z_order_cache_per_card = self.z_order_cache_per_card or {}
        local baseZ = z_orders.card
        
        -- sort the cards by actualX
        table.sort(cards, function(a, b)
            if not (a and registry:valid(a) and a ~= entt_null) then return false end
            if not (b and registry:valid(b) and b ~= entt_null) then return true  end

            local at = registry:get(a, Transform)
            local bt = registry:get(b, Transform)
            if not (at and bt) then return false end

            local aCenterX = at.actualX + at.actualW * 0.5
            local bCenterX = bt.actualX + bt.actualW * 0.5

            if aCenterX == bCenterX then
                return a < b   -- compare raw entity ids
            end
            return aCenterX < bCenterX
        end)


        for i, cardEid in ipairs(cards) do
            if cardEid and registry:valid(cardEid) and cardEid ~= entt_null then
                local ct = registry:get(cardEid, Transform)
                if ct then
                    ct.actualX = math.floor(startX + (i - 1) * spacing + 0.5)
                    ct.actualY = math.floor(centerY - ct.actualH * 0.5 + 0.5)
                end
                
                -- don't overwrite zIndex if the card is being dragged
                local zi = baseZ + (i - 1)
                self.z_order_cache_per_card[cardEid] = zi
                
                -- assign zIndex via LayerOrder system
                layer_order_system.assignZIndexToEntity(cardEid, zi)
                
                local cardGameObject = registry:get(cardEid, GameObject)
                if cardGameObject and cardGameObject.state and cardGameObject.state.isBeingDragged then
                    --overwrite
                    layer_order_system.assignZIndexToEntity(cardEid, self.z_orders.top)
                end
                
        
            end
        end
    end
    board:attach_ecs{ create_new = true }
    transform.CreateOrEmplace(registry, globals.gameWorldContainerEntity(), x, y, w, h, board:handle())
    boards[board:handle()] = board
    add_state_tag(board:handle(), PLANNING_STATE)
    
    -- get the game object for board and make it onReleaseEnabled
    local boardGameObject = registry:get(board:handle(), GameObject)
    if boardGameObject then
        boardGameObject.state.hoverEnabled = true
        boardGameObject.state.triggerOnReleaseEnabled = true
        boardGameObject.state.collisionEnabled = true   
    end
    -- give onRelease method to the board
    boardGameObject.methods.onRelease = function(registry, releasedOn, released)
        log_debug("Entity", released, "released on", releasedOn)
        
        -- when released on top of a board, add self to that board's card list
        
        -- is the released entity a card?
        local releasedCardScript = getScriptTableFromEntityID(released)
        if not releasedCardScript then return end
        
        -- check that it isn't already in this board
        for _, eid in ipairs(board.cards) do
            if eid == released then
                log_debug("released card is already in this board, not adding again")
                return   
            end
        end
        
        -- TODO: check it isn't part of a stack. if it is, add to the board only if it's the root entity of the stack.
        if releasedCardScript.stackRootEntity and releasedCardScript.stackRootEntity ~= released then
            log_debug("released card is part of a stack, and is not the root. not adding to board")
            return
        end
        
        
        -- remove it from any existing board it may be in
        for boardEid, boardScript in pairs(boards) do
            if boardScript and boardScript.cards then
                for i, eid in ipairs(boardScript.cards) do
                    if eid == released then
                        table.remove(boardScript.cards, i)
                    end
                end
            end
        end
        
        -- add it to this board
        addCardToBoard(released, board:handle())
        
        -- if this card was part of a stack, reset the z-orders of the stack
        if releasedCardScript.stackRootEntity and releasedCardScript.stackRootEntity == released then
            resetCardStackZOrder(releasedCardScript:handle())
        end
    end
    
    return board:handle()
end

function addCardToStack(rootCardScript, cardScriptToAdd)
    if not rootCardScript or not rootCardScript.cardStack then return false end
    for _, cardEid in ipairs(rootCardScript.cardStack) do
        if cardEid == cardScriptToAdd:handle() then
            log_debug("card is already in the stack, not adding again")
            return false
        end
    end
    
    -- only let action mods stack on top of actions
    if rootCardScript.category == "action" and cardScriptToAdd.category ~= "modifier" then
        log_debug("can only stack modifier cards on top of action cards")
        return false
    end
    
    -- don't let mods stack on other mods or triggers
    if rootCardScript.category == "modifier" then
        log_debug("cannot stack on top of modifier cards")
        return false
    end
    
    -- don't let actions stack on other actions or triggers
    if rootCardScript.category == "trigger" then
        log_debug("cannot stack on top of trigger cards")
        return false
    end
    
    
    
    table.insert(rootCardScript.cardStack, cardScriptToAdd:handle())
    -- also store a reference to the root entity in self
    cardScriptToAdd.stackRootEntity = rootCardScript:handle()
    -- mark as stack child
    cardScriptToAdd.isStackChild = true    
end

function removeCardFromStack(rootCardScript, cardScriptToRemove)
    if not rootCardScript or not rootCardScript.cardStack then return end
    
    -- is the card the root of a stack? then remove all children
    if rootCardScript.stackRootEntity == rootCardScript:handle() then
        for _, cardEid in ipairs(rootCardScript.cardStack) do
            local childCardScript = getScriptTableFromEntityID(cardEid)
            if childCardScript then
                childCardScript.stackRootEntity = nil
                childCardScript.isStackChild = false 
            end
        end
        rootCardScript.cardStack = {}
        return
    end
    
    for i, cardEid in ipairs(rootCardScript.cardStack) do
        if cardEid == cardScriptToRemove:handle() then
            table.remove(rootCardScript.cardStack, i)
            -- also clear the reference to the root entity in self
            cardScriptToRemove.stackRootEntity = nil
            -- unmark as stack child
            cardScriptToRemove.isStackChild = false 
            return
        end
    end
end

-- category can be "action", "trigger", "modifier"
function createNewCard(category, id, x, y) 
    
    local imageToUse = nil
    if category == "action" then
        imageToUse = "action_card_placeholder.png"
    elseif category == "trigger" then
        imageToUse = "trigger_card_placeholder.png"
    elseif category == "modifier" then
        imageToUse = "mod_card_placeholder.png"
    else
        log_debug("Invalid category for createNewCard:", category)
        return nil
    end
    
    local card = animation_system.createAnimatedObjectWithTransform(
        imageToUse, -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give card state tag
    add_state_tag(card, PLANNING_STATE)
    
    -- give a script table
    local cardScript = Node{}    
    
    cardScript.isStackable = isStackable or true -- whether this card can be stacked on other cards, default true
    
    -- save category and id
    cardScript.category = category
    cardScript.cardID = id or "unknown"
    
    -- give an update table to align the card's stacks if they exist.
    cardScript.update = function(self, dt)
        local eid = self:handle()
        
        -- return unless self's root is self.
        if self.stackRootEntity and self.stackRootEntity ~= eid then
            return
        end
        
        -- if there is a stack, align the stack
        if self.cardStack and #self.cardStack > 0 then
            local baseTransform = registry:get(eid, Transform)
            
            local stackOffsetY = baseTransform.actualH * 0.2 -- offset each card
            
            for i, stackedCardEid in ipairs(self.cardStack) do
                if stackedCardEid and registry:valid(stackedCardEid) then
                    local stackedTransform = registry:get(stackedCardEid, Transform)
                    stackedTransform.actualX = baseTransform.actualX
                    stackedTransform.actualY = baseTransform.actualY + (i * stackOffsetY)
                end
            end
        end
        
    end
    
    -- attach ecs must be called after defining the callbacks.
    cardScript:attach_ecs{ create_new = false, existing_entity = card }
    
    -- let's give the card a label (temporary) for testing
    cardScript.labelEntity = ui.definitions.getNewDynamicTextEntry(
        function() return (id or "unknown") end,  -- initial text
        20.0,                                 -- font size
        "color=blue_sky"                       -- animation spec
    ).config.object
    
    -- make the text world space
    transform.set_space(cardScript.labelEntity, "world")
    
    -- set text z order
    layer_order_system.assignZIndexToEntity(cardScript.labelEntity, z_orders.card_text)
    
    -- let's anchor to top of the card
    transform.AssignRole(registry, cardScript.labelEntity, InheritedPropertiesType.PermanentAttachment, cardScript:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak
        -- Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(cardScript.labelEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP | AlignmentFlag.HORIZONTAL_CENTER 
    
    -- make draggable and set some callbacks in the transform system
    local nodeComp = registry:get(card, GameObject)
    local gameObjectState = nodeComp.state
    gameObjectState.hoverEnabled = true
    gameObjectState.triggerOnReleaseEnabled = true
    gameObjectState.collisionEnabled = true
    gameObjectState.dragEnabled = true -- allow dragging the colonist
    
    animation_system.resizeAnimationObjectsInEntityToFit(
        card,
        48 * 2,   -- width
        64 * 2    -- height
    )
    
    -- NOTE: onRelease is called for when mouse is released ON TOP OF this node.
    nodeComp.methods.onRelease = function(registry, releasedOn, released)
        log_debug("card", released, "released on", releasedOn)
        
        -- when released on top of a card, get the root card of the stack if there is one, and add self to that stack 
        
        
        -- get the card script table
        local releasedCardScript = getScriptTableFromEntityID(released)
        local releasedOnCardScript = getScriptTableFromEntityID(releasedOn)
        if not releasedCardScript then return end
        if not releasedOnCardScript then return end
        
        -- check stackRootEntity in the table. Also, check that isStackable is true
        if not releasedCardScript.isStackable then
            log_debug("released card is not stackable or has no stackRootEntity")
            return
        end
        
        -- check that the released entity is not already a stack root
        if releasedCardScript.stackRootEntity and releasedCardScript.stackRootEntity == released and releasedCardScript.cardStack and #releasedCardScript.cardStack > 0 then
            log_debug("released card is already a stack root, not stacking on self")
            return
        end
        
        -- if the released card is already part of a stack, remove it first
        if releasedCardScript.stackRootEntity and releasedCardScript.stackRootEntity ~= releasedCardScript:handle() then
            local currentRootCardScript = getScriptTableFromEntityID(releasedCardScript.stackRootEntity)
            if currentRootCardScript then
                removeCardFromStack(currentRootCardScript, releasedCardScript)
            end
        end
        
        local rootCardScript = nil
        
        -- if the card released on has no root, then make it the root.
        if not releasedOnCardScript.stackRootEntity then
            rootCardScript = releasedOnCardScript
            releasedOnCardScript.stackRootEntity = releasedOnCardScript:handle()
            releasedOnCardScript.cardStack = releasedOnCardScript.cardStack or {}
            releasedCardScript.stackRootEntity = releasedOnCardScript:handle()
        else 
            -- if it has a root, use that instead.
            rootCardScript = getScriptTableFromEntityID(releasedOnCardScript.stackRootEntity)
        end
        
        if not rootCardScript then
            log_debug("could not find root card script")
            return
        end
        
        -- add self to the root entity's stack, if self is not the root
        if rootCardScript:handle() == released then
            log_debug("released card is the root entity, not stacking on self")
            return
        end
        
        -- make sure neither card is already in a stack and they're being dropped onto each other by accident. It's weird, but sometimes root can be dropped on a member card.
        if rootCardScript.cardStack then
            for _, e in ipairs(rootCardScript.cardStack) do
                if e == released then
                    log_debug("released card is already in the root entity's stack, not stacking again")
                    return
                end
            end
        elseif releasedCardScript.isStackChild then
            log_debug("released card is already a child in another stack, not stacking again")
            return
        end
        local result = addCardToStack(rootCardScript, releasedCardScript)
        
        if not result then
            log_debug("failed to add card to stack due to validation")
            -- return to previous position
            local t = registry:get(released, Transform)
            if t and cardScript.startingPosition then
                t.actualX = cardScript.startingPosition.x
                t.actualY = cardScript.startingPosition.y
            else
                log_debug("could not snap back to starting position, missing transform or startingPosition")
                -- just bump it down a bit
                if t then
                    t.actualY = t.actualY + 70
                end
            end
            return
        end
        
        -- after adding to the stack, update the z-orders from bottom up.
        local baseZ = z_orders.card
        
        -- give root entity the base z order
        layer_order_system.assignZIndexToEntity(rootCardScript:handle(), baseZ)
        
        -- now for every card in the stack, give it a z order above the root
        for i, stackedCardEid in ipairs(rootCardScript.cardStack) do
            if stackedCardEid and registry:valid(stackedCardEid) then
                local stackedTransform = registry:get(stackedCardEid, Transform)
                local zi = baseZ + (i) -- root is baseZ, first stacked card is baseZ + 1, etc
                layer_order_system.assignZIndexToEntity(stackedCardEid, zi)
            end
        end
        
    end
    
    nodeComp.methods.onDrag = function()
        
        if not boardEntityID then 
            layer_order_system.assignZIndexToEntity(card, z_orders.top_card)
            return 
        end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- set z order to top so it can be seen
        cardScript.isDragging = true
        
        log_debug("dragging card, bringing to top z:", board.z_orders.top)
        layer_order_system.assignZIndexToEntity(card, board.z_orders.top)
    end
    
    nodeComp.methods.onStopDrag = function()
        
        if not boardEntityID then 
            layer_order_system.assignZIndexToEntity(card, z_orders.card)
            return 
        end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- reset z order to cached value
        cardScript.isDragging = false
        local cachedZ = board.z_order_cache_per_card and board.z_order_cache_per_card[card1] or board.z_orders.card
        layer_order_system.assignZIndexToEntity(card, cachedZ)
        
        
        -- is it part of a stack?
        if cardScript.stackRootEntity and cardScript.stackRootEntity == card then
            resetCardStackZOrder(cardScript:handle())
        end
    end
    
    
    -- if x and y are given, set position
    if x and y then
        local t = registry:get(card, Transform)
        if t then
            t.actualX = x
            t.actualY = y
        end
    end
end

-- deprecated, use createNewCard instead
function createNewTestCard(boardEntityID, isStackable)
    
    local randomPool = {
        "action_card_placeholder.png",
        "mod_card_placeholder.png",
        "trigger_card_placeholder.png",
    }
    
    -- let's create a couple of cards.
    local card1 = animation_system.createAnimatedObjectWithTransform(
        lume.randomchoice(randomPool), -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give card state tag
    add_state_tag(card1, PLANNING_STATE)
    
    -- give a script table
    local cardScript = Node{}    
    
    
    cardScript.isStackable = isStackable or true -- whether this card can be stacked on other cards, default true
    
    -- give an update table to align the card's stacks if they exist.
    cardScript.update = function(self, dt)
        local eid = self:handle()
        
        -- return unless self's root is self.
        if self.stackRootEntity and self.stackRootEntity ~= eid then
            return
        end
        
        -- if there is a stack, align the stack
        if self.cardStack and #self.cardStack > 0 then
            local baseTransform = registry:get(eid, Transform)
            
            local stackOffsetY = baseTransform.actualH * 0.2 -- offset each card
            
            for i, stackedCardEid in ipairs(self.cardStack) do
                if stackedCardEid and registry:valid(stackedCardEid) then
                    local stackedTransform = registry:get(stackedCardEid, Transform)
                    stackedTransform.actualX = baseTransform.actualX
                    stackedTransform.actualY = baseTransform.actualY + (i * stackOffsetY)
                end
            end
        end
        
    end
    
    -- attach ecs must be called after defining the callbacks.
    cardScript:attach_ecs{ create_new = false, existing_entity = card1 }
    
    
    
    -- make draggable and set some callbacks in the transform system
    local nodeComp = registry:get(card1, GameObject)
    local gameObjectState = nodeComp.state
    gameObjectState.hoverEnabled = true
    gameObjectState.triggerOnReleaseEnabled = true
    gameObjectState.collisionEnabled = true
    gameObjectState.dragEnabled = true -- allow dragging the colonist
    nodeComp.methods.onHover = function()
    end
    
    nodeComp.methods.onStopHover = function()
    end
    
    animation_system.resizeAnimationObjectsInEntityToFit(
        card1,
        48 * 2,   -- width
        64 * 2    -- height
    )
    
    -- NOTE: onRelease is called for when mouse is released ON TOP OF this node.
    nodeComp.methods.onRelease = function(registry, releasedOn, released)
        log_debug("card", released, "released on", releasedOn)
        
        -- when released on top of a card, get the root card of the stack if there is one, and add self to that stack 
        
        
        -- get the card script table
        local releasedCardScript = getScriptTableFromEntityID(released)
        local releasedOnCardScript = getScriptTableFromEntityID(releasedOn)
        if not releasedCardScript then return end
        if not releasedOnCardScript then return end
        
        -- check stackRootEntity in the table. Also, check that isStackable is true
        if not releasedCardScript.isStackable then
            log_debug("released card is not stackable or has no stackRootEntity")
            return
        end
        
        -- check that the released entity is not already a stack root
        if releasedCardScript.stackRootEntity and releasedCardScript.stackRootEntity == released and releasedCardScript.cardStack and #releasedCardScript.cardStack > 0 then
            log_debug("released card is already a stack root, not stacking on self")
            return
        end
        
        local rootCardScript = nil
        
        -- if the card released on has no root, then make it the root.
        if not releasedOnCardScript.stackRootEntity then
            rootCardScript = releasedOnCardScript
            releasedOnCardScript.stackRootEntity = releasedOnCardScript:handle()
            releasedOnCardScript.cardStack = releasedOnCardScript.cardStack or {}
            releasedCardScript.stackRootEntity = releasedOnCardScript:handle()
        else 
            -- if it has a root, use that instead.
            rootCardScript = getScriptTableFromEntityID(releasedOnCardScript.stackRootEntity)
        end
        
        if not rootCardScript then
            log_debug("could not find root card script")
            return
        end
        
        -- add self to the root entity's stack, if self is not the root
        if rootCardScript:handle() == released then
            log_debug("released card is the root entity, not stacking on self")
            return
        end
        
        -- make sure neither card is already in a stack and they're being dropped onto each other by accident. It's weird, but sometimes root can be dropped on a member card.
        if rootCardScript.cardStack then
            for _, e in ipairs(rootCardScript.cardStack) do
                if e == released then
                    log_debug("released card is already in the root entity's stack, not stacking again")
                    return
                end
            end
        elseif releasedCardScript.isStackChild then
            log_debug("released card is already a child in another stack, not stacking again")
            return
        end
        addCardToStack(rootCardScript, releasedCardScript)
        
        -- after adding to the stack, update the z-orders from bottom up.
        local baseZ = z_orders.card
        
        -- give root entity the base z order
        layer_order_system.assignZIndexToEntity(rootCardScript:handle(), baseZ)
        
        -- now for every card in the stack, give it a z order above the root
        for i, stackedCardEid in ipairs(rootCardScript.cardStack) do
            if stackedCardEid and registry:valid(stackedCardEid) then
                local stackedTransform = registry:get(stackedCardEid, Transform)
                local zi = baseZ + (i) -- root is baseZ, first stacked card is baseZ + 1, etc
                layer_order_system.assignZIndexToEntity(stackedCardEid, zi)
            end
        end
        
    end
    
    nodeComp.methods.onDrag = function()
        
        if not boardEntityID then 
            layer_order_system.assignZIndexToEntity(card1, z_orders.top_card)
            return 
        end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- set z order to top so it can be seen
        cardScript.isDragging = true
        
        log_debug("dragging card, bringing to top z:", board.z_orders.top)
        layer_order_system.assignZIndexToEntity(card1, board.z_orders.top)
        
        -- save the starting position in case we need to snap back
        if not cardScript.startingPosition then
            local t = registry:get(card1, Transform)
            if t then
                cardScript.startingPosition = { x = t.actualX, y = t.actualY }
            end
        end
    end
    
    nodeComp.methods.onStopDrag = function()
        
        if not boardEntityID then 
            layer_order_system.assignZIndexToEntity(card1, z_orders.card)
            return 
        end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- reset z order to cached value
        cardScript.isDragging = false
        local cachedZ = board.z_order_cache_per_card and board.z_order_cache_per_card[card1] or board.z_orders.card
        layer_order_system.assignZIndexToEntity(card1, cachedZ)
    end
    
    
    
    return card1
    
end

-- return the object lua table from an entt id
function getScriptTableFromEntityID(eid)
    if not eid or eid == entt_null or not registry:valid(eid) then return nil end
    if not registry:has(eid, ScriptComponent) then return nil end
    local scriptComp = registry:get(eid, ScriptComponent)
    return scriptComp.self
end


function startTriggerNSecondsTimer()
    
    -- this timer should make the card pulse and jiggle + particles. Then it will go through the action board and execute all actions that are on it in sequence.
    
    -- for now, just do 3 seconds
    
    local outCubic = Easing.outQuart.f -- the easing function, not the derivative
    
    -- utility: linear interpolation
    local function lerp(a, b, t)
        return a + (b - a) * t
    end
    
    timer.every(
        3.0,
        function()
            log_debug("every N seconds trigger fired")
            -- pulse and jiggle the card
            if not trigger_board_id or trigger_board_id == entt_null or not registry:valid(trigger_board_id) then return end
            local triggerBoard = boards[trigger_board_id]
            if not triggerBoard or not triggerBoard.cards or #triggerBoard.cards == 0 then return end
            
            local triggerCardEid = triggerBoard.cards[1]
            if not triggerCardEid or triggerCardEid == entt_null or not registry:valid(triggerCardEid) then return end
            local triggerCardScript = getScriptTableFromEntityID(triggerCardEid)
            if not triggerCardScript then return end
            
            -- pulse animation
            local cardTransform = registry:get(triggerCardEid, Transform)
            cardTransform.visualS = 1.5
            
            -- create a new object for a pulsing rectangle that fades out in color over time, then destroys itself.
            local pulseObject = Node{}
            pulseObject.lifetime = 0.3
            pulseObject.age = 0.0
            pulseObject.update = function(self, dt)
                local addedScaleAmount = 0.3
                
                self.age = self.age + dt
                
                -- make scale & alpha based on age
                local alpha = 1.0 - outCubic(math.min(1.0, self.age / self.lifetime))
                local scale = 1.0 + addedScaleAmount * outCubic(math.min(1.0, self.age / self.lifetime))
                local e = math.min(1.0, self.age / self.lifetime) -- 0 to 1 over lifetime
                
                -- choose your start/end colors (any names or explicit RGBA)
                local fromColor = palette.snapToColorName("yellow")
                local toColor   = palette.snapToColorName("black")

                -- interpolate per channel
                local r = lerp(fromColor.r, toColor.r, e)
                local g = lerp(fromColor.g, toColor.g, e)
                local b = lerp(fromColor.b, toColor.b, e)
                local a = lerp(fromColor.a or 255, toColor.a or 255, e)
                
                -- make sure they're integers
                r = math.floor(r + 0.5)
                g = math.floor(g + 0.5)
                b = math.floor(b + 0.5)
                a = math.floor(a + 0.5)
                
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    local t = registry:get(triggerCardEid, Transform)
                    c.x = t.actualX + t.actualW * 0.5
                    c.y = t.actualY + t.actualH * 0.5
                    c.w = t.actualW * scale
                    c.h = t.actualH * scale
                    c.rx = 15
                    c.ry = 15
                    c.color = Col(r, g, b, a)
                    
                end, z_orders.card - 1, layer.DrawCommandSpace.World)
            end
            pulseObject
                :attach_ecs{ create_new = true }
                :destroy_when(function(self, eid) return self.age >= self.lifetime end)
        end,
        0, -- infinite repetitions
        false, -- don't start immediately
        nil, -- no after callback
        "every_N_seconds_trigger"
    )
end
function setUpLogicTimers()
    
    -- check the trigger board 
    timer.run(
        function()
            
            -- does the trigger board exist and have a card?
            if not trigger_board_id or trigger_board_id == entt_null or not registry:valid(trigger_board_id) then return end
            
            local triggerBoard = boards[trigger_board_id]
            if not triggerBoard or not triggerBoard.cards or #triggerBoard.cards == 0 then return end
            
            -- if the card is every N seconds, check that the right timer is running. if not, start one.
            local triggerCardEid = triggerBoard.cards[1]
            if not triggerCardEid or triggerCardEid == entt_null or not registry:valid(triggerCardEid) then return end
            local triggerCardScript = getScriptTableFromEntityID(triggerCardEid)
            if not triggerCardScript then return end
            
            if triggerCardScript.cardID == "every_N_seconds" then
                -- check if the timer is running
                if timer.get_timer_and_delay("every_N_seconds_trigger") then
                    -- timer is running, do nothing
                else
                    startTriggerNSecondsTimer()
                end
            end
        end
    )
end

-- initialize the game area for planning phase, where you combine cards and stuff.
function initGameArea()
    
    -- activate planning state to draw/update planning entities
    activate_state(PLANNING_STATE)
    
    
    -- make a few test cards around 600, 300
    local x = 700
    local y = 200
    local offset = 50
    createNewCard("action", "fire_basic_bolt", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    createNewCard("action", "leave_spike_hazard", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    createNewCard("action", "temporary_strength_bonus", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    createNewCard("trigger", "every_N_seconds", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    -- createNewCard("trigger", "on_pickup", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    -- createNewCard("trigger", "on_distance_moved", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    -- createNewCard("modifier", "double_effect", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    -- createNewCard("modifier", "summon_minion_wandering", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    -- createNewCard("modifier", "projectile_pierces_twice", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    
    -- let's create a card board
    local boardID = createNewBoard(100, 350, 600, 200)
    local board = boards[boardID]
    
    -- board draw function, for all baords
    timer.run(
        function()
            -- for each board
            for key, boardScript in pairs(boards) do
                local self = boardScript
                local eid = self:handle()
                if not eid or not registry:valid(eid) then return end

                local area = registry:get(eid, Transform)

                -- -- draw board border
                local pad = 20
                command_buffer.queueDrawDashedRoundedRect(layers.sprites, function(c)
                    c.rec = Rectangle.new(
                        area.actualX,
                        area.actualY,
                        math.max(0, area.actualW),
                        math.max(0, area.actualH)
                    )
                    c.radius    = 10
                    c.dashLen   = 12
                    c.gapLen    = 8
                    c.phase     = (shapeAnimationPhase)
                    c.arcSteps  = 14
                    c.thickness = 5
                    c.color     = self.borderColor or palette.snapToColorName("yellow")
                    
                end, z_orders.board, layer.DrawCommandSpace.World)

            end
        end
    )
    
    -- add a couple of starting cards to the board
    local card1 = createNewTestCard(board:handle())
    local card2 = createNewTestCard(board:handle())
    
    local testTable = getScriptTableFromEntityID(card1)
    
    board.cards = { card1, card2 } -- give a couple of starting cards. These are the entity ids.
    
    -- give a text label above the board
    board.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.action_mod_area") end,  -- initial text
        20.0,                                 -- font size
        "color=apricot_cream"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(board.textEntity, "world")
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, board.textEntity, InheritedPropertiesType.PermanentAttachment, board:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(board.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    -- FIXME: onrelease for world container doesn't work.
    local containerGameObject = registry:get(globals.gameWorldContainerEntity(), GameObject)
    if containerGameObject then
        -- containerGameObject.state.hoverEnabled = true
        containerGameObject.state.triggerOnReleaseEnabled = true
        containerGameObject.state.collisionEnabled = true
    end
    -- make world container very deep so it is always at the back
    layer_order_system.assignZIndexToEntity(globals.gameWorldContainerEntity(), -10000)
    -- make onRelease method for container
    containerGameObject.methods.onRelease = function(registry, releasedOn, released)
        log_debug("Entity", released, "released on", releasedOn)
        
        -- when released on top of the world container, remove from any existing board it may be in
        
        -- is the released entity a card?
        local releasedCardScript = getScriptTableFromEntityID(released)
        if not releasedCardScript then return end
        
        -- remove it from any existing board it may be in
        for boardEid, boardScript in pairs(boards) do
            if boardScript and boardScript.cards then
                for i, eid in ipairs(boardScript.cards) do
                    if eid == released then
                        table.remove(boardScript.cards, i)
                    end
                end
            end
        end
        
    end
    
    
    -- timer to test adding new cards
    -- timer.every(5.0, function()
    --     local newCard = createNewTestCard()
    --     table.insert(board.cards, newCard)
    -- end)
    
    
    add_state_tag(board:handle(), PLANNING_STATE)
    
    -- TimerChain:new("statesTestingChain")
    --     :after(5.0, function() activate_state(PLANNING_STATE) end)
    --     :wait(5)
    --     :after(5.0, function() activate_state(ACTION_STATE) end)
    --     :start()
    
    
    -- let's make another board, for triggers.
    local triggerBoardID = createNewBoard(100, 100, 200, 200)
    trigger_board_id = triggerBoardID -- save in global
    local triggerBoard = boards[triggerBoardID]
    triggerBoard.borderColor = palette.snapToColorName("cyan")
    triggerBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.trigger_area") end,  -- initial text
        20.0,                                 -- font size
        "color=cyan"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(triggerBoard.textEntity, "world")
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, triggerBoard.textEntity, InheritedPropertiesType.PermanentAttachment, triggerBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(triggerBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    
    -- another board for removing cards from boards.
    local removeBoardID = createNewBoard(350, 100, 200, 200)
    local removeBoard = boards[removeBoardID]
    removeBoard.borderColor = palette.snapToColorName("red")
    removeBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.remove_card_area")  end,  -- initial text
        20.0,                                 -- font size
        "color=red"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(removeBoard.textEntity, "world")
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, removeBoard.textEntity, InheritedPropertiesType.PermanentAttachment, removeBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(removeBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    -- add a different onRelease method
    local removeBoardGameObject = registry:get(removeBoard:handle(), GameObject)
    if removeBoardGameObject then
        removeBoardGameObject.methods.onRelease = function(registry, releasedOn, released)
            log_debug("Entity", released, "released on", releasedOn)  
            
            -- just remove from all boards and change its location to somewhere else
            -- is the released entity a card?
            local releasedCardScript = getScriptTableFromEntityID(released)
            if not releasedCardScript then return end   
            local isInBoard = false
            -- remove it from any existing board it may be in
            for boardEid, boardScript in pairs(boards) do
                if boardScript and boardScript.cards then
                    for i, eid in ipairs(boardScript.cards) do
                        if eid == released then
                            table.remove(boardScript.cards, i)
                            isInBoard = true
                        end
                    end
                end
            end
            -- move it somewhere elsewhere
            local t = registry:get(released, Transform)
            if t then
                t.actualY = t.visualY
                t.actualX = t.visualX + 500
            end
            -- is the card part of a stack? if it was previously part of a board, just call reset Z order.
            if releasedCardScript.stackRootEntity and isInBoard then
                resetCardStackZOrder(releasedCardScript.stackRootEntity)
            end
            
            -- if the card is the root of a stack, and it wasn't part of a board, remove all children from the stack
            if releasedCardScript.stackRootEntity and not isInBoard then
                -- remove the children and add them to a table.
                local rootCardScript = getScriptTableFromEntityID(releasedCardScript.stackRootEntity)
                local removedCards = {}
                if rootCardScript then
                    for _, childEid in ipairs(rootCardScript.cardStack) do
                        local childCardScript = getScriptTableFromEntityID(childEid)
                        removeCardFromStack(rootCardScript, childCardScript)
                        table.insert(removedCards, childCardScript)
                    end
                end
                
                -- for each child, set a new position, varying slighty at random from the root card
                local delay = 0.3
                local locationOffset = 100
                for i, childCardScript in ipairs(removedCards) do
                    timer.after(delay * (i - 1), function()
                        if childCardScript and childCardScript:handle() and registry:valid(childCardScript:handle()) then
                            local t = registry:get(releasedCardScript:handle(), Transform)
                            local ct = registry:get(childCardScript:handle(), Transform)
                            if t and ct then
                                ct.actualX = t.actualX + lume.random(-locationOffset, locationOffset)
                                ct.actualY = t.actualY + lume.random(-locationOffset, locationOffset)
                            end
                        end
                    end)
                end
                        
            end
            
        end
    end
    
    -- add another area, call it "Augment Action Card"
    local augmentBoardID = createNewBoard(800, 350, 200, 200)
    local augmentBoard = boards[augmentBoardID]
    augmentBoard.borderColor = palette.snapToColorName("apricot_cream")
    augmentBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.augment_action_area") end,  -- initial text
        20.0,                                 -- font size
        "color=apricot_cream;wiggle"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(augmentBoard.textEntity, "world")
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, augmentBoard.textEntity, InheritedPropertiesType.PermanentAttachment, augmentBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(augmentBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    
    -- let's set up an update timer for triggers.
    setUpLogicTimers()
end

function initActionPhase()
    log_debug("Action phase started!")

    -- activate action state
    activate_state(ACTION_STATE)
    
    -- 3856-TheRoguelike_1_10_alpha_649.png
    survivorEntity = animation_system.createAnimatedObjectWithTransform(
        "3856-TheRoguelike_1_10_alpha_649.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give survivor a script and hook up
    local survivorScript = Node{}
    -- TODO: add update method here if needed
    survivorScript:attach_ecs{ create_new = false, existing_entity = survivorEntity }
    
    -- give a state tag to the survivor entity
    add_state_tag(survivorEntity, ACTION_STATE)
    
    -- lets move the survivor based on input.
    -- input binding test
    input.bind("survivor_left", { device="keyboard", key=KeyboardKey.KEY_A, trigger="Pressed", context="gameplay" })
    input.bind("survivor_right", { device="keyboard", key=KeyboardKey.KEY_D, trigger="Pressed", context="gameplay" })
    input.bind("survivor_up", { device="keyboard", key=KeyboardKey.KEY_W, trigger="Pressed", context="gameplay" })
    input.bind("survivor_down", { device="keyboard", key=KeyboardKey.KEY_S, trigger="Pressed", context="gameplay" })
    
    -- create input timer. this must run every frame.
    timer.run(
        function()
            if not survivorEntity or survivorEntity == entt_null or not registry:valid(survivorEntity) then
                return
            end
            
            local speed = 200 -- pixels per second
            local dx, dy = 0, 0
            if input.action_down("survivor_left") then
                dx = dx - 1
            end
            if input.action_down("survivor_right") then
                dx = dx + 1
            end
            if input.action_down("survivor_up") then
                dy = dy - 1
            end
            if input.action_down("survivor_down") then
                dy = dy + 1
            end
            -- normalize direction vector
            if dx ~= 0 or dy ~= 0 then
                local len = math.sqrt(dx * dx + dy * dy)
                dx = dx / len
                dy = dy / len
            end
            
            local t = registry:get(survivorEntity, Transform)
            if t then
                t.actualX = t.actualX + dx * speed * GetFrameTime()
                t.actualY = t.actualY + dy * speed * GetFrameTime()
            end
            
        end,
        nil, -- no after
        "survivorEntityMovementTimer" -- timer tag
    )
    
    input.set_context("gameplay") -- set the input context to gameplay
    
    
    
end

planningUIEntities = {
    start_action_button_box = nil
}

function initPlanningUI() 
   
    -- simple button to start action phase.
    local startButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.start_action_phase") end,  -- initial text
        15.0,                                 -- font size
        "color=fuchsia"                       -- animation spec
    )
    local startButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(palette.snapToColorName("gray"))
                :addEmboss(2.0)
                :addHover(true) -- needed for button effect
                :addButtonCallback(function ()
                    playSoundEffect("effects", "button-click") -- play button click sound
                end)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )
        :addChild(startButtonText)
        :build()
        
    local startMenuRoot = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.SCROLL_PANE)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(palette.snapToColorName("yellow"))
            :addPadding(0)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(startButtonTemplate)
    :build()
    
    -- new uibox for the main menu
    planningUIEntities.start_action_button_box =  ui.box.Initialize({x = 350, y = globals.screenHeight()}, startMenuRoot)
    
    -- center the ui box X-axi
    local buttonTransform = registry:get(planningUIEntities.start_action_button_box, Transform)
    buttonTransform.actualX = globals.screenWidth() / 2 - buttonTransform.actualW / 2
    buttonTransform.actualY = globals.screenHeight() - buttonTransform.actualH - 10
end