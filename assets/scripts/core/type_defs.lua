
local Node = require("monobehavior.behavior_script_v2")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local z_orders = require("core.z_orders")

-- cache globals / upvalues
local math_max, math_floor = math.max, math.floor
local registry_get, registry_valid = registry.get, registry.valid
local assignZ = layer_order_system.assignZIndexToEntity
local cardBaseZ = z_orders.card
local ENT_NULL = entt_null


BoardType = Node:extend()

function BoardType:update(dt)
    -- tracy.zoneBeginN("BoardType:update")
    local eid = self:handle()

    ------------------------------------------------------------
    -- Resolve board area and cards
    ------------------------------------------------------------
    local area = component_cache.get(eid, Transform)
    if not area then return end

    local cards = self.cards
    if not cards or #cards == 0 then return end
    
    -- log_debug("BoardType:update - laying out " .. #cards .. " cards for board eid #" .. eid)

    ------------------------------------------------------------
    -- Probe card size from first valid card
    ------------------------------------------------------------
    local cardW, cardH = 100, 140
    for i = 1, #cards do
        local cardEid = cards[i]
        if cardEid and entity_cache.valid(cardEid) and cardEid ~= ENT_NULL then
            local ct = component_cache.get(cardEid, Transform)
            if ct and ct.actualW and ct.actualH and ct.actualW > 0 and ct.actualH > 0 then
                cardW, cardH = ct.actualW, ct.actualH
                break
            end
        end
    end

    ------------------------------------------------------------
    -- Layout math
    ------------------------------------------------------------
    local padding = 20
    local availW = math_max(0, area.actualW - padding * 2)
    local minGap = 12

    local n = #cards
    local spacing, groupW
    if n == 1 then
        spacing, groupW = 0, cardW
    else
        local fitSpacing = (availW - cardW) / (n - 1)
        spacing = math_max(minGap, fitSpacing)
        groupW = cardW + spacing * (n - 1)
        if groupW > availW then
            spacing = math_max(0, fitSpacing)
            groupW = cardW + spacing * (n - 1)
        end
    end

    local startX = area.actualX + padding + (availW - groupW) * 0.5
    local centerY = area.actualY + area.actualH * 0.5

    ------------------------------------------------------------
    -- Z-order cache and sorting
    ------------------------------------------------------------
    local zcache = self.z_order_cache_per_card
    if not zcache then
        zcache = {}
        self.z_order_cache_per_card = zcache
    end

    if n > 1 then
        local cardPositions = {}
        for i = 1, n do
            local eid = cards[i]
            local t = component_cache.get(eid, Transform)
            if t then
                cardPositions[i] = { eid = eid, cx = t.actualX + t.actualW * 0.5 }
            end
        end

        table.sort(cardPositions, function(a, b)
            if a.cx == b.cx then return a.eid < b.eid end
            return a.cx < b.cx
        end)

        for i = 1, n do
            cards[i] = cardPositions[i].eid
        end
    end

    ------------------------------------------------------------
    -- Layout cards
    ------------------------------------------------------------
    for i = 1, n do
        local cardEid = cards[i]
        local ct = component_cache.get(cardEid, Transform)
        if ct then
            local x = startX + (i - 1) * spacing
            local y = centerY - ct.actualH * 0.5

            if self.isInventoryBoard and getScriptTableFromEntityID then
                local cardScript = getScriptTableFromEntityID(cardEid)
                if cardScript and cardScript.selected and not cardScript.isBeingDragged then
                    local lift = math_max(8, ct.actualH * 0.12)
                    y = y - lift
                end
            end

            ct.actualX = math_floor(x + 0.5)
            ct.actualY = math_floor(y + 0.5)
        end

        --------------------------------------------------------
        -- Assign Z order
        --------------------------------------------------------
        local zi = cardBaseZ + (i - 1)
        zcache[cardEid] = zi
        assignZ(cardEid, zi)

        local cardObj = component_cache.get(cardEid, GameObject)
        if cardObj and cardObj.state and cardObj.state.isBeingDragged then
            assignZ(cardEid, z_orders.top_card + 1)
        end
    end

    -- tracy.zoneEnd()
end

function BoardType:swapCardWithNeighbor(selectedEid, direction)
    -- direction: -1 = left, +1 = right
    if not selectedEid or (direction ~= -1 and direction ~= 1) then return end
    if not self.cards or #self.cards == 0 then return end

    -- find index of selected card
    local idx = nil
    for i, eid in ipairs(self.cards) do
        if eid == selectedEid then
            idx = i
            break
        end
    end
    if not idx then return end

    local neighborIndex = idx + direction
    if neighborIndex < 1 or neighborIndex > #self.cards then return end

    local leftEid  = self.cards[idx]
    local rightEid = self.cards[neighborIndex]

    -- swap in table order
    self.cards[idx], self.cards[neighborIndex] = self.cards[neighborIndex], self.cards[idx]

    -- optional: immediately swap their transforms' X so it looks instant before re-layout
    local t1 = component_cache.get(leftEid, Transform)
    local t2 = component_cache.get(rightEid, Transform)
    if t1 and t2 then
        local tempX = t1.actualX
        t1.actualX = t2.actualX
        t2.actualX = tempX
    end

    -- optional: maintain z-order cache consistency
    local zcache = self.z_order_cache_per_card
    if zcache then
        local z1, z2 = zcache[leftEid], zcache[rightEid]
        zcache[leftEid], zcache[rightEid] = z2, z1
    end

    -- optional: immediately re-run layout (or wait until next frame)
    -- self:update(0)
end


-- -------------------------------------------------------------------------- --
--                                Particle type                               --
-- -------------------------------------------------------------------------- --

ParticleType = Node:extend()

function ParticleType:update(dt) 
    self.age = self.age + dt
    
    log_debug("Particle age:", self.age)
    
    -- draw a gradient rounded rect at the survivor position
    command_buffer.queueDrawGradientRectRoundedCentered(layers.sprites, function(c)
        local t = component_cache.get(survivorEntity, Transform)
        c.cx = self.savedPos.x + t.actualW / 2 -- center of survivor
        c.cy = self.savedPos.y + t.actualH / 2
        c.width = t.actualW * (1.0 - self.age / self.lifetime)
        c.height = t.actualH  * (1.0 - self.age / self.lifetime)
        c.roundness = 0.5
        c.segments = 8
        c.topLeft = util.getColor("yellow")
        c.topRight = util.getColor("blue")
        c.bottomRight = util.getColor("green")
        c.bottomLeft = util.getColor("apricot_cream")
    end, z_orders.player_vfx - 20, layer.DrawCommandSpace.World)
end


-- -------------------------------------------------------------------------- --
--                            Generic spawn marker                            --
-- -------------------------------------------------------------------------- --
