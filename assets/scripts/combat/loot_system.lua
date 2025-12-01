--[[
    Loot Drop System

    Manages loot spawning and collection:
    - XP orbs
    - Gold/currency
    - Health potions
    - Ability cards
    - Equipment items

    Features:
    - Configurable loot tables per enemy type
    - Auto-collect and manual collection modes
    - Magnet mechanics
    - Visual feedback
    - Pickup delays and despawn timers

    Integrates with:
    - Entity factory (spawn loot entities)
    - Event bus (loot events)
    - Currency system (existing spawnCurrency)
]]

local timer = require("core.timer")
local random_utils = require("util.util")

local LootSystem = {}
LootSystem.__index = LootSystem

-- Loot type constants
LootSystem.LootTypes = {
    GOLD = "gold",
    XP_ORB = "xp_orb",
    HEALTH_POTION = "health_potion",
    CARD = "card",
    ITEM = "item"
}

-- Collection mode constants
LootSystem.CollectionModes = {
    AUTO_COLLECT = "auto_collect",    -- Immediate collection
    CLICK = "click",                  -- Click to collect
    MAGNET = "magnet"                 -- Attract to player when nearby
}

--[[
    Create a new loot system

    @param config table {
        combat_context = Combat context (for event bus),
        player_entity = Player entity ID,
        loot_tables = { enemy_type = loot_table, ... },
        default_collection_mode = "auto_collect" | "click" | "magnet",
        magnet_range = number (default 150),
        despawn_time = number (default 30),
        on_loot_collected = function(player, loot_type, amount)
    }
    @return LootSystem instance
]]
function LootSystem.new(config)
    local self = setmetatable({}, LootSystem)

    self.combat_context = config.combat_context
    self.player_entity = config.player_entity
    self.loot_tables = config.loot_tables or {}

    -- Settings
    self.default_collection_mode = config.default_collection_mode or self.CollectionModes.AUTO_COLLECT
    self.magnet_range = config.magnet_range or 150
    self.despawn_time = config.despawn_time or 30

    -- Callbacks
    self.on_loot_collected = config.on_loot_collected

    -- Tracking
    self.active_loot = {}  -- List of spawned loot entities

    -- Default loot tables if none provided
    if not next(self.loot_tables) then
        self.loot_tables = self:get_default_loot_tables()
    end

    return self
end

--[[
    Get default loot tables for common enemy types
]]
function LootSystem:get_default_loot_tables()
    return {
        goblin = {
            gold = { min = 1, max = 3, chance = 100 },
            xp = { base = 10, variance = 2, chance = 100 },
            items = {
                { type = "health_potion", chance = 10 }
            }
        },
        orc = {
            gold = { min = 3, max = 7, chance = 100 },
            xp = { base = 25, variance = 5, chance = 100 },
            items = {
                { type = "health_potion", chance = 15 },
                { type = "card_common", chance = 5 }
            }
        },
        boss = {
            gold = { min = 20, max = 50, chance = 100 },
            xp = { base = 100, variance = 20, chance = 100 },
            items = {
                { type = "card_rare", chance = 50 },
                { type = "card_uncommon", chance = 100 },
                { type = "health_potion", chance = 100 }
            }
        },
        unknown = {
            gold = { min = 1, max = 2, chance = 80 },
            xp = { base = 5, variance = 1, chance = 80 }
        }
    }
end

--[[
    Spawn loot for a dead enemy

    @param enemy_type string - Enemy type identifier
    @param position table {x, y} - Spawn position
    @param combat_context - Optional combat context
]]
function LootSystem:spawn_loot_for_enemy(enemy_type, position, combat_context)
    local loot_table = self.loot_tables[enemy_type] or self.loot_tables.unknown

    if not loot_table then
        log_debug("[LootSystem] No loot table for enemy type:", enemy_type)
        return
    end

    log_debug("[LootSystem] Rolling loot for", enemy_type, "at", position.x, position.y)

    -- Roll for gold
    if loot_table.gold and self:roll_chance(loot_table.gold.chance or 100) then
        local amount = math.random(loot_table.gold.min, loot_table.gold.max)
        self:spawn_gold(position, amount)
    end

    -- Roll for XP
    if loot_table.xp and self:roll_chance(loot_table.xp.chance or 100) then
        local amount = loot_table.xp.base + math.random(-loot_table.xp.variance, loot_table.xp.variance)
        amount = math.max(1, amount)
        self:spawn_xp(position, amount)
    end

    -- Roll for items
    if loot_table.items then
        for _, item_drop in ipairs(loot_table.items) do
            if self:roll_chance(item_drop.chance) then
                self:spawn_item(position, item_drop.type)
            end
        end
    end
