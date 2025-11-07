


-- contains code limited to gameplay logic for organizational purposes

local z_orders = require("core.z_orders")
local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script
local palette = require("color.palette")
local TimerChain = require("core.timer_chain")
local Easing = require("util.easing")
local CombatSystem = require("combat.combat_system")
require ("core.card_eval_order_test")
local WandEngine = require("core.card_eval_order_test")
local signal = require("external.hump.signal")
local timer = require("core.timer")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
require("ui.ui_definition_helper")
local dsl = require("ui.ui_syntax_sugar")


require("core.type_defs") -- for Node customizations

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
    },
    {
        id = "on_bump_enemy"
    },
    {
        id = "on_dash"
    },
    
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
local cardW, cardH = 80, 112 -- these are reset on init.


-- save game state strings
PLANNING_STATE = "PLANNING"
ACTION_STATE = "SURVIVORS"
SHOP_STATE = "SHOP"
WAND_TOOLTIP_STATE = "WAND_TOOLTIP_STATE" -- we use this to show wand tooltips and hide them when needed.
CARD_TOOLTIP_STATE = "CARD_TOOLTIP_STATE" -- we use this to show card tooltips and hide them when needed.

-- combat context, to be used with the combat system.
combat_context = nil

-- some entities

survivorEntity = nil
boards = {}
cards = {}
inventory_board_id = nil
trigger_board_id_to_action_board_id = {} -- map trigger boards to action boards
trigger_board_id = nil
action_board_id = nil

-- ui tooltip cache
wand_tooltip_cache = {}
card_tooltip_cache = {}
previously_hovered_tooltip = nil

-- to decide which trigger+action board set is active
board_sets = {}
current_board_set_index = 1

-- keep track of controller focus
controller_focused_entity = nil


function addCardToBoard(cardEntityID, boardEntityID)
    if not cardEntityID or cardEntityID == entt_null or not entity_cache.valid(cardEntityID) then return end
    if not boardEntityID or boardEntityID == entt_null or not entity_cache.valid(boardEntityID) then return end
    local board = boards[boardEntityID]
    if not board then return end
    board.cards = board.cards or {}
    board.needsResort = true
    table.insert(board.cards, cardEntityID)
    log_debug("Added card", cardEntityID, "to board", boardEntityID)
    
    local cardScript = getScriptTableFromEntityID(cardEntityID)
    if cardScript then
        log_debug("Card", cardEntityID, "now on board", boardEntityID)
        cardScript.currentBoardEntity = boardEntityID
    end
end

function removeCardFromBoard(cardEntityID, boardEntityID)
    if not cardEntityID or cardEntityID == entt_null or not entity_cache.valid(cardEntityID) then return end
    if not boardEntityID or boardEntityID == entt_null or not entity_cache.valid(boardEntityID) then return end
    local board = boards[boardEntityID]
    if not board then return end
    board.cards = board.cards or {}
    board.needsResort = true
    for i, eid in ipairs(board.cards) do
        if eid == cardEntityID then
            table.remove(board.cards, i)
            break
        end
    end
    
    -- add the state of whatever the current game state is to the card again
    if is_state_active(PLANNING_STATE) then
        add_state_tag(cardEntityID, PLANNING_STATE)
    end
    
    if is_state_active(ACTION_STATE) then
        add_state_tag(cardEntityID, ACTION_STATE)
    end
    
    if is_state_active(SHOP_STATE) then
        add_state_tag(cardEntityID, SHOP_STATE)
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
        if stackedCardEid and entity_cache.valid(stackedCardEid) then
            local stackedTransform = component_cache.get(stackedCardEid, Transform)
            local zi = baseZ + (i) -- root is baseZ, first stacked card is baseZ + 1, etc
            layer_order_system.assignZIndexToEntity(stackedCardEid, zi)
        end
    end
end

function createNewBoard(x, y, w, h) 
    
    

    
    local board = BoardType{}
    
    ------------------------------------------------------------
    -- Swap positions between a selected card and its neighbor
    ------------------------------------------------------------

    board.z_orders = { bottom = z_orders.card, top = z_orders.card + 1000 } -- save specific z orders for the card in the board.
    board.z_order_cache_per_card = {} -- cache for z orders per card entity id.
    board.cards = {} -- no starting cards
    
    board:attach_ecs{ create_new = true }
    transform.CreateOrEmplace(registry, globals.gameWorldContainerEntity(), x, y, w, h, board:handle())
    boards[board:handle()] = board
    -- add_state_tag(board:handle(), PLANNING_STATE)
    
    -- get the game object for board and make it onReleaseEnabled
    local boardGameObject = component_cache.get(board:handle(), GameObject)
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
        
        -- reset card selected state
        releasedCardScript.selected = false
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

-- creates a new trigger slot card. these go in trigger boards ONLY.
function createNewTriggerSlotCard(id, x, y, gameStateToApply) 
    
    local card = createNewCard(nil, x, y, gameStateToApply)
    
    local cardScript = getScriptTableFromEntityID(card)
    
    WandEngine.apply_card_properties(cardScript, WandEngine.trigger_card_defs[id] or {})
    
    return card
end


function transitionInOutCircle(duration, message, color, startPosition)
    
    local TransitionType = Node:extend()
    
    TransitionType.age = 0
    TransitionType.duration = duration or 1.0
    TransitionType.message = message or ""
    TransitionType.color = color or palette.getColor("gray")
    TransitionType.radius = 0
    TransitionType.x = startPosition.x or globals.getScreenWidth() * 0.5
    TransitionType.y = startPosition.y or globals.getScreenHeight() * 0.5
    TransitionType.textScale = 0
    TransitionType.fontSize = 48
    
    
    
    
    function TransitionType:init()
        -- a circle that will expand to fill the screen in duration * 0.3 (tween cubic) from startPosition

        timer.tween_fields(duration * 0.3, self, { radius = math.sqrt(globals.screenWidth()^2 + globals.screenHeight()^2) }, Easing.inOutCubic.f, nil, "transition_circle_expand", "ui")
        
        -- spawn text in center after duration * 0.1, scaling up from 0 to 1 in duration * 0.2 (tween cubic).
        timer.after(duration * 0.05, function ()
            timer.tween_fields(duration * 0.2, self, { textScale = 1.0 }, Easing.inOutCubic.f, nil, "transition_text_scale_up", "ui")
        end, "transition_text_delay", "ui")
        
        -- at duration * 0.7, start shrinking circle back to center. 
        timer.after(duration * 0.7, function ()
            timer.tween_fields(duration * 0.3, self, { radius = 0 }, Easing.inOutCubic.f, nil, "transition_circle_shrink", "ui")
        end, "transition_circle_shrink_delay", "ui")
        
        timer.after(duration * 0.8, function ()
            playSoundEffect("effects", "transition_whoosh_out", 1.0)
        end, "transition_sound_delay", "ui")
        
        -- at duration 0.9, scale text back down to 0.
        timer.after(duration * 0.9, function ()
            timer.tween_fields(duration * 0.1, self, { textScale = 0.0 }, Easing.inOutCubic.f, nil, "transition_text_scale_down", "ui")
            
        end, "transition_text_scale_down_delay", "ui")
        
        playSoundEffect("effects", "transition_whoosh", 1.0)
    end
    
    function TransitionType:update(dt)
        self.age = self.age + dt
        -- float x, y, rx, ry;
        -- Color color = WHITE;
        -- std::optional<float> lineWidth = std::nullopt; // If set, draw outline with this width; else filled
        -- draw a filled circle with radius.
        command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
            c.x = self.x
            c.y = self.y
            c.rx = self.radius
            c.ry = self.radius
            c.color = self.color
        end, z_orders.ui_transition, layer.DrawCommandSpace.Screen)
        
        local textW = localization.getTextWidthWithCurrentFont(self.message, self.fontSize, 1)
        -- scale text 
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = self.message
            c.font = localization.getFont()
            c.x = globals.screenWidth() * 0.5 - textW * 0.5 * self.textScale
            c.y = globals.screenHeight() * 0.5 - (self.fontSize * self.textScale) * 0.5
            c.color = util.getColor("white")
            c.fontSize = self.fontSize * self.textScale
        end, z_orders.ui_transition + 1, layer.DrawCommandSpace.Screen)
        
    end
    
    function TransitionType:destroy()
        -- playSoundEffect("effects", "transition_whoosh_out", 1.0)
    end
    
    local transition = TransitionType{}
        :attach_ecs{ create_new = true }
        :addStateTag(PLANNING_STATE)
        :addStateTag(ACTION_STATE)
        :addStateTag(SHOP_STATE) -- make them function in all states
        :destroy_when(function(self, eid) return self.age >= self.duration end)
    
end

function setUpCardAndWandStatDisplay()
    
    local STAT_FONT_SIZE = 27
    
    local bumper_l = "xbox_lb.png"
    local bumper_r = "xbox_rb.png"
    local trigger_l = "xbox_lt.png"
    local trigger_r = "xbox_rt.png"
    local button_a = "xbox_button_color_a.png"
    local button_b = "xbox_button_color_b.png"
    local button_x = "xbox_button_color_x.png"
    local button_y = "xbox_button_color_y.png"
    local left_stick = "xbox_stick_top_l.png"
    local right_stick = "xbox_stick_top_r.png"
    local d_pad = "xbox_dpad.png"
    local plus = "flair_plus.png"
    
    
    
    timer.run(function ()
        
        -- bail if not shop or planning state
        if not is_state_active(PLANNING_STATE) and not is_state_active(SHOP_STATE) then
            return
        end
        
        -- TODO: controller prompts
        
        -- get current board set
        local boardSet = board_sets[current_board_set_index]
        if not boardSet then return end
        
        --TODO: assign a "wand" to each board set and display stats.
        
        
        -- is the mouse covering over a card?
        
        local isHoveredOverCard = false
        
        
        if (globals.inputState.cursor_hovering_target and globals.inputState.cursor_hovering_target ~= entt_null and entity_cache.valid(globals.inputState.cursor_hovering_target)) then
            for cardEid, cardScript in pairs(cards) do
                if cardEid == globals.inputState.cursor_hovering_target then
                    isHoveredOverCard = true
                    break
                end
            end
        end
        
        local hovered = globals.inputState.cursor_hovering_target
        
        local startY = globals.screenHeight() - globals.screenHeight() * 0.28
        local startX = globals.screenWidth() * 0.1
        local currentY = startY
        local columnWidth = 400
        local currentX = startX
        
        if isHoveredOverCard then
            
            -- if mousing over card, show card stats.
            local cardScript = getScriptTableFromEntityID(hovered)
            
            -- draw:
            -- id = "TEST_PROJECTILE_TIMER",
            -- type = "action",
            -- max_uses = -1,
            -- mana_cost = 8,
            -- damage = 15,
            -- damage_type = "physical",
            -- radius_of_effect = 0,
            -- spread_angle = 3,
            -- projectile_speed = 400,
            -- lifetime = 3000,
            -- cast_delay = 150,
            -- recharge_time = 0,
            -- spread_modifier = 0,
            -- speed_modifier = 0,
            -- lifetime_modifier = 0,
            -- critical_hit_chance_modifier = 0,
            -- timer_ms = 1000,
            -- weight = 2,
            -- test_label = "TEST\nprojectile\ntimer",
            
            local statsToDraw = { "card_id", "type", "max_uses", "mana_cost", "damage", "damage_type", "radius_of_effect", "spread_angle", "projectile_speed", "lifetime", "cast_delay", "recharge_time", "timer_ms" }
            
            local lineHeight = 22
            
            -- if nil, don't draw. 
            -- if reached bottom, reset to next column
            for _, statName in ipairs(statsToDraw) do
                local statValue = cardScript[statName]
                if statValue ~= nil then
                    command_buffer.queueDrawText(layers.sprites, function(c)
                        c.text = tostring(statName) .. ": " .. tostring(statValue)
                        c.font = localization.getFont()
                        c.x = currentX
                        c.y = currentY
                        c.color = util.getColor("YELLOW")
                        c.fontSize = STAT_FONT_SIZE
                    end, z_orders.card_text, layer.DrawCommandSpace.World)
                    
                    currentY = currentY + lineHeight
                    if currentY > globals.screenHeight() - 50 then
                        currentY = startY
                        currentX = currentX + columnWidth
                    end
                end
            end
            
        else
            -- else, show wand stats.
            
            local currentWandDef = board_sets[current_board_set_index].wand_def
            
            if currentWandDef then
                local statsToDraw = {
                    "id",
                    "type",
                    "max_uses",
                    "mana_max",
                    "mana_recharge_rate",
                    "cast_block_size",
                    "cast_delay",
                    "recharge_time",
                    "spread_angle",
                    "shuffle",
                    "total_card_slots",
                    "always_cast_cards"
                }
                
                local lineHeight = 22
                
                -- if nil, don't draw.
                -- if reached bottom, reset to next column
                for _, statName in ipairs(statsToDraw) do
                    local statValue = currentWandDef[statName]
                    
                    -- if it is a table, convert to string
                    if type(statValue) == "table" then
                        statValue = table.concat(statValue, ", ")
                    end
                    
                    if statValue ~= nil then
                        command_buffer.queueDrawText(layers.sprites, function(c)
                            c.text = tostring(statName) .. ": " .. tostring(statValue)
                            c.font = localization.getFont()
                            c.x = currentX
                            c.y = currentY
                            c.color = util.getColor("CYAN")
                            c.fontSize = STAT_FONT_SIZE
                        end, z_orders.card_text, layer.DrawCommandSpace.World)
                        
                        currentY = currentY + lineHeight
                        if currentY > globals.screenHeight() - 50 then
                            currentY = startY
                            currentX = currentX + columnWidth
                        end
                    end
                end
            end
        end
        
        
        --TODO: make these prettier with dynamic text later.
        
        
    end)
    
end


