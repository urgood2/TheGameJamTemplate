-- contains code limited to gameplay logic for organizational purposes

local z_orders = require("core.z_orders")
local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script
local palette = require("color.palette")
local TimerChain = require("core.timer_chain")
local Easing = require("util.easing")
local CombatSystem = require("combat.combat_system")
local ShopSystem = require("core.shop_system")
local CardMetadata = require("core.card_metadata")
local CardRarityTags = require("core.add_card_rarity_tags")
require("core.card_eval_order_test")
local WandEngine = require("core.card_eval_order_test")
local WandExecutor = require("wand.wand_executor")
local WandTriggers = require("wand.wand_triggers")
local TagEvaluator = require("wand.tag_evaluator")
local AvatarSystem = require("wand.avatar_system")
local signal = require("external.hump.signal")
local timer = require("core.timer")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
require("ui.ui_definition_helper")
local dsl = require("ui.ui_syntax_sugar")
local CastExecutionGraphUI = require("ui.cast_execution_graph_ui")
local CastBlockFlashUI = require("ui.cast_block_flash_ui")
local WandCooldownUI = require("ui.wand_cooldown_ui")
local SubcastDebugUI = require("ui.subcast_debug_ui")
local MessageQueueUI = require("ui.message_queue_ui")
local CurrencyDisplay = require("ui.currency_display")
local TagSynergyPanel = require("ui.tag_synergy_panel")
local AvatarJokerStrip = require("ui.avatar_joker_strip")
local LevelUpScreen = require("ui.level_up_screen")
local LEVEL_UP_MODAL_DELAY = 0.5
local ENABLE_SURVIVOR_MASK = false
-- local bit = require("bit") -- LuaJIT's bit library

require("core.type_defs") -- for Node customizations
local BaseCreateExecutionContext = WandExecutor.createExecutionContext
local messageQueueHooksRegistered = false
local avatarTestEventsFired = false
local DEBUG_AVATAR_TEST_EVENTS = rawget(_G, "DEBUG_AVATAR_TEST_EVENTS")
if DEBUG_AVATAR_TEST_EVENTS == nil then
    DEBUG_AVATAR_TEST_EVENTS = true
end

local function ensureMessageQueueHooks()
    if messageQueueHooksRegistered then return end
    messageQueueHooksRegistered = true

    local function ensureMQ()
        if not MessageQueueUI.isActive then
            MessageQueueUI.init()
        end
    end

    signal.register("avatar_unlocked", function(data)
        ensureMQ()
        local avatarId = (data and data.avatar_id) or "Unknown Avatar"
        MessageQueueUI.enqueue(string.format("Avatar unlocked: %s", avatarId))
    end)

    signal.register("tag_threshold_discovered", function(data)
        ensureMQ()
        local tag = (data and data.tag) or "Tag"
        local threshold = (data and data.threshold) or "?"
        MessageQueueUI.enqueue(string.format("Discovery: %s x%s", tag, threshold))
    end)

    signal.register("spell_type_discovered", function(data)
        ensureMQ()
        local spell = (data and data.spell_type) or "Spell"
        MessageQueueUI.enqueue(string.format("New spell type: %s", spell))
    end)
end

local function fireAvatarDebugEvents()
    if avatarTestEventsFired or not DEBUG_AVATAR_TEST_EVENTS then return end
    avatarTestEventsFired = true

    local testPlayer = {}
    local cards = {}
    for _ = 1, 7 do
        table.insert(cards, { tags = { "Fire" } })
    end

    -- Emits tag discovery + wildfire unlock signals
    TagEvaluator.evaluate_and_apply(testPlayer, { cards = cards })

    -- Unlocks citadel via metric path
    AvatarSystem.record_progress(testPlayer, "damage_blocked", 5000)

    -- Exercise spell discovery hook
    signal.emit("spell_type_discovered", { spell_type = "Twin Cast" })
end



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
survivorMaskEntity = nil
boards = {}
cards = {}
inventory_board_id = nil
trigger_board_id_to_action_board_id = {} -- map trigger boards to action boards
trigger_board_id = nil
action_board_id = nil

-- ui tooltip cache
wand_tooltip_cache = {}
card_tooltip_cache = {}
card_tooltip_disabled_cache = {}
previously_hovered_tooltip = nil

local tooltipStyle = {
    fontSize = 12,
    labelBg = "black",
    idBg = "gold",
    idTextColor = "black",
    labelColor = "apricot_cream",
    valueColor = "white",
    innerPadding = 3,
    rowPadding = 1,
    labelColumnMinWidth = 220,
    valueColumnMinWidth = 72,
    bgColor = Col(18, 22, 32, 235),
    innerColor = Col(28, 32, 44, 230),
    outlineColor = (util.getColor and util.getColor("apricot_cream")) or Col(255, 214, 170, 255)
}

local ensureCardTooltip -- forward declaration

local function centerTooltipAboveEntity(tooltipEntity, targetEntity, offset)
    if not tooltipEntity or not targetEntity then return end
    if not entity_cache.valid(tooltipEntity) or not entity_cache.valid(targetEntity) then return end

    ui.box.RenewAlignment(registry, tooltipEntity)

    local tooltipTransform = component_cache.get(tooltipEntity, Transform)
    local targetTransform = component_cache.get(targetEntity, Transform)
    if not tooltipTransform or not targetTransform then return end

    local gap = offset or 12
    local screenW = globals.screenWidth() or 0
    local screenH = globals.screenHeight() or 0
    local anchorX = targetTransform.actualX or 0
    local anchorY = targetTransform.actualY or 0
    local anchorW = targetTransform.actualW or 0
    local anchorH = targetTransform.actualH or 0
    local tooltipW = tooltipTransform.actualW or 0
    local tooltipH = tooltipTransform.actualH or 0

    local x = anchorX + anchorW * 0.5 - tooltipW * 0.5
    local y = anchorY - tooltipH - gap

    if x < gap then
        x = gap
    elseif x + tooltipW > screenW - gap then
        x = math.max(gap, screenW - tooltipW - gap)
    end
    if y < gap then
        y = gap
    end

    tooltipTransform.actualX = x
    tooltipTransform.actualY = y
    tooltipTransform.visualX = tooltipTransform.actualX
    tooltipTransform.visualY = tooltipTransform.actualY
end

local function positionTooltipRightOfEntity(tooltipEntity, targetEntity, opts)
    if not tooltipEntity or not targetEntity then return end
    if not entity_cache.valid(tooltipEntity) or not entity_cache.valid(targetEntity) then return end

    ui.box.RenewAlignment(registry, tooltipEntity)

    local tooltipTransform = component_cache.get(tooltipEntity, Transform)
    local targetTransform = component_cache.get(targetEntity, Transform)
    if not tooltipTransform or not targetTransform then return end

    local gap = (opts and opts.gap) or 8
    local screenW = globals.screenWidth() or 0
    local screenH = globals.screenHeight() or 0

    local tooltipW = tooltipTransform.actualW or 0
    local tooltipH = tooltipTransform.actualH or 0
    local anchorX = targetTransform.actualX or 0
    local anchorY = targetTransform.actualY or 0
    local anchorW = targetTransform.actualW or 0
    local anchorH = targetTransform.actualH or 0

    local x = anchorX + anchorW + gap
    local y = anchorY + anchorH * 0.5 - tooltipH * 0.5

    if x + tooltipW > screenW - gap then
        x = math.max(gap, screenW - tooltipW - gap)
    end

    if y < gap then
        y = gap
    elseif y + tooltipH > screenH - gap then
        y = math.max(gap, screenH - tooltipH - gap)
    end

    tooltipTransform.actualX = x
    tooltipTransform.actualY = y
    tooltipTransform.visualX = x
    tooltipTransform.visualY = y
end

-- to decide which trigger+action board set is active
board_sets = {}
current_board_set_index = 1

local reevaluateDeckTags -- forward declaration; defined after deck helpers

local function notifyDeckChanged(boardEntityID)
    if not boardEntityID or not board_sets or #board_sets == 0 then return end

    for _, boardSet in ipairs(board_sets) do
        if boardSet.action_board_id == boardEntityID or boardSet.trigger_board_id == boardEntityID then
            if reevaluateDeckTags then
                reevaluateDeckTags()
            end
            return
        end
    end
end

-- keep track of controller focus
controller_focused_entity = nil

-- shop system state
local shop_system_initialized = false
local shop_board_id = nil
local shop_buy_board_id = nil
local active_shop_instance = nil
local AVATAR_PURCHASE_COST = 10
local ensureShopSystemInitialized -- forward declaration so planning init can ensure metadata before card spawn
_G.AVATAR_PURCHASE_COST = AVATAR_PURCHASE_COST
local shop_overlay_layout = {
    margin = 14,
    pad = 10,
    rowH = 22,
    panelW = 420
}
local tryPurchaseShopCard -- forward declaration
local setPlanningPeekMode -- forward declaration
local togglePlanningPeek -- forward declaration


local dash_sfx_list               = {
    "dash_1",
    "dash_2",
    "dash_3",
    "dash_4",
    "dash_5",
    "dash_6",
    "dash_7",
}

local DASH_COOLDOWN_SECONDS       = 2.0 -- how long before the next dash is available
local DASH_LENGTH_SEC             = 0.5 -- how long a single dash lasts
local DASH_BUFFER_WINDOW          = 0.15 -- grace window for queuing a dash near the end of dash/cooldown
local DASH_COYOTE_WINDOW          = 0.1  -- leniency to allow a dash slightly before cooldown fully ends
local STAMINA_TICKER_LINGER       = 1.0 -- how long the stamina bar lingers after refilling
local ENEMY_HEALTH_BAR_LINGER     = 2.0 -- how long enemy health bars stay visible after a hit
local DAMAGE_NUMBER_LIFETIME            = 1.35 -- seconds to keep a floating damage number around
local DAMAGE_NUMBER_VERTICAL_SPEED      = 60   -- initial upward velocity of a damage number
local DAMAGE_NUMBER_HORIZONTAL_JITTER   = 14   -- horizontal scatter when spawning a damage number
local DAMAGE_NUMBER_GRAVITY             = 28   -- downward accel that eases the rise of the numbers
local DAMAGE_NUMBER_FONT_SIZE           = 22

local playerDashCooldownRemaining = 0
local playerDashTimeRemaining     = 0
local dashBufferTimer             = 0
local bufferedDashDir             = nil
local playerIsDashing             = false
local playerStaminaTickerTimer    = 0

local function lerp(a, b, t)
    return a + (b - a) * t
end

local enemyHealthUiState          = {}                                 -- eid -> { actor=<combat actor>, visibleUntil=<time> }
local combatActorToEntity         = setmetatable({}, { __mode = "k" }) -- combat actor -> eid (weak keys so actors can be GCd)
local damageNumbers               = {}                                 -- active floating damage numbers

local function isLevelUpModalActive()
    return LevelUpScreen and LevelUpScreen.isActive
end

local function isCardOverCapacity(cardScript, cardEntityID)
    if not cardScript then return false end

    local boardEntity = cardScript.currentBoardEntity
    if not boardEntity or not entity_cache.valid(boardEntity) then return false end

    -- inventory boards have no capacity cap
    if boardEntity == inventory_board_id or boardEntity == trigger_inventory_board_id then
        return false
    end

    local board = boards[boardEntity]
    if not board or not board.cards then return false end

    local cardEid = cardEntityID
    if (not cardEid) and cardScript.handle then
        cardEid = cardScript:handle()
    end

    local cardIndex = nil
    for i, cardInBoard in ipairs(board.cards) do
        if cardInBoard == cardEid then
            cardIndex = i
            break
        end
    end
    if not cardIndex then return false end

    local maxCapacity = 1 -- default for trigger boards
    if board_sets then
        for _, boardSet in ipairs(board_sets) do
            if boardSet.action_board_id == boardEntity then
                if boardSet.wandDef and boardSet.wandDef.total_card_slots then
                    maxCapacity = boardSet.wandDef.total_card_slots
                end
                break
            end
        end
    end

    return cardIndex > maxCapacity
end

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

    notifyDeckChanged(boardEntityID)
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

    notifyDeckChanged(boardEntityID)
end

