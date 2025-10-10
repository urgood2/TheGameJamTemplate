


-- contains code limited to gameplay logic for organizational purposes

local z_orders = require("core.z_orders")
local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script
local palette = require("color.palette")


function createNewCard(boardEntityID, isStackable)
    
    -- let's create a couple of cards.
    local card1 = animation_system.createAnimatedObjectWithTransform(
        "card_back_1.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
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
    
    
    nodeComp.methods.onRelease = function(registry, releasedOn, released)
        log_debug("card", released, "released on", releasedOn)
        
        -- when released on top of a card, get the root card of the stack if there is one, and add self to that stack 
        
        
        -- get the card script table
        local releasedCardScript = getScriptTableFromEntityID(released)
        if not releasedCardScript then return end
        
        -- check stackRootEntity in the table. Also, check that isStackable is true
        if not releasedCardScript.isStackable then
            log_debug("released card is not stackable or has no stackRootEntity")
            return
        end
        
        -- repeated climb tree to find the root entity from the releasedOn
        while true do
            if not releasedOn or releasedOn == entt_null or not registry:valid(releasedOn) then
                break
            end
            local releasedOnScript = getScriptTableFromEntityID(releasedOn)
            if not releasedOnScript then
                break
            end
            if not releasedOnScript.isStackable or not releasedOnScript.stackRootEntity then
                break
            end
            -- climb up the tree
            releasedOn = releasedOnScript.stackRootEntity
            break -- we just need to find it once
        end
        
        -- is the root entity a valid entity?
        local rootEntity = releasedOn or releasedCardScript.stackRootEntity
        if not rootEntity or rootEntity == entt_null or not registry:valid(rootEntity) then
            log_debug("released card has no valid stackRootEntity, setting to self")
            releasedCardScript.stackRootEntity = released
            rootEntity = released
        end
        
        -- now get the root entity's script
        local rootCardScript = getScriptTableFromEntityID(rootEntity)
        if not rootCardScript then
            log_debug("released card's stackRootEntity has no valid script table, bail")
            return
        end
        
        -- add self to the root entity's stack, if self is not the root
        if rootEntity == released then
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
        elseif releasedCardScript.cardStack then
            for _, e in ipairs(releasedCardScript.cardStack) do
                if e == rootEntity then
                    log_debug("root entity is already in the released card's stack, not stacking again")
                    return
                end
            end
        end
        rootCardScript.cardStack = rootCardScript.cardStack or {}
        table.insert(rootCardScript.cardStack, released)
        
        -- after adding to the stack, update the z-orders from bottom up.
        local baseZ = z_orders.card
        
        -- give root entity the base z order
        layer_order_system.assignZIndexToEntity(rootEntity, baseZ)
        
        -- now for every card in the stack, give it a z order above the root
        for i, stackedCardEid in ipairs(rootCardScript.cardStack) do
            if stackedCardEid and registry:valid(stackedCardEid) then
                local stackedTransform = registry:get(stackedCardEid, Transform)
                local zi = baseZ + (i) -- root is baseZ, first stacked card is baseZ + 1, etc
                layer_order_system.assignZIndexToEntity(stackedCardEid, zi)
            end
        end
        
        -- also store a reference to the root entity in self
        cardScript.stackRootEntity = rootEntity
        
    end
    
    nodeComp.methods.onDrag = function()
        
        if not boardEntityID then return end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- set z order to top so it can be seen
        cardScript.isDragging = true
        
        log_debug("dragging card, bringing to top z:", board.z_orders.top)
        layer_order_system.assignZIndexToEntity(card1, board.z_orders.top)
    end
    
    nodeComp.methods.onStopDrag = function()
        
        if not boardEntityID then return end
        
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

function initGameArea()
    
    -- let's create a card board
    
    -- first create a generic scriptable entity.
    local board = Node{}
    
    board.z_orders = { bottom = z_orders.card, top = z_orders.card + 1000 } -- save specific z orders for the card in the board.
    board.z_order_cache_per_card = {} -- cache for z orders per card entity id.
    
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
                    c.color     = palette.snapToColorName("yellow")
                end, z_orders.board, layer.DrawCommandSpace.World)

            end
        end
    )
    
    -- replace update function
    board.update = function(self, dt)
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
            c.color     = palette.snapToColorName("yellow")
        end, z_orders.board, layer.DrawCommandSpace.World)

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


    
    -- attach ecs and load update function
    board:attach_ecs{ create_new = true }
    
    
    local card1 = createNewCard(board:handle())
    local card2 = createNewCard(board:handle())
    
    -- add a couple of test cards outside the card area.
    
    local outsideCard1 = createNewCard()
    local outsideCard2 = createNewCard()
    local outsideCard3 = createNewCard()
    local outsideCard4 = createNewCard()
    
    local testTable = getScriptTableFromEntityID(card1)
    
    board.cards = { card1, card2 } -- give a couple of starting cards. These are the entity ids.
    
    -- store in boards table
    boards[board:handle()] = board
    
    -- give a transform comp (automatically in world space)
    transform.CreateOrEmplace(registry, globals.gameWorldContainerEntity(), 0, 0, 600, 200, board:handle())
    
    
    -- timer to test adding new cards
    timer.every(5.0, function()
        local newCard = createNewCard()
        table.insert(board.cards, newCard)
    end)
    
    
end