-- any card that goes in an action board. NOT TRIGGERS.
-- retursn the entity ID of the created card
function createNewCard(id, x, y, gameStateToApply) 
    
    local imageToUse = "trigger_card_placeholder.png"
    -- if category == "action" then
    --     imageToUse = "action_card_placeholder.png"
    -- elseif category == "trigger" then
    --     imageToUse = "trigger_card_placeholder.png"
    -- elseif category == "modifier" then
    --     imageToUse = "mod_card_placeholder.png"
    -- else
    --     log_debug("Invalid category for createNewCard:", category)
    --     return nil
    -- end
    
    local card = animation_system.createAnimatedObjectWithTransform(
        imageToUse, -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give card state tag
    add_state_tag(card, gameStateToApply or PLANNING_STATE)
    remove_default_state_tag(card)
    
    -- give a script table
    local CardType = Node:extend()
    local cardScript = CardType{}
    
    -- cardScript.isStackable = isStackable or false -- whether this card can be stacked on other cards, default true
    
    -- save category and id
    cardScript.category = category
    cardScript.cardID = id or "unknown"
    
    -- copy over card definition data if it exists
    if not id then
        log_debug("Warning: createNewCard called without id")
        
    else
        WandEngine.apply_card_properties(cardScript, WandEngine.card_defs[id] or {})
    end
    
    
    
    -- give an update table to align the card's stacks if they exist.
    -- cardScript.update = function(self, dt)
    --     local eid = self:handle()
    

        
    --     -- command_buffer.queuePushObjectTransformsToMatrix(layers.sprites, function (c)
    --     --     c.entity = eid
    --     -- end, z_orders.card_text, layer.DrawCommandSpace.World)
        
    --     -- draw debug label.
    --     command_buffer.queueDrawText(layers.sprites, function(c)
    --         local cardScript = getScriptTableFromEntityID(eid)
    --         local t = component_cache.get(eid, Transform)
    --         c.text = cardScript.test_label or "unknown"
    --         c.font = localization.getFont()
    --         c.x = t.visualX
    --         c.y = t.visualY
    --         c.color = util.getColor("BLACK")
    --         c.fontSize = 25.0
    --     end, z_orders.card_text, layer.DrawCommandSpace.World)
        
    --     -- command_buffer.queuePopMatrix(layers.sprites, function () end, z_orders.card_text, layer.DrawCommandSpace.World)
        
-- end
    
    -- attach ecs must be called after defining the callbacks.
    cardScript:attach_ecs{ create_new = false, existing_entity = card }
    
    -- add to cards table
    cards[cardScript:handle()] = cardScript
    
    -- if card update timer doens't exist, add it.
    if not timer.get_timer_and_delay("card_render_timer") then
        
        timer.run(function ()
            
            -- log_debug("Card Render Timer Tick")
            -- tracy.zoneBeginN("Card Render Timer Tick") -- just some default depth to avoid bugs
            -- bail if not shop or planning state
            if not is_state_active(PLANNING_STATE) and not is_state_active(SHOP_STATE) then
                return
            end
            
            -- loop through cards.
            for eid, cardScript in pairs(cards) do
                if eid and entity_cache.valid(eid) then
                    
                    -- bail if entity not active 
                    if not entity_cache.active(eid) then
                        goto continue
                    end
                    
                    local t = component_cache.get(eid, Transform)
                    if t then
                        
                        local colorToUse = util.getColor("RED")
                        if cardScript.type == "trigger" then
                            colorToUse = util.getColor("PURPLE")
                        end
                        -- command_buffer.queuePushObjectTransformsToMatrix(layers.sprites, function (c)
                        --     c.entity = eid
                        -- end, z_orders.card_text, layer.DrawCommandSpace.World)
                        
                        
                        -- command_buffer.queuePopMatrix(layers.sprites, function () end, z_orders.card_text, layer.DrawCommandSpace.World)
                        
                        -- this will draw in local space of the card, hopefully.
                        local zToUse = layer_order_system.getZIndex(eid) 
                        if cardScript.isBeingDragged then
                            zToUse = z_orders.top_card + 2 -- force on top if being dragged
                            log_debug("Card", eid, "is being dragged, forcing z to", zToUse, "from", layer_order_system.getZIndex(eid))
                        end
                        -- slightly above the card sprite
                        command_buffer.queueScopedTransformCompositeRender(layers.sprites, eid, function()
                            -- draw debug label.
                            command_buffer.queueDrawText(layers.sprites, function(c)
                                c.text = cardScript.test_label or "unknown"
                                c.font = localization.getFont()
                                c.x = t.visualW * 0.1
                                c.y = t.visualH * 0.1
                                c.color = colorToUse
                                c.fontSize = 20.0
                            end, zToUse, layer.DrawCommandSpace.World) -- z order on the inside here doesn't matter much.
                            
                            -- if it's controller_focused_entity, draw moving dashed outline
                            if eid == controller_focused_entity then
                                local thickness = 10
                                command_buffer.queueDrawDashedRoundedRect(layers.sprites, function(c)
                                    
                                    c.rec = Rectangle.new(
                                        -thickness / 2,
                                        -thickness / 2,
                                        t.actualW + thickness,
                                        t.actualH + thickness
                                    )
                                    c.radius    = 10
                                    c.dashLen   = 12
                                    c.gapLen    = 8
                                    c.phase     = shapeAnimationPhase
                                    c.arcSteps  = 14
                                    c.thickness = thickness
                                    c.color     = util.getColor("green")
                                    
                                end, zToUse + 1, layer.DrawCommandSpace.World)
                            end
                            
                        end, zToUse, layer.DrawCommandSpace.World)
                        
                        -- now make the most recent queued command follow the sprite render command immediately in the queue.
                        -- FIXME: not using this. doesn't seem to work anyway.
                        -- SetFollowAnchorForEntity(layers.sprites, eid)
                    end
                end
                ::continue::
            end
            -- tracy.zoneEnd()
            
        end,
        nil, -- no onComplete
        "card_render_timer" -- tag
        )
    end
    
    -- -- let's give the card a label (temporary) for testing
    -- cardScript.labelEntity = ui.definitions.getNewDynamicTextEntry(
    --     function() return (cardScript.test_label or "unknown") end,  -- initial text
    --     20.0,                                 -- font size
    --     "color=red"                       -- animation spec
    -- ).config.object
    
    -- -- make the text world space
    -- transform.set_space(cardScript.labelEntity, "world")
    
    -- -- text state
    -- add_state_tag(cardScript.labelEntity, gameStateToApply or PLANNING_STATE)
    
    -- -- set text z order
    -- layer_order_system.assignZIndexToEntity(cardScript.labelEntity, z_orders.card_text)
    
    -- -- let's anchor to top of the card
    -- transform.AssignRole(registry, cardScript.labelEntity, InheritedPropertiesType.PermanentAttachment, cardScript:handle(),
    --     InheritedPropertiesSync.Strong,
    --     InheritedPropertiesSync.Weak,
    --     InheritedPropertiesSync.Strong,
    --     InheritedPropertiesSync.Weak
    --     -- Vec2(0, -10) -- offset it a bit upwards
    -- );
    -- local roleComp = component_cache.get(cardScript.labelEntity, InheritedProperties)
    -- roleComp.flags = AlignmentFlag.VERTICAL_CENTER | AlignmentFlag.HORIZONTAL_CENTER 
    
    -- local shaderPipelineComp = registry:emplace(card, shader_pipeline.ShaderPipelineComponent)
    -- shaderPipelineComp:addPass("3d_skew")
    
    
    -- make draggable and set some callbacks in the transform system
    local nodeComp = registry:get(card, GameObject)
    local gameObjectState = nodeComp.state
    gameObjectState.hoverEnabled = true
    -- gameObjectState.triggerOnReleaseEnabled = true
    gameObjectState.collisionEnabled = true
    gameObjectState.clickEnabled = true
    gameObjectState.dragEnabled = true -- allow dragging the colonist
    
    animation_system.resizeAnimationObjectsInEntityToFit(
        card,
        cardW,   -- width
        cardH    -- height
    )
    
    -- registry:emplace(card, shader_pipeline.ShaderPipelineComponent)
    
    -- entity.set_draw_override(card, function(w, h)
    -- -- immediate render version of the same thing.
    --     command_buffer.executeDrawGradientRectRoundedCentered(layers.sprites, function(c)
    --         local survivorT = component_cache.get(card, Transform)

    --         c.cx = 0 -- self centered
    --         c.cy = 0
    --         c.width = w
    --         c.height = h
    --         c.roundness = 0.5
    --         c.segments = 8
    --         c.topLeft = util.getColor("white")
    --         c.topRight = util.getColor("gray")
    --         -- c.bottomRight = util.getColor("green")
    --         -- c.bottomLeft = util.getColor("apricot_cream")
                
    --         end, z_orders.card, layer.DrawCommandSpace.World)
        
    --     -- layer.ExecuteScale(1.0, -1.0) -- flip y axis for text rendering
    --     -- layer.ExecuteTranslate(0, -h) -- translate down by height
    --     -- let's draw some text.
    --     --TODO: fix. text flips over for some reason.
    --     -- command_buffer.executeDrawTextPro(layers.sprites, function(t)
    --     --     local cardScript = getScriptTableFromEntityID(card)
    --     --     t.text = cardScript.test_label or "unknown"
    --     --     t.font = localization.getFont()
    --     --     t.x = 0
    --     --     t.y = 0
    --     --     t.color = util.getColor("red")
    --     --     t.fontSize = 25.0
    --     -- end)
        
    --     -- layer.ExecuteScale(1.0, -1.0) -- re-flip y axis
    -- end, true) -- true disables sprite rendering

    
    -- NOTE: onRelease is called for when mouse is released ON TOP OF this node.
    -- TODO: removing card stacking behavior for now.
    -- nodeComp.methods.onRelease = function(registry, releasedOn, released)
    --     log_debug("card", released, "released on", releasedOn)
        
    --     -- when released on top of a card, get the root card of the stack if there is one, and add self to that stack 
        
        
    --     -- get the card script table
    --     local releasedCardScript = getScriptTableFromEntityID(released)
    --     local releasedOnCardScript = getScriptTableFromEntityID(releasedOn)
    --     if not releasedCardScript then return end
    --     if not releasedOnCardScript then return end
        
    --     -- check stackRootEntity in the table. Also, check that isStackable is true
    --     if not releasedCardScript.isStackable then
    --         log_debug("released card is not stackable or has no stackRootEntity")
    --         return
    --     end
        
    --     -- check that the released entity is not already a stack root
    --     if releasedCardScript.stackRootEntity and releasedCardScript.stackRootEntity == released and releasedCardScript.cardStack and #releasedCardScript.cardStack > 0 then
    --         log_debug("released card is already a stack root, not stacking on self")
    --         return
    --     end
        
    --     -- if the released card is already part of a stack, remove it first
    --     if releasedCardScript.stackRootEntity and releasedCardScript.stackRootEntity ~= releasedCardScript:handle() then
    --         local currentRootCardScript = getScriptTableFromEntityID(releasedCardScript.stackRootEntity)
    --         if currentRootCardScript then
    --             removeCardFromStack(currentRootCardScript, releasedCardScript)
    --         end
    --     end
        
    --     local rootCardScript = nil
        
    --     -- if the card released on has no root, then make it the root.
    --     if not releasedOnCardScript.stackRootEntity then
    --         rootCardScript = releasedOnCardScript
    --         releasedOnCardScript.stackRootEntity = releasedOnCardScript:handle()
    --         releasedOnCardScript.cardStack = releasedOnCardScript.cardStack or {}
    --         releasedCardScript.stackRootEntity = releasedOnCardScript:handle()
    --     else 
    --         -- if it has a root, use that instead.
    --         rootCardScript = getScriptTableFromEntityID(releasedOnCardScript.stackRootEntity)
    --     end
        
    --     if not rootCardScript then
    --         log_debug("could not find root card script")
    --         return
    --     end
        
    --     -- add self to the root entity's stack, if self is not the root
    --     if rootCardScript:handle() == released then
    --         log_debug("released card is the root entity, not stacking on self")
    --         return
    --     end
        
    --     -- make sure neither card is already in a stack and they're being dropped onto each other by accident. It's weird, but sometimes root can be dropped on a member card.
    --     if rootCardScript.cardStack then
    --         for _, e in ipairs(rootCardScript.cardStack) do
    --             if e == released then
    --                 log_debug("released card is already in the root entity's stack, not stacking again")
    --                 return
    --             end
    --         end
    --     elseif releasedCardScript.isStackChild then
    --         log_debug("released card is already a child in another stack, not stacking again")
    --         return
    --     end
    --     local result = addCardToStack(rootCardScript, releasedCardScript)
        
    --     if not result then
    --         log_debug("failed to add card to stack due to validation")
    --         -- return to previous position
    --         local t = component_cache.get(released, Transform)
    --         if t and cardScript.startingPosition then
    --             t.actualX = cardScript.startingPosition.x
    --             t.actualY = cardScript.startingPosition.y
    --         else
    --             log_debug("could not snap back to starting position, missing transform or startingPosition")
    --             -- just bump it down a bit
    --             if t then
    --                 t.actualY = t.actualY + 70
    --             end
    --         end
    --         return
    --     end
        
    --     -- after adding to the stack, update the z-orders from bottom up.
    --     local baseZ = z_orders.card
        
    --     -- give root entity the base z order
    --     layer_order_system.assignZIndexToEntity(rootCardScript:handle(), baseZ)
        
    --     -- now for every card in the stack, give it a z order above the root
    --     for i, stackedCardEid in ipairs(rootCardScript.cardStack) do
    --         if stackedCardEid and entity_cache.valid(stackedCardEid) then
    --             local stackedTransform = component_cache.get(stackedCardEid, Transform)
    --             local zi = baseZ + (i) -- root is baseZ, first stacked card is baseZ + 1, etc
    --             layer_order_system.assignZIndexToEntity(stackedCardEid, zi)
    --         end
    --     end
        
    -- end
    
    nodeComp.methods.onClick = function(registry, clickedEntity)
        if not cardScript.selected then
            cardScript.selected = false
        end
        cardScript.selected = not cardScript.selected
    end
    
    nodeComp.methods.onHover = function()
        log_debug("card onHover called for", card)
        -- get script
        local hoveredCardScript = getScriptTableFromEntityID(card)
        if not hoveredCardScript then return end
        
        local tooltip = card_tooltip_cache[hoveredCardScript.cardID]
        if not tooltip then
            return
        end
        add_state_tag(tooltip, CARD_TOOLTIP_STATE)
        activate_state(CARD_TOOLTIP_STATE)
        ui.box.AddStateTagToUIBox(tooltip, CARD_TOOLTIP_STATE)
        -- propagate_state_effects_to_ui_box(tooltip)
        
        previously_hovered_tooltip = tooltip
    end
    
    nodeComp.methods.onStopHover = function()
        log_debug("card onStopHover called for", card)
        -- get script
        local hoveredCardScript = getScriptTableFromEntityID(card)
        if not hoveredCardScript then return end
        
        -- disable all tooltips in the cache
        if previously_hovered_tooltip then
            clear_state_tags(previously_hovered_tooltip)
            ui.box.ClearStateTagsFromUIBox(previously_hovered_tooltip)
            -- propagate_state_effects_to_ui_box(previously_hovered_tooltip)
            previously_hovered_tooltip = nil
        end
    end
    
    nodeComp.methods.onDrag = function()
        
        
        -- sound
        -- playSoundEffect("effects", "card_pick_up", 1.0)
        
        cardScript.isBeingDragged = true
        
        if not boardEntityID then 
            layer_order_system.assignZIndexToEntity(card, z_orders.top_card)
            return 
        end
        
        local board = boards[boardEntityID]
        -- dunno why, board can be nil
        if not board then return end
        -- set z order to top so it can be seen
        
    
        
        log_debug("dragging card, bringing to top z:", z_orders.top_card)
        layer_order_system.assignZIndexToEntity(card, z_orders.top_card)
        
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
        
        
        cardScript.isBeingDragged = false
        
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
        
        -- -- make it transform authoritative again
        -- physics.set_sync_mode(registry, card, physics.PhysicsSyncMode.AuthoritativeTransform)
        
        
    end
    
    
    -- if x and y are given, set position
    if x and y then
        local t = component_cache.get(card, Transform)
        if t then
            t.actualX = x
            t.actualY = y
        end
    end
    
    return cardScript:handle()
end


-- utility: linear interpolation
local function lerp(a, b, t)
    return a + (b - a) * t
end

function addPulseEffectBehindCard(cardEntityID, startColor, endColor)
    if not cardEntityID or cardEntityID == entt_null or not entity_cache.valid(cardEntityID) then return end
    local cardTransform = component_cache.get(cardEntityID, Transform)
    if not cardTransform then return end
    
    -- create a new object for a pulsing rectangle that fades out in color over time, then destroys itself.
    local PulseObjectType = Node:extend()
    function PulseObjectType:update(dt)
        local addedScaleAmount = 0.3
        
        self.age = self.age + dt
        
        -- make scale & alpha based on age
        local alpha = 1.0 - Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
        local scale = 1.0 + addedScaleAmount * Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
        local e = math.min(1.0, self.age / self.lifetime)
        
        local fromColor = startColor or util.getColor("yellow")
        local toColor   = endColor or util.getColor("black")
        
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
            local t = component_cache.get(cardEntityID, Transform)
            c.x = t.actualX + t.actualW * 0.5
            c.y = t.actualY + t.actualH * 0.5
            c.w = t.actualW * scale
            c.h = t.actualH * scale
            c.rx = 15
            c.ry = 15
            c.color = Col(r, g, b, a)
            
        end, z_orders.card - 1, layer.DrawCommandSpace.World)
    end
    local pulseObject = PulseObjectType{}
    pulseObject.lifetime = 0.3
    pulseObject.age = 0.0
    
    pulseObject
        :attach_ecs{ create_new = true }
        :destroy_when(function(self, eid) return self.age >= self.lifetime end)