-- Moves all selected cards from the inventory board to the current set's action board.
function sendSelectedInventoryCardsToActiveActionBoard()
    if not inventory_board_id or inventory_board_id == entt_null or not entity_cache.valid(inventory_board_id) then
        return false
    end

    local inventoryBoard = boards[inventory_board_id]
    if not inventoryBoard or not inventoryBoard.cards or #inventoryBoard.cards == 0 then
        return false
    end

    local activeSet = board_sets and board_sets[current_board_set_index]
    if not activeSet or not activeSet.action_board_id or not entity_cache.valid(activeSet.action_board_id) then
        return false
    end

    local moved = false
    for i = #inventoryBoard.cards, 1, -1 do
        local cardEid = inventoryBoard.cards[i]
        if cardEid and entity_cache.valid(cardEid) then
            local script = getScriptTableFromEntityID(cardEid)
            if script and script.selected then
                removeCardFromBoard(cardEid, inventory_board_id)
                addCardToBoard(cardEid, activeSet.action_board_id)
                script.selected = false
                moved = true
            end
        end
    end

    return moved
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
    local board = BoardType {}

    ------------------------------------------------------------
    -- Swap positions between a selected card and its neighbor
    ------------------------------------------------------------

    board.z_orders = { bottom = z_orders.card, top = z_orders.card + 1000 } -- save specific z orders for the card in the board.
    board.z_order_cache_per_card = {}                                       -- cache for z orders per card entity id.
    board.cards = {}                                                        -- no starting cards

    board:attach_ecs { create_new = true }
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

        timer.tween_fields(duration * 0.3, self,
            { radius = math.sqrt(globals.screenWidth() ^ 2 + globals.screenHeight() ^ 2) }, Easing.inOutCubic.f, nil,
            "transition_circle_expand", "ui")

        -- spawn text in center after duration * 0.1, scaling up from 0 to 1 in duration * 0.2 (tween cubic).
        timer.after(duration * 0.05, function()
            timer.tween_fields(duration * 0.2, self, { textScale = 1.0 }, Easing.inOutCubic.f, nil,
                "transition_text_scale_up", "ui")
        end, "transition_text_delay", "ui")

        -- at duration * 0.7, start shrinking circle back to center.
        timer.after(duration * 0.7, function()
            timer.tween_fields(duration * 0.3, self, { radius = 0 }, Easing.inOutCubic.f, nil, "transition_circle_shrink",
                "ui")
        end, "transition_circle_shrink_delay", "ui")

        timer.after(duration * 0.8, function()
            playSoundEffect("effects", "transition_whoosh_out", 1.0)
        end, "transition_sound_delay", "ui")

        -- at duration 0.9, scale text back down to 0.
        timer.after(duration * 0.9, function()
            timer.tween_fields(duration * 0.1, self, { textScale = 0.0 }, Easing.inOutCubic.f, nil,
                "transition_text_scale_down", "ui")
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

    local transition = TransitionType {}
        :attach_ecs { create_new = true }
        :addStateTag(PLANNING_STATE)
        :addStateTag(ACTION_STATE)
        :addStateTag(SHOP_STATE) -- make them function in all states
        :destroy_when(function(self, eid) return self.age >= self.duration end)
end

function transitionGoldInterest(duration, startingGold, interestEarned)
    local TransitionType = Node:extend()

    TransitionType.age = 0
    TransitionType.duration = duration or 1.35
    TransitionType.radius = 0
    TransitionType.textScale = 0
    TransitionType.centerX = globals.screenWidth() * 0.5
    TransitionType.centerY = globals.screenHeight() * 0.5
    TransitionType.color = util.getColor("black")
    TransitionType.accent = util.getColor("gold")
    TransitionType.startingGold = math.floor(startingGold or globals.currency or 0)
    TransitionType.interest = math.floor(interestEarned or 0)
    TransitionType.displayGold = TransitionType.startingGold
    TransitionType.targetGold = TransitionType.startingGold + TransitionType.interest
    TransitionType.interestPulse = 0
    TransitionType.title = "Banked gold"

    function TransitionType:init()
        local maxRadius = math.sqrt(globals.screenWidth() ^ 2 + globals.screenHeight() ^ 2)

        timer.tween_fields(self.duration * 0.28, self,
            { radius = maxRadius }, Easing.outCubic.f, nil, "gold_transition_expand", "ui")

        timer.tween_fields(self.duration * 0.24, self, { textScale = 1.0 }, Easing.outBack.f, nil,
            "gold_transition_text", "ui")

        timer.tween_fields(self.duration * 0.55, self, { displayGold = self.targetGold }, Easing.inOutQuad.f, nil,
            "gold_transition_count", "ui")

        timer.after(self.duration * 0.42, function()
            self.interestPulse = 1.0
            if self.interest > 0 and playSoundEffect then
                playSoundEffect("effects", "gold-gain", 1.0)
            end
        end, "gold_transition_ping", "ui")

        timer.after(self.duration * 0.7, function()
            timer.tween_fields(self.duration * 0.26, self, { radius = 0, textScale = 0.0 }, Easing.inOutCubic.f, nil,
                "gold_transition_shrink", "ui")
        end, "gold_transition_shrink_delay", "ui")

        if playSoundEffect then
            playSoundEffect("effects", "transition_whoosh", 0.9)
        end
    end

    function TransitionType:update(dt)
        self.age = self.age + dt
        self.interestPulse = math.max(0, self.interestPulse - dt * 3.0)

        local alpha = 1.0
        if self.age > self.duration * 0.8 then
            alpha = math.max(0, 1 - (self.age - self.duration * 0.8) / (self.duration * 0.2))
        end

        command_buffer.queueDrawCenteredEllipse(layers.sprites, function(c)
            c.x = self.centerX
            c.y = self.centerY
            c.rx = self.radius
            c.ry = self.radius
            c.color = Col(self.color.r, self.color.g, self.color.b, math.floor(235 * alpha))
        end, z_orders.ui_transition, layer.DrawCommandSpace.Screen)

        local font = localization.getFont()
        local labelSize = 20 * self.textScale
        local amountSize = 46 * self.textScale
        local interestSize = (24 + self.interestPulse * 6) * self.textScale

        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = self.title
            c.font = font
            c.x = self.centerX - localization.getTextWidthWithCurrentFont(self.title, labelSize, 1) * 0.5
            c.y = self.centerY - 64 * self.textScale
            c.color = Col(self.accent.r, self.accent.g, self.accent.b, 220)
            c.fontSize = labelSize
        end, z_orders.ui_transition + 1, layer.DrawCommandSpace.Screen)

        local amountText = tostring(math.floor(self.displayGold + 0.5))
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = amountText
            c.font = font
            c.x = self.centerX - localization.getTextWidthWithCurrentFont(amountText, amountSize, 1) * 0.5
            c.y = self.centerY - amountSize * 0.5
            c.color = self.accent
            c.fontSize = amountSize
        end, z_orders.ui_transition + 1, layer.DrawCommandSpace.Screen)

        local interestLabel = string.format("+%d interest", self.interest)
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = interestLabel
            c.font = font
            c.x = self.centerX - localization.getTextWidthWithCurrentFont(interestLabel, interestSize, 1) * 0.5
            c.y = self.centerY + 24 * self.textScale - self.interestPulse * 6
            c.color = Col(self.accent.r, self.accent.g, self.accent.b, 220)
            c.fontSize = interestSize
        end, z_orders.ui_transition + 1, layer.DrawCommandSpace.Screen)
    end

    local transition = TransitionType {}
        :attach_ecs { create_new = true }
        :addStateTag(PLANNING_STATE)
        :addStateTag(ACTION_STATE)
        :addStateTag(SHOP_STATE)
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



    timer.run(function()
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

            local statsToDraw = { "card_id", "type", "max_uses", "mana_cost", "damage", "damage_type", "radius_of_effect",
                "spread_angle", "projectile_speed", "lifetime", "cast_delay", "recharge_time", "timer_ms" }

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

                -- Overheat Visualization
                if WandExecutor and WandExecutor.wandStates then
                    local wandState = WandExecutor.wandStates[currentWandDef.id]
                    if wandState and wandState.currentMana < 0 then
                        command_buffer.queueDrawText(layers.sprites, function(c)
                            c.text = localization.get("ui.wand_overheat")
                            c.font = localization.getFont()
                            c.x = currentX
                            c.y = currentY + lineHeight
                            c.color = util.getColor("RED")
                            c.fontSize = STAT_FONT_SIZE * 1.5
                        end, z_orders.card_text, layer.DrawCommandSpace.World)

                        -- Draw deficit
                        command_buffer.queueDrawText(layers.sprites, function(c)
                            c.text = localization.get("ui.wand_flux_deficit",
                                { amount = string.format("%.1f", math.abs(wandState.currentMana)) })
                            c.font = localization.getFont()
                            c.x = currentX
                            c.y = currentY + lineHeight * 2.5
                            c.color = util.getColor("ORANGE")
                            c.fontSize = STAT_FONT_SIZE
                        end, z_orders.card_text, layer.DrawCommandSpace.World)
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
        true        -- use animation, not sprite identifier, if false
    )

    -- give card state tag
    add_state_tag(card, gameStateToApply or PLANNING_STATE)
    remove_default_state_tag(card)

    -- give a script table
    local CardType = Node:extend()
    local cardScript = CardType {}

    -- cardScript.isStackable = isStackable or false -- whether this card can be stacked on other cards, default true

    -- save category and id
    cardScript.category = category
    cardScript.cardID = id or "unknown"
    cardScript.selected = false

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
    cardScript:attach_ecs { create_new = false, existing_entity = card }

    -- add to cards table
    cards[cardScript:handle()] = cardScript

    -- if card update timer doens't exist, add it.
    if not timer.get_timer_and_delay("card_render_timer") then
        timer.run(function()
                -- log_debug("Card Render Timer Tick")
                -- tracy.zoneBeginN("Card Render Timer Tick") -- just some default depth to avoid bugs
                -- bail if not shop or planning state
                if not is_state_active(PLANNING_STATE) and not is_state_active(SHOP_STATE) then
                    return
                end

                local dt = (GetFrameTime and GetFrameTime()) or 0.016

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
                                log_debug("Card", eid, "is being dragged, forcing z to", zToUse, "from",
                                    layer_order_system.getZIndex(eid))
                            end

                            -- animate shop buy affordance
                            local revealTarget = 0
                            if is_state_active(SHOP_STATE) and cardScript.shop_slot then
                                revealTarget = cardScript.selected and 1 or 0
                            end
                            cardScript.shopBuyReveal = lerp(cardScript.shopBuyReveal or 0, revealTarget,
                                math.min(1.0, dt * 8.0))

                            -- check if card is over capacity on its board
                            local isOverCapacity = isCardOverCapacity(cardScript, eid)
                            cardScript.isDisabled = isOverCapacity

                            if cardScript.shop_slot and cardScript.shopBuyReveal and cardScript.shopBuyReveal > 0.02 and
                                is_state_active(SHOP_STATE) then
                                local btnWidth = t.actualW * 0.9
                                local btnHeight = math.max(22, math.min(t.actualH * 0.36, 46))
                                local slide = (1 - cardScript.shopBuyReveal) * (btnHeight + 6)
                                local centerX = t.actualX + t.actualW * 0.5
                                local centerY = t.actualY - btnHeight * 0.5 + slide

                                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                                    c.x = centerX
                                    c.y = centerY
                                    c.w = btnWidth
                                    c.h = btnHeight
                                    c.rx = 12
                                    c.ry = 12
                                    c.color = Col(20, 24, 32, 215)
                                    c.outlineColor = util.getColor("apricot_cream")
                                end, math.max(0, zToUse - 1), layer.DrawCommandSpace.World)

                                local buyLabel = string.format("BUY %dg", math.floor((cardScript.shop_cost or 0) + 0.5))
                                command_buffer.queueDrawText(layers.sprites, function(c)
                                    c.text = buyLabel
                                    c.font = localization.getFont()
                                    c.x = centerX - localization.getTextWidthWithCurrentFont(buyLabel, 22, 1) * 0.5
                                    c.y = centerY - 10
                                    c.color = util.getColor("apricot_cream")
                                    c.fontSize = 22
                                end, zToUse, layer.DrawCommandSpace.World)
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

                                -- if over capacity, gray overlay + disabled marker
                                if isOverCapacity and not cardScript.isBeingDragged then
                                    local xSize = math.min(t.actualW, t.actualH) * 0.6
                                    local centerX = t.actualW * 0.5
                                    local centerY = t.actualH * 0.5
                                    local thickness = 8
                                    local xColor = util.getColor("red")

                                    command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                                        c.x = centerX
                                        c.y = centerY
                                        c.w = t.actualW
                                        c.h = t.actualH
                                        c.rx = 12
                                        c.ry = 12
                                        c.color = Col(18, 20, 24, 180)
                                    end, zToUse + 1, layer.DrawCommandSpace.World)

                                    -- draw diagonal line from top-left to bottom-right
                                    command_buffer.queueDrawLine(layers.sprites, function(c)
                                        c.x1 = centerX - xSize * 0.5
                                        c.y1 = centerY - xSize * 0.5
                                        c.x2 = centerX + xSize * 0.5
                                        c.y2 = centerY + xSize * 0.5
                                        c.color = xColor
                                        c.lineWidth = thickness
                                    end, zToUse + 2, layer.DrawCommandSpace.World)

                                    -- draw diagonal line from top-right to bottom-left
                                    command_buffer.queueDrawLine(layers.sprites, function(c)
                                        c.x1 = centerX + xSize * 0.5
                                        c.y1 = centerY - xSize * 0.5
                                        c.x2 = centerX - xSize * 0.5
                                        c.y2 = centerY + xSize * 0.5
                                        c.color = xColor
                                        c.lineWidth = thickness
                                    end, zToUse + 2, layer.DrawCommandSpace.World)
                                end

                                -- if it's controller_focused_entity, draw moving dashed outline
                                if eid == controller_focused_entity then
                                    local thickness = 10
                                    command_buffer.queueDrawDashedRoundedRect(layers.sprites, function(c)
                                        c.rec       = Rectangle.new(
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
            nil,                -- no onComplete
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
        cardW, -- width
        cardH  -- height
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
        if is_state_active and is_state_active(SHOP_STATE) and cardScript.shop_slot then
            if cardScript.selected then
                tryPurchaseShopCard(cardScript)
            else
                cardScript.selected = true
            end
            return
        end

        cardScript.selected = not cardScript.selected
    end

    nodeComp.methods.onHover = function()
        log_debug("card onHover called for", card)
        -- get script
        local hoveredCardScript = getScriptTableFromEntityID(card)
        if not hoveredCardScript then return end

        local isDisabled = isCardOverCapacity(hoveredCardScript, card)
        hoveredCardScript.isDisabled = isDisabled

        local cardDef = WandEngine.card_defs[hoveredCardScript.cardID] or WandEngine.trigger_card_defs[hoveredCardScript.cardID] or hoveredCardScript
        local tooltipOpts = nil
        if isDisabled then
            tooltipOpts = { status = "disabled", statusColor = "red" }
        end

        local tooltip = ensureCardTooltip(cardDef, tooltipOpts)
        if not tooltip then
            return
        end
        centerTooltipAboveEntity(tooltip, card, 12)
        -- hide any other tooltips before showing this one
        for _, tooltipEntity in pairs(card_tooltip_cache) do
            if tooltipEntity ~= tooltip then
                ui.box.ClearStateTagsFromUIBox(tooltipEntity)
            end
        end
        for _, tooltipEntity in pairs(card_tooltip_disabled_cache) do
            if tooltipEntity ~= tooltip then
                ui.box.ClearStateTagsFromUIBox(tooltipEntity)
            end
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

function setUpScrollingBackgroundSprites()
    local gridSpacingX     = 700
    local gridSpacingY     = 700
    local scrollSpeedX     = 50
    local scrollSpeedY     = -40
    local spriteName       = "light_03.png"
    local scale            = 1
    local tint             = Col(255, 255, 255, 255)

    local bgSprites        = {}
    local screenW, screenH = globals.screenWidth(), globals.screenHeight()

    -- extend bounds by one screen in all directions
    local startX           = -screenW
    local endX             = screenW * 2
    local startY           = -screenH
    local endY             = screenH * 2

    for gx = startX, endX, gridSpacingX do
        for gy = startY, endY, gridSpacingY do
            table.insert(bgSprites, { x = gx, y = gy })
        end
    end

    timer.every(0.016, function()
        local dt = 0.016

        for _, s in ipairs(bgSprites) do
            s.x = s.x + scrollSpeedX * dt
            s.y = s.y + scrollSpeedY * dt

            -- wrap horizontally
            if s.x > endX + gridSpacingX * 0.5 then
                s.x = s.x - (endX - startX + gridSpacingX)
            elseif s.x < startX - gridSpacingX * 0.5 then
                s.x = s.x + (endX - startX + gridSpacingX)
            end

            -- wrap vertically
            if s.y > endY + gridSpacingY * 0.5 then
                s.y = s.y - (endY - startY + gridSpacingY)
            elseif s.y < startY - gridSpacingY * 0.5 then
                s.y = s.y + (endY - startY + gridSpacingY)
            end


            command_buffer.queueDrawSpriteCentered(layers.sprites, function(c)
                c.spriteName = spriteName
                c.x = s.x
                c.y = s.y
                c.dstW = nil
                c.dstH = nil
                c.tint = tint
            end, z_orders.background, layer.DrawCommandSpace.World)
        end
    end)
end

function addPulseEffectBehindCard(cardEntityID, startColor, endColor)
    if not cardEntityID or cardEntityID == entt_null or not entity_cache.valid(cardEntityID) then return end
    local cardTransform = component_cache.get(cardEntityID, Transform)
    if not cardTransform then return end


    -- create a new object for a pulsing rectangle that fades out in color over time, then destroys itself.
    local PulseObjectType = Node:extend()

    PulseObjectType.lifetime = 0.3
    PulseObjectType.age = 0.0
    PulseObjectType.cardEntityID = cardEntityID
    PulseObjectType.startColor = startColor
    PulseObjectType.endColor = endColor

    function PulseObjectType:update(dt)
        local addedScaleAmount = 0.3

        self.age = self.age + dt

        -- make scale & alpha based on age
        local alpha = 1.0 - Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
        local scale = 1.0 + addedScaleAmount * Easing.outQuart.f(math.min(1.0, self.age / self.lifetime))
        local e = math.min(1.0, self.age / self.lifetime)

        local fromColor = self.startColor or util.getColor("yellow")
        local toColor = self.endColor or util.getColor("black")

        -- interpolate per channel
        local r = lerp(fromColor.r, toColor.r, e)
        local g = lerp(fromColor.g, toColor.g, e)
        local b = lerp(fromColor.b, toColor.b, e)
        local a = lerp(fromColor.a or 255, 0, e)

        -- make sure they're integers
        r = math.floor(r + 0.5)
        g = math.floor(g + 0.5)
        b = math.floor(b + 0.5)
        a = math.floor(a + 0.5)

        command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
            local t = component_cache.get(self.cardEntityID, Transform)
            c.x = t.actualX + t.actualW * 0.5
            c.y = t.actualY + t.actualH * 0.5
            c.w = t.actualW * scale
            c.h = t.actualH * scale
            c.rx = 15
            c.ry = 15
            c.color = Col(r, g, b, a)
        end, z_orders.card - 1, layer.DrawCommandSpace.World)
    end

    local pulseObject = PulseObjectType {}
        :attach_ecs { create_new = true }
        :destroy_when(function(self, eid) return self.age >= self.lifetime end)

    -- add planning state tag after clearing all tags
    clear_state_tags(pulseObject:handle())
    add_state_tag(pulseObject:handle(), PLANNING_STATE)
end

function slowTime(duration, targetTimeScale)
    main_loop.data.timescale = targetTimeScale or 0.2   -- slow to 20%, then over X seconds, tween back to 1.0
    timer.tween_scalar(
        duration or 1.0,                                -- duration in seconds
        function() return main_loop.data.timescale end, -- getter
        function(v) main_loop.data.timescale = v end,   -- setter
        1.0                                             -- target value
    )
end

function killPlayer()
    -- slow time using main_loop.data.timeScale


    main_loop.data.timescale = 0.15                     -- slow to 15%, then over X seconds, tween back to 1.0
    timer.tween(
        1.0,                                            -- duration in seconds
        function() return main_loop.data.timescale end, -- getter
        function(v) main_loop.data.timescale = v end,   -- setter
        1.0                                             -- target value
    )

    -- destroy the entity, get particles flying.

    timer.after(0.01, function()
        local transform = component_cache.get(survivorEntity, Transform)

        -- create a note that draws a red circle where the player was and removes itself after 0.1 second
        local DeathCircleType = Node:extend()
        local playerX = transform.actualX + transform.actualW * 0.5
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

        local deathCircle = DeathCircleType {}
        deathCircle.lifetime = 0.1
        deathCircle.age = 0.0


        deathCircle:attach_ecs { create_new = true }
        deathCircle:destroy_when(function(self, eid) return self.age >= self.lifetime end)

        spawnCircularBurstParticles(
            transform.visualX + transform.actualW * 0.5,
            transform.visualY + transform.actualH * 0.5,
            8,                     -- count
            0.9,                   -- seconds
            util.getColor("blue"), -- start color
            util.getColor("red"),  -- end color
            "outCubic",            -- from util.easing
            "world"                -- screen space
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

    local node = BulletType {}
    node.lifetime = 2.0
    node.age = 0.0

    node:attach_ecs { create_new = true }
    node:destroy_when(function(self, eid) return self.age >= self.lifetime end)

    -- give transform
    local centerX = playerTransform.actualX + playerTransform.actualW * 0.5 - bulletSize * 0.5
    local centerY = playerTransform.actualY + playerTransform.actualH * 0.5 - bulletSize * 0.5
    transform.CreateOrEmplace(registry, globals.gameWorldContainerEntity(), centerX, centerY, bulletSize, bulletSize,
        node:handle())

    -- give physics.

    local world = PhysicsManager.get_world("world")

    local info = { shape = "circle", tag = "bullet", sensor = false, density = 1.0, inflate_px = -4 } -- default tag is "WORLD"
    physics.create_physics_for_transform(registry,
        physics_manager_instance,                                                                     -- global instance
        node:handle(),                                                                                -- entity id
        "world",                                                                                      -- physics world identifier
        info
    )

    -- give bullet state
    add_state_tag(node:handle(), ACTION_STATE)

    -- collision mask
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "enemy", { "bullet" })
    physics.enable_collision_between_many(PhysicsManager.get_world("world"), "bullet", { "enemy" })
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "enemy", { "bullet" })
    physics.update_collision_masks_for(PhysicsManager.get_world("world"), "bullet", { "enemy" })

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

    local fireMarkNode = FireMarkType {}
    fireMarkNode.lifetime = 0.1
    fireMarkNode.age = 0.0

    fireMarkNode:attach_ecs { create_new = true }
    fireMarkNode:destroy_when(function(self, eid) return self.age >= self.lifetime end)
end

function spawnRandomTrapHazard()
    local playerTransform = component_cache.get(survivorEntity, Transform)

    -- make animated object
    local hazard = animation_system.createAnimatedObjectWithTransform(
        "b3997.png", -- animation ID
        true         -- use animation, not sprite identifier, if false
    )

    -- give state tag
    add_state_tag(hazard, ACTION_STATE)

    -- resize
    animation_system.resizeAnimationObjectsInEntityToFit(
        hazard,
        32 * 2, -- width
        32 * 2  -- height
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
        physics_manager_instance,                                                                              -- global instance
        hazard,                                                                                                -- entity id
        "world",                                                                                               -- physics world identifier
        info
    )


    local node = Node {}
    node.lifetime = 8.0 --TODO: base lifetime on some kind of stat, maybe?
    node.age = 0.0
    node.update = function(self, dt)
        self.age = self.age + dt
    end

    node:attach_ecs { create_new = false, existing_entity = hazard }
    node:destroy_when(function(self, eid) return self.age >= self.lifetime end)
end

function applyPlayerStrengthBonus()
    playSoundEffect("effects", "strength_bonus", 0.9 + math.random() * 0.2)

    local playerTransform = component_cache.get(survivorEntity, Transform)

    -- make a node
    local node = Node {}
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
    node:attach_ecs { create_new = true }
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
        0,         -- infinite repetitions
        false,     -- don't start immediately
        nil,       -- no after callback
        timer_name -- name of the timer (so we can check if it exists later
    )
end

-- generic weapon def, creatures must have this to deal damage.

local basic_monster_weapon = {
    id = 'basic_monster_weapon',
    slot = 'sword1',
    -- requires = { attribute = 'cunning', value = 12, mode = 'sole' },
    mods = {
        { stat = 'weapon_min', base = 6 },
        { stat = 'weapon_max', base = 10 },
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
        CombatSystem.Game.Effects.deal_damage { weapon = true, scale_pct = 100 } (combat_context, enemyCombatTable,
            playerCombatTable)

        -- pull player hp spring
        if hpBarScaleSpringEntity and entity_cache.valid(hpBarScaleSpringEntity) then
            local hpBarSpringRef = spring.get(registry, hpBarScaleSpringEntity)
            if hpBarSpringRef then
                hpBarSpringRef:pull(0.15, 120.0, 14.0)
            end
        end
    end

    if signal.exists("on_bump_enemy") == false then
        signal.register(
            "on_bump_enemy",
            on_bump_enemy_handler
        )
    end

    -- check the trigger board
    timer.run(
        function()
            -- bail if not in action state
            if not is_state_active(PLANNING_STATE) then return end

            for triggerBoardID, actionBoardID in pairs(trigger_board_id_to_action_board_id) do
                if triggerBoardID and triggerBoardID ~= entt_null and entity_cache.valid(triggerBoardID) then
                    local triggerBoard = boards[triggerBoardID]
                    -- log_debug("checking trigger board:", triggerBoardID, "contains", triggerBoard and triggerBoard.cards and #triggerBoard.cards or 0, "cards")
                    if triggerBoard and triggerBoard.cards and #triggerBoard.cards > 0 then
                        local triggerCardEid = triggerBoard.cards[1]
                        if triggerCardEid and triggerCardEid ~= entt_null and entity_cache.valid(triggerCardEid) then
                            local triggerCardScript = getScriptTableFromEntityID(triggerCardEid)

                            -- we have a trigger card in the board. we need to assemble a deck of action cards from the action board, and execute them based on the trigger type.

                            -- for now, just make sure that timer is running.
                            if timer.get_delay("trigger_simul_timer") == nil then
                                -- this timer will provide visual feedback for any of the cards which are active.
                                timer.every(
                                    1.0, -- timing may need to change if there are many cards.
                                    function()
                                        -- bail if current action board has no cards
                                        local currentSet = board_sets[current_board_set_index]
                                        if not currentSet then
                                            CastExecutionGraphUI.clear()
                                            return
                                        end
                                        local actionBoardID = currentSet.action_board_id
                                        if not actionBoardID or actionBoardID == entt_null or not entity_cache.valid(actionBoardID) then
                                            CastExecutionGraphUI.clear()
                                            return
                                        end
                                        local actionBoard = boards[actionBoardID]
                                        if not actionBoard or not actionBoard.cards or #actionBoard.cards == 0 then
                                            CastExecutionGraphUI.clear()
                                            return
                                        end

                                        local triggerBoardScript = getScriptTableFromEntityID(currentSet
                                            .trigger_board_id)
                                        log_debug("trigger_simul_timer fired for action board:", actionBoardID)
                                        log_debug("action board has", #actionBoard.cards, "cards")
                                        log_debug("Now simulating wand", currentSet.wandDef.id) -- wand def is stored in the set

                                        -- run the simulation, then take the return value to pulse the cards that would be fired.

                                        local deck = {}
                                        for _, cardEid in ipairs(actionBoard.cards) do
                                            local cardScript = getScriptTableFromEntityID(cardEid)
                                            if cardScript then
                                                table.insert(deck, cardScript)
                                            end
                                        end

                                        -- print deck
                                        for i, card in ipairs(deck) do
                                            log_debug(" - deck card", i, ":", card.cardID)
                                        end

                                        local simulatedResult = WandEngine.simulate_wand(currentSet.wandDef, deck)

                                        if simulatedResult and simulatedResult.blocks then
                                            CastExecutionGraphUI.render(simulatedResult.blocks,
                                                { wandId = currentSet.wandDef.id, title = "Execution Preview" })
                                        else
                                            CastExecutionGraphUI.clear()
                                            return
                                        end

                                        local pitchToUse = 0.7
                                        local castSequenceID = tostring(actionBoardID) ..
                                            "_" .. tostring(os.clock()) .. "_" .. tostring(math.random(1000000))

                                        -- inspect the cast blocks. for each block, pulse the corresponding cards.
                                        for blockIdx, castBlock in ipairs(simulatedResult.blocks) do
                                            log_debug(" - cast block", blockIdx, "type:", castBlock.type)
                                            

                                            -- Use card_delays for precise timing
                                            for cardIdx, delayInfo in ipairs(castBlock.card_delays) do
                                                local card = delayInfo.card
                                                local cumulativeDelay = delayInfo.cumulative_delay /
                                                    1000.0 -- Convert ms to seconds
                                                local timerTag = "cast_block_" ..
                                                    castSequenceID .. "_block" .. blockIdx .. "_card" .. cardIdx

                                                timer.after(
                                                    cumulativeDelay,
                                                    function()
                                                        log_debug("   - Firing card:", card.cardID, "at", cumulativeDelay,
                                                            "seconds")
                                                        local cardTransform = component_cache.get(card:handle(),
                                                            Transform)
                                                        if cardTransform then
                                                            cardTransform.visualS = 1.5
                                                            playSoundEffect("effects", "planning_card_activation",
                                                                0.8 + math.random() * 0.4 + pitchToUse)
                                                            pitchToUse = pitchToUse + 0.05

                                                            -- pulse the card
                                                            addPulseEffectBehindCard(card:handle(),
                                                                util.getColor("red"), util.getColor("black"))
                                                        end
                                                    end,
                                                    timerTag
                                                )
                                            end

                                            -- TODO: use total_cast_delay and total_recharge_time to determine wand visual activation.
                                        end
                                    end,
                                    0,
                                    false,
                                    nil,
                                    "trigger_simul_timer"
                                )
                            end

                            -- if triggerCardScript and triggerCardScript.cardID == "every_N_seconds" then
                            --     local timerName = "every_N_seconds_trigger_" .. tostring(triggerBoardID)
                            --     if not timer.get_timer_and_delay(timerName) then
                            --         startTriggerNSecondsTimer(triggerBoardID, actionBoardID, timerName)
                            --     end
                            -- end

                            --

                            -- bump enemy. if signal not registered, register it.
                        end
                    end
                end
            end
        end
    )
end

-- modular creation of trigger + action board sets
function createTriggerActionBoardSet(x, y, triggerWidth, actionWidth, height, padding)
    local set                   = {}

    -- Trigger board
    local triggerBoardID        = createNewBoard(x, y, triggerWidth, height)
    local triggerBoard          = boards[triggerBoardID]
    triggerBoard.noDashedBorder = true
    triggerBoard.borderColor    = util.getColor("cyan")

    triggerBoard.textEntity     = ui.definitions.getNewDynamicTextEntry(
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
    local actionBoardX                                                      = x + triggerWidth + padding
    local actionBoardID                                                     = createNewBoard(actionBoardX, y, actionWidth,
        height)
    local actionBoard                                                       = boards[actionBoardID]
    actionBoard.noDashedBorder                                              = true
    actionBoard.borderColor                                                 = util.getColor("apricot_cream")

    actionBoard.textEntity                                                  = ui.definitions.getNewDynamicTextEntry(
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

    trigger_board_id_to_action_board_id[triggerBoardID]                    = actionBoardID

    -- Store as a set
    set.trigger_board_id                                                   = triggerBoardID
    set.action_board_id                                                    = actionBoardID
    set.text_entities                                                      = { triggerBoard.textEntity, actionBoard
        .textEntity }

    -- also add to boards
    boards[triggerBoardID]                                                 = triggerBoard
    boards[actionBoardID]                                                  = actionBoard

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

            -- apply to text entity
            add_state_tag(triggerBoard.textEntity, stateTagToApply)
            remove_state_tag(triggerBoard.textEntity, PLANNING_STATE)
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

    local globalFontSize = tooltipStyle.fontSize
    local noShadowAttr   = ";shadow=false"

    -- Helper function to check if value should be excluded
    local function shouldExclude(value)
        if value == nil then return true end
        if value == -1 then return true end
        if type(value) == "number" and value == 0 then return true end
        if type(value) == "string" and (value == "N/A" or value == "NONE") then return true end
        return false
    end

    -- Helper function to add a line if value is not excluded
    local function addLine(lines, label, value, valueFormatter)
        if shouldExclude(value) then return end
        local formattedValue = valueFormatter and valueFormatter(value) or tostring(value)
        table.insert(lines,
            "[" .. label .. "](background=" .. tooltipStyle.labelBg .. ";color=" .. tooltipStyle.labelColor ..
            ";fontSize=" .. globalFontSize .. noShadowAttr .. ") [" ..
            formattedValue .. "](color=" .. tooltipStyle.valueColor .. ";fontSize=" .. globalFontSize .. noShadowAttr ..
            ")")
    end

    local lines = {}

    addLine(lines, "type", wand_def.type)
    addLine(lines, "cast block size", wand_def.cast_block_size)
    addLine(lines, "cast delay", wand_def.cast_delay)
    addLine(lines, "recharge", wand_def.recharge_time)
    addLine(lines, "spread", wand_def.spread_angle)
    addLine(lines, "shuffle", wand_def.shuffle, function(v) return v and "on" or "off" end)
    addLine(lines, "total slots", wand_def.total_card_slots)

    -- Handle always_cast_cards specially
    if wand_def.always_cast_cards and #wand_def.always_cast_cards > 0 then
        addLine(lines, "always casts", table.concat(wand_def.always_cast_cards, ", "))
    end

    local text = table.concat(lines, "\n")
    local textDef = ui.definitions.getTextFromString(text)

    local idText = ui.definitions.getTextFromString("[id: " .. tostring(wand_def.id) .. "](background=" ..
        tooltipStyle.idBg .. ";color=" .. (tooltipStyle.idTextColor or tooltipStyle.labelColor) .. ";fontSize=" .. globalFontSize .. noShadowAttr ..
        ")")

    local v = dsl.vbox {
        config = { align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            color = tooltipStyle.innerColor,
            padding = tooltipStyle.innerPadding },
        children = {
            dsl.hbox { config = { align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER) },
                children = { idText } },
            dsl.hbox { config = { align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER) },
                children = { textDef } }
        }
    }

    local root = dsl.root {
        config = {
            color = tooltipStyle.bgColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            padding = tooltipStyle.innerPadding,
            outlineThickness = 2,
            outlineColor = tooltipStyle.outlineColor,
            shadow = true,
        },
        children = { v } }

    local boxID = dsl.spawn({ x = 200, y = 200 }, root)

    ui.box.RenewAlignment(registry, boxID)
    ui.box.set_draw_layer(boxID, "ui")

    ui.box.AssignStateTagsToUIBox(boxID, PLANNING_STATE)
    remove_default_state_tag(boxID)

    return boxID
end

function makeCardTooltip(card_def, opts)
    if not card_def then
        card_def = CardTemplates.ACTION_BASIC_PROJECTILE
    end

    opts = opts or {}

    local cardId = card_def.id or card_def.cardID
    local globalFontSize = tooltipStyle.fontSize
    local noShadowAttr   = ";shadow=false"
    local labelColumnMinWidth = tooltipStyle.labelColumnMinWidth
    local valueColumnMinWidth = tooltipStyle.valueColumnMinWidth
    local rowPadding = tooltipStyle.rowPadding
    local outerPadding = tooltipStyle.innerPadding

    -- Helper function to check if value should be excluded
    local function shouldExclude(value)
        if value == nil then return true end
        if value == -1 then return true end
        if type(value) == "number" and value == 0 then return true end
        if type(value) == "string" and value == "N/A" then return true end
        return false
    end

    local function makeLabelNode(label, opts)
        opts = opts or {}
        local background = opts.background or tooltipStyle.labelBg
        local color = opts.color or tooltipStyle.labelColor
        local labelDef = ui.definitions.getTextFromString("[" .. label .. "](background=" .. background .. ";color=" .. color .. ";fontSize=" .. globalFontSize .. noShadowAttr .. ")")
        return dsl.hbox {
            config = {
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                padding = 0,
                minWidth = labelColumnMinWidth
            },
            children = { labelDef }
        }
    end

    local function makeValueNode(value, opts)
        opts = opts or {}
        local valueColor = opts.color or tooltipStyle.valueColor
        local valueDef = ui.definitions.getTextFromString("[" .. tostring(value) .. "](color=" .. valueColor .. ";fontSize=" .. globalFontSize .. noShadowAttr .. ")")
        return dsl.hbox {
            config = {
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                padding = 0,
                minWidth = valueColumnMinWidth
            },
            children = { valueDef }
        }
    end

    -- Helper function to add a line if value is not excluded
    local function addLine(rows, label, value, labelOpts, valueOpts)
        if shouldExclude(value) then return end
        table.insert(rows, dsl.hbox {
            config = {
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                padding = rowPadding
            },
            children = {
                makeLabelNode(label, labelOpts),
                makeValueNode(value, valueOpts)
            }
        })
    end

    local rows = {}

    if cardId then
        local idPill = ui.definitions.getTextFromString("[id: " .. tostring(cardId) .. "](background=" ..
            tooltipStyle.idBg .. ";color=" .. (tooltipStyle.idTextColor or tooltipStyle.labelColor) .. ";fontSize=" .. globalFontSize ..
            noShadowAttr .. ")")
        table.insert(rows, dsl.hbox {
            config = {
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                padding = rowPadding
            },
            children = { idPill }
        })
    end

    if opts.status then
        addLine(rows, "status", opts.status, { background = "dim_gray", color = "white" },
            { color = opts.statusColor or "red" })
    end

    -- Always show ID and type
    addLine(rows, "type", card_def.type)
    addLine(rows, "max uses", card_def.max_uses)
    addLine(rows, "mana cost", card_def.mana_cost)
    addLine(rows, "damage", card_def.damage)
    addLine(rows, "damage type", card_def.damage_type)
    addLine(rows, "radius of effect", card_def.radius_of_effect)
    addLine(rows, "spread angle", card_def.spread_angle)
    addLine(rows, "projectile speed", card_def.projectile_speed)
    addLine(rows, "lifetime", card_def.lifetime)
    addLine(rows, "cast delay", card_def.cast_delay)
    addLine(rows, "recharge", card_def.recharge_time)
    addLine(rows, "spread modifier", card_def.spread_modifier)
    addLine(rows, "speed modifier", card_def.speed_modifier)
    addLine(rows, "lifetime modifier", card_def.lifetime_modifier)
    addLine(rows, "crit chance mod", card_def.critical_hit_chance_modifier)
    addLine(rows, "weight", card_def.weight)

    local rarityColors = {
        common = "gray",
        uncommon = "green",
        rare = "blue",
        legendary = "purple"
    }
    local tagColors = {
        brute = "red",
        tactical = "cyan",
        mobility = "orange",
        defense = "green",
        hazard = "brown",
        elemental = "blue"
    }

    local assignment = nil
    if CardRarityTags and CardRarityTags.cardAssignments then
        assignment = CardRarityTags.cardAssignments[cardId]
    end
    if not assignment and CardRarityTags and CardRarityTags.triggerAssignments then
        assignment = CardRarityTags.triggerAssignments[cardId]
    end

    if assignment then
        local pillDefs = {}
        if assignment.rarity then
            local rarity = tostring(assignment.rarity)
            local rarityBg = rarityColors[rarity] or tooltipStyle.idBg
            table.insert(pillDefs, ui.definitions.getTextFromString(
                "[" .. rarity .. "](background=" .. rarityBg .. ";color=white;fontSize=" .. globalFontSize ..
                    noShadowAttr .. ")"))
        end
        if assignment.tags and #assignment.tags > 0 then
            for _, tag in ipairs(assignment.tags) do
                local tagBg = tagColors[tag] or "dim_gray"
                table.insert(pillDefs, ui.definitions.getTextFromString(
                    "[" .. tostring(tag) .. "](background=" .. tagBg .. ";color=white;fontSize=" .. globalFontSize ..
                        noShadowAttr .. ")"))
            end
        end
        if #pillDefs > 0 then
            table.insert(rows, dsl.hbox {
                config = {
                    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                    padding = rowPadding
                },
                children = pillDefs
            })
        end
    end

    local v = dsl.vbox {
        config = {
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            color = tooltipStyle.innerColor,
            padding = outerPadding
        },
        children = rows
    }

    local root = dsl.root {
        config = {
            color = tooltipStyle.bgColor,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            padding = outerPadding,
            outlineThickness = 2,
            outlineColor = tooltipStyle.outlineColor,
            shadow = true
        },
        children = { v }
    }

    local boxID = dsl.spawn({ x = 200, y = 200 }, root)

    ui.box.set_draw_layer(boxID, "ui")
    ui.box.RenewAlignment(registry, boxID)
    -- ui.box.AssignStateTagsToUIBox(boxID, PLANNING_STATE)
    ui.box.ClearStateTagsFromUIBox(boxID) -- remove all state tags from sub entities and box
    -- remove_default_state_tag(boxID)

    return boxID
end

function ensureCardTooltip(card_def, opts)
    if not card_def then return nil end

    local cardId = card_def.id or card_def.cardID
    if not cardId then return nil end

    local cache = card_tooltip_cache
    if opts and opts.status then
        cache = card_tooltip_disabled_cache
    end

    if cache[cardId] then return cache[cardId] end

    local tooltip = makeCardTooltip(card_def, opts)
    cache[cardId] = tooltip

    layer_order_system.assignZIndexToEntity(
        tooltip,
        z_orders.ui_tooltips
    )

    local t = component_cache.get(tooltip, Transform)
    if t then
        t.actualY = globals.screenHeight() * 0.5 - (t.actualH * 0.5)
        t.visualY = t.actualY
    end

    clear_state_tags(tooltip)
    return tooltip
end

-- initialize the game area for planning phase, where you combine cards and stuff.
function initPlanningPhase()
    
    ensureShopSystemInitialized() -- make sure card defs carry metadata/tags before any cards spawn
    local CastFeedUI = require "ui.cast_feed_ui"
    CastFeedUI.init()
    SubcastDebugUI.init()
    MessageQueueUI.init()
    CurrencyDisplay.init({ amount = globals.currency or 0 })
    TagSynergyPanel.init({
        breakpoints = TagEvaluator.get_breakpoints(),
        layout = { marginX = 24, marginTop = 18, panelWidth = 360 }
    })
    AvatarJokerStrip.init({ margin = 20 })
    
    MessageQueueUI.enqueueTest()
    
    timer.run(function()
        local dt = GetFrameTime()

        if CastFeedUI and is_state_active and (is_state_active(PLANNING_STATE) or is_state_active(ACTION_STATE)) then
            CastFeedUI.update(dt)
            CastFeedUI.draw()
        end

        -- if MessageQueueUI and is_state_active and (is_state_active(PLANNING_STATE) or is_state_active(ACTION_STATE)) then
            MessageQueueUI.update(dt)
            MessageQueueUI.draw()
        -- end

        if WandCooldownUI and is_state_active and is_state_active(ACTION_STATE) then
            WandCooldownUI.update(dt)
            WandCooldownUI.draw()
        end

        if CastBlockFlashUI and CastBlockFlashUI.isActive and is_state_active and is_state_active(ACTION_STATE) then
            CastBlockFlashUI.update(dt)
            CastBlockFlashUI.draw()
        end

        if CurrencyDisplay and CurrencyDisplay.isActive and is_state_active
            and (is_state_active(PLANNING_STATE) or is_state_active(SHOP_STATE)) then
            CurrencyDisplay.setAmount(globals.currency or 0)
            CurrencyDisplay.update(dt)
            CurrencyDisplay.draw()
        end

        if TagSynergyPanel and TagSynergyPanel.isActive and is_state_active
            and is_state_active(PLANNING_STATE) then
            TagSynergyPanel.update(dt)
            TagSynergyPanel.draw()
        end

        if AvatarJokerStrip and AvatarJokerStrip.isActive and is_state_active
            and (is_state_active(PLANNING_STATE) or is_state_active(ACTION_STATE) or is_state_active(SHOP_STATE)) then
            local playerTarget = nil
            if getTagEvaluationTargets then
                playerTarget = select(1, getTagEvaluationTargets())
            end
            AvatarJokerStrip.syncFrom(playerTarget)
            AvatarJokerStrip.update(dt)
            AvatarJokerStrip.draw()
        end

        if SubcastDebugUI and is_state_active and is_state_active(ACTION_STATE) then
            SubcastDebugUI.update(dt)
            SubcastDebugUI.draw()
        end

        if LevelUpScreen and LevelUpScreen.isActive then
            LevelUpScreen.update(dt)
            LevelUpScreen.draw()
        end
    end)

    -- let's bind d-pad input to switch between cards, and A to select.
    input.bind("controller-navigation-planning-select", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN, -- A button
        trigger = "Pressed",                                   -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                             -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-up", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP, -- D-pad up
        trigger = "Pressed",                                -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                          -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-down", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN, -- D-pad down
        trigger = "Pressed",                                  -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                            -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-left", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_LEFT, -- D-pad left
        trigger = "Pressed",                                  -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                            -- we'll use this context for planning phase only
    })

    input.bind("controller-navigation-planning-right", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_RIGHT, -- D-pad right
        trigger = "Pressed",                                   -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                             -- we'll use this context for planning phase only
    })

    input.bind("controller-navigation-planning-right-bumper", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_RIGHT_TRIGGER_1, -- D-pad right
        trigger = "Pressed",                                   -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                             -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-left-bumper", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_TRIGGER_1, -- D-pad right
        trigger = "Pressed",                                  -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                            -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-left-trigger", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_LEFT_TRIGGER_2, -- D-pad right
        trigger = "Pressed",                                  -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                            -- we'll use this context for planning phase only
    })
    input.bind("controller-navigation-planning-right-trigger", {
        device = "gamepad_button",
        button = GamepadButton.GAMEPAD_BUTTON_RIGHT_TRIGGER_2, -- D-pad right
        trigger = "Pressed",                                   -- or "Threshold" if your system uses analog triggers
        context = "planning-phase"                             -- we'll use this context for planning phase only
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

    local cardsToChange = {}

    for cardID, cardDef in pairs(catalog) do
        local card = createNewCard(cardID, 4000, 4000, PLANNING_STATE) -- offscreen for now

        table.insert(cardsToChange, card)

        -- add to navigation group as well.
        controller_nav.ud:add_entity("planning-phase", card)

        controller_nav.validate()          -- validate the nav system after setting up bindings and layers.
        controller_nav.debug_print_state() -- print state for debugging.
        controller_nav.focus_entity(card)  -- focus the newly created card.
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
                t.visualY = targetY - 100               -- start offscreen slightly above wanted pos
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

    local screenW = globals.screenWidth()
    local screenH = globals.screenHeight()

    -- Leave space for the synergy panel on the right during planning.
    local synergyPanelReserve = 300
    if TagSynergyPanel and TagSynergyPanel.layout then
        local layout = TagSynergyPanel.layout
        synergyPanelReserve = math.max(synergyPanelReserve, (layout.panelWidth or 0) + (layout.marginX or 0))
    end

    boardHeight = screenH / 5
    local planningRegionWidth = math.max(0, screenW - synergyPanelReserve)
    boardPadding = planningRegionWidth * 0.1 / 3
    local actionBoardWidth = planningRegionWidth * 0.7
    local triggerBoardWidth = planningRegionWidth * 0.2

    local boardSetTotalWidth = triggerBoardWidth + actionBoardWidth + boardPadding
    local runningYValue = boardPadding
    local leftAlignValueTriggerBoardX = math.max(boardPadding, (planningRegionWidth - boardSetTotalWidth) * 0.5)
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
                    c.x         = area.actualX + area.actualW * 0.5
                    c.y         = area.actualY + area.actualH * 0.5
                    c.w         = math.max(0, area.actualW)
                    c.h         = math.max(0, area.actualH)
                    c.rx        = 10
                    c.ry        = 10
                    c.color     = self.borderColor or util.getColor("yellow")
                    c.lineWidth = 5
                end, z_orders.board, layer.DrawCommandSpace.World)
                goto continue
            end
            command_buffer.queueDrawDashedRoundedRect(layers.sprites, function(c)
                c.rec       = Rectangle.new(
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

    local triggerInventoryWidth  = planningRegionWidth * 0.2
    local triggerInventoryHeight = (screenH - runningYValue) * 0.4

    local inventoryBoardWidth    = planningRegionWidth * 0.65
    local inventoryBoardHeight   = triggerInventoryHeight
    local boardPadding           = boardPadding or 20 -- just in case

    -- Center both panels as a group
    local totalWidth             = triggerInventoryWidth + boardPadding + inventoryBoardWidth
    local offsetX                = (planningRegionWidth - totalWidth) / 2

    -- Left (trigger) panel
    local triggerInventoryX      = offsetX
    local triggerInventoryY      = runningYValue + boardPadding * 2

    -- Right (inventory) panel
    local inventoryBoardX        = triggerInventoryX + triggerInventoryWidth + boardPadding
    local inventoryBoardY        = triggerInventoryY

    -- Create
    local inventoryBoardID       = createNewBoard(inventoryBoardX, inventoryBoardY, inventoryBoardWidth,
        inventoryBoardHeight)
    local inventoryBoard         = boards[inventoryBoardID]
    inventoryBoard.borderColor   = util.getColor("white")
    inventoryBoard.isInventoryBoard = true
    inventory_board_id           = inventoryBoardID


    -- give a text label above the board
    inventoryBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.inventory_area") end, -- initial text
        20.0,                                                        -- font size
        "color=apricot_cream"                                        -- animation spec
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
    transform.AssignRole(registry, inventoryBoard.textEntity, InheritedPropertiesType.PermanentAttachment,
        inventoryBoard:handle(),
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

    -- Send selected inventory cards up to the active action board.
    local sendUpButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.send_up") end, -- initial text
        18.0,
        "color=apricot_cream"
    )

    local canSendInventorySelection

    local sendUpButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
            :addId("inventory_send_up_button")
            :addColor(util.getColor("gray"))
            :addPadding(10.0)
            :addEmboss(2.0)
            :addHover(true)
            :addButtonCallback(function()
                if canSendInventorySelection and not canSendInventorySelection() then
                    return
                end
                local moved = sendSelectedInventoryCardsToActiveActionBoard()
                if moved then
                    playSoundEffect("effects", "card_put_down_3", 0.9 + math.random() * 0.2)
                end
            end)
            :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
            :build()
        )
        :addChild(sendUpButtonText)
        :build()

    local sendUpRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
            :addColor(util.getColor("blank"))
            :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
            :build()
        )
        :addChild(sendUpButtonTemplate)
        :build()

    local sendUpMargin = boardPadding * 0.25

    planningUIEntities.send_up_button_box = ui.box.Initialize(
        { x = inventoryBoardX + inventoryBoardWidth * 0.5, y = inventoryBoardY + inventoryBoardHeight + sendUpMargin },
        sendUpRoot
    )

    ui.box.RenewAlignment(registry, planningUIEntities.send_up_button_box)
    local sendUpBoxTransform = component_cache.get(planningUIEntities.send_up_button_box, Transform)
    local inventoryTransform = inventoryBoard and inventoryBoard:handle() and component_cache.get(inventoryBoard:handle(),
        Transform)

    local function recenterSendUpButton()
        if not sendUpBoxTransform or not inventoryTransform then return end
        sendUpBoxTransform.actualX = inventoryTransform.actualX + (inventoryTransform.actualW * 0.5) -
                                         (sendUpBoxTransform.actualW * 0.5)
        sendUpBoxTransform.actualY = inventoryTransform.actualY + inventoryTransform.actualH + sendUpMargin
        sendUpBoxTransform.visualX = sendUpBoxTransform.actualX
        sendUpBoxTransform.visualY = sendUpBoxTransform.actualY
        ui.box.RenewAlignment(registry, planningUIEntities.send_up_button_box)
    end

    recenterSendUpButton()
    timer.after(0, recenterSendUpButton, nil, nil, "send_up_button_recentering")

    ui.box.AssignStateTagsToUIBox(planningUIEntities.send_up_button_box, PLANNING_STATE)
    remove_default_state_tag(planningUIEntities.send_up_button_box)

    local sendUpButtonEntity = ui.box.GetUIEByID(registry, "inventory_send_up_button")
    planningUIEntities.send_up_button = sendUpButtonEntity

    -- Helper used by both UI state and button callback.
    function canSendInventorySelection()
        if not inventoryBoard or not inventoryBoard.cards then
            return false
        end

        local hasSelection = false
        for _, cardEid in ipairs(inventoryBoard.cards) do
            local script = getScriptTableFromEntityID(cardEid)
            if script and script.selected then
                hasSelection = true
                break
            end
        end

        local activeSet = board_sets and board_sets[current_board_set_index]
        local hasDestination = activeSet and activeSet.action_board_id and entity_cache.valid(activeSet.action_board_id)
        return hasSelection and hasDestination
    end

    local lastDisabledState = nil
    local function updateSendUpButtonState()
        if not sendUpButtonEntity or not entity_cache.valid(sendUpButtonEntity) then return end
        if not is_state_active or not is_state_active(PLANNING_STATE) then return end

        local disabled = not canSendInventorySelection()
        if disabled == lastDisabledState then return end
        lastDisabledState = disabled

        local config = component_cache.get(sendUpButtonEntity, UIConfig)
        if config then
            config.disable_button = disabled
        end

        local go = component_cache.get(sendUpButtonEntity, GameObject)
        if go then
            go.state.hoverEnabled = true
            go.state.collisionEnabled = true
            go.state.clickEnabled = true
        end
    end

    timer.run(function()
        updateSendUpButtonState()
    end, nil, "inventory_send_up_button_state")


    -- -------------------------------------------------------------------------- --
    --       make a separate trigger inventory on the left of the inventory.      --
    -- --------------------------------------------------------------------------

    local triggerInventoryBoardID = createNewBoard(triggerInventoryX, triggerInventoryY, triggerInventoryWidth,
        triggerInventoryHeight)
    local triggerInventoryBoard = boards[triggerInventoryBoardID]
    triggerInventoryBoard.borderColor = util.getColor("cyan")
    trigger_inventory_board_id = triggerInventoryBoardID -- save in global

    -- give a text label above the board
    triggerInventoryBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.trigger_inventory_area") end, -- initial text
        20.0,                                                                -- font size
        "color=cyan"                                                         -- animation spec
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
    transform.AssignRole(registry, triggerInventoryBoard.textEntity, InheritedPropertiesType.PermanentAttachment,
        triggerInventoryBoard:handle(),
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

        boardSet.wandDef = WandEngine.wand_defs[indexToUse]

        -- inject the def with the trigger board's entity id

        boardSet.wandDef = util.deep_copy(WandEngine.wand_defs[indexToUse]) -- make a copy to avoid mutating original
        boardSet.wandDef.trigger_board_entity = boardSet.trigger_board_id
        boardSet.wandDef.action_board_entity = boardSet.action_board_id
    end

    local function addCardTooltip(cardDef)
        ensureCardTooltip(cardDef)
    end

    -- for each card, make a tooltip
    for id, cardDef in pairs(WandEngine.card_defs) do
        addCardTooltip(cardDef)
    end

    -- ensure trigger cards get tooltips too
    for id, cardDef in pairs(WandEngine.trigger_card_defs or {}) do
        addCardTooltip(cardDef)
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

local function formatDamageNumber(amount)
    if not amount then return "0" end
    if amount >= 10 then
        return string.format("%.0f", amount)
    end
    return string.format("%.1f", amount)
end

local function pickDamageColor(amount)
    -- Damage above zero → opaque red, non-damage/zero → white
    if amount and amount > 0 then
        return { r = 255, g = 70, b = 70, a = 255 }
    end
    return { r = 255, g = 255, b = 255, a = 255 }
end

local function spawnDamageNumber(targetEntity, amount, isCrit)
    if not targetEntity or not entity_cache.valid(targetEntity) then return end
    if not amount then return end

    local t = component_cache.get(targetEntity, Transform)
    if not t then return end

    local spawnX = t.actualX + t.actualW * 0.5 + (math.random() - 0.5) * DAMAGE_NUMBER_HORIZONTAL_JITTER
    local spawnY = t.actualY - 10

    damageNumbers[#damageNumbers + 1] = {
        x        = spawnX,
        y        = spawnY,
        vx       = (math.random() - 0.5) * (DAMAGE_NUMBER_HORIZONTAL_JITTER * 0.8),
        vy       = -(DAMAGE_NUMBER_VERTICAL_SPEED + math.random() * 20),
        life     = DAMAGE_NUMBER_LIFETIME,
        age      = 0,
        text     = formatDamageNumber(amount),
        crit     = isCrit or false,
        fontSize = DAMAGE_NUMBER_FONT_SIZE,
        color    = pickDamageColor(amount),
    }
end

function initCombatSystem()
    -- init combat system.

    local combatBus                    = CombatSystem.Core.EventBus.new()
    local combatTime                   = CombatSystem.Core.Time.new()
    local combatStatDefs, DAMAGE_TYPES = CombatSystem.Core.StatDef.make()
    local combatBundle                 = CombatSystem.Game.Combat.new(CombatSystem.Core.RR, DAMAGE_TYPES) -- carries RR + DAMAGE_TYPES; stored on ctx.combat



    combat_context     = {
        stat_defs    = combatStatDefs, -- definitions for stats in this combat
        DAMAGE_TYPES = DAMAGE_TYPES,   -- damage types available in this combat
        _make_actor  = make_actor,     -- Factory for creating actors
        debug        = true,           -- verbose debug prints across systems
        bus          = combatBus,      -- shared event bus for this arena
        time         = combatTime,     -- shared clock for statuses/DoTs/cooldowns
        combat       = combatBundle    -- optional bundle for RR+damage types, if needed
    }

    local ctx          = combat_context

    -- add side-aware accessors to ctx
    -- Used by targeters and AI; these close over 'ctx' (safe here).
    ctx.get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end
    ctx.get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end

    --TODO: probably make separate enemy creation functions for each enemy type.

    -- Hero baseline: some OA/Cunning/Spirit, crit damage, CDR, cost reduction, and atk/cast speed.
    local hero         = make_actor('Hero', combatStatDefs, CombatSystem.Game.Content.attach_attribute_derivations)
    hero.side          = 1
    hero.level_curve   = 'fast_start'
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
    ogre.stats:add_base('damage_taken_reduction_pct', 2000) -- stress test: massive DR → negative damage (healing)
    ogre.stats:recompute()

    ctx.side1 = { hero }
    ctx.side2 = { ogre }

    -- store in player entity for easy access later
    assert(survivorEntity and entity_cache.valid(survivorEntity), "Survivor entity is not valid in combat system init!")
    local playerScript        = getScriptTableFromEntityID(survivorEntity)
    playerScript.combatTable  = hero
    combatActorToEntity[hero] = survivorEntity

    -- attach defs/derivations to ctx for easy access later for pets
    ctx._defs                 = combatStatDefs
    ctx._attach               = CombatSystem.Game.Content.attach_attribute_derivations
    ctx._make_actor           = make_actor

    -- subscribe to events.
    ctx.bus:on('OnLevelUp', function()
        -- send player level up signal.
        signal.emit("player_level_up")
    end)
    ctx.bus:on('OnHitResolved', function(ev)
        local targetEntity = combatActorToEntity[ev.target]
        if targetEntity and enemyHealthUiState[targetEntity] then
            enemyHealthUiState[targetEntity].visibleUntil = GetTime() + ENEMY_HEALTH_BAR_LINGER
        end
        if targetEntity then
            spawnDamageNumber(targetEntity, ev.damage or 0, ev.crit)
        end
    end)

    -- make springs for exp bar and hp bar SCALE (for undulation effect)
    expBarScaleSpringEntity, expBarScaleSpringRef = spring.make(registry, 1.0, 120.0, 14.0, {
        target = 1.0,
        smoothingFactor = 0.9,
        preventOvershoot = false,
        maxVelocity = 10.0
    })
    hpBarScaleSpringEntity, hpBarScaleSpringRef = spring.make(registry, 1.0, 120.0, 14.0, {
        target = 1.0,
        smoothingFactor = 0.9,
        preventOvershoot = false,
        maxVelocity = 10.0
    })

    -- make springs for the main XP bar value (smooth lerping)
    expBarMainSpringEntity, expBarMainSpringRef = spring.make(registry, 0.0, 60.0, 8.0, {
        target = 0.0,
        smoothingFactor = 0.85,
        preventOvershoot = false,
        maxVelocity = 8.0
    })

    -- make springs for delayed indicator bars (white bars that catch up)
    expBarDelayedSpringEntity, expBarDelayedSpringRef = spring.make(registry, 1.0, 60.0, 8.0, {
        target = 1.0,
        smoothingFactor = 0.85,
        preventOvershoot = false,
        maxVelocity = 8.0
    })
    hpBarDelayedSpringEntity, hpBarDelayedSpringRef = spring.make(registry, 1.0, 60.0, 8.0, {
        target = 1.0,
        smoothingFactor = 0.85,
        preventOvershoot = false,
        maxVelocity = 8.0
    })

    -- Track previous values for change detection
    local prevHpPct = 1.0
    local prevXpPct = 0.0
    local movementTutorialStyle = {
        margin = 20,
        paddingX = 14,
        paddingY = 12,
        rowSpacing = 10,
        iconTextGap = 12,
        keySize = 28,
        keyGap = 4,
        spaceWidth = 80,
        spaceHeight = 24,
        stickSize = 40,
        buttonSize = 32,
        fontSize = 18,
        textColor = util.getColor("apricot_cream"),
        bgColor = Col(8, 10, 16, 170),
        outlineColor = Col(255, 255, 255, 30),
        z = z_orders.background - 1
    }

    local function measureMoveHint(isPad)
        if isPad then
            local size = movementTutorialStyle.stickSize
            return size, size
        end
        local keySize = movementTutorialStyle.keySize
        local gap = movementTutorialStyle.keyGap
        return keySize * 3 + gap * 2, keySize * 2 + gap
    end

    local function measureDashHint(isPad)
        if isPad then
            local size = movementTutorialStyle.buttonSize
            return size, size
        end
        return movementTutorialStyle.spaceWidth, movementTutorialStyle.spaceHeight
    end

    local function drawMoveHintIcons(x, y, isPad, z)
        if isPad then
            local size = movementTutorialStyle.stickSize
            command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
                c.spriteName = "xbox_stick_top_l.png"
                c.x = x
                c.y = y
                c.dstW = size
                c.dstH = size
            end, z, layer.DrawCommandSpace.Screen)
            return
        end

        local keySize = movementTutorialStyle.keySize
        local gap = movementTutorialStyle.keyGap
        local rowWidth = keySize * 3 + gap * 2
        local topX = x + (rowWidth - keySize) * 0.5
        local topY = y
        local bottomY = y + keySize + gap

        command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
            c.spriteName = "keyboard_w.png"
            c.x = topX
            c.y = topY
            c.dstW = keySize
            c.dstH = keySize
        end, z, layer.DrawCommandSpace.Screen)

        command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
            c.spriteName = "keyboard_a.png"
            c.x = x
            c.y = bottomY
            c.dstW = keySize
            c.dstH = keySize
        end, z, layer.DrawCommandSpace.Screen)

        command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
            c.spriteName = "keyboard_s.png"
            c.x = x + keySize + gap
            c.y = bottomY
            c.dstW = keySize
            c.dstH = keySize
        end, z, layer.DrawCommandSpace.Screen)

        command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
            c.spriteName = "keyboard_d.png"
            c.x = x + (keySize + gap) * 2
            c.y = bottomY
            c.dstW = keySize
            c.dstH = keySize
        end, z, layer.DrawCommandSpace.Screen)
    end

    local function drawDashHintIcon(x, y, isPad, z)
        if isPad then
            local size = movementTutorialStyle.buttonSize
            command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
                c.spriteName = "xbox_button_a.png"
                c.x = x
                c.y = y
                c.dstW = size
                c.dstH = size
            end, z, layer.DrawCommandSpace.Screen)
            return
        end

        command_buffer.queueDrawSpriteTopLeft(layers.sprites, function(c)
            c.spriteName = "keyboard_space.png"
            c.x = x
            c.y = y
            c.dstW = movementTutorialStyle.spaceWidth
            c.dstH = movementTutorialStyle.spaceHeight
        end, z, layer.DrawCommandSpace.Screen)
    end

    local function drawActionInputTutorial()
        local screenH = globals.screenHeight() or 0
        local usingPad = input and input.isPadConnected and input.isPadConnected(0)

        local moveText = "to move"
        local dashText = "to dash"
        local fontSize = movementTutorialStyle.fontSize
        local moveTextWidth = localization.getTextWidthWithCurrentFont(moveText, fontSize, 1)
        local dashTextWidth = localization.getTextWidthWithCurrentFont(dashText, fontSize, 1)

        local moveIconW, moveIconH = measureMoveHint(usingPad)
        local dashIconW, dashIconH = measureDashHint(usingPad)
        local rowSpacing = movementTutorialStyle.rowSpacing
        local row1Height = math.max(moveIconH, fontSize)
        local row2Height = math.max(dashIconH, fontSize)
        local contentWidth = math.max(
            moveIconW + movementTutorialStyle.iconTextGap + moveTextWidth,
            dashIconW + movementTutorialStyle.iconTextGap + dashTextWidth
        )
        local contentHeight = row1Height + row2Height + rowSpacing
        local panelW = contentWidth + movementTutorialStyle.paddingX * 2
        local panelH = contentHeight + movementTutorialStyle.paddingY * 2
        local startX = movementTutorialStyle.margin
        local startY = math.max(movementTutorialStyle.margin, screenH - movementTutorialStyle.margin - panelH)

        command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
            c.x = startX + panelW * 0.5
            c.y = startY + panelH * 0.5
            c.w = panelW
            c.h = panelH
            c.rx = 10
            c.ry = 10
            c.color = movementTutorialStyle.bgColor
            c.outlineColor = movementTutorialStyle.outlineColor
        end, movementTutorialStyle.z, layer.DrawCommandSpace.Screen)

        local cursorY = startY + movementTutorialStyle.paddingY
        local iconX = startX + movementTutorialStyle.paddingX

        local moveIconY = cursorY + (row1Height - moveIconH) * 0.5
        drawMoveHintIcons(iconX, moveIconY, usingPad, movementTutorialStyle.z + 1)
        local moveTextX = iconX + moveIconW + movementTutorialStyle.iconTextGap
        local moveTextY = cursorY + (row1Height - fontSize) * 0.5
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = moveText
            c.font = localization.getFont()
            c.x = moveTextX
            c.y = moveTextY
            c.color = movementTutorialStyle.textColor
            c.fontSize = fontSize
        end, movementTutorialStyle.z + 2, layer.DrawCommandSpace.Screen)

        cursorY = cursorY + row1Height + rowSpacing
        local dashIconY = cursorY + (row2Height - dashIconH) * 0.5
        drawDashHintIcon(iconX, dashIconY, usingPad, movementTutorialStyle.z + 1)
        local dashTextX = iconX + dashIconW + movementTutorialStyle.iconTextGap
        local dashTextY = cursorY + (row2Height - fontSize) * 0.5
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = dashText
            c.font = localization.getFont()
            c.x = dashTextX
            c.y = dashTextY
            c.color = movementTutorialStyle.textColor
            c.fontSize = fontSize
        end, movementTutorialStyle.z + 2, layer.DrawCommandSpace.Screen)
    end

    -- update combat system every frame / render health bars
    timer.run(
        function()
            -- bail if not in action state
            if not is_state_active(ACTION_STATE) or isLevelUpModalActive() then return end

            local frameDt = GetFrameTime()
            WandExecutor.update(frameDt)
            ctx.time:tick(frameDt)
            if playerDashCooldownRemaining > 0 then
                playerDashCooldownRemaining = math.max(playerDashCooldownRemaining - frameDt, 0)
            end
            if playerDashTimeRemaining > 0 then
                playerDashTimeRemaining = math.max(playerDashTimeRemaining - frameDt, 0)
                if playerDashTimeRemaining <= 0 then
                    playerIsDashing = false
                end
            end
            if dashBufferTimer > 0 then
                dashBufferTimer = math.max(dashBufferTimer - frameDt, 0)
                if dashBufferTimer <= 0 then
                    bufferedDashDir = nil
                end
            end
            if playerStaminaTickerTimer > 0 then
                playerStaminaTickerTimer = math.max(playerStaminaTickerTimer - frameDt, 0)
            end


            -- also, display a health bar indicator above the player entity, and an EXP bar.

            if not survivorEntity or not entity_cache.valid(survivorEntity) then
                return
            end

            local anchorTransform = component_cache.get(survivorEntity, Transform)

            if anchorTransform then
                local playerCombatInfo = ctx.side1[1]

                local playerHealth = playerCombatInfo.hp
                local playerMaxHealth = playerCombatInfo.max_health

                local playerXP = playerCombatInfo.xp or 0
                local playerXPForNextLevel = CombatSystem.Game.Leveling.xp_to_next(ctx, playerCombatInfo,
                    playerCombatInfo.level or 1)

                local hpPct = playerHealth / playerMaxHealth
                local xpPct = math.min(playerXP / playerXPForNextLevel, 1.0)

                ------------------------------------------------------------
                -- DASH STAMINA TICKER (world space, lingers after refilling)
                ------------------------------------------------------------
                if playerStaminaTickerTimer > 0 then
                    local staminaPct = 1.0
                    if playerDashCooldownRemaining > 0 then
                        staminaPct = 1.0 - (playerDashCooldownRemaining / DASH_COOLDOWN_SECONDS)
                    end
                    staminaPct          = math.max(0.0, math.min(1.0, staminaPct))

                    local visualCenterX = anchorTransform.visualX + anchorTransform.visualW * 0.5
                    local visualBottomY = anchorTransform.visualY + anchorTransform.visualH

                    local staminaWidth  = math.max(anchorTransform.visualW * 0.8, 48)
                    local staminaHeight = 6
                    local staminaX      = visualCenterX
                    local staminaY      = visualBottomY + 10

                    command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                        c.x     = staminaX
                        c.y     = staminaY
                        c.w     = staminaWidth
                        c.h     = staminaHeight
                        c.rx    = 3
                        c.ry    = 3
                        c.color = Col(20, 20, 20, 190)
                    end, z_orders.player_vfx + 1, layer.DrawCommandSpace.World)

                    local staminaFillWidth = staminaWidth * staminaPct
                    local staminaFillCenterX = (visualCenterX - staminaWidth * 0.5) + staminaFillWidth * 0.5

                    command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                        c.x              = staminaFillCenterX
                        c.y              = staminaY
                        c.w              = staminaFillWidth
                        c.h              = staminaHeight
                        c.rx             = 3
                        c.ry             = 3
                        local onCooldown = playerDashCooldownRemaining > 0
                        c.color          = onCooldown and Col(90, 180, 255, 235) or Col(90, 230, 140, 255)
                    end, z_orders.player_vfx + 2, layer.DrawCommandSpace.World)
                end

                ------------------------------------------------------------
                -- CHANGE DETECTION & SPRING UPDATES
                ------------------------------------------------------------
                local hpChanged = math.abs(hpPct - prevHpPct) > 0.001
                local xpChanged = math.abs(xpPct - prevXpPct) > 0.001

                if hpChanged then
                    -- Fetch scale spring ref
                    local hpBarScaleSpringRef = spring.get(registry, hpBarScaleSpringEntity)
                    local hpBarDelayedSpringRef = spring.get(registry, hpBarDelayedSpringEntity)

                    -- Trigger scale pulse for undulation
                    hpBarScaleSpringRef.value = 1.15
                    hpBarScaleSpringRef.targetValue = 1.0

                    if hpPct < prevHpPct then
                        -- HP decreased: delayed spring lerps down from old to new
                        hpBarDelayedSpringRef.targetValue = hpPct
                    else
                        -- HP increased: delayed spring jumps to new value
                        hpBarDelayedSpringRef.value = hpPct
                        hpBarDelayedSpringRef.targetValue = hpPct
                    end
                    prevHpPct = hpPct
                end

                if xpChanged then
                    -- Fetch scale spring ref
                    local expBarScaleSpringRef = spring.get(registry, expBarScaleSpringEntity)
                    local expBarMainSpringRef = spring.get(registry, expBarMainSpringEntity)
                    local expBarDelayedSpringRef = spring.get(registry, expBarDelayedSpringEntity)

                    -- Trigger scale pulse for undulation
                    expBarScaleSpringRef.value = 1.15
                    expBarScaleSpringRef.targetValue = 1.0

                    if xpPct < prevXpPct then
                        -- XP decreased (level up): main bar jumps to 0, white bar lerps down
                        expBarMainSpringRef.value = xpPct
                        expBarMainSpringRef.targetValue = xpPct
                        expBarDelayedSpringRef.targetValue = xpPct
                    else
                        -- XP increased: white bar jumps to new value, yellow bar lerps up
                        expBarDelayedSpringRef.value = xpPct
                        expBarDelayedSpringRef.targetValue = xpPct
                        expBarMainSpringRef.targetValue = xpPct
                    end
                    prevXpPct = xpPct
                end

                -- Fetch spring refs for rendering
                local hpBarScaleSpringRef    = spring.get(registry, hpBarScaleSpringEntity)
                local expBarScaleSpringRef   = spring.get(registry, expBarScaleSpringEntity)
                local hpBarDelayedSpringRef  = spring.get(registry, hpBarDelayedSpringEntity)
                local expBarDelayedSpringRef = spring.get(registry, expBarDelayedSpringEntity)
                local expBarMainSpringRef    = spring.get(registry, expBarMainSpringEntity)

                -- Get current spring values
                local hpScale                = hpBarScaleSpringRef.value or 1.0
                local xpScale                = expBarScaleSpringRef.value or 1.0
                local hpDelayedSpringVal     = hpBarDelayedSpringRef.value or hpPct
                local xpDelayedSpringVal     = expBarDelayedSpringRef.value or xpPct
                local xpMainSpringVal        = expBarMainSpringRef.value or xpPct

                local screenCenterX          = globals.screenWidth() * 0.5

                ------------------------------------------------------------
                -- HEALTH BAR (container only – no scaling)
                ------------------------------------------------------------
                local baseHealthBarWidth     = globals.screenWidth() * 0.4
                local baseHealthBarHeight    = 20

                local healthBarWidth         = baseHealthBarWidth
                local healthBarHeight        = baseHealthBarHeight

                local healthBarX             = screenCenterX
                local healthBarY             = healthBarHeight

                -- background container
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x     = healthBarX
                    c.y     = healthBarY + healthBarHeight * 0.5
                    c.w     = healthBarWidth
                    c.h     = healthBarHeight
                    c.rx    = 5
                    c.ry    = 5
                    c.color = util.getColor("dark_gray")
                end, z_orders.background, layer.DrawCommandSpace.Screen)

                ------------------------------------------------------------
                -- HEALTH BARS: Two bars - main (red) and delayed (white)
                -- Decrease: red moves to new value, white (behind) catches up
                -- Increase: white jumps to new value, red catches up
                -- White bar always rendered behind red bar
                ------------------------------------------------------------
                local hpDelayedPct = hpDelayedSpringVal

                -- White bar shows: max of current and delayed (so it's always the "bigger" reference)
                local hpWhitePct = math.max(hpPct, hpDelayedPct)
                -- Red bar shows: min of current and delayed (so it's always the "smaller" or actual)
                local hpRedPct = math.min(hpPct, hpDelayedPct)

                -- White bar (behind) - shows the larger value
                local fillWhiteWidth = baseHealthBarWidth * hpWhitePct
                local fillWhiteCenterX = (healthBarX - healthBarWidth * 0.5) + fillWhiteWidth * 0.5

                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x     = fillWhiteCenterX
                    c.y     = healthBarY + healthBarHeight * 0.5
                    c.w     = fillWhiteWidth
                    c.h     = healthBarHeight * hpScale
                    c.rx    = 5
                    c.ry    = 5
                    c.color = Col(255, 255, 255, 255)
                end, z_orders.background + 1, layer.DrawCommandSpace.Screen)

                -- Red bar (front) - shows the smaller/current value
                local fillRedWidth = baseHealthBarWidth * hpRedPct
                local fillRedCenterX = (healthBarX - healthBarWidth * 0.5) + fillRedWidth * 0.5

                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x     = fillRedCenterX
                    c.y     = healthBarY + healthBarHeight * 0.5
                    c.w     = fillRedWidth
                    c.h     = healthBarHeight * hpScale
                    c.rx    = 5
                    c.ry    = 5
                    c.color = util.getColor("red")
                end, z_orders.background + 2, layer.DrawCommandSpace.Screen)

                ------------------------------------------------------------
                -- EXP BAR (container only — no scaling)
                ------------------------------------------------------------
                local baseExpBarWidth  = globals.screenWidth()
                local baseExpBarHeight = 20

                local expBarWidth      = baseExpBarWidth
                local expBarHeight     = baseExpBarHeight

                local expBarX          = screenCenterX
                local expBarY          = healthBarY - expBarHeight

                -- background container
                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x     = expBarX
                    c.y     = expBarY + expBarHeight * 0.5
                    c.w     = expBarWidth
                    c.h     = expBarHeight
                    c.rx    = 5
                    c.ry    = 5
                    c.color = util.getColor("dark_gray")
                end, z_orders.background, layer.DrawCommandSpace.Screen)

                ------------------------------------------------------------
                -- EXP BARS: Two bars - main (yellow) and delayed (white)
                -- Yellow bar uses main spring (smooth lerp), white bar shows buffer
                ------------------------------------------------------------
                local xpDelayedPct = xpDelayedSpringVal
                local xpYellowPct = xpMainSpringVal

                -- White bar shows: max of main and delayed (buffer)
                local xpWhitePct = math.max(xpYellowPct, xpDelayedPct)

                -- White bar (behind) - shows the larger value
                local xpFillWhiteWidth = baseExpBarWidth * xpWhitePct
                local xpFillWhiteCenterX = (expBarX - expBarWidth * 0.5) + xpFillWhiteWidth * 0.5

                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x     = xpFillWhiteCenterX
                    c.y     = expBarY + expBarHeight * 0.5
                    c.w     = xpFillWhiteWidth
                    c.h     = expBarHeight * xpScale
                    c.rx    = 5
                    c.ry    = 5
                    c.color = Col(255, 255, 255, 255)
                end, z_orders.background + 1, layer.DrawCommandSpace.Screen)

                -- Yellow bar (front) - shows the main spring value (smooth lerp)
                local xpFillYellowWidth = baseExpBarWidth * xpYellowPct
                local xpFillYellowCenterX = (expBarX - expBarWidth * 0.5) + xpFillYellowWidth * 0.5

                command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                    c.x     = xpFillYellowCenterX
                    c.y     = expBarY + expBarHeight * 0.5
                    c.w     = xpFillYellowWidth
                    c.h     = expBarHeight * xpScale
                    c.rx    = 5
                    c.ry    = 5
                    c.color = util.getColor("yellow")
                end, z_orders.background + 2, layer.DrawCommandSpace.Screen)

                ------------------------------------------------------------
                -- ENEMY HEALTH BARS (world space, show briefly after damage)
                ------------------------------------------------------------
                local now = GetTime()
                local enemiesToRemove = nil
                for enemyEid, state in pairs(enemyHealthUiState) do
                    if not entity_cache.valid(enemyEid) then
                        enemiesToRemove = enemiesToRemove or {}
                        table.insert(enemiesToRemove, enemyEid)
                    else
                        local actor = state.actor
                        local enemyT = component_cache.get(enemyEid, Transform)
                        local maxHp = actor and (actor.max_health or (actor.stats and actor.stats:get('health')))
                        local showBar = state.visibleUntil and state.visibleUntil > now
                        if showBar and enemyT and actor and maxHp and maxHp > 0 then
                            local hpPct = math.max(0.0, math.min(1.0, (actor.hp or maxHp) / maxHp))
                            local barWidth = math.max(enemyT.actualW, 40)
                            local barHeight = 6
                            local barX = enemyT.actualX + enemyT.actualW * 0.5
                            local barY = enemyT.actualY - 8

                            command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                                c.x     = barX
                                c.y     = barY
                                c.w     = barWidth
                                c.h     = barHeight
                                c.rx    = 3
                                c.ry    = 3
                                c.color = Col(20, 20, 20, 190)
                            end, z_orders.enemies + 1, layer.DrawCommandSpace.World)

                            local hpFillWidth = barWidth * hpPct
                            local hpFillCenterX = (barX - barWidth * 0.5) + hpFillWidth * 0.5

                            command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                                c.x     = hpFillCenterX
                                c.y     = barY
                                c.w     = hpFillWidth
                                c.h     = barHeight
                                c.rx    = 3
                                c.ry    = 3
                                c.color = util.getColor("red")
                            end, z_orders.enemies + 2, layer.DrawCommandSpace.World)
                        end
                    end
                end
                if enemiesToRemove then
                    for _, eid in ipairs(enemiesToRemove) do
                        enemyHealthUiState[eid] = nil
                    end
                end

                ------------------------------------------------------------
                -- DAMAGE NUMBERS (world space, float up and fade)
                ------------------------------------------------------------
                if #damageNumbers > 0 then
                    for i = #damageNumbers, 1, -1 do
                        local dn = damageNumbers[i]
                        dn.age = (dn.age or 0) + frameDt
                        local life = dn.life or DAMAGE_NUMBER_LIFETIME

                        if dn.age >= life then
                            table.remove(damageNumbers, i)
                        else
                            dn.x = dn.x + (dn.vx or 0) * frameDt
                            dn.y = dn.y + (dn.vy or 0) * frameDt
                            dn.vy = (dn.vy or 0) + DAMAGE_NUMBER_GRAVITY * frameDt

                            local remaining = 1.0 - (dn.age / life)
                            local alpha = math.max(0.0, math.min(1.0, remaining))
                            local color = dn.color or { r = 255, g = 255, b = 255, a = 255 }
                            local scale = (dn.crit and 1.15 or 1.0) * (1.0 + 0.05 * alpha)
                            local fontSize = (dn.fontSize or DAMAGE_NUMBER_FONT_SIZE) * scale
                            local r = color.r or 255
                            local g = color.g or 255
                            local b = color.b or 255
                            local a = color.a or 255
                            local z = z_orders.enemies + 3

                            -- subtle shadow
                            command_buffer.queueDrawText(layers.sprites, function(c)
                                c.text = dn.text
                                c.font = localization.getFont()
                                c.x = dn.x + 1
                                c.y = dn.y + 1
                                c.color = Col(0, 0, 0, math.floor(180 * alpha))
                                c.fontSize = fontSize
                            end, z, layer.DrawCommandSpace.World)

                            command_buffer.queueDrawText(layers.sprites, function(c)
                                c.text = dn.text
                                c.font = localization.getFont()
                                c.x = dn.x
                                c.y = dn.y
                                c.color = Col(r, g, b, math.floor(a * alpha))
                                c.fontSize = fontSize
                            end, z + 1, layer.DrawCommandSpace.World)
                        end
                    end
                end
                -- Simple manual input tutorial (icons + text) for action phase
                drawActionInputTutorial()
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

    -- activate tooltip state
    activate_state(WAND_TOOLTIP_STATE)