end

--[[
    Roll a chance (0-100)

    @param chance number - Percentage chance (0-100)
    @return boolean
]]
function LootSystem:roll_chance(chance)
    return math.random(1, 100) <= chance
end

--[[
    Spawn gold loot

    @param position table {x, y}
    @param amount number - Amount of gold to drop
]]
function LootSystem:spawn_gold(position, amount)
    -- Use existing currency spawning if available
    if spawnCurrency then
        for i = 1, amount do
            local offset_x = (math.random() - 0.5) * 80
            local offset_y = (math.random() - 0.5) * 80
            spawnCurrency(position.x + offset_x, position.y + offset_y, "whale_dust")
        end

        log_debug("[LootSystem] Spawned", amount, "gold at", position.x, position.y)
    else
        log_debug("[LootSystem] spawnCurrency not available, using fallback")
        self:spawn_loot_entity(self.LootTypes.GOLD, position, amount)
    end

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnLootDropped", {
            loot_type = self.LootTypes.GOLD,
            amount = amount,
            position = position
        })
    end
end

--[[
    Spawn XP orb

    @param position table {x, y}
    @param amount number - Amount of XP
]]
function LootSystem:spawn_xp(position, amount)
    log_debug("[LootSystem] Spawning XP orb:", amount, "at", position.x, position.y)

    local loot_entity = self:spawn_loot_entity(self.LootTypes.XP_ORB, position, amount)

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnLootDropped", {
            loot_entity = loot_entity,
            loot_type = self.LootTypes.XP_ORB,
            amount = amount,
            position = position
        })
    end
end

--[[
    Spawn an item drop

    @param position table {x, y}
    @param item_type string - Type of item
]]
function LootSystem:spawn_item(position, item_type)
    log_debug("[LootSystem] Spawning item:", item_type, "at", position.x, position.y)

    local loot_entity = self:spawn_loot_entity(item_type, position, 1)

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnLootDropped", {
            loot_entity = loot_entity,
            loot_type = item_type,
            position = position
        })
    end
end

--[[
    Spawn a loot entity (XP orb, health potion, etc.)

    @param loot_type string
    @param position table {x, y}
    @param amount number
    @return entity_id or nil
]]
function LootSystem:spawn_loot_entity(loot_type, position, amount)
    local sprite = self:get_loot_sprite(loot_type)

    if not sprite then
        log_error("[LootSystem] No sprite for loot type:", loot_type)
        return nil
    end

    -- Create animated object
    if not animation_system or not animation_system.createAnimatedObjectWithTransform then
        log_error("[LootSystem] animation_system not available")
        return nil
    end

    local entity_id = animation_system.createAnimatedObjectWithTransform(
        sprite,
        false,  -- looping
        position.x,
        position.y,
        nil,    -- shader pass
        true    -- shadow
    )

    if not entity_id or entity_id == entt_null then
        log_error("[LootSystem] Failed to create loot entity")
        return nil
    end

    -- Resize to reasonable size
    if animation_system.resizeAnimationObjectsInEntityToFit then
        local size = self:get_loot_size(loot_type)
        animation_system.resizeAnimationObjectsInEntityToFit(entity_id, size.w, size.h)
    end

    -- Setup collection behavior
    self:setup_loot_collection(entity_id, loot_type, amount, position)

    -- Track loot
    table.insert(self.active_loot, {
        entity_id = entity_id,
        loot_type = loot_type,
        amount = amount,
        spawn_time = os.clock()
    })

    -- Auto-despawn after timeout
    timer.after(self.despawn_time, function()
        self:despawn_loot(entity_id)
    end, "loot_despawn_" .. entity_id)

    log_debug("[LootSystem] Spawned loot entity:", entity_id, "type:", loot_type)

    return entity_id