end

function slowTime(duration, targetTimeScale)
    main_loop.data.timescale = targetTimeScale or 0.2 -- slow to 20%, then over X seconds, tween back to 1.0
    timer.tween_scalar(
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
        local transform = component_cache.get(survivorEntity, Transform)
        
        -- create a note that draws a red circle where the player was and removes itself after 0.1 second
        local DeathCircleType = Node:extend()local playerX = transform.actualX + transform.actualW * 0.5
        local playerY = transform.actualY + transform.actualH * 0.5
        local playerW = transform.actualW
        local playerH = transform.actualH
        local playerX = transform.actualX + transform.actualW * 0.5
        local playerY = transform.actualY + transform.actualH * 0.5
        local playerW = transform.actualW
        local playerH = transform.actualH
        function DeathCircleType:update(dt)
            self.age = self.age + dt
            command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
                local t = component_cache.get(survivorEntity, Transform)
                c.x = playerX
                c.y = playerY
                c.rx = playerW * 0.5 * (1.0 + self.age * 5.0)
                c.ry = playerH * 0.5 * (1.0 + self.age * 5.0)
                c.color = util.getColor("red")
            end, z_orders.player_vfx, layer.DrawCommandSpace.World)
        end
        local deathCircle = DeathCircleType{}
        deathCircle.lifetime = 0.1
        deathCircle.age = 0.0
        
        
        deathCircle:attach_ecs{ create_new = true }
        deathCircle:destroy_when(function(self, eid) return self.age >= self.lifetime end)
        
        spawnCircularBurstParticles(
            transform.visualX + transform.actualW * 0.5,
            transform.visualY + transform.actualH * 0.5,
            8, -- count
            0.9, -- seconds
            util.getColor("blue"), -- start color
            util.getColor("red"), -- end color
            "outCubic", -- from util.easing
            "world" -- screen space
        )
        
        registry:destroy(survivorEntity)
    end)
    
    
end

function spawnRandomBullet() 
    
    local bulletSize = 10
    
    local playerTransform = component_cache.get(survivorEntity, Transform)
    
    local BulletType = Node:extend() -- define the type before instantiating
    function BulletType:update(dt)
        self.age = self.age + dt
        
        -- draw a circle
        command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
            local t = component_cache.get(self:handle(), Transform)
            c.x = t.actualX + t.actualW * 0.5
            c.y = t.actualY + t.actualH * 0.5
            c.rx = t.actualW * 0.5
            c.ry = t.actualH * 0.5
            c.color = util.getColor("red")
        end, z_orders.projectiles, layer.DrawCommandSpace.World)
    end
    
    local node = BulletType{}
    node.lifetime = 2.0
    node.age = 0.0
    
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
    local FireMarkType = Node:extend()
    function FireMarkType:update(dt)
        self.age = self.age + dt
        -- draw a small flash at the bullet position
        command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
            local t = component_cache.get(node:handle(), Transform)
            c.x = t.actualX + t.actualW * 0.5
            c.y = t.actualY + t.actualH * 0.5
            c.rx = t.actualW * 1.5
            c.ry = t.actualH * 1.5
            c.color = util.getColor("yellow")
        end, z_orders.projectiles, layer.DrawCommandSpace.World)
    end
    local fireMarkNode = FireMarkType{}
    fireMarkNode.lifetime = 0.1
    fireMarkNode.age = 0.0
    
    fireMarkNode:attach_ecs{ create_new = true }
    fireMarkNode:destroy_when(function(self, eid) return self.age >= self.lifetime end)
end

function spawnRandomTrapHazard()
    
    local playerTransform = component_cache.get(survivorEntity, Transform)
    
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
    local hazardTransform = component_cache.get(hazard, Transform)
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
    
    local playerTransform = component_cache.get(survivorEntity, Transform)
    
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
        
        local startColor = util.getColor("white")
        local endColor = util.getColor("red")
        
        local t = component_cache.get(survivorEntity, Transform)
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
    if not cardEntityID or cardEntityID == entt_null or not entity_cache.valid(cardEntityID) then return end
    local cardScript = getScriptTableFromEntityID(cardEntityID)
    if not cardScript then return end
    
    local playerScript = getScriptTableFromEntityID(survivorEntity)
    local playerTransform = component_cache.get(survivorEntity, Transform)
    
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
    if not boardEntityID or boardEntityID == entt_null or not entity_cache.valid(boardEntityID) then return end
    local board = boards[boardEntityID]
    if not board or not board.cards or #board.cards == 0 then return end
    
    -- for now, just log the card ids in order
    local cooldownBetweenActions = 0.5 -- seconds
    local runningDelay = 0.3
    local pulseColorRampTable = palette.ramp_quantized("blue", "white", #board.cards)
    local index = 1
    for _, cardEid in ipairs(board.cards) do
        if cardEid and cardEid ~= entt_null and entity_cache.valid(cardEid) then
            local cardScript = getScriptTableFromEntityID(cardEid)
            if cardScript then
                
                timer.after(
                    runningDelay,
                    function()
                        -- log_debug("Firing action card:", cardScript.cardID)
                        
                        -- pulse and jiggle
                        local cardTransform = component_cache.get(cardEid, Transform)
                        if cardTransform then
                            cardTransform.visualS = 2.0
                            addPulseEffectBehindCard(cardEid, pulseColorRampTable[index], util.getColor("black"))    
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
            if not trigger_board_id or trigger_board_id == entt_null or not entity_cache.valid(trigger_board_id) then return end
            local triggerBoard = boards[trigger_board_id]
            if not triggerBoard or not triggerBoard.cards or #triggerBoard.cards == 0 then return end
            
            local triggerCardEid = triggerBoard.cards[1]
            if not triggerCardEid or triggerCardEid == entt_null or not entity_cache.valid(triggerCardEid) then return end
            local triggerCardScript = getScriptTableFromEntityID(triggerCardEid)
            if not triggerCardScript then return end
            
            -- pulse animation
            local cardTransform = component_cache.get(triggerCardEid, Transform)
            cardTransform.visualS = 1.5
            
            -- play sound
            playSoundEffect("effects", "trigger_activate", 1.0)
            
            addPulseEffectBehindCard(triggerCardEid, util.getColor("yellow"), util.getColor("black"))
            
            -- start chain of action cards in the action board
            if not action_board_id or action_board_id == entt_null or not entity_cache.valid(action_board_id) then return end
            fireActionCardsInBoard(action_board_id) 
        end,
        0, -- infinite repetitions
        false, -- don't start immediately
        nil, -- no after callback
        timer_name -- name of the timer (so we can check if it exists later
    )
end

-- generic weapon def, creatures must have this to deal damage.

local basic_monster_weapon = {
    id = 'basic_monster_weapon',
    slot = 'sword1',
    -- requires = { attribute = 'cunning', value = 12, mode = 'sole' },
    mods = {
      { stat = 'weapon_min',      base = 6 },
      { stat = 'weapon_max',      base = 10 },
    --   { stat = 'fire_modifier_pct', add_pct = 15 },
    },
    -- conversions = { { from = 'physical', to = 'fire', pct = 25 } },
    -- procs = {
    --   {
    --     trigger = 'OnBasicAttack',
    --     chance = 70,
    --     effects = Effects.deal_damage {
    --       components = { { type = 'fire', amount = 40 } }, tags = { ability = true }
    --     },
    --   },
    -- },
    -- granted_spells = { 'Fireball' },
  }
function setUpLogicTimers()
    
    -- handler for bumping into enemy. just get the enemy's combat script and let the enemy deal damage to the player.
    local function on_bump_enemy_handler(enemyEntityID)
        
        log_debug("on_bump_enemy_handler called with enemy entity:", enemyEntityID)
        
        if not enemyEntityID or enemyEntityID == entt_null or not entity_cache.valid(enemyEntityID) then return end
        
        local enemyScript = getScriptTableFromEntityID(enemyEntityID)
        if not enemyScript then return end
        
        -- for now just deal generic damage to the player. 
        -- TODO: expand with other enemies who deal different types of damage.
        
        local playerScript = getScriptTableFromEntityID(survivorEntity)
        if not playerScript then return end
        
        local enemyCombatTable = enemyScript.combatTable
        if not enemyCombatTable then return end
        
        local playerCombatTable = playerScript.combatTable
        if not playerCombatTable then return end
        
        -- 1. Basic attack (vanilla weapon hit)
        CombatSystem.Game.Effects.deal_damage { weapon = true, scale_pct = 100 } (combat_context, enemyCombatTable, playerCombatTable)
        
    end
    
    -- check the trigger board 
    timer.run(
        function()
            
            -- bail if not in action state
            if not is_state_active(ACTION_STATE) then return end
            
            for triggerBoardID, actionBoardID in pairs(trigger_board_id_to_action_board_id) do
                if triggerBoardID and triggerBoardID ~= entt_null and entity_cache.valid(triggerBoardID) then
                    local triggerBoard = boards[triggerBoardID]
                    -- log_debug("checking trigger board:", triggerBoardID, "contains", triggerBoard and triggerBoard.cards and #triggerBoard.cards or 0, "cards")
                    if triggerBoard and triggerBoard.cards and #triggerBoard.cards > 0 then
                        local triggerCardEid = triggerBoard.cards[1]
                        if triggerCardEid and triggerCardEid ~= entt_null and entity_cache.valid(triggerCardEid) then
                            local triggerCardScript = getScriptTableFromEntityID(triggerCardEid)
                            if triggerCardScript and triggerCardScript.cardID == "every_N_seconds" then
                                local timerName = "every_N_seconds_trigger_" .. tostring(triggerBoardID)
                                if not timer.get_timer_and_delay(timerName) then
                                    startTriggerNSecondsTimer(triggerBoardID, actionBoardID, timerName)
                                end   
                                    
                            end
                            
                            -- bump enemy. if signal not registered, register it.
                            if triggerCardScript and triggerCardScript.card_id == "on_bump_enemy" then
                               
                                
                                if signal.exists("on_bump_enemy") == false then
                                    signal.register(
                                        "on_bump_enemy",
                                        on_bump_enemy_handler
                                    )
                                end
                                
                            end
                            
                        end
                    end
                end
            end
            
        end
    )
end

-- modular creation of trigger + action board sets
function createTriggerActionBoardSet(x, y, triggerWidth, actionWidth, height, padding)
    local set = {}

    -- Trigger board
    local triggerBoardID = createNewBoard(x, y, triggerWidth, height)
    local triggerBoard   = boards[triggerBoardID]
    triggerBoard.noDashedBorder = true
    triggerBoard.borderColor = util.getColor("cyan")

    triggerBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.trigger_area") end,
        20.0, "color=cyan"
    ).config.object

    transform.set_space(triggerBoard.textEntity, "world")
    
    -- give state tags to boards, remove default state tags
    add_state_tag(triggerBoardID, PLANNING_STATE)
    remove_default_state_tag(triggerBoardID)
    add_state_tag(triggerBoard.textEntity, PLANNING_STATE)
    remove_default_state_tag(triggerBoard.textEntity)
    
    transform.AssignRole(registry, triggerBoard.textEntity,
        InheritedPropertiesType.PermanentAttachment, triggerBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10)
    )
    component_cache.get(triggerBoard.textEntity, InheritedProperties).flags = AlignmentFlag.VERTICAL_TOP

    -- Action board
    local actionBoardX = x + triggerWidth + padding
    local actionBoardID = createNewBoard(actionBoardX, y, actionWidth, height)
    local actionBoard   = boards[actionBoardID]
    actionBoard.noDashedBorder = true
    actionBoard.borderColor = util.getColor("apricot_cream")

    actionBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.action_mod_area") end,
        20.0, "color=apricot_cream"
    ).config.object

    transform.set_space(actionBoard.textEntity, "world")
    
    -- give state tags to boards, remove default state tags
    add_state_tag(actionBoardID, PLANNING_STATE)
    remove_default_state_tag(actionBoardID)
    add_state_tag(actionBoard.textEntity, PLANNING_STATE)
    remove_default_state_tag(actionBoard.textEntity)
    
    transform.AssignRole(registry, actionBoard.textEntity,
        InheritedPropertiesType.PermanentAttachment, actionBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10)
    )
    component_cache.get(actionBoard.textEntity, InheritedProperties).flags = AlignmentFlag.VERTICAL_TOP

    trigger_board_id_to_action_board_id[triggerBoardID] = actionBoardID

    -- Store as a set
    set.trigger_board_id = triggerBoardID
    set.action_board_id  = actionBoardID
    set.text_entities    = { triggerBoard.textEntity, actionBoard.textEntity }
    
    -- also add to boards
    boards[triggerBoardID] = triggerBoard
    boards[actionBoardID]  = actionBoard

    table.insert(board_sets, set)
    return set
