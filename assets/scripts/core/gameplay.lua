


-- contains code limited to gameplay logic for organizational purposes

local z_orders = require("core.z_orders")
local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script
local palette = require("color.palette")
local TimerChain = require("core.timer_chain")
local Easing = require("util.easing")
local CombatSystem = require("combat.combat_system")

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

-- card sizes
local cardW, cardH = 80, 112


-- save game state strings
PLANNING_STATE = "PLANNING"
ACTION_STATE = "SURVIVORS"
SHOP_STATE = "SHOP"

survivorEntity = nil
boards = {}
trigger_board_id_to_action_board_id = {} -- map trigger boards to action boards
trigger_board_id = nil
action_board_id = nil

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
        
        
        --TODO: debuggin, is shop board updating?
        if (self.gameStates and self.gameStates[1] == SHOP_STATE) then
            log_debug("shop board updating")
        end

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
-- retursn the entity ID of the created card
function createNewCard(category, id, x, y, gameStateToApply) 
    
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
    add_state_tag(card, gameStateToApply or PLANNING_STATE)
    
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
    
    -- text state
    add_state_tag(cardScript.labelEntity, gameStateToApply or PLANNING_STATE)
    
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
        cardW,   -- width
        cardH    -- height
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
        
        
        -- sound
        -- playSoundEffect("effects", "card_pick_up", 1.0)
        
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
        
        
        -- sound
        local putDownSounds = {
            "card_put_down_1",
            "card_put_down_2",
            "card_put_down_3",
            "card_put_down_4"
        }
        playSoundEffect("effects", lume.randomchoice(putDownSounds), 0.9 + math.random() * 0.2)
        
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
        
        -- make it transform authoritative again
        physics.set_sync_mode(registry, card, physics.PhysicsSyncMode.AuthoritativeTransform)
        
    end
    
    
    -- if x and y are given, set position
    if x and y then
        local t = registry:get(card, Transform)
        if t then
            t.actualX = x
            t.actualY = y
        end
    end
    
    return cardScript:handle()
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

-- utility: linear interpolation
local function lerp(a, b, t)
    return a + (b - a) * t
end

function addPulseEffectBehindCard(cardEntityID, startColor, endColor)
    if not cardEntityID or cardEntityID == entt_null or not registry:valid(cardEntityID) then return end
    local cardTransform = registry:get(cardEntityID, Transform)
    if not cardTransform then return end
    
    -- create a new object for a pulsing rectangle that fades out in color over time, then destroys itself.
    local pulseObject = Node{}
    pulseObject.lifetime = 0.3
    pulseObject.age = 0.0
    pulseObject.update = function(self, dt)
        local addedScaleAmount = 0.3
        
        self.age = self.age + dt
        
        -- make scale & alpha based on age
        local alpha = 1.0 - Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
        local scale = 1.0 + addedScaleAmount * Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
        local e = math.min(1.0, self.age / self.lifetime)
        
        local fromColor = startColor or palette.snapToColorName("yellow")
        local toColor   = endColor or palette.snapToColorName("black")
        
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
            local t = registry:get(cardEntityID, Transform)
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
end

function slowTime(duration, targetTimeScale)
    main_loop.data.timescale = targetTimeScale or 0.2 -- slow to 20%, then over X seconds, tween back to 1.0
    timer.tween(
        duration or 1.0, -- duration in seconds
        function() return main_loop.data.timescale end, -- getter
        function(v) main_loop.data.timescale = v end, -- setter
        1.0 -- target value
    )
end

function killPlayer()
    -- slow time using main_loop.data.timeScale
    
    
    main_loop.data.timescale = 0.15 -- slow to 15%, then over X seconds, tween back to 1.0
    timer.tween(
        1.0, -- duration in seconds
        function() return main_loop.data.timescale end, -- getter
        function(v) main_loop.data.timescale = v end, -- setter
        1.0 -- target value
    )
    
    -- destroy the entity, get particles flying.
    
    timer.after(0.01, function()
        local transform = registry:get(survivorEntity, Transform)
        
        -- create a note that draws a red circle where the player was and removes itself after 0.1 second
        local deathCircle = Node{}
        deathCircle.lifetime = 0.1
        deathCircle.age = 0.0
        local playerX = transform.actualX + transform.actualW * 0.5
        local playerY = transform.actualY + transform.actualH * 0.5
        local playerW = transform.actualW
        local playerH = transform.actualH
        deathCircle.update = function(self, dt)
            self.age = self.age + dt
            command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
                local t = registry:get(survivorEntity, Transform)
                c.x = playerX
                c.y = playerY
                c.rx = playerW * 0.5 * (1.0 + self.age * 5.0)
                c.ry = playerH * 0.5 * (1.0 + self.age * 5.0)
                c.color = palette.snapToColorName("red")
            end, z_orders.player_vfx, layer.DrawCommandSpace.World)
        end
        deathCircle:attach_ecs{ create_new = true }
        deathCircle:destroy_when(function(self, eid) return self.age >= self.lifetime end)
        
        spawnCircularBurstParticles(
            transform.visualX + transform.actualW * 0.5,
            transform.visualY + transform.actualH * 0.5,
            8, -- count
            0.9, -- seconds
            palette.snapToColorName("blue"), -- start color
            palette.snapToColorName("red"), -- end color
            "outCubic", -- from util.easing
            "world" -- screen space
        )
        
        registry:destroy(survivorEntity)
    end)
    
    
end

