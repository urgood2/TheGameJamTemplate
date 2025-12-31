local ShopPackUI = {}

local z_orders = require("core.z_orders")
local timer = require("core.timer")
local signal = require("external.hump.signal")

local ShopSystem = nil
local function getShopSystem()
    if not ShopSystem then
        local ok, mod = pcall(require, "core.shop_system")
        if ok then ShopSystem = mod end
    end
    return ShopSystem
end

local CONFIG = {
    packButtonW = 140,
    packButtonH = 180,
    packSpacing = 20,
    packTopMargin = 100,
    
    cardW = 80,
    cardH = 112,
    cardSpacing = 100,
    cardRevealDelay = 0.3,
    
    dissolveSpeed = 1.5,
    
    errorDisplayTime = 2.0,
}

local PACK_COLORS = {
    trigger = { bg = Col(100, 60, 120, 230), border = Col(180, 120, 220, 255) },
    modifier = { bg = Col(60, 100, 120, 230), border = Col(120, 180, 220, 255) },
    action = { bg = Col(120, 80, 60, 230), border = Col(220, 160, 120, 255) },
}

local state = {
    isActive = false,
    phase = "packs",
    activePack = nil,
    revealedCards = {},
    cardEntities = {},
    chosenIndex = nil,
    dissolveProgress = {},
    errorMessage = nil,
    errorUntil = 0,
    hoveredPack = nil,
    hoveredCard = nil,
    timerGroup = "shop_pack_ui",
}

local function getPlayer()
    if globals and globals.player then
        return globals.player
    end
    return nil
end

local function getPlayerGold()
    local player = getPlayer()
    if player and player.gold then
        return player.gold
    end
    return 0
end

local function getMousePos()
    if input and input.getMousePos then
        local m = input.getMousePos()
        if m and m.x and m.y then return m.x, m.y end
    end
    if globals then
        return globals.mouseX or 0, globals.mouseY or 0
    end
    return 0, 0
end

local function isMousePressed()
    if IsMouseButtonPressed then
        return IsMouseButtonPressed(0)
    end
    return false
end

local function isInRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function ShopPackUI.init()
    state.isActive = true
    state.phase = "packs"
    state.activePack = nil
    state.revealedCards = {}
    state.cardEntities = {}
    state.chosenIndex = nil
    state.dissolveProgress = {}
    state.errorMessage = nil
    state.hoveredPack = nil
    state.hoveredCard = nil
end

function ShopPackUI.show()
    state.isActive = true
    state.phase = "packs"
end

function ShopPackUI.hide()
    state.isActive = false
    timer.kill_group(state.timerGroup)
end

local function showError(msg)
    state.errorMessage = msg
    state.errorUntil = (GetTime and GetTime() or 0) + CONFIG.errorDisplayTime
end

local function startPackOpening(packType)
    local shop = getShopSystem()
    local player = getPlayer()
    
    if not shop or not player then
        showError("Shop not available")
        return
    end
    
    if not shop.canAffordPack(player) then
        showError("Not enough gold!")
        return
    end
    
    local success, packOrErr = shop.purchasePack(packType, player, 1)
    if not success then
        showError(packOrErr or "Purchase failed")
        return
    end
    
    state.activePack = packOrErr
    state.phase = "revealing"
    state.revealedCards = {}
    state.cardEntities = {}
    state.chosenIndex = nil
    state.dissolveProgress = {}
    
    signal.emit("deck_changed", { source = "shop_pack" })
    
    for i = 1, #state.activePack.cards do
        state.revealedCards[i] = false
        
        timer.after_opts({
            delay = (i - 1) * CONFIG.cardRevealDelay,
            action = function()
                state.revealedCards[i] = true
                if i == #state.activePack.cards then
                    state.phase = "choosing"
                end
            end,
            tag = state.timerGroup .. "_reveal_" .. i,
        })
    end
end

local function chooseCard(index)
    if state.phase ~= "choosing" then return end
    if not state.activePack or not state.activePack.cards then return end
    if index < 1 or index > #state.activePack.cards then return end
    
    state.chosenIndex = index
    state.phase = "resolving"
    
    local shop = getShopSystem()
    local player = getPlayer()
    
    if shop and player then
        shop.chooseFromPack(state.activePack, index, player)
        signal.emit("deck_changed", { source = "shop_pack_choice" })
    end
    
    for i = 1, #state.activePack.cards do
        if i ~= index then
            state.dissolveProgress[i] = 0
        end
    end
    
    timer.after_opts({
        delay = 1.5,
        action = function()
            state.phase = "packs"
            state.activePack = nil
            state.revealedCards = {}
            state.chosenIndex = nil
            state.dissolveProgress = {}
        end,
        tag = state.timerGroup .. "_return",
    })
end