end


-- takes a given entity management state tag and applies it to all boards and cards in the board set
function applyStateToBoardSet(boardSet, stateTagToApply)
    if not boardSet then return end
    
    -- for each board in the set, apply the state to it and its cards.
    
    if boardSet.trigger_board_id then
        local triggerBoard = boards[boardSet.trigger_board_id]
        if triggerBoard then
            -- apply to cards
            for _, cardEid in ipairs(triggerBoard.cards) do
                add_state_tag(cardEid, stateTagToApply)
                remove_state_tag(cardEid, PLANNING_STATE)
            end
            -- apply to board
            add_state_tag(triggerBoard:handle(), stateTagToApply)
            remove_state_tag(triggerBoard:handle(), PLANNING_STATE)
        end
    end
    
    if boardSet.action_board_id then
        local actionBoard = boards[boardSet.action_board_id]
        if actionBoard then
            -- apply to cards
            for _, cardEid in ipairs(actionBoard.cards) do
                add_state_tag(cardEid, stateTagToApply)
                remove_state_tag(cardEid, PLANNING_STATE)
            end
            -- apply to board
            add_state_tag(actionBoard:handle(), stateTagToApply)
            remove_state_tag(actionBoard:handle(), PLANNING_STATE)
        end
    end
end

-- methods to toggle visibility of a board set
function toggleBoardSetVisibility(boardSet, visible)
    if not boardSet then return end
    
    -- we'll create a new state "boardSet" + id to manage visibility
    local id = "boardSet_" .. tostring(boardSet.trigger_board_id) .. "_" .. tostring(boardSet.action_board_id)
    
    -- we'll add it to both boards and their cards
    applyStateToBoardSet(boardSet, id)
    if visible then
        activate_state(id)
    else
        deactivate_state(id)
    end
end


function makeWandTooltip(wand_def)
    
    if not wand_def then
        wand_def = WandEngine.wand_defs[1]
    end
    
    local text = "[id](background=red;color=pink) [" .. wand_def.id .. "](color=pink)\n" ..
    "[type](background=gray;color=green) [" .. wand_def.type .. "](color=pink)\n" ..
    "[cast block size](background=gray;color=green) [" .. wand_def.cast_block_size .. "](color=pink)\n" ..
    "[cast delay](background=gray;color=green) [" .. (wand_def.cast_delay or "NONE") .. "](color=pink)\n" ..
    "[recharge](background=gray;color=green) [" .. wand_def.recharge_time .. "](color=pink)\n" ..
    "[spread](background=gray;color=green) [" .. (wand_def.spread_angle or "none") .. "](color=pink)\n" ..
    "[shuffle](background=gray;color=green) [" .. (wand_def.shuffle and "on" or "off") .. "](color=pink)\n" ..
    "[total slots](background=gray;color=green) [" .. (wand_def.total_card_slots or "N/A") .. "](color=pink)\n" ..
    "[always casts](background=gray;color=green) [" .. table.concat(wand_def.always_cast_cards, ", ") .. "](color=pink)" 
    
    local textDef = ui.definitions.getTextFromString(text)
    
    local v = dsl.vbox{
        config = { align = AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_CENTER,
                   color = "blue" },
        children = { textDef }
    }
    
    local root = dsl.root{ 
        config = {
            color = "purple",
            align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER,
        },
        children = { v } }
    
    local boxID = dsl.spawn({x=200, y=200}, root)
    
    ui.box.RenewAlignment(registry, boxID)
    
    ui.box.AssignStateTagsToUIBox(boxID, PLANNING_STATE)
    remove_default_state_tag(boxID)
    
    return boxID
end

function makeCardTooltip(card_def)
    if not card_def then
        card_def = CardTemplates.ACTION_BASIC_PROJECTILE
    end

    local text =
    "[id](background=red;color=pink) [" .. (card_def.id or "N/A") .. "](color=pink)\n" ..
    "[type](background=gray;color=green) [" .. (card_def.type or "N/A") .. "](color=pink)\n" ..
    "[max uses](background=gray;color=green) [" .. (card_def.max_uses or "N/A") .. "](color=pink)\n" ..
    "[mana cost](background=gray;color=green) [" .. (card_def.mana_cost or "N/A") .. "](color=pink)\n" ..
    "[damage](background=gray;color=green) [" .. (card_def.damage or "N/A") .. "](color=pink)\n" ..
    "[damage type](background=gray;color=green) [" .. (card_def.damage_type or "N/A") .. "](color=pink)\n" ..
    "[radius of effect](background=gray;color=green) [" .. (card_def.radius_of_effect or "N/A") .. "](color=pink)\n" ..
    "[spread angle](background=gray;color=green) [" .. (card_def.spread_angle or "N/A") .. "](color=pink)\n" ..
    "[projectile speed](background=gray;color=green) [" .. (card_def.projectile_speed or "N/A") .. "](color=pink)\n" ..
    "[lifetime](background=gray;color=green) [" .. (card_def.lifetime or "N/A") .. "](color=pink)\n" ..
    "[cast delay](background=gray;color=green) [" .. (card_def.cast_delay or "N/A") .. "](color=pink)\n" ..
    "[recharge](background=gray;color=green) [" .. (card_def.recharge_time or "N/A") .. "](color=pink)\n" ..
    "[spread modifier](background=gray;color=green) [" .. (card_def.spread_modifier or "N/A") .. "](color=pink)\n" ..
    "[speed modifier](background=gray;color=green) [" .. (card_def.speed_modifier or "N/A") .. "](color=pink)\n" ..
    "[lifetime modifier](background=gray;color=green) [" .. (card_def.lifetime_modifier or "N/A") .. "](color=pink)\n" ..
    "[crit chance mod](background=gray;color=green) [" .. (card_def.critical_hit_chance_modifier or "N/A") .. "](color=pink)\n" ..
    "[weight](background=gray;color=green) [" .. (card_def.weight or "N/A") .. "](color=pink)"

    local textDef = ui.definitions.getTextFromString(text)

    local v = dsl.vbox{
        config = {
            align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER,
            color = "blue"
        },
        children = { textDef }
    }

    local root = dsl.root{
        config = {
            color = "purple",
            align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER
        },
        children = { v }
    }

    local boxID = dsl.spawn({ x = 200, y = 200 }, root)

    ui.box.RenewAlignment(registry, boxID)
    -- ui.box.AssignStateTagsToUIBox(boxID, PLANNING_STATE)
    ui.box.ClearStateTagsFromUIBox(boxID) -- remove all state tags from sub entities and box
    -- remove_default_state_tag(boxID)

    return boxID
end