end

function cycleBoardSet(targetIndex)
    if not targetIndex or not board_sets or #board_sets == 0 then return end
    local clamped = math.max(1, math.min(#board_sets, targetIndex))
    local delta = clamped - current_board_set_index
    if delta ~= 0 then
        cycleBoardSets(delta)
    end
end

local virtualCardCounter = 0

local function makeVirtualCardFromTemplate(template)
    if not template then return nil end
    virtualCardCounter = virtualCardCounter + 1
    local card = util.deep_copy(template)
    card.card_id = template.id or template.card_id
    card.type = template.type
    card._virtual_handle = "virtual_card_" .. tostring(virtualCardCounter)
    card.handle = function(self) return self._virtual_handle end
    return card
end

local function collectCardPoolForBoardSet(boardSet)
    if not boardSet then return nil end
    local actionBoard = boards[boardSet.action_board_id]
    if not actionBoard or not actionBoard.cards or #actionBoard.cards == 0 then return nil end

    local pool = {}

    local function pushCard(cardScript)
        if not cardScript then return end
        if cardScript.cardStack and #cardScript.cardStack > 0 then
            for _, modEid in ipairs(cardScript.cardStack) do
                if modEid and entity_cache.valid(modEid) then
                    local modScript = getScriptTableFromEntityID(modEid)
                    if modScript then
                        table.insert(pool, modScript)
                    end
                end
            end
        end
        table.insert(pool, cardScript)
    end

    for _, cardEid in ipairs(actionBoard.cards) do
        if cardEid and entity_cache.valid(cardEid) then
            pushCard(getScriptTableFromEntityID(cardEid))
        end
    end

    if boardSet.wandDef and boardSet.wandDef.always_cast_cards then
        for _, alwaysId in ipairs(boardSet.wandDef.always_cast_cards) do
            local template = WandEngine.card_defs[alwaysId]
            local virtualCard = makeVirtualCardFromTemplate(template)
            if virtualCard then
                table.insert(pool, virtualCard)
            end
        end
    end

    return pool
end

local tagEvaluationFallbackPlayer = { active_tag_bonuses = {}, active_procs = {} }

local function buildDeckSnapshotFromBoards()
    local cards = {}

    if board_sets then
        for _, boardSet in ipairs(board_sets) do
            local pool = collectCardPoolForBoardSet(boardSet)
            if pool then
                for _, card in ipairs(pool) do
                    cards[#cards + 1] = card
                end
            end
        end
    end

    return { cards = cards }
end

local function getTagEvaluationTargets()
    local playerScript = survivorEntity and getScriptTableFromEntityID(survivorEntity)

    if playerScript and playerScript.combatTable then
        return playerScript.combatTable, playerScript
    end

    if playerScript then
        return playerScript, playerScript
    end

    if player and type(player) == "table" then
        return player, nil
    end

    return tagEvaluationFallbackPlayer, nil
end

reevaluateDeckTags = function()
    if not board_sets or #board_sets == 0 then
        return
    end

    local deckSnapshot = buildDeckSnapshotFromBoards()
    local playerTarget, playerScript = getTagEvaluationTargets()
    if not playerTarget then return end

    TagEvaluator.evaluate_and_apply(playerTarget, deckSnapshot, combat_context)
    if TagSynergyPanel and TagSynergyPanel.isActive then
        TagSynergyPanel.setData(playerTarget.tag_counts, TagEvaluator.get_breakpoints())
    end
    if AvatarJokerStrip and AvatarJokerStrip.isActive then
        AvatarJokerStrip.syncFrom(playerTarget)
    end

    if playerScript and playerTarget ~= playerScript then
        playerScript.tag_counts = playerTarget.tag_counts
        playerScript.active_tag_bonuses = playerTarget.active_tag_bonuses
    end
end

local DEFAULT_TRIGGER_INTERVAL = 1.0

local function buildTriggerDefForBoardSet(boardSet)
    if not boardSet then return nil end
    local triggerBoard = boards[boardSet.trigger_board_id]
    if not triggerBoard or not triggerBoard.cards or #triggerBoard.cards == 0 then return nil end

    local triggerCard = getScriptTableFromEntityID(triggerBoard.cards[1])
    if not triggerCard then return nil end

    -- Trigger defs are keyed by template name (e.g., TEST_TRIGGER_*), so scan values by their .id
    local triggerTemplate
    local triggerId = triggerCard.card_id or triggerCard.cardID
    if triggerId then
        for _, template in pairs(WandEngine.trigger_card_defs) do
            if template.id == triggerId then
                triggerTemplate = template
                break
            end
        end
    end

    local triggerDef = triggerTemplate and util.deep_copy(triggerTemplate)
        or { id = triggerId or triggerCard.cardID, type = "trigger" }

    triggerDef.id = triggerDef.id or triggerCard.cardID
    triggerDef.type = triggerDef.type or "trigger"

    if triggerDef.id == "every_N_seconds" then
        triggerDef.interval = triggerDef.interval or triggerCard.interval or DEFAULT_TRIGGER_INTERVAL
    elseif triggerDef.id == "on_distance_traveled" then
        triggerDef.distance = triggerDef.distance or triggerCard.distance
    end

    return triggerDef
end

local function loadWandsIntoExecutorFromBoards()
    WandExecutor.cleanup()
    WandExecutor.init()
    virtualCardCounter = 0

    WandExecutor.getPlayerEntity = function()
        return survivorEntity
    end

    WandExecutor.createExecutionContext = function(wandId, state, activeWand)
        local ctx = BaseCreateExecutionContext(wandId, state, activeWand)
        local playerScript = survivorEntity and getScriptTableFromEntityID(survivorEntity)
        if playerScript and playerScript.combatTable and playerScript.combatTable.stats then
            ctx.playerStats = playerScript.combatTable.stats
        end
        return ctx
    end

    for index, boardSet in ipairs(board_sets) do
        local cardPool = collectCardPoolForBoardSet(boardSet)
        local triggerDef = buildTriggerDefForBoardSet(boardSet)

        if boardSet.wandDef and cardPool and #cardPool > 0 and triggerDef then
            local wandDefCopy = util.deep_copy(boardSet.wandDef)
            WandExecutor.loadWand(wandDefCopy, cardPool, triggerDef)
        else
            log_debug(string.format("Skipping wand load for set %d (cards: %s, trigger: %s)", index,
                cardPool and #cardPool or 0, triggerDef and triggerDef.id or "none"))
        end
    end

    if reevaluateDeckTags then
        reevaluateDeckTags()
    end
end

local function playStateTransition()
    transitionInOutCircle(0.6, localization.get("ui.loading_transition_text"), util.getColor("black"),
        { x = globals.screenWidth() / 2, y = globals.screenHeight() / 2 })
end

-- Phase-specific peaches background settings (action uses the default values defined in shader_uniforms).
local peaches_background_defaults = nil
local peaches_background_targets = {
    planning = {
        blob_count = 4.4,
        blob_spacing = -1.2,
        shape_amplitude = 0.14,
        distortion_strength = 2.5,
        noise_strength = 0.08,
        radial_falloff = 0.12,
        wave_strength = 1.1,
        highlight_gain = 2.6,
        cl_shift = -0.04,
        edge_softness_min = 0.45,
        edge_softness_max = 0.86,
        colorTint = { x = 0.22, y = 0.55, z = 0.78 },
        blob_color_blend = 0.55,
        hue_shift = 0.45,
        pixel_size = 5.0,
        pixel_enable = 1.0,
        blob_offset = { x = -0.05, y = -0.05 },
        movement_randomness = 7.5
    },
    shop = {
        blob_count = 6.8,
        blob_spacing = -0.4,
        shape_amplitude = 0.32,
        distortion_strength = 5.0,
        noise_strength = 0.22,
        radial_falloff = -0.15,
        wave_strength = 2.3,
        highlight_gain = 4.6,
        cl_shift = 0.18,
        edge_softness_min = 0.24,
        edge_softness_max = 0.55,
        colorTint = { x = 0.82, y = 0.50, z = 0.28 },
        blob_color_blend = 0.78,
        hue_shift = 0.05,
        pixel_size = 7.0,
        pixel_enable = 1.0,
        blob_offset = { x = 0.08, y = -0.14 },
        movement_randomness = 12.0
    }
}

local function make_vec2(x, y)
    if _G.Vector2 then
        return _G.Vector2(x, y)
    end
    return { x = x, y = y }
end

local function make_vec3(x, y, z)
    if _G.Vector3 then
        return _G.Vector3(x, y, z)
    end
    return { x = x, y = y, z = z }
end

local function copy_vec2(v)
    if not v then return { x = 0, y = 0 } end
    return { x = v.x or v[1] or 0, y = v.y or v[2] or 0 }
end

local function copy_vec3(v)
    if not v then return { x = 0, y = 0, z = 0 } end
    return { x = v.x or v[1] or 0, y = v.y or v[2] or 0, z = v.z or v[3] or 0 }
end

local function ensure_peaches_defaults()
    if peaches_background_defaults or not globalShaderUniforms then
        return peaches_background_defaults ~= nil
    end

    peaches_background_defaults = {
        blob_count = globalShaderUniforms:get("peaches_background", "blob_count") or 0.0,
        blob_spacing = globalShaderUniforms:get("peaches_background", "blob_spacing") or 0.0,
        shape_amplitude = globalShaderUniforms:get("peaches_background", "shape_amplitude") or 0.0,
        distortion_strength = globalShaderUniforms:get("peaches_background", "distortion_strength") or 0.0,
        noise_strength = globalShaderUniforms:get("peaches_background", "noise_strength") or 0.0,
        radial_falloff = globalShaderUniforms:get("peaches_background", "radial_falloff") or 0.0,
        wave_strength = globalShaderUniforms:get("peaches_background", "wave_strength") or 0.0,
        highlight_gain = globalShaderUniforms:get("peaches_background", "highlight_gain") or 0.0,
        cl_shift = globalShaderUniforms:get("peaches_background", "cl_shift") or 0.0,
        edge_softness_min = globalShaderUniforms:get("peaches_background", "edge_softness_min") or 0.0,
        edge_softness_max = globalShaderUniforms:get("peaches_background", "edge_softness_max") or 0.0,
        colorTint = copy_vec3(globalShaderUniforms:get("peaches_background", "colorTint")),
        blob_color_blend = globalShaderUniforms:get("peaches_background", "blob_color_blend") or 0.0,
        hue_shift = globalShaderUniforms:get("peaches_background", "hue_shift") or 0.0,
        pixel_size = globalShaderUniforms:get("peaches_background", "pixel_size") or 0.0,
        pixel_enable = globalShaderUniforms:get("peaches_background", "pixel_enable") or 0.0,
        blob_offset = copy_vec2(globalShaderUniforms:get("peaches_background", "blob_offset")),
        movement_randomness = globalShaderUniforms:get("peaches_background", "movement_randomness") or 0.0
    }

    peaches_background_targets.action = {
        blob_count = peaches_background_defaults.blob_count,
        blob_spacing = peaches_background_defaults.blob_spacing,
        shape_amplitude = peaches_background_defaults.shape_amplitude,
        distortion_strength = peaches_background_defaults.distortion_strength,
        noise_strength = peaches_background_defaults.noise_strength,
        radial_falloff = peaches_background_defaults.radial_falloff,
        wave_strength = peaches_background_defaults.wave_strength,
        highlight_gain = peaches_background_defaults.highlight_gain,
        cl_shift = peaches_background_defaults.cl_shift,
        edge_softness_min = peaches_background_defaults.edge_softness_min,
        edge_softness_max = peaches_background_defaults.edge_softness_max,
        colorTint = copy_vec3(peaches_background_defaults.colorTint),
        blob_color_blend = peaches_background_defaults.blob_color_blend,
        hue_shift = peaches_background_defaults.hue_shift,
        pixel_size = peaches_background_defaults.pixel_size,
        pixel_enable = peaches_background_defaults.pixel_enable,
        blob_offset = copy_vec2(peaches_background_defaults.blob_offset),
        movement_randomness = peaches_background_defaults.movement_randomness
    }

    return true
end

local function tween_peaches_scalar(name, target, duration, tag_suffix)
    if target == nil then return end
    timer.tween_scalar(
        duration,
        function() return globalShaderUniforms:get("peaches_background", name) end,
        function(v) globalShaderUniforms:set("peaches_background", name, v) end,
        target,
        Easing.inOutQuad.f,
        nil,
        "peaches_bg_" .. name .. (tag_suffix or "")
    )
end

local function tween_peaches_vec2(name, target, duration, tag_suffix)
    if not target then return end
    local baseTag = "peaches_bg_" .. name .. (tag_suffix or "")

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.x or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local y = (current and current.y) or target.y or 0
            globalShaderUniforms:set("peaches_background", name, make_vec2(v, y))
        end,
        target.x,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_x"
    )

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.y or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local x = (current and current.x) or target.x or 0
            globalShaderUniforms:set("peaches_background", name, make_vec2(x, v))
        end,
        target.y,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_y"
    )
end

local function tween_peaches_vec3(name, target, duration, tag_suffix)
    if not target then return end
    local baseTag = "peaches_bg_" .. name .. (tag_suffix or "")

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.x or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local y = (current and current.y) or target.y or 0
            local z = (current and current.z) or target.z or 0
            globalShaderUniforms:set("peaches_background", name, make_vec3(v, y, z))
        end,
        target.x,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_x"
    )

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.y or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local x = (current and current.x) or target.x or 0
            local z = (current and current.z) or target.z or 0
            globalShaderUniforms:set("peaches_background", name, make_vec3(x, v, z))
        end,
        target.y,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_y"
    )

    timer.tween_scalar(
        duration,
        function()
            local current = globalShaderUniforms:get("peaches_background", name)
            return current and current.z or 0
        end,
        function(v)
            local current = globalShaderUniforms:get("peaches_background", name)
            local x = (current and current.x) or target.x or 0
            local y = (current and current.y) or target.y or 0
            globalShaderUniforms:set("peaches_background", name, make_vec3(x, y, v))
        end,
        target.z,
        Easing.inOutQuad.f,
        nil,
        baseTag .. "_z"
    )
end

local function tween_peaches_background(targets, duration)
    if not targets or not ensure_peaches_defaults() then
        return
    end

    local dur = duration or 1.0
    tween_peaches_scalar("blob_count", targets.blob_count, dur)
    tween_peaches_scalar("blob_spacing", targets.blob_spacing, dur)
    tween_peaches_scalar("shape_amplitude", targets.shape_amplitude, dur)
    tween_peaches_scalar("distortion_strength", targets.distortion_strength, dur)
    tween_peaches_scalar("noise_strength", targets.noise_strength, dur)
    tween_peaches_scalar("radial_falloff", targets.radial_falloff, dur)
    tween_peaches_scalar("wave_strength", targets.wave_strength, dur)
    tween_peaches_scalar("highlight_gain", targets.highlight_gain, dur)
    tween_peaches_scalar("cl_shift", targets.cl_shift, dur)
    tween_peaches_scalar("edge_softness_min", targets.edge_softness_min, dur)
    tween_peaches_scalar("edge_softness_max", targets.edge_softness_max, dur)
    tween_peaches_vec3("colorTint", targets.colorTint, dur)
    tween_peaches_scalar("blob_color_blend", targets.blob_color_blend, dur)
    tween_peaches_scalar("hue_shift", targets.hue_shift, dur)
    tween_peaches_scalar("pixel_size", targets.pixel_size, dur)
    tween_peaches_scalar("pixel_enable", targets.pixel_enable, dur)
    tween_peaches_vec2("blob_offset", targets.blob_offset, dur)
    tween_peaches_scalar("movement_randomness", targets.movement_randomness, dur)
end

local function apply_peaches_background_phase(phase)
    if not globalShaderUniforms then
        return
    end
    if not ensure_peaches_defaults() then
        return
    end
    tween_peaches_background(peaches_background_targets[phase], 1.0)
end

function startActionPhase()
    clear_states() -- disable all states.
    if setPlanningPeekMode then
        setPlanningPeekMode(false)
    end

    if record_telemetry then
        local now = os.clock()
        if _G.current_phase and _G.phase_started_at then
            record_telemetry("phase_exit", {
                phase = _G.current_phase,
                duration_s = now - _G.phase_started_at,
                next_phase = "action",
                session_id = telemetry_session_id()
            })
        end
        _G.current_phase = "action"
        _G.phase_started_at = now
    end

    activate_state(ACTION_STATE)
    activate_state("default_state") -- just for defaults, keep them open

    setLowPassTarget(0.0)           -- low pass filter off

    input.set_context("gameplay")   -- set input context to action phase.

    PhysicsManager.enable_step("world", true)

    loadWandsIntoExecutorFromBoards()
    CastBlockFlashUI.init()

    playStateTransition()
    apply_peaches_background_phase("action")

    if record_telemetry then
        record_telemetry("phase_enter", { phase = "action", session_id = telemetry_session_id() })
    end

    -- fadeOutMusic("main-menu", 0.3)
    -- fadeOutMusic("shop-music", 0.3)
    -- fadeOutMusic("planning-music", 0.3)
    -- fadeInMusic("action-music", 0.6)


    -- debug

    print("States active:", is_state_active(PLANNING_STATE), is_state_active(ACTION_STATE), is_state_active(SHOP_STATE))
end

function startPlanningPhase()
	    clear_states() -- disable all states.
	    if setPlanningPeekMode then
	        setPlanningPeekMode(false)
	    end
	    WandExecutor.cleanup()
	    entity_cache.clear()
	    CastBlockFlashUI.clear()
	    SubcastDebugUI.clear()
	    SubcastDebugUI.init()

    if record_telemetry then
        local now = os.clock()
        if _G.current_phase and _G.phase_started_at then
            record_telemetry("phase_exit", {
                phase = _G.current_phase,
                duration_s = now - _G.phase_started_at,
                next_phase = "planning",
                session_id = telemetry_session_id()
            })
        end
        _G.current_phase = "planning"
        _G.phase_started_at = now
    end

    activate_state(PLANNING_STATE)
    activate_state("default_state")     -- just for defaults, keep them open

    input.set_context("planning-phase") -- set input context to planning phase.

    PhysicsManager.enable_step("world", false)

    setLowPassTarget(1.0) -- low pass fileter on

    -- fadeOutMusic("planning-music", 0.3)
    -- fadeOutMusic("main-menu", 0.3)
    -- fadeOutMusic("action-music", 0.3)
    -- fadeOutMusic("shop-music", 0.3)
    -- fadeInMusic("planning-music", 0.6)

    -- Reset camera immediately to center to fix intermittent camera positioning bug
    local cam = camera.Get("world_camera")
    if cam then
        cam:SetActualTarget(globals.screenWidth() / 2, globals.screenHeight() / 2)
    end

    playStateTransition()
    apply_peaches_background_phase("planning")

    if record_telemetry then
        record_telemetry("phase_enter", { phase = "planning", session_id = telemetry_session_id() })
    end


    -- debug

    print("States active:", is_state_active(PLANNING_STATE), is_state_active(ACTION_STATE), is_state_active(SHOP_STATE))
end

function startShopPhase()
    local preShopGold = globals.currency or 0
    local interestPreview = ShopSystem.calculateInterest(preShopGold)
    clear_states() -- disable all states.
    if setPlanningPeekMode then
        setPlanningPeekMode(false)
    end
    WandExecutor.cleanup()

    if record_telemetry then
        local now = os.clock()
        if _G.current_phase and _G.phase_started_at then
            record_telemetry("phase_exit", {
                phase = _G.current_phase,
                duration_s = now - _G.phase_started_at,
                next_phase = "shop",
                session_id = telemetry_session_id()
            })
        end
        _G.current_phase = "shop"
        _G.phase_started_at = now
    end

    activate_state(SHOP_STATE)
    activate_state("default_state") -- just for defaults, keep them open

    PhysicsManager.enable_step("world", false)

    setLowPassTarget(1.0) -- low pass fileter on

    -- fadeOutMusic("main-menu", 0.3)
    -- fadeOutMusic("action-music", 0.3)
    -- fadeOutMusic("planning-music", 0.3)
    -- fadeInMusic("shop-music", 0.6)

    -- Reset camera immediately to center to fix intermittent camera positioning bug
    local cam = camera.Get("world_camera")
    if cam then
        cam:SetActualTarget(globals.screenWidth() / 2, globals.screenHeight() / 2)
    end

    transitionGoldInterest(1.35, preShopGold, interestPreview)
    apply_peaches_background_phase("shop")

    if record_telemetry then
        record_telemetry("phase_enter", { phase = "shop", session_id = telemetry_session_id() })
    end

    regenerateShopState()


    -- debug

    print("States active:", is_state_active(PLANNING_STATE), is_state_active(ACTION_STATE), is_state_active(SHOP_STATE))
end

local lastFrame = -1

-- Debug card spawner ---------------------------------------------------------
local TESTED_CARD_IDS = {}
local cardSpawnerState = {
    built = false,
    target = "inventory",
    tested = {},
    untested = {}
}

local function rebuildCardSpawnerLists()
    local testedLookup = {}
    for _, id in ipairs(TESTED_CARD_IDS) do
        testedLookup[id] = true
    end

    cardSpawnerState.tested = {}
    cardSpawnerState.untested = {}

    local function push(def, source)
        if not def then return end
        local cid = def.id or def.card_id
        if not cid then return end
        local entry = {
            id = cid,
            name = def.name or def.test_label or cid,
            type = def.type or (source == "trigger" and "trigger") or def.category or "card",
            source = source
        }
        if testedLookup[cid] then
            table.insert(cardSpawnerState.tested, entry)
        else
            table.insert(cardSpawnerState.untested, entry)
        end
    end

    for _, def in pairs(WandEngine.card_defs or {}) do
        push(def, "card")
    end
    for _, def in pairs(WandEngine.trigger_card_defs or {}) do
        push(def, "trigger")
    end

    local function sortEntries(list)
        table.sort(list, function(a, b)
            return (a.name or a.id or "") < (b.name or b.id or "")
        end)
    end

    sortEntries(cardSpawnerState.tested)
    sortEntries(cardSpawnerState.untested)
    cardSpawnerState.built = true
end

local function resolveCardSpawnTarget(entry)
    if not entry then return nil end

    if entry.type == "trigger" then
        if trigger_inventory_board_id and entity_cache.valid(trigger_inventory_board_id) then
            return trigger_inventory_board_id
        end
        local set = board_sets and board_sets[current_board_set_index]
        if set and set.trigger_board_id and entity_cache.valid(set.trigger_board_id) then
            return set.trigger_board_id
        end
    else
        if cardSpawnerState.target == "action" then
            local set = board_sets and board_sets[current_board_set_index]
            if set and set.action_board_id and entity_cache.valid(set.action_board_id) then
                return set.action_board_id
            end
        end
        if inventory_board_id and entity_cache.valid(inventory_board_id) then
            return inventory_board_id
        end
    end

    return nil
end

local function spawnCardEntry(entry)
    if not entry or not entry.id then return end

    local boardId = resolveCardSpawnTarget(entry)
    if not boardId then
        print("[CardSpawner] No valid target board for " .. tostring(entry.id))
        return
    end

    local eid
    if entry.type == "trigger" then
        eid = createNewTriggerSlotCard(entry.id, 0, 0, PLANNING_STATE)
    else
        eid = createNewCard(entry.id, 0, 0, PLANNING_STATE)
    end

    if not eid or eid == entt_null or not entity_cache.valid(eid) then
        print("[CardSpawner] Failed to spawn " .. tostring(entry.id))
        return
    end

    local script = getScriptTableFromEntityID(eid)
    if script then
        script.category = script.category or script.type or entry.type
        script.id = script.id or entry.id
        script.card_id = script.card_id or entry.id
        CardMetadata.enrich(script)
    end

    addCardToBoard(eid, boardId)
end

local function renderCardList(entries, childId)
    if not entries then return end
    ImGui.BeginChild(childId, 0, 240, true)
    for _, entry in ipairs(entries) do
        ImGui.PushID(entry.id)
        ImGui.Text(string.format("%s (%s)", entry.name or entry.id, entry.type or "card"))
        ImGui.SameLine()
        if ImGui.Button("Spawn##" .. entry.id) then
            spawnCardEntry(entry)
        end
        ImGui.PopID()
    end
    ImGui.EndChild()
end

local function renderCardSpawnerDebugUI()
    if not ImGui or not ImGui.Begin then return end
    if not cardSpawnerState.built then
        rebuildCardSpawnerLists()
    end

    if ImGui.Begin("Card Spawner (Debug)") then
        ImGui.Text("Drop target:")
        if ImGui.Button(cardSpawnerState.target == "inventory" and "[Inventory]" or "Inventory") then
            cardSpawnerState.target = "inventory"
        end
        ImGui.SameLine()
        if ImGui.Button(cardSpawnerState.target == "action" and "[Action Board]" or "Action Board") then
            cardSpawnerState.target = "action"
        end

        ImGui.Separator()
        ImGui.Text(string.format("Untested cards (%d)", #cardSpawnerState.untested))
        renderCardList(cardSpawnerState.untested, "untested_card_list")
        ImGui.Separator()
        ImGui.Text("Tested cards")
        if #cardSpawnerState.tested == 0 then
            ImGui.Text("None marked tested yet.")
        else
            renderCardList(cardSpawnerState.tested, "tested_card_list")
        end
    end
    ImGui.End()
end

-- call every frame
function debugUI()
    -- open a window (returns shouldDraw)
    if ImGui.Begin("Quick access") then
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
        ImGui.End()
    end

    renderCardSpawnerDebugUI()
end

cardsSoldInShop = {}



local function get_mag_items(world, player, radius)
    local t = component_cache.get(player, Transform)

    local pos = { x = t.actualX + t.actualW / 2, y = t.actualY + t.actualH / 2 }

    local x1 = pos.x - radius
    local y1 = pos.y - radius
    local x2 = pos.x + radius
    local y2 = pos.y + radius

    local candidates = physics.GetObjectsInArea(world, x1, y1, x2, y2)
    local result = {}

    for _, e in ipairs(candidates) do
        if entity_cache.valid(e) then
            local ipos = physics.GetPosition(world, e)
            local dx = ipos.x - pos.x
            local dy = ipos.y - pos.y
            if (dx * dx + dy * dy) <= radius * radius then
                table.insert(result, e)
            end
        end
    end

    return result
end

function createJointedMask(parentEntity, worldName)
    local world = PhysicsManager.get_world(worldName)

    -- Create mask entity with physics
    local maskEntity = animation_system.createAnimatedObjectWithTransform(
        "b6813.png",
        true
    )

    -- Position at parent's head
    local parentT = component_cache.get(parentEntity, Transform)
    local maskT = component_cache.get(maskEntity, Transform)

    local headOffsetY = -parentT.actualH * 0.3
    maskT.actualX = parentT.actualX + parentT.actualW / 2 - maskT.actualW / 2
    maskT.actualY = parentT.actualY + headOffsetY
    maskT.visualX = maskT.actualX
    maskT.visualY = maskT.actualY

    -- Give mask physics (dynamic body)
    physics.create_physics_for_transform(
        registry,
        physics_manager_instance,
        maskEntity,
        worldName,
        {
            shape = "rectangle",
            tag = "mask",
            sensor = true,
            density = 0.0 -- Light weight
        }
    )

    physics.SetBodyType(world, maskEntity, "dynamic")
    physics.SetMass(world, maskEntity, 0.01)

    -- Disable collision between mask and player
    -- physics.enable_trigger_between(world, "mask", "player")

    -- Option 1: PIVOT JOINT (simple hinge)
    -- Mask rotates freely around attachment point
    local pivotJoint = physics.add_pivot_joint_world(
        world,
        parentEntity,
        maskEntity,
        { x = maskT.actualX + maskT.actualW / 2, y = maskT.actualY + maskT.actualH / 2 } -- Attach at mask's initial position
    )

    physics.SetMoment(world, maskEntity, 0.01) -- Keep inertia tiny so it doesn't tug the player

    -- Make joint strong but allow some flex
    -- physics.set_constraint_limits(world, pivotJoint, 10000, nil)  -- maxForce

    -- Option 2: DAMPED SPRING (bouncy attachment)
    -- Uncomment to use instead of pivot:
    -- local spring = physics.add_damped_spring(
    --     world,
    --     parentEntity,
    --     {x = 0, y = headOffsetY},  -- Anchor on parent (local coords)
    --     maskEntity,
    --     {x = 0, y = 0},            -- Anchor on mask (center)
    --     0,                         -- Rest length (0 = tight)
    --     500,                       -- Stiffness
    --     10                         -- Damping
    -- )

    -- Option 3: SLIDE JOINT (constrained distance)
    -- Allows mask to slide within min/max range:
    -- local slideJoint = physics.add_slide_joint(
    --     world,
    --     parentEntity,
    --     {x = 0, y = headOffsetY},
    --     maskEntity,
    --     {x = 0, y = 0},
    --     0,     -- Min distance
    --     10     -- Max distance (can stretch up to 10 units)
    -- )

    -- Add rotary spring to keep mask mostly upright
    local rotarySpring = physics.add_damped_rotary_spring(
        world,
        parentEntity,
        maskEntity,
        0,    -- Rest angle (upright)
        6000, -- Stiffness (lower = more floppy)
        5     -- Damping
    )


    physics.set_sync_mode(registry, maskEntity, physics.PhysicsSyncMode.AuthoritativePhysics)

    -- don't know why this is necessary, but set the rotation of the transform to match physics body
    timer.run(
        function()
            if not entity_cache.valid(maskEntity) then return end

            local bodyAngle = physics.GetAngle(world, maskEntity)
            local t = component_cache.get(maskEntity, Transform)
            t.actualR = math.deg(bodyAngle)
        end
    )

    -- Add some angular damping for smoother rotation
    -- physics.SetDamping(world, maskEntity, 0.3)

    -- Layer above player
    layer_order_system.assignZIndexToEntity(maskEntity, z_orders.player_char + 1)

    return maskEntity
end

function initSurvivorEntity()
    local world = PhysicsManager.get_world("world")

    -- 3856-TheRoguelike_1_10_alpha_649.png
    survivorEntity = animation_system.createAnimatedObjectWithTransform(
        "3856-TheRoguelike_1_10_alpha_649.png", -- animation ID
        true                                    -- use animation, not sprite identifier, if false
    )

    -- give survivor a script and hook up
    local SurvivorType = Node:extend()
    local survivorScript = SurvivorType {}
    -- TODO: add update method here if needed

    survivorScript:attach_ecs { create_new = false, existing_entity = survivorEntity }

    -- relocate to the center of the screen
    local survivorTransform = component_cache.get(survivorEntity, Transform)
    survivorTransform.actualX = globals.screenWidth() / 2
    survivorTransform.actualY = globals.screenHeight() / 2
    survivorTransform.visualX = survivorTransform.actualX
    survivorTransform.visualY = survivorTransform.actualY

    -- give survivor physics.
    local info = { shape = "rectangle", tag = "player", sensor = false, density = 1.0, inflate_px = -5 } -- default tag is "WORLD"
    physics.create_physics_for_transform(registry,
        physics_manager_instance,                                                                        -- global instance
        survivorEntity,                                                                                  -- entity id
        "world",                                                                                         -- physics world identifier
        info
    )

    -- make it collide with enemies & walls & pickups
    physics.enable_collision_between_many(world, "WORLD", { "player", "projectile", "enemy" })
    physics.enable_collision_between_many(world, "player", { "WORLD" })
    physics.enable_collision_between_many(world, "projectile", { "WORLD" })
    -- physics.enable_collision_between_many(world, "enemy", { "WORLD" })
    physics.enable_collision_between_many(world, "pickup", { "player" })
    physics.enable_collision_between_many(world, "player", { "pickup" })

    physics.update_collision_masks_for(world, "player", { "WORLD" })
    physics.update_collision_masks_for(world, "enemy", { "WORLD" })
    physics.update_collision_masks_for(world, "WORLD", { "player", "enemy" })


    -- assign z level
    layer_order_system.assignZIndexToEntity(
        survivorEntity,
        z_orders.player_char
    )


    -- make walls after defining collision relationships
    local wallThickness = SCREEN_BOUND_THICKNESS or 30
    physics.add_screen_bounds(PhysicsManager.get_world("world"),
        SCREEN_BOUND_LEFT - wallThickness,
        SCREEN_BOUND_TOP - wallThickness,
        SCREEN_BOUND_RIGHT + wallThickness,
        SCREEN_BOUND_BOTTOM + wallThickness,
        wallThickness,
        "WORLD"
    )

    -- make a timer that runs every frame when action state is active, to render the walls
    timer.run(
        function()
            -- bail if not in action state
            if not is_state_active(ACTION_STATE) then return end

            -- draw walls
            command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
                c.x     = SCREEN_BOUND_LEFT + (SCREEN_BOUND_RIGHT - SCREEN_BOUND_LEFT) / 2
                c.y     = SCREEN_BOUND_TOP + (SCREEN_BOUND_BOTTOM - SCREEN_BOUND_TOP) / 2
                c.w     = SCREEN_BOUND_RIGHT - SCREEN_BOUND_LEFT
                c.h     = SCREEN_BOUND_BOTTOM - SCREEN_BOUND_TOP
                c.rx    = 30
                c.ry    = 30
                -- c.lineWidth = 10
                c.color = util.getColor("pink"):setAlpha(230)
            end, z_orders.background, layer.DrawCommandSpace.World)
        end
    )

    -- give player fixed rotation.
    physics.use_transform_fixed_rotation(registry, survivorEntity)

    -- give shader pipeline comp for later use
    local shaderPipelineComp = registry:emplace(survivorEntity, shader_pipeline.ShaderPipelineComponent)

    -- give mask (optional)
    if ENABLE_SURVIVOR_MASK then
        survivorMaskEntity = createJointedMask(survivorEntity, "world")
    else
        survivorMaskEntity = nil
    end


    physics.enable_collision_between_many(world, "enemy", { "player", "enemy" }) -- enemy>player and enemy>enemy
    physics.enable_collision_between_many(world, "player", { "enemy" })          -- player>enemy
    physics.update_collision_masks_for(world, "player", { "enemy" })
    physics.update_collision_masks_for(world, "enemy", { "player", "enemy" })

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
                    particle.spawnRadialParticles(
                        pickupTransform.actualX + pickupTransform.actualW / 2,
                        pickupTransform.actualY + pickupTransform.actualH / 2,
                        20,                       -- count
                        0.4,                      -- base lifespan
                        {
                            lifetimeJitter = 0.5, -- ±50% lifetime variance
                            scaleJitter = 0.3,    -- ±30% scale variance
                            minScale = 3,
                            maxScale = 4,
                            scaleEasing = "cubic",
                            minSpeed = 100,
                            maxSpeed = 300,
                            colors = { util.getColor("RED") },
                            renderType = particle.ParticleRenderType.CIRCLE_FILLED,
                            easing = "cubic",
                            rotationSpeed = 90,   -- degrees/sec
                            rotationJitter = 0.5, -- ±50% variance
                            space = "world",
                            z = 0,
                        }
                    )
                end

                registry:destroy(pickupEntity)
            end
        end)
    end)

    -- test
    -- local shaderPipelineComp = component_cache.get(survivorEntity, shader_pipeline.ShaderPipelineComponent)
    -- shaderPipelineComp:addPass("vacuum_collapse")


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

        hitFX(survivorEntity, 10, 0.2)


        -- play sound

        playSoundEffect("effects", "time_slow", 0.9 + math.random() * 0.2)
        -- low pass on
        setLowPassTarget(1.0)
        slowTime(1.5, 0.1) -- slow time for 2 seconds, to 20% speed

        playSoundEffect("effects", "player_hurt", 0.9 + math.random() * 0.2)

        timer.after(1.0, function()
            -- playSoundEffect("effects", "time_back_to_normal", 0.9 + math.random() * 0.2)

            -- low pass off
            setLowPassTarget(0.0)
        end)

        -- TODO: make player take damage, play hit effect, etc.

        -- local shaderPipelineComp = component_cache.get(survivorEntity, shader_pipeline.ShaderPipelineComponent)
        -- shaderPipelineComp:addPass("flash")

        -- shake camera
        local cam = camera.Get("world_camera")
        if cam then
            cam:Shake(15.0, 0.5, 60)
        end

        -- -- remove after a short delay
        -- timer.after(1.0, function()
        --     local shaderPipelineComp = component_cache.get(survivorEntity, shader_pipeline.ShaderPipelineComponent)
        --     if shaderPipelineComp then
        --         shaderPipelineComp:removePass("flash")
        --     end
        -- end)

        -- set abberation
        globalShaderUniforms:set("crt", "aberation_amount", 10)
        -- set to 0 after 0.5 seconds
        timer.after(0.15, function()
            globalShaderUniforms:set("crt", "aberation_amount", 0)
        end)

        -- tween up noise, then back down
        timer.tween_scalar(
            0.1,                                                                   -- duration in seconds
            function() return globalShaderUniforms:get("crt", "noise_amount") end, -- getter
            function(v) globalShaderUniforms:set("crt", "noise_amount", v) end,    -- setter
            0.7                                                                    -- target value
        )
        timer.after(0.1, function()
            timer.tween_scalar(
                0.1,                                                                   -- duration in seconds
                function() return globalShaderUniforms:get("crt", "noise_amount") end, -- getter
                function(v) globalShaderUniforms:set("crt", "noise_amount", v) end,    -- setter
                0                                                                      -- target value
            )
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
    input.bind("survivor_left",
        { device = "keyboard", key = KeyboardKey.KEY_A, trigger = "Pressed", context = "gameplay" })
    input.bind("survivor_right", {
        device = "keyboard",
        key = KeyboardKey.KEY_D,
        trigger = "Pressed",
        context =
        "gameplay"
    })
    input.bind("survivor_up", { device = "keyboard", key = KeyboardKey.KEY_W, trigger = "Pressed", context = "gameplay" })
    input.bind("survivor_down",
        { device = "keyboard", key = KeyboardKey.KEY_S, trigger = "Pressed", context = "gameplay" })
    input.bind("survivor_dash", {
        device = "keyboard",
        key = KeyboardKey.KEY_SPACE,
        trigger = "Pressed",
        context =
        "gameplay"
    })

    --also allow gamepad.
    -- same dash
    input.bind("survivor_dash", {
        device = "gamepad_button",
        axis = GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN, -- A button
        trigger = "Pressed",                                 -- or "Threshold" if your system uses analog triggers
        context = "gameplay"
    })

    -- Horizontal movement (Left stick X)
    input.bind("gamepad_move_x", {
        device = "gamepad_axis",
        axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X,
        trigger = "AxisPos", -- or "Threshold" if your system uses analog triggers
        threshold = 0.2,     -- deadzone threshold
        context = "gameplay"
    })
    input.bind("gamepad_move_x", {
        device = "gamepad_axis",
        axis = GamepadAxis.GAMEPAD_AXIS_LEFT_X,
        trigger = "AxisNeg", -- or "Threshold" if your system uses analog triggers
        threshold = 0.2,     -- deadzone threshold
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
        local playerScript = getScriptTableFromEntityID(survivorEntity)
        timer.after(LEVEL_UP_MODAL_DELAY, function()
            LevelUpScreen.push({
                playerEntity = survivorEntity,
                actor = playerScript and playerScript.combatTable
            })
        end, "level_up_modal_delay")
    end)


    -- lets run every physics frame, detecting for magnet radus
    timer.every_physics_step(
        function()
            if isLevelUpModalActive() then return end
            local magnetRadius = 200 -- TODO; make this a player stat later.
            local magItems = get_mag_items(PhysicsManager.get_world("world"), survivorEntity, magnetRadius)

            -- iterate
            for _, itemEntity in ipairs(magItems) do
                if entity_cache.valid(itemEntity) then
                    -- get script
                    local itemScript = getScriptTableFromEntityID(itemEntity)
                    if itemScript and itemScript.isPickup and not itemScript.pickedUp then
                        -- enable steering towards player
                        steering.make_steerable(registry, itemEntity, 3000.0, 8000.0, math.pi * 2.0, 10)


                        -- add a timer to move towards player
                        timer.every_physics_step(
                            function()
                                if isLevelUpModalActive() then return end
                                if entity_cache.valid(itemEntity) and entity_cache.valid(survivorEntity) then
                                    local playerT = component_cache.get(survivorEntity, Transform)

                                    -- steering.seek_point(registry, enemyEntity, playerLocation, 1.0, 0.5)

                                    steering.seek_point(registry, itemEntity,
                                        {
                                            x = playerT.actualX + playerT.actualW / 2,
                                            y = playerT.actualY + playerT.actualH / 2
                                        }, 1.0, 10)
                                else
                                    -- cancel timer, entity no longer valid
                                    timer.cancel("player_magnet_steering_" .. tostring(itemEntity))
                                end
                            end,
                            "player_magnet_steering_" .. tostring(itemEntity),
                            nil
                        )

                        itemScript.pickedUp = true -- mark as picked up to avoid double processing
                    end
                end
            end
        end,
        "player_magnet_detection", nil
    )

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

        -- tug the exp bar spring
        if expBarScaleSpringEntity and entity_cache.valid(expBarScaleSpringEntity) then
            local expBarSpringRef = spring.get(registry, expBarScaleSpringEntity)
            if expBarSpringRef then
                expBarSpringRef:pull(0.15, 120.0, 14.0)
            end
        end

        local playerT = component_cache.get(survivorEntity, Transform)
        if playerT then
            playerT.visualS = 1.5
        end

        --TODo: this is just a test.
    end)
end

function ensureShopSystemInitialized()
    if shop_system_initialized then
        return
    end
    CardMetadata.registerAllWithShop(ShopSystem)
    ShopSystem.init()
    shop_system_initialized = true
end

local function clearBoardCards(boardId)
    local board = boards[boardId]
    if not board or not board.cards then
        return
    end

    for _, eid in ipairs(board.cards) do
        cards[eid] = nil
        if eid and entity_cache.valid(eid) then
            registry:destroy(eid)
        end
    end
    board.cards = {}
end

local planningPeekEntities = {}

local function refreshShopUIFromInstance(shop)
    if globals.ui and globals.ui.refreshShopUIFromInstance then
        globals.ui.refreshShopUIFromInstance(shop or active_shop_instance)
    end
end

local function addPurchasedCardToInventory(cardInstance)
    if not cardInstance then return end
    local cardId = cardInstance.id or cardInstance.card_id or cardInstance.cardID
    if not cardId then return end

    local dropX, dropY = globals.screenWidth() * 0.74, globals.screenHeight() * 0.78
    local inventoryBoard = boards[inventory_board_id]
    if inventoryBoard then
        local t = component_cache.get(inventory_board_id, Transform)
        if t then
            dropX = t.actualX + t.actualW * 0.5
            dropY = t.actualY + t.actualH * 0.2
        end
    end

    local eid = createNewCard(cardId, dropX, dropY, PLANNING_STATE)
    local script = getScriptTableFromEntityID(eid)
    if script then
        script.selected = false
    end
    addCardToBoard(eid, inventory_board_id)
    return eid
end

local function collectPlanningPeekTargets()
    local targets = {}
    local function add(eid)
        if eid and eid ~= entt_null and entity_cache.valid(eid) then
            table.insert(targets, eid)
        end
    end

    add(inventory_board_id)
    local invBoard = boards[inventory_board_id]
    if invBoard and invBoard.textEntity then add(invBoard.textEntity) end

    add(trigger_inventory_board_id)
    local trigInv = boards[trigger_inventory_board_id]
    if trigInv and trigInv.textEntity then add(trigInv.textEntity) end

    if board_sets then
        for _, set in ipairs(board_sets) do
            add(set.trigger_board_id)
            add(set.action_board_id)
            local trigBoard = set.trigger_board_id and boards[set.trigger_board_id]
            if trigBoard and trigBoard.textEntity then add(trigBoard.textEntity) end
            local actBoard = set.action_board_id and boards[set.action_board_id]
            if actBoard and actBoard.textEntity then add(actBoard.textEntity) end
        end
    end

    if planningUIEntities then
        add(planningUIEntities.send_up_button_box)
    end

    return targets
end

setPlanningPeekMode = function(enable)
    globals.shopUIState = globals.shopUIState or {}
    planningPeekEntities = collectPlanningPeekTargets()
    for _, eid in ipairs(planningPeekEntities) do
        if enable then
            add_state_tag(eid, SHOP_STATE)
        else
            remove_state_tag(eid, SHOP_STATE)
        end
    end
    globals.shopUIState.peekPlanning = enable
    newTextPopup(
        enable and "Planning boards visible" or "Planning boards hidden",
        globals.screenWidth() * 0.5,
        globals.screenHeight() * 0.14,
        1.2,
        "color=apricot_cream"
    )
end

togglePlanningPeek = function()
    globals.shopUIState = globals.shopUIState or {}
    setPlanningPeekMode(not globals.shopUIState.peekPlanning)
end

local function formatShopLabel(offering)
    if not offering or not offering.cardDef then
        return "Unknown"
    end
    local rarity = offering.rarity or "?"
    local cost = offering.cost or 0
    return string.format("%s\n[%s] %dg", offering.cardDef.id or "?", rarity, cost)
end

local function populateShopBoard(shop)
    if not shop_board_id or not shop then
        return
    end

    clearBoardCards(shop_board_id)

    for index, offering in ipairs(shop.offerings or {}) do
        if not offering.isEmpty and offering.cardDef then
            local eid = createNewCard(offering.cardDef.id, 0, 0, SHOP_STATE)
            local script = getScriptTableFromEntityID(eid)
            if script then
                script.test_label = formatShopLabel(offering)
                script.shop_slot = index
                script.shop_cost = offering.cost
                script.shop_rarity = offering.rarity
                script.shopBuyReveal = 0
                script.selected = false
            end
            addCardToBoard(eid, shop_board_id)
        end
    end

    refreshShopUIFromInstance(shop)
end

function regenerateShopState()
    ensureShopSystemInitialized()
    ShopSystem.initUI()

    local playerLevel = (globals.shopState and globals.shopState.playerLevel) or 1
    local player = {
        gold = globals.currency or 0,
        cards = (globals.shopState and globals.shopState.cards) or {}
    }

    local interestEarned = ShopSystem.applyInterest(player)
    globals.currency = player.gold

    active_shop_instance = ShopSystem.generateShop(playerLevel, player.gold)
    globals.shopState = globals.shopState or {}
    globals.shopState.instance = active_shop_instance
    globals.shopState.lastInterest = interestEarned
    globals.shopState.playerLevel = playerLevel
    globals.shopState.cards = player.cards

    globals.shopUIState.rerollCost = active_shop_instance.rerollCost
    globals.shopUIState.rerollCount = active_shop_instance.rerollCount

    setShopLocked(false)

    populateShopBoard(active_shop_instance)
end

function rerollActiveShop()
    if not active_shop_instance then
        return false
    end

    local player = {
        gold = globals.currency or 0,
        cards = (globals.shopState and globals.shopState.cards) or {}
    }

    local success = ShopSystem.rerollOfferings(active_shop_instance, player)
    if not success then
        return false
    end

    globals.currency = player.gold
    globals.shopState.cards = player.cards
    globals.shopUIState.rerollCost = active_shop_instance.rerollCost
    globals.shopUIState.rerollCount = active_shop_instance.rerollCount

    populateShopBoard(active_shop_instance)
    return true
end

tryPurchaseShopCard = function(cardScript)
    if not cardScript or not cardScript.shop_slot or not active_shop_instance then
        return false
    end

    globals.shopState = globals.shopState or {}
    local offering = active_shop_instance.offerings[cardScript.shop_slot]
    if not offering or offering.isEmpty then
        return false
    end

    local player = {
        gold = globals.currency or 0,
        cards = (globals.shopState and globals.shopState.cards) or {}
    }

    local success, cardInstance = ShopSystem.purchaseCard(active_shop_instance, cardScript.shop_slot, player)
    if not success then
        playSoundEffect("effects", "cannot-buy")
        newTextPopup(
            "Need more gold",
            globals.screenWidth() * 0.5,
            globals.screenHeight() * 0.4,
            1.4,
            "color=fiery_red"
        )
        return false
    end

    globals.currency = player.gold
    globals.shopState.cards = player.cards
    globals.shopState.instance = active_shop_instance

    addPurchasedCardToInventory(cardInstance)

    playSoundEffect("effects", "shop-buy", 1.0)
    newTextPopup(
        string.format("Bought %s", cardInstance.id or cardInstance.card_id or "card"),
        globals.screenWidth() * 0.5,
        globals.screenHeight() * 0.36,
        1.6,
        "color=marigold"
    )

    populateShopBoard(active_shop_instance)
    refreshShopUIFromInstance(active_shop_instance)

    return true
end

function tryPurchaseAvatar(avatarId)
    if not avatarId then
        return false
    end

    globals.shopState = globals.shopState or {}
    globals.shopState.avatarPurchases = globals.shopState.avatarPurchases or {}

    local playerTarget = getTagEvaluationTargets and select(1, getTagEvaluationTargets()) or nil
    if not playerTarget then
        return false
    end

    AvatarSystem.check_unlocks(playerTarget, { tag_counts = playerTarget.tag_counts })
    local unlocked = playerTarget.avatar_state and playerTarget.avatar_state.unlocked
        and playerTarget.avatar_state.unlocked[avatarId]
    if not unlocked then
        newTextPopup(
            "Avatar not unlocked yet",
            globals.screenWidth() * 0.72,
            globals.screenHeight() * 0.3,
            1.4,
            "color=fiery_red"
        )
        playSoundEffect("effects", "cannot-buy")
        return false
    end

    if globals.shopState.avatarPurchases[avatarId] then
        newTextPopup(
            "Already purchased",
            globals.screenWidth() * 0.72,
            globals.screenHeight() * 0.3,
            1.2,
            "color=apricot_cream"
        )
        return false
    end

    if (globals.currency or 0) < AVATAR_PURCHASE_COST then
        playSoundEffect("effects", "cannot-buy")
        newTextPopup(
            string.format("Need %dg", AVATAR_PURCHASE_COST),
            globals.screenWidth() * 0.72,
            globals.screenHeight() * 0.3,
            1.4,
            "color=fiery_red"
        )
        return false
    end

    globals.currency = (globals.currency or 0) - AVATAR_PURCHASE_COST
    globals.shopState.avatarPurchases[avatarId] = true
    AvatarSystem.equip(playerTarget, avatarId)

    if AvatarJokerStrip and AvatarJokerStrip.syncFrom then
        AvatarJokerStrip.syncFrom(playerTarget)
    end

    playSoundEffect("effects", "shop-buy")
    newTextPopup(
        string.format("Avatar unlocked: %s", avatarId),
        globals.screenWidth() * 0.72,
        globals.screenHeight() * 0.3,
        1.6,
        "color=marigold"
    )

    refreshShopUIFromInstance(active_shop_instance)
    return true
end

local function buildAvatarOverlayEntries()
    local entries = {}
    local defs = require("data.avatars")
    local purchases = (globals.shopState and globals.shopState.avatarPurchases) or {}
    local playerTarget = getTagEvaluationTargets and select(1, getTagEvaluationTargets()) or nil
    if playerTarget then
        AvatarSystem.check_unlocks(playerTarget, { tag_counts = playerTarget.tag_counts })
    end

    for id, def in pairs(defs or {}) do
        entries[#entries + 1] = {
            id = id,
            name = def.name or id,
            unlocked = playerTarget and playerTarget.avatar_state and playerTarget.avatar_state.unlocked
                and playerTarget.avatar_state.unlocked[id],
            purchased = purchases[id]
        }
    end

    table.sort(entries, function(a, b) return (a.name or a.id) < (b.name or b.id) end)
    return entries
end

local function drawShopPanel(x, y, w, h, title)
    local cx, cy = x + w * 0.5, y + h * 0.5
    command_buffer.queueDrawCenteredFilledRoundedRect(layers.sprites, function(c)
        c.x = cx
        c.y = cy
        c.w = w
        c.h = h
        c.rx = 12
        c.ry = 12
        c.color = Col(18, 22, 32, 220)
        c.outlineColor = util.getColor("apricot_cream")
    end, z_orders.card - 1, layer.DrawCommandSpace.Screen)

    command_buffer.queueDrawText(layers.sprites, function(c)
        c.text = title
        c.font = localization.getFont()
        c.x = x + shop_overlay_layout.pad
        c.y = y + shop_overlay_layout.pad
        c.color = util.getColor("apricot_cream")
        c.fontSize = 20
    end, z_orders.card, layer.DrawCommandSpace.Screen)
end

local function drawShopOverlay()
    if not is_state_active or not is_state_active(SHOP_STATE) then
        return
    end
    if not active_shop_instance then
        return
    end

    local screenW, screenH = globals.screenWidth(), globals.screenHeight()
    local margin = shop_overlay_layout.margin
    local pad = shop_overlay_layout.pad
    local rowH = shop_overlay_layout.rowH
    local panelW = math.min(shop_overlay_layout.panelW, screenW - margin * 2)

    local offerCount = math.min(#(active_shop_instance.offerings or {}), ShopSystem.config.offerSlots or 5)
    local offersHeight = pad * 2 + 26 + offerCount * rowH

    local avatarEntries = buildAvatarOverlayEntries()
    local maxAvatarRows = math.min(4, #avatarEntries)
    local avatarHeight = pad * 2 + 26 + maxAvatarRows * rowH

    local spacing = 10
    local totalHeight = offersHeight + avatarHeight + spacing

    local startX = screenW - panelW - margin
    local startY = margin
    if startY + totalHeight > screenH - margin then
        startY = math.max(margin, screenH - totalHeight - margin)
    end

    -- Offers panel
    drawShopPanel(startX, startY, panelW, offersHeight, "Shop offers")
    local textY = startY + pad + 24
    for i = 1, offerCount do
        local offering = active_shop_instance.offerings[i]
        local status = string.format("%d) Empty", i)
        local color = util.getColor("gray")
        if offering then
            if offering.isEmpty then
                status = offering.sold and string.format("%d) Sold", i) or status
            elseif offering.cardDef then
                local lockSuffix = (active_shop_instance.locks and active_shop_instance.locks[i]) and " [Locked]" or ""
                status = string.format("%d) %s [%s] %dg%s", i, offering.cardDef.id or "?",
                    tostring(offering.rarity or "?"), math.floor((offering.cost or 0) + 0.5), lockSuffix)
                color = util.getColor("apricot_cream")
            end
        end
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = status
            c.font = localization.getFont()
            c.x = startX + pad
            c.y = textY
            c.color = color
            c.fontSize = 18
        end, z_orders.card, layer.DrawCommandSpace.Screen)
        textY = textY + rowH
    end

    -- Avatars panel
    local avatarY = startY + offersHeight + spacing
    drawShopPanel(startX, avatarY, panelW, avatarHeight, "Avatars")
    local avatarTextY = avatarY + pad + 24
    for idx = 1, maxAvatarRows do
        local entry = avatarEntries[idx]
        local label = entry.name
        local color = util.getColor("gray")
        if entry.purchased then
            label = label .. " [Owned]"
            color = util.getColor("marigold")
        elseif entry.unlocked then
            label = label .. string.format(" [%dg]", AVATAR_PURCHASE_COST)
            color = util.getColor("mint_green")
        else
            label = label .. " [Locked]"
        end
        command_buffer.queueDrawText(layers.sprites, function(c)
            c.text = label
            c.font = localization.getFont()
            c.x = startX + pad
            c.y = avatarTextY
            c.color = color
            c.fontSize = 18
        end, z_orders.card, layer.DrawCommandSpace.Screen)
        avatarTextY = avatarTextY + rowH
    end
end

function setShopLocked(locked)
    globals.shopUIState.locked = locked

    if active_shop_instance then
        for i = 1, #active_shop_instance.offerings do
            if active_shop_instance.locks[i] ~= locked then
                if locked then
                    ShopSystem.lockOffering(active_shop_instance, i)
                else
                    ShopSystem.unlockOffering(active_shop_instance, i)
                end
            end
        end
    end

    if globals.ui and globals.ui.setLockIconsVisible then
        globals.ui.setLockIconsVisible(globals.shopUIState.locked)
    end
end

timer.run(function()
    drawShopOverlay()
end, nil, "shop_overlay_draw")

function getActiveShop()
    return active_shop_instance
end

function initShopPhase()
    ensureShopSystemInitialized()
    -- let's make a large board for shopping
    local shopBoardID = createNewBoard(100, 100, 800, 400)
    shop_board_id = shopBoardID
    local shopBoard = boards[shopBoardID]
    shopBoard.borderColor = util.getColor("apricot_cream")

    -- give a text label above the board
    shopBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.shop_area") end, -- initial text
        20.0,                                                   -- font size
        "color=apricot_cream"                                   -- animation spec
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

    -- let's add a (buy) board below.
    local buyBoardID = createNewBoard(100, 550, 800, 150)
    shop_buy_board_id = buyBoardID
    local buyBoard = boards[buyBoardID]
    buyBoard.borderColor = util.getColor("green")
    buyBoard.textEntity = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.buy_area") end, -- initial text
        20.0,                                                  -- font size
        "color=green"                                          -- animation spec
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
SCREEN_BOUND_THICKNESS = 30

local playerFootStepSounds = {
    "walk_1",
    "walk_2",
    "walk_3",
    "walk_4",
    "walk_5",
    "walk_6",
    "walk_7",
    "walk_8",
    "walk_9",
    "walk_10"
}

local function spawnWalkDust()
    -- Lightweight puff at the player's feet while walking
    local t = component_cache.get(survivorEntity, Transform)
    if not t then return end

    local jitterX = (math.random() - 0.5) * (t.actualW * 0.25)
    local baseX = t.actualX + t.actualW * 0.5 + jitterX
    local baseY = t.actualY + t.actualH - 6

    particle.spawnRadialParticles(baseX, baseY, 4, 0.35, {
        lifetimeJitter = 0.35,
        scaleJitter = 0.25,
        minScale = 2.0,
        maxScale = 4.0,
        minSpeed = 40,
        maxSpeed = 90,
        colors = { Col(200, 190, 170, 200) },
        renderType = particle.ParticleRenderType.CIRCLE_FILLED,
        easing = "cubic",
        gravity = 0,
        space = "world",
        z = z_orders.player_vfx - 5,
    })
end

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

    local spawnMarkerNode = SpawnMarkerType {}
    spawnMarkerNode.scale = 1.0

    spawnMarkerNode:attach_ecs { create_new = true }
    add_state_tag(spawnMarkerNode:handle(), state or ACTION_STATE)

    -- tween down
    -- local h5 = timer.tween(1.2, camera, { x = 320, y = 180, zoom = 1.25 }, nil, nil, "cam_move", "camera")
    timer.tween_fields(0.2, spawnMarkerNode, { scale = 0.0 }, nil, function()
        registry:destroy(spawnMarkerNode:handle())
    end)
end







function initActionPhase()
    
    LevelUpScreen.init()
    
    local CastFeedUI = require("ui.cast_feed_ui")
    if not MessageQueueUI.isActive then
        MessageQueueUI.init()
    end
    ensureMessageQueueHooks()
    fireAvatarDebugEvents()

    -- Clamp the camera to the playable arena so its edges stay on screen.
    -- do
        local cam = camera.Get("world_camera")
        if cam then
            cam:SetBounds {
                x = SCREEN_BOUND_LEFT,
                y = SCREEN_BOUND_TOP,
                width = SCREEN_BOUND_RIGHT - SCREEN_BOUND_LEFT,
                height = SCREEN_BOUND_BOTTOM - SCREEN_BOUND_TOP
            }
            cam:SetBoundsPadding(10) -- small screen-space slack so camera can float while keeping arena visible
        end
    -- end

    -- Initialize CastFeedUI
    CastFeedUI.init()
    WandCooldownUI.init()
    SubcastDebugUI.init()
    
    -- add shader to backgorund layer
    add_layer_shader("background", "peaches_background")
    -- add_layer_shader("background", "fireworks")
    -- add_layer_shader("background", "starry_tunnel")
    -- add_layer_shader("background", "vacuum_collapse")
    -- add_fullscreen_shader("peaches_background")

    log_debug("Action phase started!")

    -- setUpScrollingBackgroundSprites()

    local world = PhysicsManager.get_world("world")
    world:AddCollisionTag("sensor")
    world:AddCollisionTag("player")
    world:AddCollisionTag("bullet")
    world:AddCollisionTag("WORLD")
    world:AddCollisionTag("trap")
    world:AddCollisionTag("enemy")
    world:AddCollisionTag("card")
    world:AddCollisionTag("pickup") -- for items on ground
    world:AddCollisionTag("projectile")
    world:AddCollisionTag("mask")

    initSurvivorEntity()

    physics.SetSleepTimeThreshold(world, 100000) -- time in seconds before body goes to sleep

    playerIsDashing = false
    playerDashCooldownRemaining = 0
    playerDashTimeRemaining = 0
    dashBufferTimer = 0
    bufferedDashDir = nil
    playerStaminaTickerTimer = 0
    enemyHealthUiState = {}
    combatActorToEntity = setmetatable({}, { __mode = "k" })
    damageNumbers = {}

    local DASH_END_TIMER_NAME = "dash_end_timer"
    local lastMoveInput = { x = 0, y = 0 }

    local function resolveDashDirection(baseDir)
        local dirX = (baseDir and baseDir.x) or 0
        local dirY = (baseDir and baseDir.y) or 0
        local len = math.sqrt(dirX * dirX + dirY * dirY)
        if len == 0 then
            local vel = physics.GetVelocity(world, survivorEntity)
            len = math.sqrt(vel.x * vel.x + vel.y * vel.y)
            if len > 0 then
                dirX = vel.x / len
                dirY = vel.y / len
            else
                dirX, dirY = 0, -1 -- default forward dash (e.g., up)
            end
        else
            dirX, dirY = dirX / len, dirY / len
        end
        return dirX, dirY
    end

    local function queueDashRequest(dir)
        bufferedDashDir = dir and { x = dir.x, y = dir.y } or nil
        dashBufferTimer = DASH_BUFFER_WINDOW
    end

    local function startPlayerDash(dir)
        if not survivorEntity or survivorEntity == entt_null or not entity_cache.valid(survivorEntity) then return end

        local dashX, dashY = resolveDashDirection(dir)
        local moveDir = { x = dashX, y = dashY }

        dashBufferTimer = 0
        bufferedDashDir = nil
        playerIsDashing = true
        playerDashTimeRemaining = DASH_LENGTH_SEC
        playerDashCooldownRemaining = DASH_COOLDOWN_SECONDS
        playerStaminaTickerTimer = DASH_COOLDOWN_SECONDS + STAMINA_TICKER_LINGER

        timer.cancel(DASH_END_TIMER_NAME)

        log_debug("Dash pressed!")

        local t = component_cache.get(survivorEntity, Transform)
        if t then
            -- Base squash/stretch factors
            local dirX, dirY = moveDir.x, moveDir.y
            local absX, absY = math.abs(dirX), math.abs(dirY)
            local dominant = absX > absY and "horizontal" or "vertical"

            local squeeze = 0.6   -- how thin to get
            local stretch = 1.4   -- how long to stretch
            local duration = 0.15 -- squash+stretch speed

            -- store original values
            local originalW = t.visualW
            local originalH = t.visualH
            local originalS = t.visualS or 1.0
            local originalR = t.visualR or 0.0

            if dominant == "horizontal" then
                -- Dash left/right → wider, shorter
                t.visualW = originalW * stretch
                t.visualH = originalH * squeeze
                t.visualS = originalS * 1.1
            else
                -- Dash up/down → taller, thinner
                t.visualH = originalH * stretch
                t.visualW = originalW * squeeze
                t.visualS = originalS * 1.1
            end

            -- Tiny rotational flair for diagonals
            if absX > 0.2 and absY > 0.2 then
                local tilt = math.deg(math.atan(dirY, dirX)) * 0.15
                t.visualR = originalR + tilt
            end
        end



        local maskEntity = survivorMaskEntity
        if ENABLE_SURVIVOR_MASK and maskEntity and entity_cache.valid(maskEntity) then
            -- Apply rotational impulse (torque) to make mask spin
            local torqueStrength = 800 -- Tuned for lighter, mostly-weightless mask
            -- physics.ApplyTorque(world, maskEntity, torqueStrength)
            physics.ApplyAngularImpulse(world, maskEntity, moveDir.x * torqueStrength)
            -- Optional linear impulse skipped while mask disabled
        end

        local DASH_STRENGTH = 340

        -- physics.ApplyImpulse(PhysicsManager.get_world("world"), survivorEntity, moveDir.x * DASH_STRENGTH, moveDir.y * DASH_STRENGTH)

        -- timer.on_new_physics_step(function()
        physics.ApplyImpulse(world, survivorEntity, moveDir.x * DASH_STRENGTH, moveDir.y * DASH_STRENGTH)
        -- end, "dash_impulse_timer")

        WandTriggers.handleEvent("on_dash", { player = survivorEntity })

        playSoundEffect("effects", random_utils.random_element_string(dash_sfx_list), 0.9 + math.random() * 0.2)

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
                spread = 30, -- degrees
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
                easing = "cubic",
                renderType = particle.ParticleRenderType.CIRCLE_FILLED,
                space = "world",
                z = z_orders.player_vfx - 20
            })

            spawnHollowCircleParticle(
                origin.x,
                origin.y,
                30,
                util.getColor("dim_gray"),
                0.2
            )

            particle.spawnDirectionalStreaksCone(origin, 10, DASH_LENGTH_SEC, {
                direction = Vec2(-moveDir.x, -moveDir.y), -- up
                spread = a,                               -- ±22.5° cone
                minSpeed = 200,
                maxSpeed = 300,
                minScale = 8,
                maxScale = 10,
                autoAspect = true,
                shrink = true,
                colors = { Col(255, 200, 100) },
                space = "world",
                z = 5
            })

            particle.spawnDirectionalLinesCone(origin, 20, 0.8, {
                direction = Vec2(-moveDir.x, -moveDir.y),
                spread = 45,
                minSpeed = 200,
                maxSpeed = 400,
                minLength = 32,
                maxLength = 64,
                minThickness = 2,
                maxThickness = 5,
                colors = { Col(255, 220, 120), Col(255, 180, 80), Col(255, 120, 50) },
                durationJitter = 0.3,
                sizeJitter = 0.2,
                faceVelocity = true,
                shrink = true,
                space = "world",
                z = z_orders.particle_vfx
            })


            -- makeSwirlEmitter(320, 180, 120,
            --     { Col(255, 220, 120), Col(255, 160, 80), Col(255, 100, 60) },
            --     1.0,   -- emitDuration: spawn new dots for 1 second
            --     2.5    -- totalLifetime: fadeout & cleanup
            -- )

            makeSwirlEmitterWithRing(
                320, 180, 96,
                { util.getColor("white"), Col(255, 160, 80), Col(255, 100, 60) },
                1.0, -- emitDuration (how long to spawn new dots)
                2.5  -- totalLifetime
            )

            spawnCrescentParticle(
                200, 200, 40,
                Vec2(250, -60),
                Col(255, 220, 150, 255),
                1.5
            )

            -- Bigger diagonal slash effect
            spawnImpactSmear(320, 180, Vec2(0.7, 0.7), Col(255, 200, 200, 255), 0.3,
                { maxLength = 80, maxThickness = 6, single = true })

            particle.attachTrailToEntity(survivorEntity, DASH_LENGTH_SEC * 0.3, {
                space = "world",
                count = 20,
                direction = Vec2(-moveDir.x, -moveDir.y),
                spread = 45,
                colors = { util.getColor("white") },
                minSpeed = 80,
                maxSpeed = 220,
                lifetime = 0.4,
                interval = 0.01,

                onFinish = function(ent)
                    -- spawn final burst at entity’s last known position
                    local t = component_cache.get(survivorEntity, Transform)
                    if t then
                        particle.spawnDirectionalLinesCone(
                            Vec2(t.actualX + t.actualW * 0.5, t.actualY + t.actualH * 0.5), 10, 0.3, {
                                direction = Vec2(-moveDir.x, -moveDir.y),
                                spread = 360,
                                minSpeed = 200,
                                maxSpeed = 400,
                                minLength = 32,
                                maxLength = 64,
                                minThickness = 2,
                                maxThickness = 5,
                                colors = { util.getColor("white") },
                                durationJitter = 0.3,
                                sizeJitter = 0.2,
                                faceVelocity = true,
                                shrink = false,
                                space = "world",
                                z = z_orders.particle_vfx
                            })
                    end
                end
            })

            -- Yellow rotating dashed circle with faint fill for 2 seconds
            makeDashedCircleArea(320, 500, 80, {
                color = util.getColor("YELLOW"),
                fillColor = Col(255, 255, 100, 200),
                hasFill = true,
                dashLength = 18,
                gapLength = 10,
                rotateSpeed = 120, -- faster rotation
                thickness = 5,
                duration = 2.0
            })

            local p1 = Vec2(200, 600)
            local p2 = Vec2(500, 800)

            makePulsingBeam(p1, p2, {
                color = util.getColor("CYAN"),
                duration = 1.8,
                radius = 14,
                beamThickness = 12,
                pulseSpeed = 3.5,
            })


            -- Wipe upward while facing 45° angle
            -- makeDirectionalWipeWithTimer(320, 180, 400, 200,
            --     Vec2(0.7, 0.7),  -- facing diagonal
            --     Vec2(0, -1),     -- wipe upward
            --     Col(255, 180, 120, 255),
            --     1.0)
        end


        timer.after(DASH_LENGTH_SEC, function()
            timer.on_new_physics_step(function()
                -- physics.SetDamping(world, survivorEntity, 5.0)
                playerIsDashing = false
                playerDashTimeRemaining = 0
            end)
        end, DASH_END_TIMER_NAME)
    end

    local function tryConsumeBufferedDash(fallbackDir)
        if dashBufferTimer > 0 and not playerIsDashing and playerDashCooldownRemaining <= DASH_COYOTE_WINDOW then
            startPlayerDash(bufferedDashDir or fallbackDir)
            return true
        end
        return false
    end

    -- create input timer. this must run every frame.
    timer.every_physics_step(
        function()
            if isLevelUpModalActive() then return end
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
                playerMoving = len > 0.15
                if len > 1 then
                    move_x = move_x / len
                    move_y = move_y / len
                end

                moveDir.x = move_x
                moveDir.y = move_y
            else
                -- find intended dash direction from inputs
                if input.action_down("survivor_left") then moveDir.x = moveDir.x - 1 end
                if input.action_down("survivor_right") then moveDir.x = moveDir.x + 1 end
                if input.action_down("survivor_up") then moveDir.y = moveDir.y - 1 end
                if input.action_down("survivor_down") then moveDir.y = moveDir.y + 1 end

                local len = math.sqrt(moveDir.x * moveDir.x + moveDir.y * moveDir.y)
                if len ~= 0 then
                    moveDir.x, moveDir.y = moveDir.x / len, moveDir.y / len
                    playerMoving = true
                else
                    moveDir.x, moveDir.y = 0, 0
                end
            end

            if (moveDir.x > 0) then
                animation_system.set_horizontal_flip(survivorEntity, true)
            elseif (moveDir.x < 0) then
                animation_system.set_horizontal_flip(survivorEntity, false)
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

            local dustTimerName = "survivorWalkDustTimer"
            if playerMoving and not playerIsDashing then
                if not timer.get_timer_and_delay(dustTimerName) then
                    timer.every(0.12, function()
                        spawnWalkDust()
                    end, 0, true, nil, dustTimerName)
                end
            else
                timer.cancel(dustTimerName)
            end

            local dashPressed = input.action_pressed("survivor_dash")
            local moveLen = math.sqrt(moveDir.x * moveDir.x + moveDir.y * moveDir.y)
            local prevLen = math.sqrt(lastMoveInput.x * lastMoveInput.x + lastMoveInput.y * lastMoveInput.y)
            local moveInputChanged = false
            if moveLen > 0.1 then
                if prevLen <= 0.1 then
                    moveInputChanged = true
                else
                    local dot = (moveDir.x * lastMoveInput.x + moveDir.y * lastMoveInput.y) / (moveLen * prevLen)
                    moveInputChanged = dot < 0.5
                end
            end

            if playerIsDashing and moveInputChanged then
                startPlayerDash(moveDir)
            elseif dashPressed then
                if (not playerIsDashing) and playerDashCooldownRemaining <= DASH_COYOTE_WINDOW then
                    startPlayerDash(moveDir)
                else
                    queueDashRequest(moveDir)
                end
            end

            tryConsumeBufferedDash(moveDir)

            lastMoveInput.x, lastMoveInput.y = moveDir.x, moveDir.y

            if playerIsDashing then
                return -- skip movement input while dashing
            end

            local speed = 200 -- pixels per second

            physics.SetVelocity(PhysicsManager.get_world("world"), survivorEntity, moveDir.x * speed, moveDir.y * speed)

            -- tracy.zoneEnd()
        end,
        nil,                          -- no after
        "survivorEntityMovementTimer" -- timer tag
    )

    input.set_context("gameplay") -- set the input context to gameplay



    initCombatSystem()

    -- lets make a timer that, if action state is active, spawn an enemy every few seconds
    timer.every(5.0, function()
            if is_state_active(ACTION_STATE) and not isLevelUpModalActive() then
                -- animation entity
                local enemyEntity = animation_system.createAnimatedObjectWithTransform(
                    "b1060.png", -- animation ID
                    true         -- use animation, not sprite identifier, if false
                )

                playSoundEffect("effects", "monster_appear_whoosh", 0.8 + math.random() * 0.3)

                -- give state
                add_state_tag(enemyEntity, ACTION_STATE)
                -- remove default state tag
                remove_default_state_tag(enemyEntity)

                -- set it to a random position, within the screen bounds.
                local enemyTransform = component_cache.get(enemyEntity, Transform)
                enemyTransform.actualX = lume.random(SCREEN_BOUND_LEFT + 50, SCREEN_BOUND_RIGHT - 50)
                enemyTransform.actualY = lume.random(SCREEN_BOUND_TOP + 50, SCREEN_BOUND_BOTTOM - 50)

                -- snap
                enemyTransform.visualX = enemyTransform.actualX
                enemyTransform.visualY = enemyTransform.actualY

                -- give it physics
                local info = { shape = "rectangle", tag = "enemy", sensor = false, density = 1.0, inflate_px = -4 } -- default tag is "WORLD"
                physics.create_physics_for_transform(registry,
                    physics_manager_instance,                                                                       -- global instance
                    enemyEntity,                                                                                    -- entity id
                    "world",                                                                                        -- physics world identifier
                    info
                )

                -- give pipeline
                registry:emplace(enemyEntity, shader_pipeline.ShaderPipelineComponent)

                physics.update_collision_masks_for(PhysicsManager.get_world("world"), "enemy", { "player", "enemy" })
                physics.update_collision_masks_for(PhysicsManager.get_world("world"), "player", { "enemy" })

                -- make it steerable
                -- steering
                steering.make_steerable(registry, enemyEntity, 3000.0, 30000.0, math.pi * 2.0, 2.0)


                -- give a blinking timer
                timer.every(0.1, function()
                    if entity_cache.valid(enemyEntity) then
                        local animComp = component_cache.get(enemyEntity, AnimationQueueComponent)
                        if animComp then
                            animComp.noDraw = not animComp.noDraw
                        end
                    end
                end, nil, true, function()
                end, "enemy_blink_timer_" .. tostring(enemyEntity))

                -- tween the multiplier up to 3.0 over 0.5 seconds, then remove the timer
                timer.tween_scalar(0.5, function()
                        return timer.get_multiplier("enemy_blink_timer_" .. tostring(enemyEntity))
                    end,
                    function(v)
                        timer.set_multiplier("enemy_blink_timer_" .. tostring(enemyEntity), v)
                    end, 2, Easing.cubic.f, function()
                        timer.cancel("enemy_blink_timer_" .. tostring(enemyEntity))
                        -- ensure it's visible
                        local animComp = component_cache.get(enemyEntity, AnimationQueueComponent)
                        if animComp then
                            animComp.noDraw = false
                        end
                    end)


                timer.after(0.6, function()
                    -- cancel blinking timer
                    timer.cancel("enemy_blink_timer_" .. tostring(enemyEntity))
                    -- ensure it's visible
                    local animComp = component_cache.get(enemyEntity, AnimationQueueComponent)
                    if animComp then
                        animComp.noDraw = false
                    end
                end)


                -- give it a combat table.

                -- Ogre: tougher target with defense layers and reactive behaviors (reflect/retaliation/block).
                local ogre = combat_context._make_actor('Ogre', combat_context.stat_defs,
                    CombatSystem.Game.Content.attach_attribute_derivations)
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
                local enemyScriptNode = Node {}
                enemyScriptNode.combatTable = ogre
                enemyScriptNode:attach_ecs { create_new = false, existing_entity = enemyEntity }
                combatActorToEntity[ogre] = enemyEntity
                enemyHealthUiState[enemyEntity] = { actor = ogre, visibleUntil = 0 }


                -- make circle marker for enemy appearance, tween it down to 0 scale and then remove it
                local SpawnMarkerType = Node:extend()
                local enemyX = enemyTransform.actualX + enemyTransform.actualW / 2
                local enemyY = enemyTransform.actualY + enemyTransform.actualH / 2
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

                local spawnMarkerNode = SpawnMarkerType {}
                spawnMarkerNode.scale = 1.0

                spawnMarkerNode:attach_ecs { create_new = true }
                add_state_tag(spawnMarkerNode:handle(), ACTION_STATE)

                -- tween down
                -- local h5 = timer.tween(1.2, camera, { x = 320, y = 180, zoom = 1.25 }, nil, nil, "cam_move", "camera")
                timer.tween_fields(0.2, spawnMarkerNode, { scale = 0.0 }, nil, function()
                    registry:destroy(spawnMarkerNode:handle())
                end)

                timer.every_physics_step(function()
                    if isLevelUpModalActive() then return end
                    local t = component_cache.get(enemyEntity, Transform)

                    local playerLocation = { x = 0, y = 0 }
                    local playerT = component_cache.get(survivorEntity, Transform)
                    if playerT then
                        playerLocation.x = playerT.actualX + playerT.actualW / 2
                        playerLocation.y = playerT.actualY + playerT.actualH / 2
                    end

                    steering.seek_point(registry, enemyEntity, playerLocation, 1.0, 0.5)
                    -- steering.flee_point(registry, player, {x=playerT.actualX + playerT.actualW/2, y=playerT.actualY + playerT.actualH/2}, 300.0, 1.0)
                    steering.wander(registry, enemyEntity, 300.0, 300.0, 150.0, 3)

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
    timer.run(function()
            -- tracy.zoneBeginN("Camera Pan Timer Tick") -- just some default depth to avoid bugs
            -- log_debug("Camera pan timer tick")
            if entity_cache.state_active(ACTION_STATE) then
                local targetX, targetY = 0, 0
                local t = component_cache.get(survivorEntity, Transform)
                if t then
                    targetX = t.actualX + t.actualW / 2
                    targetY = t.actualY + t.actualH / 2
                    -- Gently steer toward the player instead of hard locking.
                    local current = cam:GetActualTarget()
                    local lerp = 0.045 -- smaller = slower camera drift
                    cam:SetActualTarget(
                        current.x + (targetX - current.x) * lerp,
                        current.y + (targetY - current.y) * lerp
                    )
                end
            else
                -- local cam = camera.Get("world_camera")
                -- log_debug("Camera pan timer tick - no action state, centering camera")
                local c = cam:GetActualTarget()

                -- if not already at halfway point in screen, then move it there
                if math.abs(c.x - globals.screenWidth() / 2) > 5 or math.abs(c.y - globals.screenHeight() / 2) > 5 then
                    camera_smooth_pan_to("world_camera", globals.screenWidth() / 2, globals.screenHeight() / 2) -- pan to the target smoothly
                end
            end
            -- tracy.zoneEnd()
        end,
        nil,
        false,
        nil,
        "cameraPanToPlayerTimer")

    local expPickupSounds = {
        "item_appear_1",
        "item_appear_2",
        "item_appear_3",
        "item_appear_4"
    }

    -- timer to spawn an exp pickup every few seconds, for testing purposes.
    timer.every(3.0, function()
        if is_state_active(ACTION_STATE) and not isLevelUpModalActive() then
            playSoundEffect("effects", random_utils.random_element_string(expPickupSounds), 0.9 + math.random() * 0.2)

            local expPickupEntity = animation_system.createAnimatedObjectWithTransform(
                "b8090.png", -- animation ID
                true         -- use animation, not sprite identifier, if false
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
                expPickupTransform.actualW,
                util.getColor("red"),
                ACTION_STATE
            )



            -- give it physics
            local info = { shape = "rectangle", tag = "pickup", sensor = true, density = 1.0, inflate_px = 0 } -- default tag is "WORLD"

            physics.create_physics_for_transform(registry,
                physics_manager_instance, -- global instance
                expPickupEntity,          -- entity id
                "world",                  -- physics world identifier
                info
            )

            physics.enable_collision_between_many(PhysicsManager.get_world("world"), "pickup", { "player" })
            physics.enable_collision_between_many(PhysicsManager.get_world("world"), "player", { "pickup" })
            physics.update_collision_masks_for(PhysicsManager.get_world("world"), "pickup", { "player" })
            physics.update_collision_masks_for(PhysicsManager.get_world("world"), "player", { "pickup" })

            -- give it a script
            local expPickupScript = Node {}

            expPickupScript:attach_ecs { create_new = false, existing_entity = expPickupEntity }

            expPickupScript.isPickup = true
        end
    end)

    -- blanket collision update
    -- physics.reapply_all_filters(PhysicsManager.get_world("world"))
end

planningUIEntities = {
    start_action_button_box = nil,
    send_up_button_box = nil,
    send_up_button = nil,
    wand_buttons = {}
}



function initPlanningUI()
    -- makeWandTooltip()

    -- simple button to start action phase.
    local startButtonText = ui.definitions.getNewDynamicTextEntry(
        function() return localization.get("ui.start_action_phase") end, -- initial text
        15.0,                                                            -- font size
        "color=fuchsia"                                                  -- animation spec
    )
    local startButtonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
            :addColor(util.getColor("gray"))
            :addEmboss(2.0)
            :addHover(true)                                -- needed for button effect
            :addButtonCallback(function()
                playSoundEffect("effects", "button-click") -- play button click sound
                startActionPhase()
            end)
            :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
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
            :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
        )
        :addChild(startButtonTemplate)
        :build()

    -- new uibox for the main menu
    planningUIEntities.start_action_button_box = ui.box.Initialize({ x = 350, y = globals.screenHeight() }, startMenuRoot)

    -- center the ui box X-axi
    local buttonTransform = component_cache.get(planningUIEntities.start_action_button_box, Transform)
    buttonTransform.actualX = globals.screenWidth() / 2 - buttonTransform.actualW / 2
    buttonTransform.actualY = globals.screenHeight() - buttonTransform.actualH - 10

    -- ggive entire box the planning state
    ui.box.AssignStateTagsToUIBox(planningUIEntities.start_action_button_box, PLANNING_STATE)
    -- remove default state
    remove_default_state_tag(planningUIEntities.start_action_button_box)

    planningUIEntities.wand_buttons = {}

    local function createWandSelectorButtons()
        if not board_sets or #board_sets == 0 then return end

        local anchorTransform = nil
        if board_sets[1] and board_sets[1].trigger_board_id and entity_cache.valid(board_sets[1].trigger_board_id) then
            anchorTransform = component_cache.get(board_sets[1].trigger_board_id, Transform)
        end

        local screenW = globals.screenWidth()
        local screenH = globals.screenHeight()
        local usableScreenH = screenH or 9999
        local buttonMargin = 12
        local verticalSpacing = 8
        local defaultButtonWidth = 52
        local defaultButtonHeight = 52
        local estimatedTotalHeight = (#board_sets) * (defaultButtonHeight + verticalSpacing) - verticalSpacing

        local startX = (anchorTransform and anchorTransform.actualX) or (screenW * 0.08)
        local startY = math.max(buttonMargin, (usableScreenH - estimatedTotalHeight) * 0.5)

        for index, boardSet in ipairs(board_sets) do
            local buttonIndex = index
            local thisBoardSet = boardSet
            local buttonId = "wand_selector_button_" .. buttonIndex
            local label = ui.definitions.getTextFromString("[" .. tostring(buttonIndex) .. "](color=" .. tooltipStyle.labelColor .. ";fontSize=24;shadow=false)")

            local buttonTemplate = UIElementTemplateNodeBuilder.create()
                :addType(UITypeEnum.HORIZONTAL_CONTAINER)
                :addConfig(
                    UIConfigBuilder.create()
                    :addId(buttonId)
                    :addColor(util.getColor("gray"))
                    :addPadding(8.0)
                    :addEmboss(2.0)
                    :addHover(true)
                    :addMinWidth(defaultButtonWidth)
                    :addMinHeight(defaultButtonHeight)
                    :addButtonCallback(function()
                        cycleBoardSet(buttonIndex)
                    end)
                    :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
                    :build()
                )
                :addChild(label)
                :build()

            local root = UIElementTemplateNodeBuilder.create()
                :addType(UITypeEnum.ROOT)
                :addConfig(
                    UIConfigBuilder.create()
                    :addColor(util.getColor("blank"))
                    :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP))
                    :build()
                )
                :addChild(buttonTemplate)
                :build()

            local box = ui.box.Initialize({ x = startX, y = startY }, root)
            ui.box.AssignStateTagsToUIBox(box, PLANNING_STATE)
            remove_default_state_tag(box)
            ui.box.RenewAlignment(registry, box)

            local boxTransform = component_cache.get(box, Transform)
            local resolvedButtonHeight = (boxTransform and boxTransform.actualH) or defaultButtonHeight
            local resolvedButtonWidth = (boxTransform and boxTransform.actualW) or defaultButtonWidth
            if boxTransform then
                local targetX = startX - (resolvedButtonWidth + buttonMargin)
                local totalHeight = (#board_sets) * (resolvedButtonHeight + verticalSpacing) - verticalSpacing
                local centeredTop = (usableScreenH - totalHeight) * 0.5
                local clampedY = math.max(buttonMargin, math.min(centeredTop, usableScreenH - totalHeight - buttonMargin))
                boxTransform.actualX = math.max(buttonMargin, targetX)
                boxTransform.actualY = clampedY + (buttonIndex - 1) * (resolvedButtonHeight + verticalSpacing)
            end

            local buttonEntity = ui.box.GetUIEByID(registry, buttonId)
            local anchorBox = box
            local go = component_cache.get(buttonEntity, GameObject)
            if go then
                go.state.hoverEnabled = true
                go.state.collisionEnabled = true
                go.state.clickEnabled = true
                go.methods.onHover = function()
                    local wandDef = thisBoardSet and thisBoardSet.wandDef
                    if not wandDef then return end

                    for id, tooltipEntity in pairs(wand_tooltip_cache) do
                        if id == wandDef.id then
                            positionTooltipRightOfEntity(tooltipEntity, anchorBox, { gap = 10 })
                            add_state_tag(tooltipEntity, WAND_TOOLTIP_STATE)
                        else
                            clear_state_tags(tooltipEntity)
                        end
                    end

                    activate_state(WAND_TOOLTIP_STATE)
                end
                go.methods.onStopHover = function()
                    deactivate_state(WAND_TOOLTIP_STATE)
                end
            end

            planningUIEntities.wand_buttons[buttonIndex] = {
                box = box,
                button = buttonEntity
            }
        end
    end

    createWandSelectorButtons()

    timer.run(function()
        if not is_state_active or not is_state_active(PLANNING_STATE) then return end
        if not planningUIEntities.wand_buttons then return end

        local currentButton = planningUIEntities.wand_buttons[current_board_set_index]
        if not currentButton or not currentButton.box or not entity_cache.valid(currentButton.box) then return end

        local t = component_cache.get(currentButton.box, Transform)
        if not t then return end

        local zIndex = (layer_order_system and layer_order_system.getZIndex and layer_order_system.getZIndex(currentButton.box)) or 0
        local centerX = (t.actualX or 0) + (t.actualW or 0) * 0.5
        local centerY = (t.actualY or 0) + (t.actualH or 0) * 0.5
        local pulse = 0.5 + 0.5 * math.sin(os.clock() * 3.0)
        local baseRadius = math.max(t.actualW or 0, t.actualH or 0) * 0.6
        local alpha = math.floor(110 + 80 * pulse)

        -- soft halo
        command_buffer.queueDrawCircleFilled(layers.ui, function(c)
            c.x = centerX
            c.y = centerY
            c.radius = baseRadius + 6 * pulse
            c.color = Col(255, 210, 140, alpha)
        end, zIndex - 2, layer.DrawCommandSpace.Screen)

        -- outward particle stream (procedural)
        local now = os.clock()
        for i = 1, 10 do
            local phase = (now * 1.8 + i * 0.23)
            local progress = phase - math.floor(phase)
            local angle = (i * 0.8 + phase * 2.6)
            local travel = baseRadius + progress * (baseRadius * 0.8 + 26)
            local moteRadius = 2 + progress * 4
            local fade = math.floor(180 * (1.0 - progress))

            command_buffer.queueDrawCircleFilled(layers.ui, function(c)
                c.x = centerX + math.cos(angle) * travel
                c.y = centerY + math.sin(angle) * travel
                c.radius = moteRadius
                c.color = Col(255, 225, 180, fade)
            end, zIndex - 1, layer.DrawCommandSpace.Screen)
        end
    end, nil, "wand_selector_highlight")
end