function ShopPackUI.update(dt)
    if not state.isActive then return end
    
    local now = GetTime and GetTime() or 0
    if state.errorMessage and now >= state.errorUntil then
        state.errorMessage = nil
    end
    
    if state.phase == "resolving" then
        for i, progress in pairs(state.dissolveProgress) do
            state.dissolveProgress[i] = math.min(1, progress + dt * CONFIG.dissolveSpeed)
        end
    end
    
    local mx, my = getMousePos()
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    
    state.hoveredPack = nil
    state.hoveredCard = nil
    
    if state.phase == "packs" then
        local packTypes = { "trigger", "modifier", "action" }
        local totalW = #packTypes * CONFIG.packButtonW + (#packTypes - 1) * CONFIG.packSpacing
        local startX = (screenW - totalW) / 2
        local y = CONFIG.packTopMargin
        
        for i, packType in ipairs(packTypes) do
            local x = startX + (i - 1) * (CONFIG.packButtonW + CONFIG.packSpacing)
            if isInRect(mx, my, x, y, CONFIG.packButtonW, CONFIG.packButtonH) then
                state.hoveredPack = packType
                if isMousePressed() then
                    startPackOpening(packType)
                end
            end
        end
    elseif state.phase == "choosing" and state.activePack then
        local cardCount = #state.activePack.cards
        local totalW = cardCount * CONFIG.cardW + (cardCount - 1) * CONFIG.cardSpacing
        local startX = (screenW - totalW) / 2
        local y = screenH / 2 - CONFIG.cardH / 2
        
        for i = 1, cardCount do
            if state.revealedCards[i] then
                local x = startX + (i - 1) * (CONFIG.cardW + CONFIG.cardSpacing)
                if isInRect(mx, my, x, y, CONFIG.cardW, CONFIG.cardH) then
                    state.hoveredCard = i
                    if isMousePressed() then
                        chooseCard(i)
                    end
                end
            end
        end
    end
end

function ShopPackUI.draw()
    if not state.isActive then return end
    if not command_buffer or not layers then return end
    
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1920
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 1080
    local space = layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen
    local baseZ = (z_orders and z_orders.ui_tooltips or 0) + 10
    local font = localization and localization.getFont and localization.getFont()
    
    if state.phase == "packs" then
        ShopPackUI.drawPackButtons(screenW, screenH, space, baseZ, font)
    elseif state.phase == "revealing" or state.phase == "choosing" or state.phase == "resolving" then
        ShopPackUI.drawCards(screenW, screenH, space, baseZ, font)
    end
    
    if state.errorMessage then
        local errW = 300
        local errH = 40
        local errX = (screenW - errW) / 2
        local errY = screenH - 100
        
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = screenW / 2
            c.y = errY + errH / 2
            c.w = errW
            c.h = errH
            c.rx = 8
            c.ry = 8
            c.color = Col(180, 60, 60, 230)
        end, baseZ + 50, space)
        
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = state.errorMessage
            c.font = font
            c.x = errX + 20
            c.y = errY + 10
            c.color = Col(255, 255, 255, 255)
            c.fontSize = 18
        end, baseZ + 51, space)
    end
end

function ShopPackUI.drawPackButtons(screenW, screenH, space, baseZ, font)
    local shop = getShopSystem()
    local packTypes = shop and shop.getPackTypes and shop.getPackTypes() or { "trigger", "modifier", "action" }
    local packCost = shop and shop.config and shop.config.packCost or 25
    
    local totalW = #packTypes * CONFIG.packButtonW + (#packTypes - 1) * CONFIG.packSpacing
    local startX = (screenW - totalW) / 2
    local y = CONFIG.packTopMargin
    
    local playerGold = getPlayerGold()
    local canAfford = playerGold >= packCost
    
    for i, packType in ipairs(packTypes) do
        local x = startX + (i - 1) * (CONFIG.packButtonW + CONFIG.packSpacing)
        local cx = x + CONFIG.packButtonW / 2
        local cy = y + CONFIG.packButtonH / 2
        local isHovered = state.hoveredPack == packType
        
        local colors = PACK_COLORS[packType] or PACK_COLORS.action
        local bgColor = colors.bg
        local borderColor = colors.border
        
        if not canAfford then
            bgColor = Col(60, 60, 60, 200)
            borderColor = Col(100, 100, 100, 200)
        elseif isHovered then
            bgColor = Col(math.min(255, bgColor.r + 30), math.min(255, bgColor.g + 30), math.min(255, bgColor.b + 30), bgColor.a)
        end
        
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = cx
            c.y = cy
            c.w = CONFIG.packButtonW + 4
            c.h = CONFIG.packButtonH + 4
            c.rx = 12
            c.ry = 12
            c.color = borderColor
        end, baseZ, space)
        
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = cx
            c.y = cy
            c.w = CONFIG.packButtonW
            c.h = CONFIG.packButtonH
            c.rx = 10
            c.ry = 10
            c.color = bgColor
        end, baseZ + 1, space)
        
        local displayName = shop and shop.getPackDisplayName and shop.getPackDisplayName(packType) or packType
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = displayName
            c.font = font
            c.x = x + 10
            c.y = y + CONFIG.packButtonH - 50
            c.color = Col(255, 255, 255, canAfford and 255 or 150)
            c.fontSize = 16
        end, baseZ + 2, space)
        
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = packCost .. "g"
            c.font = font
            c.x = x + 10
            c.y = y + CONFIG.packButtonH - 30
            c.color = canAfford and util.getColor("gold") or Col(150, 150, 150, 200)
            c.fontSize = 20
        end, baseZ + 2, space)
    end
    
    command_buffer.queueDrawText(layers.ui, function(c)
        c.text = "Your Gold: " .. playerGold
        c.font = font
        c.x = startX
        c.y = y + CONFIG.packButtonH + 20
        c.color = util.getColor("gold")
        c.fontSize = 18
    end, baseZ + 2, space)