end

--[[
    Get sprite for loot type

    @param loot_type string
    @return string - Animation ID
]]
function LootSystem:get_loot_sprite(loot_type)
    local sprites = {
        [self.LootTypes.XP_ORB] = "krill_1_anim",  -- Placeholder
        [self.LootTypes.HEALTH_POTION] = "blue_whale_anim",  -- Placeholder
        [self.LootTypes.CARD] = "krill_2_anim",  -- Placeholder
        [self.LootTypes.ITEM] = "krill_3_anim"   -- Placeholder
    }

    return sprites[loot_type] or "krill_1_anim"
end

--[[
    Get size for loot type

    @param loot_type string
    @return table {w, h}
]]
function LootSystem:get_loot_size(loot_type)
    local sizes = {
        [self.LootTypes.XP_ORB] = { w = 24, h = 24 },
        [self.LootTypes.GOLD] = { w = 32, h = 32 },
        [self.LootTypes.HEALTH_POTION] = { w = 32, h = 32 },
        [self.LootTypes.CARD] = { w = 40, h = 56 },
        [self.LootTypes.ITEM] = { w = 40, h = 40 }
    }

    return sizes[loot_type] or { w = 32, h = 32 }
end

--[[
    Setup loot collection behavior

    @param entity_id
    @param loot_type string
    @param amount number
    @param position table {x, y}
]]
function LootSystem:setup_loot_collection(entity_id, loot_type, amount, position)
    local collection_mode = self.default_collection_mode

    if collection_mode == self.CollectionModes.AUTO_COLLECT then
        self:setup_auto_collect(entity_id, loot_type, amount)

    elseif collection_mode == self.CollectionModes.CLICK then
        self:setup_click_collect(entity_id, loot_type, amount)

    elseif collection_mode == self.CollectionModes.MAGNET then
        self:setup_magnet_collect(entity_id, loot_type, amount)
    end

    -- Spawn animation (jiggle)
    if transform and transform.InjectDynamicMotionDefault then
        transform.InjectDynamicMotionDefault(entity_id)
    end
end

--[[
    Setup auto-collect (immediate)
]]
function LootSystem:setup_auto_collect(entity_id, loot_type, amount)
    timer.after(0.3, function()
        self:collect_loot(entity_id, loot_type, amount)
    end, "loot_autocollect_" .. entity_id)
end

--[[
    Setup click-to-collect
]]
function LootSystem:setup_click_collect(entity_id, loot_type, amount)
    if not registry or not registry:valid(entity_id) then return end

    local game_object = registry:get(entity_id, GameObject)
    if not game_object then return end

    game_object.state.clickEnabled = true
    game_object.state.hoverEnabled = true
    game_object.state.collisionEnabled = true

    game_object.methods.onClick = function(reg, eid)
        self:collect_loot(eid, loot_type, amount)
    end
end

--[[
    Setup magnet-collect (attract to player)
]]
function LootSystem:setup_magnet_collect(entity_id, loot_type, amount)
    -- Update position every frame to move towards player
    timer.every(0.033, function()  -- ~30 FPS
        if not registry or not registry:valid(entity_id) or not self.player_entity then
            timer.cancel("loot_magnet_" .. entity_id)
            return
        end

        local loot_transform = registry:get(entity_id, Transform)
        local player_transform = registry:get(self.player_entity, Transform)

        if not loot_transform or not player_transform then
            timer.cancel("loot_magnet_" .. entity_id)
            return
        end

        -- Calculate distance
        local loot_x = loot_transform.actualX + (loot_transform.actualW or 0) * 0.5
        local loot_y = loot_transform.actualY + (loot_transform.actualH or 0) * 0.5
        local player_x = player_transform.actualX + (player_transform.actualW or 0) * 0.5
        local player_y = player_transform.actualY + (player_transform.actualH or 0) * 0.5

        local dx = player_x - loot_x
        local dy = player_y - loot_y
        local distance = math.sqrt(dx * dx + dy * dy)

        -- In range?
        if distance < self.magnet_range then
            -- Move towards player
            local speed = 300  -- pixels per second
            local dt = 0.033

            if distance < 20 then
                -- Close enough, collect
                timer.cancel("loot_magnet_" .. entity_id)
                self:collect_loot(entity_id, loot_type, amount)
            else
                -- Move towards player
                local dir_x = dx / distance
                local dir_y = dy / distance

                loot_transform.actualX = loot_transform.actualX + dir_x * speed * dt
                loot_transform.actualY = loot_transform.actualY + dir_y * speed * dt
            end
        end
    end, 0, true, nil, "loot_magnet_" .. entity_id)