-- initialize the game area for planning phase, where you combine cards and stuff.
function initPlanningPhase()
    
    
    

    
    
    -- activate planning state to draw/update planning entities
    activate_state(PLANNING_STATE)
    
    -- set up timer to render tooltips
    -- setUpCardAndWandStatDisplay()
    
    -- let's bind d-pad input to switch between cards, and A to select.
    input.bind("controller-navigation-planning-select", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN, -- A button
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-up", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP, -- D-pad up
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-down", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN, -- D-pad down
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-left", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_LEFT, -- D-pad left
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    
    input.bind("controller-navigation-planning-right", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_RIGHT, -- D-pad right
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    
    input.bind("controller-navigation-planning-right-bumper", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_RIGHT_TRIGGER_1, -- D-pad right
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-left-bumper", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_TRIGGER_1, -- D-pad right
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-left-trigger", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_TRIGGER_2, -- D-pad right
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-right-trigger", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_RIGHT_TRIGGER_2, -- D-pad right
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "planning-phase" -- we'll use this context for planning phase only
    })
    
    -- let's set up the nav group so the controller can navigate the cards.
    controller_nav.create_layer("planning-input-layer")
    controller_nav.create_group("planning-phase")
    controller_nav.add_group_to_layer("planning-input-layer", "planning-phase")

    controller_nav.set_group_callbacks("planning-phase", {
        on_focus = function(e) 
            
            -- sound
            playSoundEffect("effects", "card_focus", 0.9 + math.random() * 0.2)
            
            -- update to move cursor to entity
            input.updateCursorFocus()
            
            -- jiggle
            transform.InjectDynamicMotionDefault(e)
            
            controller_focused_entity = e
            
            -- get card script, set selected
            local cardScript = getScriptTableFromEntityID(e)
            if cardScript then
                cardScript.selected = true
            end
        end,
        on_unfocus = function(e) 
            -- unselect card
            local cardScript = getScriptTableFromEntityID(e)
            if cardScript then
                cardScript.selected = false
            end
        end,
        on_select = function(e) 
            
            playSoundEffect("effects", "card_click", 0.9 + math.random() * 0.2)
            
            transform.InjectDynamicMotionDefault(e)
            
            local script = getScriptTableFromEntityID(e)
            
            -- first check if the card belongs to one of the boards in the current board set.
            if not board_sets or #board_sets == 0 then return end
            
            if not current_board_set_index then return end
            local currentSet = board_sets[current_board_set_index]
            if not currentSet then return end
            
            local belongsToCurrentSet = false
            -- check trigger board
            if script.currentBoardEntity == currentSet.trigger_board_id then
                belongsToCurrentSet = true
            end
            -- check action board
            if script.currentBoardEntity == currentSet.action_board_id then
                belongsToCurrentSet = true
            end
            
            
            -- is it a trigger card?
            
            if script and script.type == "trigger" then
                
                -- add to current trigger board, if not already on it. otherwise send it back to trigger inventory.
                if board_sets and #board_sets > 0 then
                    
                    
                    local currentSet = board_sets[current_board_set_index]
                    
                    
                    if currentSet and currentSet.trigger_board_id then
                        
                        -- if already on trigger board, send back to inventory
                        if belongsToCurrentSet and script.currentBoardEntity == currentSet.trigger_board_id then
                            -- already on trigger board, send back to inventory
                            removeCardFromBoard(e, script.currentBoardEntity)
                            addCardToBoard(e, trigger_inventory_board_id)
                            playSoundEffect("effects", "card_pick_up", 0.9 + math.random() * 0.2)
                            script.selected = false
                            return
                        end
                        
                        -- otherwise add to trigger board
                        removeCardFromBoard(e, script.currentBoardEntity) -- remove from any board it's currently on
                        addCardToBoard(e, currentSet.trigger_board_id)
                        playSoundEffect("effects", "card_put_down_3", 0.9 + math.random() * 0.2)
                    end
                end
            else 
                -- add to current action board
                if board_sets and #board_sets > 0 then
                    local currentSet = board_sets[current_board_set_index]
                    if currentSet and currentSet.action_board_id then
                        
                        -- if already on action board, send back to inventory
                        if belongsToCurrentSet and script.currentBoardEntity == currentSet.action_board_id then
                            -- already on action board, send back to inventory
                            removeCardFromBoard(e, script.currentBoardEntity)
                            addCardToBoard(e, inventory_board_id)
                            playSoundEffect("effects", "card_pick_up", 0.9 + math.random() * 0.2)
                            -- set selected to false
                            script.selected = false
                            return
                        end
                        
                        -- otherwise add to action board up top 
                        removeCardFromBoard(e, script.currentBoardEntity) -- remove from any board it's currently on
                        addCardToBoard(e, currentSet.action_board_id)
                        playSoundEffect("effects", "card_put_down_3", 0.9 + math.random() * 0.2)
                    end 
                end
            end
        end,
    })
    controller_nav.set_group_mode("planning-phase", "spatial")
    controller_nav.set_wrap("planning-phase", true)
    controller_nav.ud:set_active_layer("planning-input-layer")

    -- let's set input context to planning phase when in planning state
    
    
    -- make an input timer that runs onlyi in planning phase to handle controller navigation
    timer.run(
        function()
            -- only in planning state
            if not entity_cache.state_active(PLANNING_STATE) then return end
            
            local leftTriggerDown = input.action_down("controller-navigation-planning-left-trigger")
            local rightTriggerDown = input.action_down("controller-navigation-planning-right-trigger")
            
            if input.action_down("controller-navigation-planning-up") then
                log_debug("Planning phase nav: up")
                controller_nav.navigate("planning-phase", "U")
            elseif input.action_down("controller-navigation-planning-down") then
                log_debug("Planning phase nav: down")
                controller_nav.navigate("planning-phase", "D")
            elseif input.action_down("controller-navigation-planning-left") then
                if (leftTriggerDown) then
                    log_debug("Planning phase nav: trigger L is down, swapping left")
                    -- get the board of the current focused entity
                    local selectedCardScript = getScriptTableFromEntityID(controller_focused_entity)
                    local boardScript = getScriptTableFromEntityID(selectedCardScript.currentBoardEntity)
                    boardScript:swapCardWithNeighbor(controller_focused_entity, -1)
                else
                    log_debug("Planning phase nav: left")
                    controller_nav.navigate("planning-phase", "L")
                end
                
            elseif input.action_down("controller-navigation-planning-right") then
                
                if (leftTriggerDown) then
                    log_debug("Planning phase nav: trigger L is down, swapping right")
                    
                    -- get the board of the current focused entity
                    local selectedCardScript = getScriptTableFromEntityID(controller_focused_entity)
                    local boardScript = getScriptTableFromEntityID(selectedCardScript.currentBoardEntity)
                    boardScript:swapCardWithNeighbor(controller_focused_entity, 1)
                else
                    log_debug("Planning phase nav: right")
                    controller_nav.navigate("planning-phase", "R")
                end
            elseif input.action_down("controller-navigation-planning-select") then
                log_debug("Planning phase nav: select")
                controller_nav.select_current("planning-phase")
            elseif input.action_down("controller-navigation-planning-right-bumper") then
                log_debug("Planning phase nav: next board set")
                -- next board set
                cycleBoardSets(1)
            elseif input.action_down("controller-navigation-planning-left-bumper") then
                log_debug("Planning phase nav: previous board set")
                -- previous board set
                cycleBoardSets(-1)
            end
        end
    )
    
    
    
    -- set default card size based on screen size
    cardW = globals.screenWidth() * 0.10
    cardH = cardW * (64 / 48) -- default card aspect ratio is 48:64
    
    -- make entire roster of cards
    local catalog = WandEngine.card_defs
    
    local cardsToChange = { }
    
    for cardID, cardDef in pairs(catalog) do
        local card = createNewCard(cardID, 4000, 4000, PLANNING_STATE) -- offscreen for now
        
        table.insert(cardsToChange, card)
        
        -- add to navigation group as well.
        controller_nav.ud:add_entity("planning-phase", card)
        
        controller_nav.validate() -- validate the nav system after setting up bindings and layers.
        controller_nav.debug_print_state() -- print state for debugging.
        controller_nav.focus_entity(card) -- focus the newly created card.
        
    end
    
    
    -- deal the cards out with dely & sound.
    for _, card in ipairs(cardsToChange) do
        if card and card ~= entt_null and entity_cache.valid(card) then
            -- set the location of each card to an offscreen pos
            local t = component_cache.get(card, Transform)
            if t then
                t.actualX = -500
                t.actualY = -500
                t.visualX = t.actualX
                t.visualY = t.actualY
            end
        end
    end
    
    local cardDelay = 4.0 -- start X seconds after game init
    for _, card in ipairs(cardsToChange) do
        if card and card ~= entt_null and entity_cache.valid(card) then
            timer.after(cardDelay, function()
                local t = component_cache.get(card, Transform)
                
                local inventoryBoardTransform = component_cache.get(inventory_board_id, Transform)
                
                -- slide it into place at x, y (offset random)
                local targetX = globals.screenWidth() * 0.8
                local targetY = inventoryBoardTransform.actualY
                t.actualX = targetX
                t.actualY = targetY
                t.visualY = targetY - 100 -- start offscreen slightly above wanted pos
                t.visualX = globals.screenWidth() * 1.2 -- start offscreen right
                
                -- play sound with randomized pitch
                playSoundEffect("effects", "card_deal", 0.7 + math.random() * 0.3)
                
                -- add to board
                addCardToBoard(card, inventory_board_id)
                -- give physics
                -- local info = { shape = "rectangle", tag = "card", sensor = false, density = 1.0, inflate_px = 15 } -- inflate so cards will not stick to each other when dealt.
                -- physics.create_physics_for_transform(registry,
                --     physics_manager_instance, -- global instance
                --     card, -- entity id
                --     "world", -- physics world identifier
                --     info
                -- )
                
                -- collision mask so cards collide with each other
                -- physics.enable_collision_between_many(PhysicsManager.get_world("world"), "card", {"card"})
                -- physics.update_collision_masks_for(PhysicsManager.get_world("world"), "card", {"card"})
                
                
                -- physics.use_transform_fixed_rotation(registry, card)
                    
            end)
            cardDelay = cardDelay + 0.1
        end
    end
    
    -- for _, card in ipairs(cardsToChange) do
    --     if card and card ~= entt_null and entity_cache.valid(card) then
    --         -- remove physics after a few seconds
    --         timer.after(7.0, function()
    --             if card and card ~= entt_null and entity_cache.valid(card) then
    --                 -- physics.clear_all_shapes(PhysicsManager.get_world("world"), card)
                    
                        
    --                 -- make transform autoritative
    --                 physics.set_sync_mode(registry, card, physics.PhysicsSyncMode.AuthoritativeTransform)
                    
    --                 -- get card transform, set rotation to 0
    --                 local t = component_cache.get(card, Transform)
    --                 if t then
    --                     t.actualR = 0
    --                 end
                    
    --                 -- remove phyics entirely.
    --                 physics.remove_physics(PhysicsManager.get_world("world"), card, true)
    --             end
    --         end)
    --     end
    -- end
    
    
    local testTable = getScriptTableFromEntityID(card1)
    
    boardHeight = globals.screenHeight() / 5
    local actionBoardWidth = globals.screenWidth() * 0.7
    local triggerBoardWidth = globals.screenWidth() * 0.2
    
    boardPadding = globals.screenWidth() * 0.1 / 3
    
    local runningYValue = boardPadding
    local leftAlignValueTriggerBoardX = boardPadding
    local leftAlignValueActionBoardX = leftAlignValueTriggerBoardX + triggerBoardWidth + boardPadding
    local leftAlignValueRemoveBoardX = leftAlignValueActionBoardX + actionBoardWidth + boardPadding

    
    -- board draw function, for all baords
    timer.run(function()
        -- tracy.zoneBeginN("Planning Phase Board Draw") -- just some default depth to avoid bugs
        
        -- log_debug("Drawing board borders")
        
        if is_state_active(PLANNING_STATE) then
            
            -- draw which board set is selected (text), below the trigger board.
            local text = tostring(current_board_set_index) .. " of " .. tostring(#board_sets)
            command_buffer.queueDrawText(layers.sprites, function(c)
                c.text = text
                c.x = leftAlignValueTriggerBoardX
                c.y = boardPadding + boardHeight + 30
                c.fontSize = 30
                c.font = localization.getFont()
                c.color = util.getColor("purple")
            end, z_orders.card_text, layer.DrawCommandSpace.World)
            
        end
        
        
        
        for key, boardScript in pairs(boards) do
            local self = boardScript
            local eid = self:handle()
            if not (eid and entity_cache.valid(eid) and entity_cache.active(eid)) then
                goto continue
            end

            -- local draw = true
            -- if type(self.gameStates) == "table" and next(self.gameStates) ~= nil then
            --     draw = false
            --     for _, state in pairs(self.gameStates) do
            --         if is_state_active(state) then
            --             draw = true
            --             break
            --         end
            --     end
            -- else
            --     -- draw only in planning state by default
            --     if not is_state_active(PLANNING_STATE) then
            --         draw = false
            --     end
            -- end

            -- if draw then
                
                local area = component_cache.get(eid, Transform)
                
                
                
                if self.noDashedBorder then
                    command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                        c.x = area.actualX + area.actualW * 0.5
                        c.y = area.actualY + area.actualH * 0.5
                        c.w = math.max(0, area.actualW)
                        c.h = math.max(0, area.actualH)
                        c.rx = 10
                        c.ry = 10
                        c.color     = self.borderColor or util.getColor("yellow")
                        c.lineWidth = 5
                    end, z_orders.board, layer.DrawCommandSpace.World)
                    goto continue
                end
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
                    c.color     = self.borderColor or util.getColor("yellow")
                end, z_orders.board, layer.DrawCommandSpace.World)
            -- end

            ::continue::
        end
        -- tracy.zoneEnd()
    end)
    
-- -------------------------------------------------------------------------- --
--                   create a set of trigger + action board                   --
-- -------------------------------------------------------------------------- -

    local set = createTriggerActionBoardSet(
        leftAlignValueTriggerBoardX,
        runningYValue,
        triggerBoardWidth,
        actionBoardWidth,
        boardHeight,
        boardPadding
    )
    
    -- let's make a total of 3 sets and disable the last two for now.
    local set2 = createTriggerActionBoardSet(
        leftAlignValueTriggerBoardX,
        runningYValue,
        triggerBoardWidth,
        actionBoardWidth,
        boardHeight,
        boardPadding
    )
    
    local set3 = createTriggerActionBoardSet(
        leftAlignValueTriggerBoardX,
        runningYValue,
        triggerBoardWidth,
        actionBoardWidth,
        boardHeight,
        boardPadding
    )
    
    toggleBoardSetVisibility(set2, false)
    toggleBoardSetVisibility(set3, false)
    
    runningYValue = runningYValue + boardHeight + boardPadding

    -- let's create a card board
    
    
    -- make a trigger card and add it to the trigger board.
    -- local triggerCard = createNewCard("TEST_TRIGGER_EVERY_N_SECONDS", 4000, 4000, PLANNING_STATE) -- offscreen for now
    