function spawnRandomBullet() 
    
    local bulletSize = 10
    
    local playerTransform = registry:get(survivorEntity, Transform)
    
    local node = Node{}
    node.lifetime = 2.0
    node.age = 0.0
    node.update = function(self, dt)
        self.age = self.age + dt
        
        -- draw a circle
        command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
            local t = registry:get(self:handle(), Transform)
            c.x = t.actualX + t.actualW * 0.5
            c.y = t.actualY + t.actualH * 0.5
            c.rx = t.actualW * 0.5
            c.ry = t.actualH * 0.5
            c.color = palette.snapToColorName("red")
        end, z_orders.projectiles, layer.DrawCommandSpace.World)
    end
    node:attach_ecs{ create_new = true }
    node:destroy_when(function(self, eid) return self.age >= self.lifetime end) 
    
    -- give transform
    local centerX = playerTransform.actualX + playerTransform.actualW * 0.5 - bulletSize * 0.5
    local centerY = playerTransform.actualY + playerTransform.actualH * 0.5 - bulletSize * 0.5
    transform.CreateOrEmplace(registry, globals.gameWorldContainerEntity(), centerX, centerY, bulletSize, bulletSize, node:handle())
    
    -- give physics.
    
    local world = PhysicsManager.get_world("world")

    local info = { shape = "circle", tag = "bullet", sensor = false, density = 1.0, inflate_px = -4 } -- default tag is "WORLD"
    physics.create_physics_for_transform(registry,
        physics_manager_instance, -- global instance
        node:handle(), -- entity id
        "world", -- physics world identifier
        info
    )
    
    -- give bullet state
    add_state_tag(node:handle(), ACTION_STATE)
    
    -- collision mask
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "enemy", {"bullet"})
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "bullet", {"enemy"})
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "enemy", {"bullet"})
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "bullet", {"enemy"})
    
    -- ignore damping
    physics.SetBullet(world, node:handle(), true)
    
    -- Fire in the direction the player is currently moving.
    local v = physics.GetVelocity(world, survivorEntity)
    local vx = v.x
    local vy = v.y
    local speed = 300.0

    -- If the player is standing still, default to forward or random.
    if vx == 0 and vy == 0 then
        local angle = math.random() * math.pi * 2.0
        vx = math.cos(angle)
        vy = math.sin(angle)
    end

    -- Normalize
    local mag = math.sqrt(vx * vx + vy * vy)
    if mag > 0 then
        vx, vy = vx / mag * speed, vy / mag * speed
    end

    physics.SetVelocity(world, node:handle(), vx, vy)
    
    -- make a new node that discards after 0.1 seconds to mark bullet firing
    local fireMarkNode = Node{}
    fireMarkNode.lifetime = 0.1
    fireMarkNode.age = 0.0
    fireMarkNode.update = function(self, dt)
        self.age = self.age + dt
        -- draw a small flash at the bullet position
        command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
            local t = registry:get(node:handle(), Transform)
            c.x = t.actualX + t.actualW * 0.5
            c.y = t.actualY + t.actualH * 0.5
            c.rx = t.actualW * 1.5
            c.ry = t.actualH * 1.5
            c.color = palette.snapToColorName("yellow")
        end, z_orders.projectiles, layer.DrawCommandSpace.World)
    end
    fireMarkNode:attach_ecs{ create_new = true }
    fireMarkNode:destroy_when(function(self, eid) return self.age >= self.lifetime end)
end