end

--[[
    Collect loot

    @param entity_id
    @param loot_type string
    @param amount number
]]
function LootSystem:collect_loot(entity_id, loot_type, amount)
    if not registry or not registry:valid(entity_id) then
        return
    end

    log_debug("[LootSystem] Collecting loot:", loot_type, "amount:", amount)

    -- Apply loot effect
    if loot_type == self.LootTypes.XP_ORB then
        self:apply_xp(amount)
    elseif loot_type == self.LootTypes.GOLD then
        self:apply_gold(amount)
    elseif loot_type == self.LootTypes.HEALTH_POTION then
        self:apply_health_potion()
    end

    -- Emit event
    if self.combat_context and self.combat_context.bus then
        self.combat_context.bus:emit("OnLootCollected", {
            player = self.player_entity,
            loot_type = loot_type,
            amount = amount
        })
    end

    -- Callback
    if self.on_loot_collected then
        self.on_loot_collected(self.player_entity, loot_type, amount)
    end

    -- Remove loot entity
    self:despawn_loot(entity_id)
end

--[[
    Apply XP to player

    @param amount number
]]
function LootSystem:apply_xp(amount)
    -- Use combat system leveling if available
    if self.combat_context and self.combat_context.Leveling then
        local player_data = self:get_player_data()
        if player_data then
            self.combat_context.Leveling.grant_exp(self.combat_context, player_data, amount)
        end
    else
        log_debug("[LootSystem] Granted", amount, "XP (no leveling system)")
    end
end

--[[
    Apply gold to player

    @param amount number
]]
function LootSystem:apply_gold(amount)
    amount = amount or 0
    if globals and globals.currencies and globals.currencies.whale_dust then
        globals.currencies.whale_dust.target = (globals.currencies.whale_dust.target or 0) + amount
        log_debug("[LootSystem] Granted", amount, "gold")
    else
        log_debug("[LootSystem] Granted", amount, "gold (no currency system)")
    end

    if globals then
        globals.currency = (globals.currency or 0) + amount
    end
end

--[[
    Apply health potion to player
]]
function LootSystem:apply_health_potion()
    local player_data = self:get_player_data()
    if player_data and player_data.hp and player_data.max_health then
        player_data.hp = math.min(player_data.hp + 50, player_data.max_health)
        log_debug("[LootSystem] Healed player for 50 HP")
    end
end

--[[
    Get player data object
]]
function LootSystem:get_player_data()
    if not self.player_entity or not registry or not registry:valid(self.player_entity) then
        return nil
    end

    if getScriptTableFromEntityID then
        return getScriptTableFromEntityID(self.player_entity)
    end

    return nil
end

--[[
    Despawn a loot entity

    @param entity_id
]]
function LootSystem:despawn_loot(entity_id)
    if not registry or not registry:valid(entity_id) then
        return
    end

    -- Cancel timers
    timer.cancel("loot_despawn_" .. entity_id)
    timer.cancel("loot_autocollect_" .. entity_id)
    timer.cancel("loot_magnet_" .. entity_id)

    -- Remove from tracking
    for i, loot in ipairs(self.active_loot) do
        if loot.entity_id == entity_id then
            table.remove(self.active_loot, i)
            break
        end
    end

    -- Destroy entity
    registry:destroy(entity_id)

    log_debug("[LootSystem] Despawned loot:", entity_id)
end

--[[
    Cleanup all active loot
]]
function LootSystem:cleanup_all_loot()
    log_debug("[LootSystem] Cleaning up", #self.active_loot, "active loot entities")

    for _, loot in ipairs(self.active_loot) do
        self:despawn_loot(loot.entity_id)
    end

    self.active_loot = {}
end

return LootSystem