-- -------------------------------------------------------------------------- --
--       make a large board at bottom that will serve as the inventory, with a trigger inventory on the left.       --
-- -------------------------------------------------------------------------- 

    local triggerInventoryWidth  = globals.screenWidth() * 0.2
    local triggerInventoryHeight = (globals.screenHeight() - runningYValue) * 0.4

    local inventoryBoardWidth  = globals.screenWidth() * 0.65
    local inventoryBoardHeight = triggerInventoryHeight
    local boardPadding         = boardPadding or 20  -- just in case

    -- Center both panels as a group
    local totalWidth = triggerInventoryWidth + boardPadding + inventoryBoardWidth
    local offsetX = (globals.screenWidth() - totalWidth) / 2

    -- Left (trigger) panel
    local triggerInventoryX = offsetX
    local triggerInventoryY = runningYValue + boardPadding * 2

    -- Right (inventory) panel
    local inventoryBoardX = triggerInventoryX + triggerInventoryWidth + boardPadding
    local inventoryBoardY = triggerInventoryY

    -- Create
    local inventoryBoardID = createNewBoard(inventoryBoardX, inventoryBoardY, inventoryBoardWidth, inventoryBoardHeight)
    local inventoryBoard = boards[inventoryBoardID]
    inventoryBoard.borderColor = util.getColor("white")
    inventory_board_id = inventoryBoardID

    
    -- give a text label above the board
    inventoryBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.inventory_area") end,  -- initial text
        20.0,                                 -- font size
        "color=apricot_cream"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(inventoryBoard.textEntity, "world")
    -- state tags 
    add_state_tag(inventoryBoard.textEntity, PLANNING_STATE)
    add_state_tag(inventoryBoardID, PLANNING_STATE)
    -- remove default state tags
    remove_default_state_tag(inventoryBoard.textEntity)
    remove_default_state_tag(inventoryBoardID)
    
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, inventoryBoard.textEntity, InheritedPropertiesType.PermanentAttachment, inventoryBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = component_cache.get(inventoryBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP 
    
    -- map
    inventory_board_id = inventoryBoardID
    
    
-- -------------------------------------------------------------------------- --
--       make a separate trigger inventory on the left of the inventory.      --
-- -------------------------------------------------------------------------- 
    
    local triggerInventoryBoardID = createNewBoard(triggerInventoryX, triggerInventoryY, triggerInventoryWidth, triggerInventoryHeight)
    local triggerInventoryBoard = boards[triggerInventoryBoardID]
    triggerInventoryBoard.borderColor = util.getColor("cyan")
    trigger_inventory_board_id = triggerInventoryBoardID -- save in global
    
    -- give a text label above the board
    triggerInventoryBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.trigger_inventory_area") end,  -- initial text
        20.0,                                 -- font size
        "color=cyan"                       -- animation spec
    ).config.object
    -- make the text world space
    transform.set_space(triggerInventoryBoard.textEntity, "world")
    -- give state tags
    add_state_tag(triggerInventoryBoard.textEntity, PLANNING_STATE)
    add_state_tag(triggerInventoryBoardID, PLANNING_STATE)
    -- remove default state tags
    remove_default_state_tag(triggerInventoryBoard.textEntity)
    remove_default_state_tag(triggerInventoryBoardID)
    -- let's anchor to top of the trigger board
    transform.AssignRole(registry, triggerInventoryBoard.textEntity, InheritedPropertiesType.PermanentAttachment, triggerInventoryBoard:handle(),
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        InheritedPropertiesSync.Strong,
        InheritedPropertiesSync.Weak,
        Vec2(0, -10) -- offset it a bit upwards
    );
    local roleComp = component_cache.get(triggerInventoryBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP 

    
    
    
    -- add every trigger defined so we can test them all
    for id, def in pairs(WandEngine.trigger_card_defs) do
        local triggerCard = createNewTriggerSlotCard(id, 4000, 4000, PLANNING_STATE)
        addCardToBoard(triggerCard, triggerInventoryBoardID)
        -- add to navigation group as well.
        controller_nav.ud:add_entity("planning-phase", triggerCard)
    end
    
    -- for each board set, we get a corresponding index wand def to save, or if the index is out of range, we loop around.
    for index, boardSet in ipairs(board_sets) do
        
        local indexToUse = index
        if indexToUse > #WandEngine.wand_defs then
            indexToUse = ((indexToUse - 1) % #WandEngine.wand_defs) + 1
        end
        
        boardSet.wand_def = WandEngine.wand_defs[indexToUse]
    end
    
    -- for each card, make a tooltip
    for id, cardDef in pairs(WandEngine.card_defs) do
        card_tooltip_cache[cardDef.id] = makeCardTooltip(cardDef)
        
        -- z_orders
        layer_order_system.assignZIndexToEntity(
            card_tooltip_cache[cardDef.id], 
            z_orders.ui_tooltips
        )
        
        -- get transform and center vertically
        local t = component_cache.get(card_tooltip_cache[cardDef.id], Transform)
        if t then
            t.actualY = globals.screenHeight() * 0.5 - (t.actualH * 0.5)
            t.visualY = t.actualY
        end
        
        -- disable by default, enable only on 
        clear_state_tags(card_tooltip_cache[cardDef.id])
    end
    
    activate_state(WAND_TOOLTIP_STATE) -- keep activated at  all times.
    -- activate_state(CARD_TOOLTIP_STATE) -- keep activated at all times.
    
    -- make tooltip for each wand in WandEngine.wand_defs
    for id, wandDef in pairs(WandEngine.wand_defs) do
        wand_tooltip_cache[wandDef.id] = makeWandTooltip(wandDef)
        
        -- z_orders
        layer_order_system.assignZIndexToEntity(
            wand_tooltip_cache[wandDef.id], 
            z_orders.ui_tooltips
        )
        
        -- disable by default
        clear_state_tags(wand_tooltip_cache[wandDef.id])
    end
    
    
    -- let's set up an update timer for triggers.
    setUpLogicTimers()
end

local ctx = nil

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
function initCombatSystem()

    -- init combat system.
    
    local combatBus       = CombatSystem.Core.EventBus.new()
    local combatTime      = CombatSystem.Core.Time.new()
    local combatStatDefs, DAMAGE_TYPES = CombatSystem.Core.StatDef.make()
    local combatBundle    = CombatSystem.Game.Combat.new(CombatSystem.Core.RR, DAMAGE_TYPES)  -- carries RR + DAMAGE_TYPES; stored on ctx.combat

    
        
    combat_context = {
        stat_defs     = combatStatDefs, -- definitions for stats in this combat
        DAMAGE_TYPES  = DAMAGE_TYPES,    -- damage types available in this combat
        _make_actor    = make_actor, -- Factory for creating actors
        debug          = true,       -- verbose debug prints across systems
        bus            = combatBus,        -- shared event bus for this arena
        time           = combatTime,       -- shared clock for statuses/DoTs/cooldowns
        combat         = combatBundle      -- optional bundle for RR+damage types, if needed
    }
    
    local ctx = combat_context
    
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
    
    -- store in player entity for easy access later
    assert(survivorEntity and entity_cache.valid(survivorEntity), "Survivor entity is not valid in combat system init!")
    local playerScript = getScriptTableFromEntityID(survivorEntity)
    playerScript.combatTable = hero
    
    -- attach defs/derivations to ctx for easy access later for pets
    ctx._defs       = combatStatDefs
    ctx._attach     = CombatSystem.Game.Content.attach_attribute_derivations
    ctx._make_actor = make_actor
    
    -- subscribe to events.
    ctx.bus:on('OnLevelUp', function ()
        -- send player level up signal.
        signal.emit("player_level_up")
    end)
    
    
    -- update combat system every frame / render health bars
    timer.run(
        function()
            
            -- bail if not in action state
            if not is_state_active(ACTION_STATE) then return end
            
            ctx.time:tick(GetFrameTime())
            
            
            -- also, display a health bar indicator above the player entity, and an EXP bar.
            
            if not survivorEntity or not entity_cache.valid(survivorEntity) then
                return
            end
            
            local t = component_cache.get(survivorEntity, Transform)
            
            if t then
                
                local playerCombatInfo = ctx.side1[1]
                
                local playerHealth = playerCombatInfo.hp
                local playerMaxHealth = playerCombatInfo.max_health
                
                local playerXP = playerCombatInfo.xp or 0
                local playerXPForNextLevel = CombatSystem.Game.Leveling.xp_to_next(ctx, playerCombatInfo, playerCombatInfo.level or 1)
                
                -- rounded rect across the screen (screen space) along the top. One in red for health, one in blue for XP, background is dark gray.
                local healthBarWidth = globals.screenWidth() * 0.4
                local healthBarHeight = 20
                local healthBarX = globals.screenWidth() * 0.5 - healthBarWidth * 0.5
                local healthBarY = healthBarHeight
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x = healthBarX + healthBarWidth * 0.5
                    c.y = healthBarY + healthBarHeight * 0.5
                    c.w = healthBarWidth
                    c.h = healthBarHeight
                    c.rx = 5
                    c.ry = 5
                    c.color     = util.getColor("dark_gray")
                end, z_orders.background, layer.DrawCommandSpace.Screen)
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x = healthBarX + (playerHealth / playerMaxHealth) * healthBarWidth * 0.5
                    c.y = healthBarY + healthBarHeight * 0.5
                    c.w = (playerHealth / playerMaxHealth) * healthBarWidth
                    c.h = healthBarHeight
                    c.rx = 5
                    c.ry = 5
                    c.color     = util.getColor("red")
                end, z_orders.background + 1, layer.DrawCommandSpace.Screen)
                
                -- exp bar fully across top of screen
                local expBarWidth = globals.screenWidth()
                local expBarHeight = healthBarHeight
                local expBarX = globals.screenWidth() * 0.5 - expBarWidth * 0.5
                local expBarY = healthBarY - expBarHeight
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x = expBarX + expBarWidth * 0.5
                    c.y = expBarY + expBarHeight * 0.5
                    c.w = expBarWidth
                    c.h = expBarHeight
                    c.rx = 5
                    c.ry = 5
                    c.color     = util.getColor("dark_gray")
                end, z_orders.background, layer.DrawCommandSpace.Screen)
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x = expBarX + (math.min(playerXP / playerXPForNextLevel, 1.0)) * expBarWidth * 0.5
                    c.y = expBarY + expBarHeight * 0.5
                    c.w = (math.min(playerXP / playerXPForNextLevel, 1.0)) * expBarWidth
                    c.h = expBarHeight
                    c.rx = 5
                    c.ry = 5
                    c.color     = util.getColor("yellow")
                end, z_orders.background + 1, layer.DrawCommandSpace.Screen)
            end
        end
        
    )
    
end

function cycleBoardSets(amount)
    current_board_set_index = current_board_set_index + amount
    if current_board_set_index < 1 then
        current_board_set_index = #board_sets
    elseif current_board_set_index > #board_sets then
        current_board_set_index = 1
    end
    
    -- hide all board sets except the current one
    for index, boardSet in ipairs(board_sets) do
        if index == current_board_set_index then
            toggleBoardSetVisibility(boardSet, true)
        else
            toggleBoardSetVisibility(boardSet, false)
        end
    end
    
    -- get current board's wand def
    local currentSet = board_sets[current_board_set_index]
    local wandDef = currentSet.wand_def
    
    -- activate the wand tooltip for this wand
    for id, tooltipEntity in pairs(wand_tooltip_cache) do
        if id == wandDef.id then
            add_state_tag(tooltipEntity, WAND_TOOLTIP_STATE)
        else
            clear_state_tags(tooltipEntity)
        end
    end
    
    -- activate tooltip state
    activate_state(WAND_TOOLTIP_STATE)
    
end

function startActionPhase()
    clear_states() -- disable all states.
    
    activate_state(ACTION_STATE)
    activate_state("default_state") -- just for defaults, keep them open
    
    input.set_context("gameplay") -- set input context to action phase.
    
    PhysicsManager.enable_step("world", true)
    
    fadeOutMusic("space-ambiance", 0.3)
    fadeOutMusic("shop-music", 0.3)
    fadeOutMusic("planning-music", 0.3)
    fadeInMusic("action-music", 0.6)
    
    
    -- debug
    
    print("States active:", is_state_active(PLANNING_STATE), is_state_active(ACTION_STATE), is_state_active(SHOP_STATE))
end

function startPlanningPhase()
    
    clear_states() -- disable all states.
    entity_cache.clear()
    
    activate_state(PLANNING_STATE)
    activate_state("default_state") -- just for defaults, keep them open
    
    input.set_context("planning-phase") -- set input context to planning phase.
    
    PhysicsManager.enable_step("world", false)
    
    fadeOutMusic("planning-music", 0.3)
    fadeOutMusic("space-ambiance", 0.3)
    fadeOutMusic("action-music", 0.3)
    fadeOutMusic("shop-music", 0.3)
    fadeInMusic("planning-music", 0.6)
    
    transitionInOutCircle(2, "LOADING", util.getColor("black"), { x = globals.screenWidth() / 2, y = globals.screenHeight() / 2 })
    
    
    -- debug
    
    print("States active:", is_state_active(PLANNING_STATE), is_state_active(ACTION_STATE), is_state_active(SHOP_STATE))

end

function startShopPhase()
    
    clear_states() -- disable all states.
    
    activate_state(SHOP_STATE)
    activate_state("default_state") -- just for defaults, keep them open
    
    PhysicsManager.enable_step("world", false)
    
    fadeOutMusic("space-ambiance", 0.3)
    fadeOutMusic("action-music", 0.3)
    fadeOutMusic("planning-music", 0.3)
    fadeInMusic("shop-music", 0.6)
    
    
    -- debug
    
    print("States active:", is_state_active(PLANNING_STATE), is_state_active(ACTION_STATE), is_state_active(SHOP_STATE))
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
        if ImGui.Button("Next Board Set") then
            cycleBoardSets(1)
            
            -- cam jiggle
            local cam = camera.Get("world_camera")
            cam:SetVisualRotation(1)
        end
    end
    ImGui.End()
end

cardsSoldInShop = {}