function spawnRandomTrapHazard()
    
    local playerTransform = registry:get(survivorEntity, Transform)
    
    -- make animated object
    local hazard = animation_system.createAnimatedObjectWithTransform(
        "b3997.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give state tag
    add_state_tag(hazard, ACTION_STATE)
    
    -- resize
    animation_system.resizeAnimationObjectsInEntityToFit(
        hazard,
        32 * 2,   -- width
        32 * 2    -- height
    )
    
    -- position it in front of the player, at a random offset
    local offsetDistance = 80.0
    local angle = (math.random() * 0.5 - 0.25) * math.pi -- random angle between -45 and +45 degrees
    local offsetX = math.cos(angle) * offsetDistance
    local offsetY = math.sin(angle) * offsetDistance
    local playerCenterX = playerTransform.actualX + playerTransform.actualW * 0.5
    local playerCenterY = playerTransform.actualY + playerTransform.actualH * 0.5
    local hazardX = playerCenterX + offsetX - 32 -- center the hazard
    local hazardY = playerCenterY + offsetY - 32
    
    -- snap visual to actual
    local hazardTransform = registry:get(hazard, Transform)
    hazardTransform.actualX = hazardX
    hazardTransform.actualY = hazardY
    hazardTransform.visualX = hazardX
    hazardTransform.visualY = hazardY
    
    -- jiggle
    hazardTransform.visualS = 1.5
    
    -- give physics & node        
    local info = { shape = "rectangle", tag = "spike_hazard", sensor = false, density = 1.0, inflate_px = -4 } -- default tag is "WORLD"
    physics.create_physics_for_transform(registry,
        physics_manager_instance, -- global instance
        hazard, -- entity id
        "world", -- physics world identifier
        info
    )
    
    
    local node = Node{}
    node.lifetime = 8.0 --TODO: base lifetime on some kind of stat, maybe?
    node.age = 0.0
    node.update = function(self, dt)
        self.age = self.age + dt    
    end
    
    node:attach_ecs{ create_new = false, existing_entity = hazard }
    node:destroy_when(function(self, eid) return self.age >= self.lifetime end) 
end

function applyPlayerStrengthBonus()
    
    playSoundEffect("effects", "strength_bonus", 0.9 + math.random() * 0.2)
    
    local playerTransform = registry:get(survivorEntity, Transform)
    
    -- make a node
    local node = Node{}
    node.lifetime = 1.0 -- lasts for 10 seconds
    node.age = 0.0
    node.update = function(self, dt)
        self.age = self.age + dt
        
        local tweenProgress = math.min(1.0, self.age / self.lifetime)
        
        -- draw a series of vertical lines on the player that move up and lengthen over time, cubically.
        
        local numlines = 5
        local baseHeight = playerTransform.actualH * 0.3
        local addedHeight = playerTransform.actualH * 0.7
        
        local startColor = palette.snapToColorName("white")
        local endColor = palette.snapToColorName("red")
        
        local t = registry:get(survivorEntity, Transform)
        local centerX = t.actualX + t.actualW * 0.5
        local baseY = t.actualY + t.actualH
        
        for i = 1, numlines do
            local lineProgress = (i - 1) / (numlines - 1)
            local x = centerX + (lineProgress - 0.5) * t.actualW * 0.8
            local h = baseHeight + addedHeight * Easing.outExpo.f(tweenProgress) * (0.5 + 0.5 * lineProgress)
            
            -- interpolate color
            local r = lerp(startColor.r, endColor.r, tweenProgress)
            local g = lerp(startColor.g, endColor.g, tweenProgress)
            local b = lerp(startColor.b, endColor.b, tweenProgress)
            local a = lerp(startColor.a or 255, endColor.a or 255, tweenProgress)
            
            -- make sure they're integers
            r = math.floor(r + 0.5)
            g = math.floor(g + 0.5)
            b = math.floor(b + 0.5)
            a = math.floor(a + 0.5)
            
            -- draw the lines
            command_buffer.queueDrawLine(layers.sprites, function(c)
                    c.x1 = x
                    c.y1 = baseY
                    c.x2 = x
                    c.y2 = baseY - h
                    c.color = Col(r, g, b, a)
                    c.lineWidth = 2
                end, z_orders.player_vfx, layer.DrawCommandSpace.World)
        end
    end
    node:attach_ecs{ create_new = true }
    node:destroy_when(function(self, eid) return self.age >= self.lifetime end)
end

function fireActionCardWithModifiers(cardEntityID, executionIndex)
    if not cardEntityID or cardEntityID == entt_null or not registry:valid(cardEntityID) then return end
    local cardScript = getScriptTableFromEntityID(cardEntityID)
    if not cardScript then return end
    
    local playerScript = getScriptTableFromEntityID(survivorEntity)
    local playerTransform = registry:get(survivorEntity, Transform)
    
    log_debug("Firing action card:", cardScript.cardID)
    
    
    local pitchIncrement = 0.1;
    
    -- play a sound
    playSoundEffect("effects", "card_activate", 0.9 + pitchIncrement * (executionIndex or 0))
    
    
    
    -- first, let's see if the card has any modifiers stacked on it, and log them
    
    local modsTable = {}
    
    if cardScript.cardStack and #cardScript.cardStack > 0 then
        log_debug("Card has", #cardScript.cardStack, "modifiers stacked on it:")
        for i, modEid in ipairs(cardScript.cardStack) do
            local modCardScript = getScriptTableFromEntityID(modEid)
            if modCardScript then
                log_debug(" - modifier", i, ":", modCardScript.cardID)
                table.insert(modsTable, modCardScript.cardID)
            end
        end
    end
    
    
    -- for now, we'll handle bolt, spike hazard, and strength bonus
    
    
    
    -- let's see what the card ID is and do something based on that
    if cardScript.cardID == "fire_basic_bolt" then
        -- create a basic bolt projectile in a random direction.
        
        -- play sound once, doesn't make sense to play multiple times
        playSoundEffect("effects", "fire_bolt", 0.9 + math.random() * 0.2)
    
        spawnRandomBullet()
        
        -- if mods contains double_effect, do it again
        if lume.find(modsTable, "double_effect") then
            spawnRandomBullet()
        end
        
    elseif cardScript.cardID == "leave_spike_hazard" then
        -- create a spike hazard at a random position in front of the player
        
        playSoundEffect("effects", "place_trap", 0.9 + math.random() * 0.2)
        
        spawnRandomTrapHazard()
        
        -- if mods contains double_effect, do it again
        if lume.find(modsTable, "double_effect") then
            spawnRandomTrapHazard()
        end
        
    elseif cardScript.cardID == "temporary_strength_bonus" then
        -- for now, just log it
        log_debug("Strength bonus activated! (no effect yet)")
        
        applyPlayerStrengthBonus()
        
        -- if mods contains double_effect, wait a bit, then do it again.
        if lume.find(modsTable, "double_effect") then
            timer.after(1.1, function()
                applyPlayerStrengthBonus()
            end)
        end
        
    else
        log_debug("Unknown action card ID:", cardScript.cardID)
    end
end

-- TODO: handle things like cooldown, modifiers that change the effect, etc
function fireActionCardsInBoard(boardEntityID)
    if not boardEntityID or boardEntityID == entt_null or not registry:valid(boardEntityID) then return end
    local board = boards[boardEntityID]
    if not board or not board.cards or #board.cards == 0 then return end
    
    -- for now, just log the card ids in order
    local cooldownBetweenActions = 0.5 -- seconds
    local runningDelay = 0.3
    local pulseColorRampTable = palette.ramp_quantized("blue", "white", #board.cards)
    local index = 1
    for _, cardEid in ipairs(board.cards) do
        if cardEid and cardEid ~= entt_null and registry:valid(cardEid) then
            local cardScript = getScriptTableFromEntityID(cardEid)
            if cardScript then
                
                timer.after(
                    runningDelay,
                    function()
                        -- log_debug("Firing action card:", cardScript.cardID)
                        
                        -- pulse and jiggle
                        local cardTransform = registry:get(cardEid, Transform)
                        if cardTransform then
                            cardTransform.visualS = 2.0
                            addPulseEffectBehindCard(cardEid, pulseColorRampTable[index], palette.snapToColorName("black"))    
                        end
                        
                        -- actually execute the logic of the card
                        fireActionCardWithModifiers(cardEid, index)
                        
                    end
                )
                
                runningDelay = runningDelay + cooldownBetweenActions
                
            end
        end
        index = index + 1
    end
end
function startTriggerNSecondsTimer(trigger_board_id, action_board_id, timer_name)
    
    -- this timer should make the card pulse and jiggle + particles. Then it will go through the action board and execute all actions that are on it in sequence.
    
    -- for now, just do 3 seconds
    
    local outCubic = Easing.outQuart.f -- the easing function, not the derivative
    
    
    -- log_debug("startTriggerNSecondsTimer called for trigger board:", trigger_board_id, "and action board:", action_board_id)
    timer.every(
        3.0,
        function()
            
            -- onlly in action state
            if not is_state_active(ACTION_STATE) then return end
            
            -- log_debug("every N seconds trigger fired")
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
            
            -- play sound
            playSoundEffect("effects", "trigger_activate", 1.0)
            
            addPulseEffectBehindCard(triggerCardEid, palette.snapToColorName("yellow"), palette.snapToColorName("black"))
            
            -- start chain of action cards in the action board
            if not action_board_id or action_board_id == entt_null or not registry:valid(action_board_id) then return end
            fireActionCardsInBoard(action_board_id) 
        end,
        0, -- infinite repetitions
        false, -- don't start immediately
        nil, -- no after callback
        timer_name -- name of the timer (so we can check if it exists later
    )
end
function setUpLogicTimers()
    
    -- check the trigger board 
    timer.run(
        function()
            
            for triggerBoardID, actionBoardID in pairs(trigger_board_id_to_action_board_id) do
                if triggerBoardID and triggerBoardID ~= entt_null and registry:valid(triggerBoardID) then
                    local triggerBoard = boards[triggerBoardID]
                    -- log_debug("checking trigger board:", triggerBoardID, "contains", triggerBoard and triggerBoard.cards and #triggerBoard.cards or 0, "cards")
                    if triggerBoard and triggerBoard.cards and #triggerBoard.cards > 0 then
                        local triggerCardEid = triggerBoard.cards[1]
                        if triggerCardEid and triggerCardEid ~= entt_null and registry:valid(triggerCardEid) then
                            local triggerCardScript = getScriptTableFromEntityID(triggerCardEid)
                            if triggerCardScript and triggerCardScript.cardID == "every_N_seconds" then
                                local timerName = "every_N_seconds_trigger_" .. tostring(triggerBoardID)
                                if not timer.get_timer_and_delay(timerName) then
                                    startTriggerNSecondsTimer(triggerBoardID, actionBoardID, timerName)
                                end   
                                    
                            end
                        end
                    end
                end
            end
            
        end
    )
end

-- initialize the game area for planning phase, where you combine cards and stuff.
function initPlanningPhase()
    
    -- activate planning state to draw/update planning entities
    activate_state(PLANNING_STATE)
    
    
    -- make a few test cards around 600, 300
    local x = 950
    local y = 600
    local offset = 50
    local testCard1 = createNewCard("action", "fire_basic_bolt", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    local testCard2 = createNewCard("action", "leave_spike_hazard", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    local testCard3 = createNewCard("action", "temporary_strength_bonus", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    local testCard4 = createNewCard("trigger", "every_N_seconds", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    -- createNewCard("trigger", "on_pickup", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    -- createNewCard("trigger", "on_distance_moved", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    local testCard5 =createNewCard("modifier", "double_effect", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    local testCard6 = createNewCard("modifier", "summon_minion_wandering", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    local testCard7 = createNewCard("modifier", "projectile_pierces_twice", lume.random(x - offset, x + offset), lume.random(y - offset, y + offset))
    
    -- let's give each card a physics entity which we will remove after 5 seconds.
    local cardsToChange = { testCard1, testCard2, testCard3, testCard4, testCard5, testCard6, testCard7 }
    
    for _, card in ipairs(cardsToChange) do
        if card and card ~= entt_null and registry:valid(card) then
            -- set the location of each card to an offscreen pos
            local t = registry:get(card, Transform)
            if t then
                t.actualX = -500
                t.actualY = -500
                t.visualX = t.actualX
                t.visualY = t.actualY
            end
        end
    end
    
    local cardDelay = 2.0 -- start 2 seconds after game init
    for _, card in ipairs(cardsToChange) do
        if card and card ~= entt_null and registry:valid(card) then
            timer.after(cardDelay, function()
                local t = registry:get(card, Transform)
                
                -- slide it into place at x, y (offset random)
                local targetX = x + lume.random(-offset, offset)
                local targetY = y + lume.random(-offset, offset)
                t.actualX = targetX
                t.actualY = targetY
                
                -- play sound with randomized pitch
                playSoundEffect("effects", "card_deal", 0.7 + math.random() * 0.3)
                
                -- give physics
                local info = { shape = "rectangle", tag = "card", sensor = false, density = 1.0, inflate_px = 15 } -- inflate so cards will not stick to each other when dealt.
                physics.create_physics_for_transform(registry,
                    physics_manager_instance, -- global instance
                    card, -- entity id
                    "world", -- physics world identifier
                    info
                )
                
                -- collision mask so cards collide with each other
                physics.enable_collision_between_many(PhysicsManager.get_world("world"), "card", {"card"})
                physics.update_collision_masks_for(PhysicsManager.get_world("world"), "card", {"card"})
                
                
                physics.use_transform_fixed_rotation(registry, card)
                    
            end)
            cardDelay = cardDelay + 0.1
        end
    end
    
    for _, card in ipairs(cardsToChange) do
        if card and card ~= entt_null and registry:valid(card) then
            -- remove physics after a few seconds
            timer.after(7.0, function()
                if card and card ~= entt_null and registry:valid(card) then
                    -- physics.clear_all_shapes(PhysicsManager.get_world("world"), card)
                    
                        
                    -- make transform autoritative
                    physics.set_sync_mode(registry, card, physics.PhysicsSyncMode.AuthoritativeTransform)
                    
                    -- get card transform, set rotation to 0
                    local t = registry:get(card, Transform)
                    if t then
                        t.actualR = 0
                    end
                    
                    -- remove phyics entirely.
                    physics.remove_physics(PhysicsManager.get_world("world"), card, true)
                end
            end)
        end
    end
    
    
    -- PhysicsManager.get_world("world"):InstallDefaultBeginHandlersForAllTags()
    

    
    -- board draw function, for all baords
    timer.run(function()
        for key, boardScript in pairs(boards) do
            local self = boardScript
            local eid = self:handle()
            if not (eid and registry:valid(eid)) then
                goto continue
            end

            local draw = true
            if type(self.gameStates) == "table" and next(self.gameStates) ~= nil then
                draw = false
                for _, state in pairs(self.gameStates) do
                    if is_state_active(state) then
                        draw = true
                        break
                    end
                end
            else
                -- draw only in planning state by default
                if not is_state_active(PLANNING_STATE) then
                    draw = false
                end
            end

            if draw then
                local area = registry:get(eid, Transform)
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
                    c.phase     = shapeAnimationPhase
                    c.arcSteps  = 14
                    c.thickness = 5
                    c.color     = self.borderColor or palette.snapToColorName("yellow")
                end, z_orders.board, layer.DrawCommandSpace.World)
            end

            ::continue::
        end
    end)
    
    local testTable = getScriptTableFromEntityID(card1)
    
    local boardHeight = 150
    local actionBoardWidth = 600
    local triggerBoardWidth = 150
    
    local boardPadding = 50
    
    local runningYValue = boardPadding
    local leftAlignValueTriggerBoardX = boardPadding
    local leftAlignValueActionBoardX = leftAlignValueTriggerBoardX + triggerBoardWidth + boardPadding
    local leftAlignValueRemoveBoardX = leftAlignValueActionBoardX + actionBoardWidth + boardPadding
-- -------------------------------------------------------------------------- --
--                   create a set of trigger + action board                   --
-- -------------------------------------------------------------------------- -

    -- let's create a card board
    local boardID = createNewBoard(leftAlignValueActionBoardX, runningYValue, actionBoardWidth, boardHeight)
    local board = boards[boardID]
    board.cards = {  } -- cards are entity ids.
    
    -- store the board in separate global for easy access
    action_board_id = boardID -- save in global
    
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
    
    -- give text state
    add_state_tag(board.textEntity, PLANNING_STATE)
    add_state_tag(board:handle(), PLANNING_STATE)
    
    -- let's make another board, for triggers.
    local triggerBoardID = createNewBoard(leftAlignValueTriggerBoardX, runningYValue, triggerBoardWidth, boardHeight)
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
    -- tex state
    add_state_tag(triggerBoard.textEntity, PLANNING_STATE)
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
    
    -- now map
    trigger_board_id_to_action_board_id[triggerBoardID] = boardID
    
    -- next row
    runningYValue = runningYValue + boardHeight + boardPadding


-- -------------------------------------------------------------------------- --
--                          now make another 4 pairs                          --
-- -------------------------------------------------------------------------- 
    
    local secondTriggerBoardID = createNewBoard(leftAlignValueTriggerBoardX, runningYValue, triggerBoardWidth, boardHeight)
    local secondTriggerBoard = boards[secondTriggerBoardID]
    secondTriggerBoard.borderColor = palette.snapToColorName("cyan")
    secondTriggerBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.trigger_area") end,  -- initial text
        20.0,                                 -- font size
        "color=cyan"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(secondTriggerBoard.textEntity, "world")
    -- tex state
    add_state_tag(secondTriggerBoard.textEntity, PLANNING_STATE)
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, secondTriggerBoard.textEntity, InheritedPropertiesType.PermanentAttachment, secondTriggerBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(secondTriggerBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    local secondActionBoardID = createNewBoard(leftAlignValueActionBoardX, runningYValue, actionBoardWidth, boardHeight)
    local secondActionBoard = boards[secondActionBoardID]
    secondActionBoard.cards = {  } -- cards are entity ids.
    
    -- map
    trigger_board_id_to_action_board_id[secondTriggerBoardID] = secondActionBoardID
    
    -- give a text label above the board
    secondActionBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.action_mod_area") end,  -- initial text
        20.0,                                 -- font size
        "color=apricot_cream"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(secondActionBoard.textEntity, "world")
    -- give text state
    add_state_tag(secondActionBoard.textEntity, PLANNING_STATE)
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, secondActionBoard.textEntity, InheritedPropertiesType.PermanentAttachment, secondActionBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(secondActionBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    -- next row
    runningYValue = runningYValue + boardHeight + boardPadding
    
    
-- ---------------------------------- row 3 --------------------------------- 
    
    local thirdTriggerBoardID = createNewBoard(leftAlignValueTriggerBoardX, runningYValue, triggerBoardWidth, boardHeight)
    local thirdTriggerBoard = boards[thirdTriggerBoardID]
    thirdTriggerBoard.borderColor = palette.snapToColorName("cyan")
    thirdTriggerBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.trigger_area") end,  -- initial text
        20.0,                                 -- font size
        "color=cyan"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(thirdTriggerBoard.textEntity, "world")
    -- tex state
    add_state_tag(thirdTriggerBoard.textEntity, PLANNING_STATE)
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, thirdTriggerBoard.textEntity, InheritedPropertiesType.PermanentAttachment, thirdTriggerBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(thirdTriggerBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    local thirdActionBoardID = createNewBoard(leftAlignValueActionBoardX, runningYValue, actionBoardWidth, boardHeight)
    local thirdActionBoard = boards[thirdActionBoardID]
    thirdActionBoard.cards = {  } -- cards are entity ids.
    
    -- map
    trigger_board_id_to_action_board_id[thirdTriggerBoardID] = thirdActionBoardID
    
    -- give a text label above the board
    thirdActionBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.action_mod_area") end,  -- initial text
        20.0,                                 -- font size
        "color=apricot_cream"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(thirdActionBoard.textEntity, "world")
    -- give text state
    add_state_tag(thirdActionBoard.textEntity, PLANNING_STATE)
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, thirdActionBoard.textEntity, InheritedPropertiesType.PermanentAttachment, thirdActionBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(thirdActionBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    -- next row
    runningYValue = runningYValue + boardHeight + boardPadding
    
-- ---------------------------------- row 4 ---------------------------------

    local fourthTriggerBoardID = createNewBoard(leftAlignValueTriggerBoardX, runningYValue, triggerBoardWidth, boardHeight)
    local fourthTriggerBoard = boards[fourthTriggerBoardID]
    fourthTriggerBoard.borderColor = palette.snapToColorName("cyan")
    fourthTriggerBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.trigger_area") end,  -- initial text
        20.0,                                 -- font size
        "color=cyan"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(fourthTriggerBoard.textEntity, "world")
    -- tex state
    add_state_tag(fourthTriggerBoard.textEntity, PLANNING_STATE)
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, fourthTriggerBoard.textEntity, InheritedPropertiesType.PermanentAttachment, fourthTriggerBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(fourthTriggerBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    local fourthActionBoardID = createNewBoard(leftAlignValueActionBoardX, runningYValue, actionBoardWidth, boardHeight)
    local fourthActionBoard = boards[fourthActionBoardID]
    fourthActionBoard.cards = {  } -- cards are entity ids.
    
    -- map
    trigger_board_id_to_action_board_id[fourthTriggerBoardID] = fourthActionBoardID
    
    -- give a text label above the board
    fourthActionBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.action_mod_area") end,  -- initial text
        20.0,                                 -- font size
        "color=apricot_cream"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(fourthActionBoard.textEntity, "world")
    -- give text state
    add_state_tag(fourthActionBoard.textEntity, PLANNING_STATE)
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, fourthActionBoard.textEntity, InheritedPropertiesType.RoleInheritor, fourthActionBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(fourthActionBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP 
    
    -- next row
    runningYValue = runningYValue + boardHeight + boardPadding


-- -------------------------------------------------------------------------- --
--                           make remove card board                           --
-- --------------------------------------------------------------------------
    
    -- another board for removing cards from boards.
    local removeBoardID = createNewBoard(leftAlignValueRemoveBoardX, boardPadding, triggerBoardWidth, boardHeight)
    local removeBoard = boards[removeBoardID]
    removeBoard.borderColor = palette.snapToColorName("red")
    removeBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.remove_card_area")  end,  -- initial text
        20.0,                                 -- font size
        "color=red"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(removeBoard.textEntity, "world")
    add_state_tag(removeBoard.textEntity, PLANNING_STATE)
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
                t.actualY = t.visualY + 400
                t.actualX = t.visualX
            end
            -- is the card part of a stack? if it was previously part of a board, just call reset Z order.
            if releasedCardScript.stackRootEntity and isInBoard then
                resetCardStackZOrder(releasedCardScript.stackRootEntity)
            end
            
            -- play sound
            playSoundEffect("effects", "remove_area_triggered", 0.9 + math.random() * 0.2)
            
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
    -- local augmentBoardID = createNewBoard(800, 350, 200, 200)
    -- local augmentBoard = boards[augmentBoardID]
    -- augmentBoard.borderColor = palette.snapToColorName("apricot_cream")
    -- augmentBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
    --     function() return localization.get("ui.augment_action_area") end,  -- initial text
    --     20.0,                                 -- font size
    --     "color=apricot_cream;wiggle"                       -- animation spec
    -- ).config.object
    -- -- make the text world space
    -- transform.set_space(augmentBoard.textEntity, "world")
    -- -- let's anchor to top of the trigger board
    -- transform.AssignRole(registry, augmentBoard.textEntity, InheritedPropertiesType.PermanentAttachment, augmentBoard:handle(),
    --     InheritedPropertiesSync.Strong,
    --     InheritedPropertiesSync.Weak,
    --     InheritedPropertiesSync.Strong,
    --     InheritedPropertiesSync.Weak,
    --     Vec2(0, -10) -- offset it a bit upwards
    -- );
    -- local roleComp = registry:get(augmentBoard.textEntity, InheritedProperties)
    -- roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    
    -- let's set up an update timer for triggers.
    setUpLogicTimers()
end

local ctx = nil
function initCombatSystem()

    -- init combat system.
    
    local combatBus       = CombatSystem.Core.EventBus.new()
    local combatTime      = CombatSystem.Core.Time.new()
    local combatStatDefs, DAMAGE_TYPES = CombatSystem.Core.StatDef.make()
    local combatBundle    = CombatSystem.Game.Combat.new(CombatSystem.Core.RR, DAMAGE_TYPES)  -- carries RR + DAMAGE_TYPES; stored on ctx.combat

    function make_actor(name, defs, attach)
        -- Creates a fresh Stats instance, applies attribute derivations via `attach`,
        -- and snapshots initial HP/Energy as both current and max. The actor also
        -- carries helpers for pet creation (so PetsAndSets.spawn_pet can reuse them).
        local s = CombatSystem.Core.Stats.new(defs)
        attach(s)
        s:recompute()
        local hp = s:get('health')
        local en = s:get('energy')

        return {
            name             = name,
            stats            = s,
            hp               = hp,
            max_health       = hp,
            energy           = en,
            max_energy       = en,
            gear_conversions = {},
            tags             = {},
            timers           = {},

            -- add these so spawn_pet can reuse them
            _defs            = defs,
            _attach          = attach,
            _make_actor      = make_actor,
        }
    end
        
    ctx = {
        _make_actor    = make_actor, -- Factory for creating actors
        debug          = true,       -- verbose debug prints across systems
        bus            = combatBus,        -- shared event bus for this arena
        time           = combatTime,       -- shared clock for statuses/DoTs/cooldowns
        combat         = combatBundle      -- optional bundle for RR+damage types, if needed
    }
    
    -- add side-aware accessors to ctx
    -- Used by targeters and AI; these close over 'ctx' (safe here).
    ctx.get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end
    ctx.get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end
    
    --TODO: probably make separate enemy creation functions for each enemy type.
    
    -- Hero baseline: some OA/Cunning/Spirit, crit damage, CDR, cost reduction, and atk/cast speed.
    local hero = make_actor('Hero', combatStatDefs, CombatSystem.Game.Content.attach_attribute_derivations)
    hero.side = 1
    hero.level_curve = 'fast_start'
    hero.stats:add_base('physique', 16)
    hero.stats:add_base('cunning', 18)
    hero.stats:add_base('spirit', 12)
    hero.stats:add_base('weapon_min', 18)
    hero.stats:add_base('weapon_max', 25)
    hero.stats:add_base('life_steal_pct', 10)
    hero.stats:add_base('crit_damage_pct', 50) -- +50% crit damage
    hero.stats:add_base('cooldown_reduction', 20)
    hero.stats:add_base('skill_energy_cost_reduction', 15)
    hero.stats:add_base('attack_speed', 1.0)
    hero.stats:add_base('cast_speed', 1.0)
    hero.stats:recompute()

    -- Ogre: tougher target with defense layers and reactive behaviors (reflect/retaliation/block).
    local ogre = make_actor('Ogre', combatStatDefs, CombatSystem.Game.Content.attach_attribute_derivations)
    ogre.side = 2
    ogre.stats:add_base('health', 400)
    ogre.stats:add_base('defensive_ability', 95)
    ogre.stats:add_base('armor', 50)
    ogre.stats:add_base('armor_absorption_bonus_pct', 20)
    ogre.stats:add_base('fire_resist_pct', 40)
    ogre.stats:add_base('dodge_chance_pct', 10)
    -- ogre.stats:add_base('deflect_chance_pct', 8) -- (deflection not currently used)
    ogre.stats:add_base('reflect_damage_pct', 5)
    ogre.stats:add_base('retaliation_fire', 8)
    ogre.stats:add_base('retaliation_fire_modifier_pct', 25)
    ogre.stats:add_base('block_chance_pct', 30)
    ogre.stats:add_base('block_amount', 60)
    ogre.stats:add_base('block_recovery_reduction_pct', 25)
    ogre.stats:add_base('damage_taken_reduction_pct',2000) -- stress test: massive DR → negative damage (healing)
    ogre.stats:recompute()

    ctx.side1 = { hero }
    ctx.side2 = { ogre }
    
    -- attach defs/derivations to ctx for easy access later for pets
    ctx._defs       = combatStatDefs
    ctx._attach     = CombatSystem.Game.Content.attach_attribute_derivations
    ctx._make_actor = make_actor
    
    
    -- update combat system every frame
    timer.run(
        function()
            ctx.time:tick(GetFrameTime())
        end
    )
end

function startActionPhase()
    clear_states() -- disable all states.
    
    activate_state(ACTION_STATE)
    activate_state("default_state") -- just for defaults, keep them open
    
    PhysicsManager.enable_step("world", true)
end

function startPlanningPhase()
    
    clear_states() -- disable all states.
    
    activate_state(PLANNING_STATE)
    activate_state("default_state") -- just for defaults, keep them open
    
    PhysicsManager.enable_step("world", false)
end

function startShopPhase()
    
    clear_states() -- disable all states.
    
    activate_state(SHOP_STATE)
    activate_state("default_state") -- just for defaults, keep them open
    
    PhysicsManager.enable_step("world", false)
end

local lastFrame = -1

-- call every frame
function debugUI()
    

    
    -- open a window (returns shouldDraw)
    local shouldDraw = ImGui.Begin("Quick access")
    if shouldDraw then
        if ImGui.Button("Goto Planning Phase") then
            startPlanningPhase()
        end
        if ImGui.Button("Goto Action Phase") then
            startActionPhase()
        end
        if ImGui.Button("Goto Shop Phase") then
            startShopPhase()
        end
    end
    ImGui.End()
end

cardsSoldInShop = {}

function initShopPhase()
    
    -- let's make a large board for shopping
    local shopBoardID = createNewBoard(100, 100, 800, 400)
    local shopBoard = boards[shopBoardID]
    shopBoard.borderColor = palette.snapToColorName("apricot_cream")
    
    -- give a text label above the board    
    shopBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.shop_area") end,  -- initial text
        20.0,                                 -- font size
        "color=apricot_cream"                       -- animation spec
    ).config.object
    
    -- make the text world space
    transform.set_space(shopBoard.textEntity, "world")
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, shopBoard.textEntity, InheritedPropertiesType.PermanentAttachment, shopBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(shopBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    -- give the text & board state
    add_state_tag(shopBoard.textEntity, SHOP_STATE)
    add_state_tag(shopBoard:handle(), SHOP_STATE)
    shopBoard.gameStates = { SHOP_STATE } -- store in board as well
    
    -- let's populate the shop with some cards
    local testCard1 = createNewCard("action", "fire_basic_bolt", 200, 200, SHOP_STATE)
    local testCard2 = createNewCard("action", "leave_spike_hazard",
        400, 200, SHOP_STATE)
    local testCard3 = createNewCard("action", "temporary_strength_bonus",
        600, 200, SHOP_STATE)
        
    -- add them to the board.
    addCardToBoard(testCard1, shopBoard:handle())
    addCardToBoard(testCard2, shopBoard:handle())
    addCardToBoard(testCard3, shopBoard:handle())
    
    -- let's add a (buy) board below.
    local buyBoardID = createNewBoard(100, 550, 800, 150)
    local buyBoard = boards[buyBoardID]
    buyBoard.borderColor = palette.snapToColorName("green")
    buyBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.buy_area") end,  -- initial text
        20.0,                                 -- font size
        "color=green"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(buyBoard.textEntity, "world")
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, buyBoard.textEntity, InheritedPropertiesType.PermanentAttachment, buyBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,   
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = registry:get(buyBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP 
    -- give the text & board state
    add_state_tag(buyBoard.textEntity, SHOP_STATE)
    add_state_tag(buyBoard:handle(), SHOP_STATE)
    buyBoard.gameStates = { SHOP_STATE } -- store in board as well
    
    buyBoard.cards = {} -- cards are entity ids.
    
    -- add a different onRelease method
    local buyBoardGameObject = registry:get(buyBoard:handle(), GameObject)
    if buyBoardGameObject then
        buyBoardGameObject.methods.onRelease = function(registry, releasedOn, released)
            log_debug("Entity", released, "released on", releasedOn)
            -- when released on top of the buy board, if it's a card in the shop, move it to the buy board.
            -- is the released entity a card?
            local releasedCardScript = getScriptTableFromEntityID(released)
            if not releasedCardScript then return end   
            
            --TODO: buy logic.
        end
    end
    
end

SCREEN_BOUND_LEFT = 0
SCREEN_BOUND_TOP = 0
SCREEN_BOUND_RIGHT = 1280
SCREEN_BOUND_BOTTOM = 720
function initActionPhase()
    log_debug("Action phase started!")
    
    initCombatSystem()
    
    
    -- activate action state
    activate_state(ACTION_STATE)
    
    local world = PhysicsManager.get_world("world")
    world:AddCollisionTag("sensor")
    world:AddCollisionTag("player")
    world:AddCollisionTag("bullet")
    world:AddCollisionTag("WORLD")
    world:AddCollisionTag("trap")
    world:AddCollisionTag("enemy")
    world:AddCollisionTag("card")
    
    -- 3856-TheRoguelike_1_10_alpha_649.png
    survivorEntity = animation_system.createAnimatedObjectWithTransform(
        "3856-TheRoguelike_1_10_alpha_649.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give survivor a script and hook up
    local survivorScript = Node{}
    -- TODO: add update method here if needed
    survivorScript.update = function(self, dt)
        local t = registry:get(self:handle(), Transform)
        if t then
            -- make sure visual matches actual, so there's no lag and vfx always stays on the player
            t.visualX = t.actualX
            t.visualY = t.actualY
        end
    end
    survivorScript:attach_ecs{ create_new = false, existing_entity = survivorEntity }
    
    -- relocate to the center of the screen
    local survivorTransform = registry:get(survivorEntity, Transform)
    survivorTransform.actualX = globals.screenWidth() / 2
    survivorTransform.actualY = globals.screenHeight() / 2
    survivorTransform.visualX = survivorTransform.actualX   
    survivorTransform.visualY = survivorTransform.actualY
    
    -- give survivor physics.
    local info = { shape = "rectangle", tag = "player", sensor = false, density = 1.0, inflate_px = 0 } -- default tag is "WORLD"
    physics.create_physics_for_transform(registry,
        physics_manager_instance, -- global instance
        survivorEntity, -- entity id
        "world", -- physics world identifier
        info
    )
    
    -- make it collide with enemies & walls
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "WORLD", {"player"})
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "player", {"WORLD"})
    
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "player", {"WORLD"})
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "WORLD", {"player"})
    
    
    -- make walls after defining collision relationships, tesitng because of bug.
    physics.add_screen_bounds(PhysicsManager.get_world("world"), 
        SCREEN_BOUND_LEFT, SCREEN_BOUND_TOP, SCREEN_BOUND_RIGHT, SCREEN_BOUND_BOTTOM,
        30, 
        "WORLD"
    )
    
    -- give player fixed rotation.
    physics.use_transform_fixed_rotation(registry, survivorEntity)
    
    -- give shader pipeline comp for later use
    local shaderPipelineComp = registry:emplace(survivorEntity, shader_pipeline.ShaderPipelineComponent)

    
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "enemy", {"player", "enemy"}) -- enemy>player and enemy>enemy
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "player", {"enemy"}) -- player>enemy
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "player", {"enemy"})
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "enemy", {"player", "enemy"})
    
    -- entity.set_draw_override(survivorEntity, function(w, h)
    --     -- immediate render version of the same thing.
    --     command_buffer.executeDrawGradientRectRoundedCentered(layers.sprites, function(c)
    --         local survivorT = registry:get(survivorEntity, Transform)
    
    --         c.cx = 0 -- self centered
    --         c.cy = 0
    --         c.width = w
    --         c.height = h
    --         c.roundness = 0.5
    --         c.segments = 8
    --         c.topLeft = palette.snapToColorName("apricot_cream")
    --         c.topRight = palette.snapToColorName("green")
    --         c.bottomRight = palette.snapToColorName("green")
    --         c.bottomLeft = palette.snapToColorName("apricot_cream")
                
    --         end, z_orders.projectiles + 1, layer.DrawCommandSpace.World)
    --     end, true) -- true disables sprite rendering
    
    -- give survivor collision callback, namely begin.
    -- modifying a file.
    physics.on_pair_begin(world, "player", "enemy", function(arb) 
        
        log_debug("Survivor hit an enemy!")
        -- play sound
        
        playSoundEffect("effects", "time_slow", 0.9 + math.random() * 0.2)
        slowTime(1.5, 0.1) -- slow time for 2 seconds, to 20% speed
        
        timer.after(0.3, function()
            playSoundEffect("effects", "time_back_to_normal", 0.9 + math.random() * 0.2)
        end)
        
        -- TODO: make player take damage, play hit effect, etc.
        
        local shaderPipelineComp = registry:get(survivorEntity, shader_pipeline.ShaderPipelineComponent)
        shaderPipelineComp:addPass("flash")
        
        -- shake camera
        local cam = camera.Get("world_camera")
        if cam then
            cam:Shake(10.0, 0.35, 30.0)
        end
        
        -- remove after a short delay
        timer.after(1.0, function()
            local shaderPipelineComp = registry:get(survivorEntity, shader_pipeline.ShaderPipelineComponent)
            if shaderPipelineComp then
                shaderPipelineComp:removePass("flash")
            end
        end)
        
        return false -- reject collision 
    end)

    
    -- allow transform manipuation to alter physics body
    -- physics.set_sync_mode(registry, survivorEntity, physics.PhysicsSyncMode.AuthoritativeTransform)
    
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
            -- local dx, dy = 0, 0
            -- if input.action_down("survivor_left") then
            --     dx = dx - 1
            -- end
            -- if input.action_down("survivor_right") then
            --     dx = dx + 1
            -- end
            -- if input.action_down("survivor_up") then
            --     dy = dy - 1
            -- end
            -- if input.action_down("survivor_down") then
            --     dy = dy + 1
            -- end
            -- -- normalize direction vector
            -- if dx ~= 0 or dy ~= 0 then
            --     local len = math.sqrt(dx * dx + dy * dy)
            --     dx = dx / len
            --     dy = dy / len
            -- end
            
            -- local t = registry:get(survivorEntity, Transform)
            -- if t then
            --     t.actualX = t.actualX + dx * speed * GetFrameTime()
            --     t.actualY = t.actualY + dy * speed * GetFrameTime()
            -- end
            
            local isMoving = false
            local moveDir = {x=0, y=0}
            if input.action_down("survivor_left") then
                moveDir.x = -1
                isMoving = true
            end
            if input.action_down("survivor_right") then
                moveDir.x = 1
                isMoving = true
            end
            if input.action_down("survivor_up") then
                moveDir.y = -1
                isMoving = true
            end
            if input.action_down("survivor_down") then
                moveDir.y = 1
                isMoving = true
            end
            -- normalize
            local len = math.sqrt(moveDir.x * moveDir.x + moveDir.y * moveDir.y)
            if len > 0 then
                moveDir.x = moveDir.x / len
                moveDir.y = moveDir.y / len
            end
            physics.SetVelocity(PhysicsManager.get_world("world"), survivorEntity, moveDir.x * speed, moveDir.y * speed)
            
        end,
        nil, -- no after
        "survivorEntityMovementTimer" -- timer tag
    )
    
    input.set_context("gameplay") -- set the input context to gameplay
    
    
    -- lets make a timer that, if action state is active, spawn an enemy every few seconds
    timer.every(5.0, function()
        if is_state_active(ACTION_STATE) then
            
            -- animation entity
            local enemyEntity = animation_system.createAnimatedObjectWithTransform(
                "b453.png", -- animation ID
                true             -- use animation, not sprite identifier, if false
            )
            
            -- give state
            add_state_tag(enemyEntity, ACTION_STATE)
            
            -- set it to a random position, within the screen bounds.
            local enemyTransform = registry:get(enemyEntity, Transform)
            enemyTransform.actualX =   lume.random(SCREEN_BOUND_LEFT + 50, SCREEN_BOUND_RIGHT - 50)
            enemyTransform.actualY =   lume.random(SCREEN_BOUND_TOP + 50, SCREEN_BOUND_BOTTOM - 50)
            
            -- snap
            enemyTransform.visualX = enemyTransform.actualX
            enemyTransform.visualY = enemyTransform.actualY
            
            -- give it physics
            local info = { shape = "rectangle", tag = "enemy", sensor = false, density = 1.0, inflate_px = -4 } -- default tag is "WORLD"
            physics.create_physics_for_transform(registry,
                physics_manager_instance, -- global instance
                enemyEntity, -- entity id
                "world", -- physics world identifier
                info
            )
            
            -- 
            
            physics.update_collision_masks_for(PhysicsManager.get_world("world"), "enemy", {"player", "enemy"})
            physics.update_collision_masks_for(PhysicsManager.get_world("world"), "player", {"enemy"})
            
            -- make it steerable
            -- steering
            steering.make_steerable(registry, enemyEntity, 140.0, 2000.0, math.pi*2.0, 2.0)
            
            -- make circle marker for enemy appearance, tween it down to 0 scale and then remove it
            local spawnMarkerNode = Node{}
            spawnMarkerNode.scale = 1.0
            local enemyX = enemyTransform.actualX + enemyTransform.actualW/2
            local enemyY = enemyTransform.actualY + enemyTransform.actualH/2
            spawnMarkerNode.update = function(self, dt)
                
                
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x = enemyX
                    c.y = enemyY
                    c.w = 64 * self.scale
                    c.h = 64 * self.scale
                    c.rx = 32
                    c.ry = 32
                    c.color = Col(255, 255, 255, 255)
                    
                end, z_orders.projectiles + 1, layer.DrawCommandSpace.World)
            end
            spawnMarkerNode:attach_ecs{}
            -- tween down
            -- local h5 = timer.tween(1.2, camera, { x = 320, y = 180, zoom = 1.25 }, nil, nil, "cam_move", "camera")
            timer.tween(0.2, spawnMarkerNode, { scale = 0.0 }, nil, function()
                registry:destroy(spawnMarkerNode:handle())
            end)
            
            timer.run(function()
                local t = registry:get(enemyEntity, Transform)
                
                local playerLocation = {x=0,y=0}
                local playerT = registry:get(survivorEntity, Transform)
                if playerT then
                    playerLocation.x = playerT.actualX + playerT.actualW/2
                    playerLocation.y = playerT.actualY + playerT.actualH/2
                end
                
                steering.seek_point(registry, enemyEntity, playerLocation, 1.0, 0.5)
                -- steering.flee_point(registry, player, {x=playerT.actualX + playerT.actualW/2, y=playerT.actualY + playerT.actualH/2}, 300.0, 1.0)
                steering.wander(registry, enemyEntity, 20.0, 150.0, 40.0, 0.5)
                
                -- steering.path_follow(registry, player, 1.0, 1.0)
                
                -- run every frame for this to work
                -- physics.ApplyTorque(world, player, 1000)

            end)
            
            
            
        end
    end,
    nil,
    "spawnEnemyTimer")
    
    -- timer to pan camera to follow player
    timer.every(0.1, function()
        if is_state_active(ACTION_STATE) then
            local targetX, targetY = 0, 0
            local t = registry:get(survivorEntity, Transform)
            if t then
                targetX = t.actualX + t.actualW/2
                targetY = t.actualY + t.actualH/2
                camera_smooth_pan_to("world_camera", targetX, targetY) -- pan to the target smoothly
            end
            
        else
            local cam = camera.Get("world_camera")
            local c = cam:GetActualTarget()
            
            -- if not already at halfway point in screen, then move it there
            if math.abs(c.x - globals.screenWidth()/2) > 5 or math.abs(c.y - globals.screenHeight()/2) > 5 then
                camera_smooth_pan_to("world_camera", globals.screenWidth()/2, globals.screenHeight()/2) -- pan to the target smoothly
            end
        end
    end,
    nil,
    "cameraPanToPlayerTimer")
    
    
    -- blanket collision update
    -- physics.reapply_all_filters(PhysicsManager.get_world("world"))
    
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
    
    -- ggive entire box the planning state
    ui.box.AssignStateTagsToUIBox(planningUIEntities.start_action_button_box, PLANNING_STATE)
    
    
    
end