end

function ShopPackUI.drawCards(screenW, screenH, space, baseZ, font)
    if not state.activePack or not state.activePack.cards then return end
    
    local cardCount = #state.activePack.cards
    local totalW = cardCount * CONFIG.cardW + (cardCount - 1) * CONFIG.cardSpacing
    local startX = (screenW - totalW) / 2
    local y = screenH / 2 - CONFIG.cardH / 2
    
    for i, cardDef in ipairs(state.activePack.cards) do
        local x = startX + (i - 1) * (CONFIG.cardW + CONFIG.cardSpacing)
        local cx = x + CONFIG.cardW / 2
        local cy = y + CONFIG.cardH / 2
        
        local isRevealed = state.revealedCards[i]
        local isChosen = state.chosenIndex == i
        local dissolve = state.dissolveProgress[i] or 0
        local isHovered = state.hoveredCard == i and state.phase == "choosing"
        
        if dissolve >= 1 then
            goto continue
        end
        
        local alpha = math.floor(255 * (1 - dissolve))
        local scale = isHovered and 1.1 or 1.0
        if isChosen then scale = 1.15 end
        
        local w = CONFIG.cardW * scale
        local h = CONFIG.cardH * scale
        
        local bgColor, borderColor
        if not isRevealed then
            bgColor = Col(40, 40, 50, alpha)
            borderColor = Col(80, 80, 100, alpha)
        else
            local rarity = state.activePack.rarities[i] or "common"
            if rarity == "legendary" then
                borderColor = Col(243, 156, 18, alpha)
            elseif rarity == "rare" then
                borderColor = Col(155, 89, 182, alpha)
            elseif rarity == "uncommon" then
                borderColor = Col(74, 144, 226, alpha)
            else
                borderColor = Col(180, 180, 180, alpha)
            end
            bgColor = Col(30, 35, 45, alpha)
        end
        
        if isChosen then
            borderColor = Col(100, 255, 100, alpha)
        end
        
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = cx
            c.y = cy
            c.w = w + 4
            c.h = h + 4
            c.rx = 8
            c.ry = 8
            c.color = borderColor
        end, baseZ + i, space)
        
        command_buffer.queueDrawCenteredFilledRoundedRect(layers.ui, function(c)
            c.x = cx
            c.y = cy
            c.w = w
            c.h = h
            c.rx = 6
            c.ry = 6
            c.color = bgColor
        end, baseZ + i + 1, space)
        
        if isRevealed then
            local cardName = cardDef.id or "Card"
            if #cardName > 12 then
                cardName = string.sub(cardName, 1, 10) .. ".."
            end
            
            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = cardName
                c.font = font
                c.x = x + 5
                c.y = y + h - 25
                c.color = Col(255, 255, 255, alpha)
                c.fontSize = 10
            end, baseZ + i + 2, space)
        else
            command_buffer.queueDrawText(layers.ui, function(c)
                c.text = "?"
                c.font = font
                c.x = cx - 10
                c.y = cy - 15
                c.color = Col(150, 150, 150, alpha)
                c.fontSize = 30
            end, baseZ + i + 2, space)
        end
        
        ::continue::
    end
    
    if state.phase == "choosing" then
        command_buffer.queueDrawText(layers.ui, function(c)
            c.text = "Click a card to keep it"
            c.font = font
            c.x = screenW / 2 - 80
            c.y = y + CONFIG.cardH + 30
            c.color = Col(200, 200, 200, 255)
            c.fontSize = 16
        end, baseZ + 20, space)
    end
end

function ShopPackUI.cleanup()
    timer.kill_group(state.timerGroup)
    state.isActive = false
    state.phase = "packs"
    state.activePack = nil
end

return ShopPackUI