function initSurvivorEntity() 
    
    local world = PhysicsManager.get_world("world")
    
   -- 3856-TheRoguelike_1_10_alpha_649.png
    survivorEntity = animation_system.createAnimatedObjectWithTransform(
        "3856-TheRoguelike_1_10_alpha_649.png", -- animation ID
        true             -- use animation, not sprite identifier, if false
    )
    
    -- give survivor a script and hook up
    local SurvivorType = Node:extend()
    local survivorScript = SurvivorType{}
    -- TODO: add update method here if needed

    survivorScript:attach_ecs{ create_new = false, existing_entity = survivorEntity }
    
    -- relocate to the center of the screen
    local survivorTransform = component_cache.get(survivorEntity, Transform)
    survivorTransform.actualX = globals.screenWidth() / 2
    survivorTransform.actualY = globals.screenHeight() / 2
    survivorTransform.visualX = survivorTransform.actualX   
    survivorTransform.visualY = survivorTransform.actualY
    
    -- give survivor physics.
    local info = { shape = "rectangle", tag = "player", sensor = false, density = 1.0, inflate_px = -5 } -- default tag is "WORLD"
    physics.create_physics_for_transform(registry,
        physics_manager_instance, -- global instance
        survivorEntity, -- entity id
        "world", -- physics world identifier
        info
    )
    
    -- make it collide with enemies & walls & pickups
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "WORLD", {"player"})
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "player", {"WORLD"})
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "pickup", {"player"})
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "player", {"pickup"})
    
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "player", {"WORLD"})
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "WORLD", {"player"})
    
    
    
    
    
    -- make walls after defining collision relationships, tesitng because of bug.
    physics.add_screen_bounds(PhysicsManager.get_world("world"), 
        SCREEN_BOUND_LEFT, SCREEN_BOUND_TOP, SCREEN_BOUND_RIGHT, SCREEN_BOUND_BOTTOM,
        30, 
        "WORLD"
    )
    
    -- make a timer that runs every frame when action state is active, to render the walls
    timer.run(
        function()
            -- bail if not in action state
            if not is_state_active(ACTION_STATE) then return end
            
            -- draw walls
            command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                c.x = SCREEN_BOUND_LEFT + (SCREEN_BOUND_RIGHT - SCREEN_BOUND_LEFT) / 2
                c.y = SCREEN_BOUND_TOP + (SCREEN_BOUND_BOTTOM - SCREEN_BOUND_TOP) / 2
                c.w = SCREEN_BOUND_RIGHT - SCREEN_BOUND_LEFT
                c.h = SCREEN_BOUND_BOTTOM - SCREEN_BOUND_TOP
                c.rx = 5
                c.ry = 5
                c.lineWidth = 10
                c.color     = util.getColor("white")
            end, z_orders.background, layer.DrawCommandSpace.World)
        end
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
    --         local survivorT = component_cache.get(survivorEntity, Transform)
    
    --         c.cx = 0 -- self centered
    --         c.cy = 0
    --         c.width = w
    --         c.height = h
    --         c.roundness = 0.5
    --         c.segments = 8
    --         c.topLeft = util.getColor("apricot_cream")
    --         c.topRight = util.getColor("green")
    --         c.bottomRight = util.getColor("green")
    --         c.bottomLeft = util.getColor("apricot_cream")
                
    --         end, z_orders.projectiles + 1, layer.DrawCommandSpace.World)
    --     end, true) -- true disables sprite rendering
    
    
    -- player vs pickup collision
    physics.on_pair_begin(world, "player", "pickup", function(arb) 
        log_debug("Survivor hit a pickup!")
        
        local a, b = arb:entities()
            
        local pickupEntity = nil
        if (a ~= survivorEntity) then
            pickupEntity = a
        else
            pickupEntity = b
        end
        
        -- remove a couple frames later
        timer.after(0.1, function()
            
            -- fire off signal
            signal.emit("on_pickup", pickupEntity)
            
            -- remove pickup entity
            if pickupEntity and entity_cache.valid(pickupEntity) then
                
                -- create a small particle effect at pickup location
                local pickupTransform = component_cache.get(pickupEntity, Transform)
                if pickupTransform then
                    spawnCircularBurstParticles(
                        pickupTransform.actualX + pickupTransform.actualW / 2,
                        pickupTransform.actualY + pickupTransform.actualH / 2,
                        15, -- num particles
                        0.4,
                        util.getColor("yellow"), 
                        util.getColor("apricot_cream"), -- colors
                        "cubic_in_out", -- ease
                        "world"
                    )
                end
                
                registry:destroy(pickupEntity)
            end
        end)
    end)
    
    
    -- give survivor collision callback, namely begin.
    -- modifying a file.
    physics.on_pair_begin(world, "player", "enemy", function(arb) 
        
        log_debug("Survivor hit an enemy!")
        
        -- ascertain the enemy entity, only on first contact
        if arb:is_first_contact() then
            local a, b = arb:entities()
            
            local enemyEntity = nil
            if (a ~= survivorEntity) then
                enemyEntity = a
            else
                enemyEntity = b
            end
            
            -- fire off signal
            signal.emit("on_bump_enemy", enemyEntity)
        end
        
        
        
        -- play sound
        
        playSoundEffect("effects", "time_slow", 0.9 + math.random() * 0.2)
        slowTime(1.5, 0.1) -- slow time for 2 seconds, to 20% speed
        
        playSoundEffect("effects", "player_hurt", 0.9 + math.random() * 0.2)
        
        timer.after(0.2, function()
            playSoundEffect("effects", "time_back_to_normal", 0.9 + math.random() * 0.2)
        end)
        
        -- TODO: make player take damage, play hit effect, etc.
        
        local shaderPipelineComp = component_cache.get(survivorEntity, shader_pipeline.ShaderPipelineComponent)
        shaderPipelineComp:addPass("flash")
        
        -- shake camera
        local cam = camera.Get("world_camera")
        if cam then
            cam:Shake(10.0, 0.35, 30.0)
        end
        
        -- remove after a short delay
        timer.after(1.0, function()
            local shaderPipelineComp = component_cache.get(survivorEntity, shader_pipeline.ShaderPipelineComponent)
            if shaderPipelineComp then
                shaderPipelineComp:removePass("flash")
            end
        end)
        
        return false -- reject collision 
    end)

    
    -- allow transform manipuation to alter physics body
    physics.set_sync_mode(registry, survivorEntity, physics.PhysicsSyncMode.AuthoritativePhysics)
    
    physics.SetBodyType(PhysicsManager.get_world("world"), survivorEntity, "dynamic")
    
    -- give a state tag to the survivor entity
    add_state_tag(survivorEntity, ACTION_STATE)
    -- remove default
    remove_default_state_tag(survivorEntity)
    
    
    
    -- lets move the survivor based on input.
    input.bind("survivor_left", { device="keyboard", key=KeyboardKey.KEY_A, trigger="Pressed", context="gameplay" })
    input.bind("survivor_right", { device="keyboard", key=KeyboardKey.KEY_D, trigger="Pressed", context="gameplay" })
    input.bind("survivor_up", { device="keyboard", key=KeyboardKey.KEY_W, trigger="Pressed", context="gameplay" })
    input.bind("survivor_down", { device="keyboard", key=KeyboardKey.KEY_S, trigger="Pressed", context="gameplay" }) 
    input.bind("survivor_dash", { device="keyboard", key=KeyboardKey.KEY_SPACE, trigger="Pressed", context="gameplay" })
    
    --also allow gamepad.
    -- same dash
    input.bind("survivor_dash", {
        device = "gamepad_button",
        axis = GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN, -- A button
        trigger = "Pressed",     -- or "Threshold" if your system uses analog triggers
        context = "gameplay"
    })
    
    -- Horizontal movement (Left stick X)
    input.bind("gamepad_move_x", {
        device = "gamepad_axis",
        axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X,
        trigger = "AxisPos",     -- or "Threshold" if your system uses analog triggers
        threshold = 0.2,       -- deadzone threshold
        context = "gameplay"
    })
    input.bind("gamepad_move_x", {
        device = "gamepad_axis",
        axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X,
        trigger = "AxisNeg",     -- or "Threshold" if your system uses analog triggers
        threshold = 0.2,       -- deadzone threshold
        context = "gameplay"
    })

    -- Vertical movement (Left stick Y)
    input.bind("gamepad_move_y", {
        device = "gamepad_axis",
        axis = GamepadAxis.GAMEPAD_AXIS_LEFT_Y,
        trigger = "AxisPos",
        threshold = 0.2,
        context = "gameplay"
    })
    input.bind("gamepad_move_y", {
        device = "gamepad_axis",
        axis = GamepadAxis.GAMEPAD_AXIS_LEFT_Y,
        trigger = "AxisNeg",
        threshold = 0.2,
        context = "gameplay"
    })
    
    signal.register("player_level_up", function()
        log_debug("Player leveled up!")
        playSoundEffect("effects", "level_up", 1.0)
        
    end)
    
    
    -- let's register signal listeners
    signal.register("on_pickup", function(pickupEntity)
        log_debug("Survivor picked up entity", pickupEntity)
        
        local playerScript = getScriptTableFromEntityID(survivorEntity)
        
        if not playerScript or not playerScript.combatTable then
            log_debug("No combat table on player, cannot grant exp!")
            return
        end
        
        playSoundEffect("effects", "gain_exp_pickup", 1.0)
        
        CombatSystem.Game.Leveling.grant_exp(combat_context, playerScript.combatTable, 50) -- grant 20 exp per pickup
        
        --TODo: this is just a test.
        
    end)
end

function initShopPhase()
    
    -- let's make a large board for shopping
    local shopBoardID = createNewBoard(100, 100, 800, 400)
    local shopBoard = boards[shopBoardID]
    shopBoard.borderColor = util.getColor("apricot_cream")
    
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
    local roleComp = component_cache.get(shopBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP
    
    -- give the text & board state
    clear_state_tags(shopBoard.textEntity)
    clear_state_tags(shopBoard:handle())
    add_state_tag(shopBoard.textEntity, SHOP_STATE)
    add_state_tag(shopBoard:handle(), SHOP_STATE)
    
    -- let's populate the shop with some cards
    local testCard1 = createNewCard(WandEngine.card_defs.ACTION_BASIC_PROJECTILE, 0, 0, SHOP_STATE)
    local testCard2 = createNewCard(WandEngine.card_defs.ACTION_FIREBALL, 0, 0, SHOP_STATE)
    local testCard3 = createNewCard(WandEngine.card_defs.ACTION_FAST_ACCURATE_PROJECTILE, 0, 0, SHOP_STATE)
        
    -- add them to the board.
    addCardToBoard(testCard1, shopBoard:handle())
    addCardToBoard(testCard2, shopBoard:handle())
    addCardToBoard(testCard3, shopBoard:handle())
    
    -- let's add a (buy) board below.
    local buyBoardID = createNewBoard(100, 550, 800, 150)
    local buyBoard = boards[buyBoardID]
    buyBoard.borderColor = util.getColor("green")
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
    local roleComp = component_cache.get(buyBoard.textEntity, InheritedProperties)
    roleComp.flags = AlignmentFlag.VERTICAL_TOP 
    -- give the text & board state
    clear_state_tags(buyBoard.textEntity)
    clear_state_tags(buyBoard:handle())
    add_state_tag(buyBoard.textEntity, SHOP_STATE)
    add_state_tag(buyBoard:handle(), SHOP_STATE)
    
    buyBoard.cards = {} -- cards are entity ids.
    
    -- add a different onRelease method
    local buyBoardGameObject = component_cache.get(buyBoard:handle(), GameObject)
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

local playerFootStepSounds = {
    "walk_1",
    "walk_2",
    "walk_3",
    "walk_4",  
    "walk_5"
}

-- location is top left of circle
local function makeSpawnMarkerCircle(x, y, radius, color, state)

    -- make circle marker for enemy appearance, tween it down to 0 scale and then remove it
    local SpawnMarkerType = Node:extend()
    local enemyX = x + radius / 2
    local enemyY = y + radius / 2
    function SpawnMarkerType:update(dt)
        
        
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
            c.x = enemyX
            c.y = enemyY
            c.w = 64 * self.scale
            c.h = 64 * self.scale
            c.rx = 32
            c.ry = 32
            c.color = color or Col(255, 255, 255, 255)
            
        end, z_orders.projectiles + 1, layer.DrawCommandSpace.World)
    end
    
    local spawnMarkerNode = SpawnMarkerType{}
    spawnMarkerNode.scale = 1.0
    
    spawnMarkerNode:attach_ecs{ create_new = true }
    add_state_tag(spawnMarkerNode:handle(), state or ACTION_STATE)
    
    -- tween down
    -- local h5 = timer.tween(1.2, camera, { x = 320, y = 180, zoom = 1.25 }, nil, nil, "cam_move", "camera")
    timer.tween_fields(0.2, spawnMarkerNode, { scale = 0.0 }, nil, function()
        registry:destroy(spawnMarkerNode:handle())
    end)
            
end
function initActionPhase()
    
    
    log_debug("Action phase started!")
    
    
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
    world:AddCollisionTag("pickup") -- for items on ground
    
    initSurvivorEntity()
    
    physics.SetSleepTimeThreshold(world, 100000) -- time in seconds before body goes to sleep
    
    playerIsDashing = false
    
    -- create input timer. this must run every frame.
    timer.every_physics_step(
        function()
            -- TODO: debug by logging pos
            -- local debugPos = physics.GetPosition(world, survivorEntity)
            -- log_debug("Survivor pos:", debugPos.x, debugPos.y)
            
            -- log_debug("Survivor sleeping state:", physics.IsSleeping(world, survivorEntity))
            
            -- tracy.zoneBeginN("Survivor Input Handling") -- just some default depth to avoid bugs
            if not survivorEntity or survivorEntity == entt_null or not entity_cache.valid(survivorEntity) then
                return
            end
            
            local isGamePadActive = input.isPadConnected(0) -- check if gamepad is connected, assuming player 0
            
            local moveDir = { x = 0, y = 0 }
            
            local playerMoving = false
            
            if (isGamePadActive) then
                
                -- log_debug("Gamepad active for movement")
                
                local move_x = input.action_value("gamepad_move_x")
                local move_y = input.action_value("gamepad_move_y")
                
                -- log_debug("Gamepad move x:", move_x, "move y:", move_y)

                -- If you want to invert Y (Raylib default is up = -1)
                -- move_y = -move_y

                -- Normalize deadzone
                local len = math.sqrt(move_x * move_x + move_y * move_y)
                if len > 1 then
                    move_x = move_x / len
                    move_y = move_y / len
                end
                
                moveDir.x = move_x
                moveDir.y = move_y
            else 
                -- find intended dash direction from inputs
                if input.action_down("survivor_left") then  moveDir.x = moveDir.x - 1 end
                if input.action_down("survivor_right") then moveDir.x = moveDir.x + 1 end
                if input.action_down("survivor_up") then    moveDir.y = moveDir.y - 1 end
                if input.action_down("survivor_down") then  moveDir.y = moveDir.y + 1 end

                local len = math.sqrt(moveDir.x * moveDir.x + moveDir.y * moveDir.y)
                if len ~= 0 then
                    moveDir.x, moveDir.y = moveDir.x / len, moveDir.y / len
                    playerMoving = true
                else 
                    moveDir.x, moveDir.y = 0, 0
                end
            end
            
            -- if player is moving, keep the timer running. if not, end the timer.
            local timerName = "survivorFootstepsSoundTimer"
            if playerMoving then
                if not timer.get_timer_and_delay(timerName) then
                    -- timer not active. turn it on.
                    timer.every(0.8, function()
                        -- play footstep sound at survivor position
                        playSoundEffect("effects", random_utils.random_element_string(playerFootStepSounds))
                    end, 0, true, nil, timerName)
                else
                    -- timer active, do nothing.
                end
                    
            else 
                -- turn off timer if active
                timer.cancel(timerName)
            end
            
            if not playerIsDashing and input.action_down("survivor_dash") then
                log_debug("Dash pressed!")
                
                -- make transform not authoritative
                -- physics.set_sync_mode(registry, survivorEntity, physics.PhysicsSyncMode.AuthoritativePhysics)
                -- physics.SetBodyType(PhysicsManager.get_world("world"), survivorEntity, "dynamic")
                -- physics.SetDamping(PhysicsManager.get_world("world"), survivorEntity, 0.0) -- no damping while dashing
                -- set velocity to zero
                -- physics.SetVelocity(PhysicsManager.get_world("world"), survivorEntity, 0, 0)
                
                -- let's add dashing.
                
                local len = math.sqrt(moveDir.x * moveDir.x + moveDir.y * moveDir.y)
                if len == 0 then
                    -- fallback: use last known facing or velocity
                    local vel = physics.GetVelocity(world, survivorEntity)
                    len = math.sqrt(vel.x * vel.x + vel.y * vel.y)
                    if len > 0 then
                        moveDir.x = vel.x / len
                        moveDir.y = vel.y / len
                    else
                        moveDir.x, moveDir.y = 0, -1 -- default forward dash (e.g., up)
                    end
                end
    
                -- add impulse in the direction it's going
                -- timer that resets damping after a short delay. (SetDamping)
                
                local DASH_STRENGTH = 340
                
                -- physics.ApplyImpulse(PhysicsManager.get_world("world"), survivorEntity, moveDir.x * DASH_STRENGTH, moveDir.y * DASH_STRENGTH)
                
                -- timer.on_new_physics_step(function()
                    physics.ApplyImpulse(world, survivorEntity, moveDir.x * DASH_STRENGTH, moveDir.y * DASH_STRENGTH)
                -- end, "dash_impulse_timer")
                
                playerIsDashing = true
                
                local DASH_LENGTH_SEC = 0.5
                
                playSoundEffect("effects", "dash", math.random() * 0.2 + 0.9)
                
                -- timer.every((DASH_LENGTH_SEC) / 20, function()
                --     local t = component_cache.get(survivorEntity, Transform)
                --     if t then
                        
                --         -- new node
                        
                --         local particleNode = ParticleType{}
                --         particleNode.lifetime = 0.1
                --         particleNode.age = 0.0
                --         particleNode.savedPos = { x = t.visualX, y = t.visualY }
                        
                        
                --         particleNode
                --             :attach_ecs{ create_new = true }
                --             :destroy_when(function(self, eid) return self.age >= self.lifetime end)
                        
                --         add_state_tag(particleNode:handle(), ACTION_STATE)
                        
                --     end
                -- end, 10) -- 5 times
                
                -- directional dash trail particles
                local survivorTransform = component_cache.get(survivorEntity, Transform)
                if survivorTransform then
                    local origin = Vec2(survivorTransform.actualX + survivorTransform.actualW * 0.5,
                                        survivorTransform.actualY + survivorTransform.actualH * 0.5)

                    particle.spawnDirectionalCone(origin, 30, DASH_LENGTH_SEC, {
                        direction = Vec2(-moveDir.x, -moveDir.y),
                        spread = 30,                -- degrees
                        colors = {
                            util.getColor("blue")
                        },
                        endColor = util.getColor("blue"),
                        minSpeed = 120,
                        maxSpeed = 340,
                        minScale = 3,
                        maxScale = 10,
                        rotationSpeed = 10,
                        rotationJitter = 0.2,
                        lifetimeJitter = 0.3,
                        scaleJitter = 0.1,
                        gravity = 0,
                        easing = "outCubic",
                        renderType = particle.ParticleRenderType.CIRCLE_FILLED,
                        space = "world",
                        z = z_orders.player_vfx - 20
                    })
                end
                

                timer.after(DASH_LENGTH_SEC, function()
                    timer.on_new_physics_step(function()
                        -- physics.SetDamping(world, survivorEntity, 5.0)
                        playerIsDashing = false
                    end)
                end, "dash_end_timer")
                -- make timer to end dash after short delay
                -- timer.after(DASH_LENGTH_SEC, function()
                --     -- reset damping
                --     physics.SetDamping(PhysicsManager.get_world("world"), survivorEntity, 5.0) -- normal damping
                    
                --     playerIsDashing = false
                    
                --     -- make transform authoritative again
                --     -- physics.set_sync_mode(registry, survivorEntity, physics.PhysicsSyncMode.AuthoritativeTransform)
                -- end)
            end
            
            if playerIsDashing then
                return -- skip movement input while dashing
            end
            
            local speed = 200 -- pixels per second
            
            physics.SetVelocity(PhysicsManager.get_world("world"), survivorEntity, moveDir.x * speed, moveDir.y * speed)
            
            -- tracy.zoneEnd()
            
        end,
        nil, -- no after
        "survivorEntityMovementTimer" -- timer tag
    )
    
    input.set_context("gameplay") -- set the input context to gameplay
    
    
    
    initCombatSystem()
    
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
            -- remove default state tag
            remove_default_state_tag(enemyEntity)
            
            -- set it to a random position, within the screen bounds.
            local enemyTransform = component_cache.get(enemyEntity, Transform)
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
            steering.make_steerable(registry, enemyEntity, 300.0, 3000.0, math.pi*2.0, 2.0)
            
            
            -- give it a combat table.
                    
            -- Ogre: tougher target with defense layers and reactive behaviors (reflect/retaliation/block).
            local ogre = combat_context._make_actor('Ogre', combat_context.stat_defs, CombatSystem.Game.Content.attach_attribute_derivations)
            ogre.side = 2
            ogre.stats:add_base('health', 10)
            ogre.stats:add_base('offensive_ability', 10)
            ogre.stats:add_base('defensive_ability', 10)
            ogre.stats:add_base('armor', 10)
            ogre.stats:add_base('armor_absorption_bonus_pct', 0)
            ogre.stats:add_base('fire_resist_pct', 0)
            ogre.stats:add_base('dodge_chance_pct', 0)
            -- ogre.stats:add_base('deflect_chance_pct', 8) -- (deflection not currently used)
            -- ogre.stats:add_base('reflect_damage_pct', 0)
            -- ogre.stats:add_base('retaliation_fire', 8)
            -- ogre.stats:add_base('retaliation_fire_modifier_pct', 25)
            -- ogre.stats:add_base('block_chance_pct', 30)
            -- ogre.stats:add_base('block_amount', 60)
            -- ogre.stats:add_base('block_recovery_reduction_pct', 25)
            -- ogre.stats:add_base('damage_taken_reduction_pct',2000) -- stress test: massive DR → negative damage (healing)
            ogre.stats:recompute()
            
            
            CombatSystem.Game.ItemSystem.equip(combat_context, ogre, basic_monster_weapon)
            
            -- give node
            local enemyScriptNode = Node{}
            enemyScriptNode.combatTable = ogre
            enemyScriptNode:attach_ecs{ create_new = false, existing_entity = enemyEntity }
            
            
            -- make circle marker for enemy appearance, tween it down to 0 scale and then remove it
            local SpawnMarkerType = Node:extend()
            local enemyX = enemyTransform.actualX + enemyTransform.actualW/2
            local enemyY = enemyTransform.actualY + enemyTransform.actualH/2
            function SpawnMarkerType:update(dt)
                
                
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
            
            local spawnMarkerNode = SpawnMarkerType{}
            spawnMarkerNode.scale = 1.0
            
            spawnMarkerNode:attach_ecs{ create_new = true }
            add_state_tag(spawnMarkerNode:handle(), ACTION_STATE)
            
            -- tween down
            -- local h5 = timer.tween(1.2, camera, { x = 320, y = 180, zoom = 1.25 }, nil, nil, "cam_move", "camera")
            timer.tween_fields(0.2, spawnMarkerNode, { scale = 0.0 }, nil, function()
                registry:destroy(spawnMarkerNode:handle())
            end)
            
            timer.every_physics_step(function()
                local t = component_cache.get(enemyEntity, Transform)
                
                local playerLocation = {x=0,y=0}
                local playerT = component_cache.get(survivorEntity, Transform)
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
    
    

    local cam = camera.Get("world_camera")
    -- timer to pan camera to follow player
    timer.run( function()
        -- tracy.zoneBeginN("Camera Pan Timer Tick") -- just some default depth to avoid bugs
        -- log_debug("Camera pan timer tick")
        if entity_cache.state_active(ACTION_STATE) then
            local targetX, targetY = 0, 0
            local t = component_cache.get(survivorEntity, Transform)
            if t then
                targetX = t.actualX + t.actualW/2
                targetY = t.actualY + t.actualH/2
                -- camera_smooth_pan_to("world_camera", targetX, targetY, { tag = "interval"}) -- pan to the target smoothly
                
                cam:SetActualTarget(targetX, targetY)
            end
            
        else
            -- local cam = camera.Get("world_camera")
            log_debug("Camera pan timer tick - no action state, centering camera")
            local c = cam:GetActualTarget()
            
            -- if not already at halfway point in screen, then move it there
            if math.abs(c.x - globals.screenWidth()/2) > 5 or math.abs(c.y - globals.screenHeight()/2) > 5 then
                camera_smooth_pan_to("world_camera", globals.screenWidth()/2, globals.screenHeight()/2) -- pan to the target smoothly
            end
        end
        -- tracy.zoneEnd()
    end,
    nil,
    false,
    nil,
    "cameraPanToPlayerTimer")
    
    
    -- timer to spawn an exp pickup every few seconds, for testing purposes.
    timer.every(3.0, function()
        if is_state_active(ACTION_STATE) then
            
            local expPickupEntity = animation_system.createAnimatedObjectWithTransform(
                "b8090.png", -- animation ID
                true             -- use animation, not sprite identifier, if false
            )
            
            add_state_tag(expPickupEntity, ACTION_STATE)
            remove_default_state_tag(expPickupEntity)
            
            local expPickupTransform = component_cache.get(expPickupEntity, Transform)
            expPickupTransform.actualX = lume.random(SCREEN_BOUND_LEFT + 50, SCREEN_BOUND_RIGHT - 50)
            expPickupTransform.actualY = lume.random(SCREEN_BOUND_TOP + 50, SCREEN_BOUND_BOTTOM - 50)
            expPickupTransform.visualX = expPickupTransform.actualX
            expPickupTransform.visualY = expPickupTransform.actualY
            
            
            -- add marker spanw
            makeSpawnMarkerCircle(
                expPickupTransform.actualX,
                expPickupTransform.actualY,
                64,
                util.getColor("yellow"),
                ACTION_STATE
            )

            
            
            -- give it physics
            local info = { shape = "rectangle", tag = "pickup", sensor = false, density = 1.0, inflate_px = 0 } -- default tag is "WORLD"
            
            physics.create_physics_for_transform(registry,
                physics_manager_instance, -- global instance
                expPickupEntity, -- entity id
                "world", -- physics world identifier
                info
            )
            
            physics.enable_collision_between_many(PhysicsManager.get_world("world"), "pickup", {"player"})
            physics.enable_collision_between_many(PhysicsManager.get_world("world"), "player", {"pickup"})
            physics.update_collision_masks_for(PhysicsManager.get_world("world"), "pickup", {"player"})
            physics.update_collision_masks_for(PhysicsManager.get_world("world"), "player", {"pickup"})
            
            -- give it a script 
            local expPickupScript = Node{}

            expPickupScript:attach_ecs{ create_new = false, existing_entity = expPickupEntity }
            
        end
        
    end)
    
    -- blanket collision update
    -- physics.reapply_all_filters(PhysicsManager.get_world("world"))
    
end

planningUIEntities = {
    start_action_button_box = nil
}



function initPlanningUI() 
    
    -- makeWandTooltip()
   
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
                :addColor(util.getColor("gray"))
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
            :addColor(util.getColor("yellow"))
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
    local buttonTransform = component_cache.get(planningUIEntities.start_action_button_box, Transform)
    buttonTransform.actualX = globals.screenWidth() / 2 - buttonTransform.actualW / 2
    buttonTransform.actualY = globals.screenHeight() - buttonTransform.actualH - 10
    
    -- ggive entire box the planning state
    ui.box.AssignStateTagsToUIBox(planningUIEntities.start_action_button_box, PLANNING_STATE)
    -- remove default state
    remove_default_state_tag(planningUIEntities.start_action_button_box)
    
    
    
    -- testing ui
    require("ui.ui_definition_helper")
    local dsl = require("ui.ui_syntax_sugar")

    -- Example: simple button
    local shopButton = dsl.hbox{
        config = {
            id    = "shop_button",
            color = "red",
            align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER,
            hover = true,
            onClick = function()
                playSoundEffect("effects", "button-click")
                log_debug("Shop button clicked!")
            end,
        },
        children = {
            dsl.anim("4130-TheRoguelike_1_10_alpha_923.png", { w = 20, h = 20, isAnimation = false, shadow = false }),
            dsl.text(localization.get("ui.tooltip_wand_button"), { color = "blackberry", fontSize = 27.0 }),
        }
    }

    local root = dsl.root{ 
        config = {
            color = "blank",
            align = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER,
        },
        children = { shopButton } }

    -- Create box and attach resize callback
    local box = dsl.spawn({x = 0, y = 700}, root, "HUD", 5, {
        onBoxResize = function(registry, eid, w, h)
            log_debug("Resized box", eid, "to", w, h)
        end
    })

    -- Attach hovers recursively (uses orderedChildren)
    dsl.applyHoverRecursive(box)
    
    -- ggive entire box the planning state
    ui.box.AssignStateTagsToUIBox(box, PLANNING_STATE)
    -- remove default state
    remove_default_state_tag(box)
    
    -- get shop button entity
    local buttonEntity =  ui.box.GetUIEByID(registry, "shop_button")
    
    -- add onhover and stophover
    local node = component_cache.get(buttonEntity, GameObject)
    
    if node then
        node.state.hoverEnabled = true
        node.state.collisionEnabled = true   
    
        node.methods.onHover = function(registry, hoveredEntity)
            log_debug("Shop button hovered!", hoveredEntity)
            -- playSoundEffect("effects", "button-hover")
            
            -- show current wand tooltip
             -- get current board's wand def
            local currentSet = board_sets[current_board_set_index]
            local wandDef = currentSet.wand_def
            
            -- activate the wand tooltip for this wand
            for id, tooltipEntity in pairs(wand_tooltip_cache) do
                if id == wandDef.id then
                    add_state_tag(tooltipEntity, WAND_TOOLTIP_STATE)
                else
                    clear_state_tags(tooltipEntity)
                end
            end
            
            -- activate tooltip state
            activate_state(WAND_TOOLTIP_STATE)
        end
        node.methods.onStopHover = function(registry, hoveredEntity)
            log_debug("Shop button stop hovered!", hoveredEntity)
            
            -- hide all wand tooltips
            
            deactivate_state(WAND_TOOLTIP_STATE)
        end
    end
    
    -- test resize
    timer.after(2.0, function()
        ui.box.RenewAlignment(registry, box)
    end)
    
    
end