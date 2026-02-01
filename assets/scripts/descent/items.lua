-- assets/scripts/descent/items.lua
--[[
================================================================================
DESCENT ITEMS MODULE
================================================================================
Item and inventory system for Descent roguelike mode.

Features:
- Item definitions and instances
- Inventory management (pickup/drop/use/equip)
- Capacity enforcement per spec (block policy)
- Equipment slots (weapon, armor)
- Integration hooks for player stats

Usage:
    local items = require("descent.items")
    items.init()
    local inv = items.create_inventory()
    items.pickup(inv, item, player_pos)
]]

local M = {}

-- Dependencies
local spec = require("descent.spec")
local rng  -- Lazy loaded

--------------------------------------------------------------------------------
-- Item Definitions
--------------------------------------------------------------------------------

-- Item types
M.ITEM_TYPE = {
    WEAPON = "weapon",
    ARMOR = "armor",
    POTION = "potion",
    SCROLL = "scroll",
    GOLD = "gold",
    FOOD = "food",
    MISC = "misc",
}

-- Equipment slots
M.EQUIP_SLOT = {
    WEAPON = "weapon",
    ARMOR = "armor",
}

-- Base item definitions (templates)
local item_templates = {
    -- Weapons
    short_sword = {
        id = "short_sword",
        name = "Short Sword",
        type = M.ITEM_TYPE.WEAPON,
        slot = M.EQUIP_SLOT.WEAPON,
        stackable = false,
        stats = { damage = 5, accuracy = 0 },
        value = 50,
    },
    long_sword = {
        id = "long_sword",
        name = "Long Sword",
        type = M.ITEM_TYPE.WEAPON,
        slot = M.EQUIP_SLOT.WEAPON,
        stackable = false,
        stats = { damage = 8, accuracy = -5 },
        value = 100,
    },
    dagger = {
        id = "dagger",
        name = "Dagger",
        type = M.ITEM_TYPE.WEAPON,
        slot = M.EQUIP_SLOT.WEAPON,
        stackable = false,
        stats = { damage = 3, accuracy = 10 },
        value = 30,
    },
    
    -- Armor
    leather_armor = {
        id = "leather_armor",
        name = "Leather Armor",
        type = M.ITEM_TYPE.ARMOR,
        slot = M.EQUIP_SLOT.ARMOR,
        stackable = false,
        stats = { armor = 2, evasion = 0 },
        value = 60,
    },
    chain_mail = {
        id = "chain_mail",
        name = "Chain Mail",
        type = M.ITEM_TYPE.ARMOR,
        slot = M.EQUIP_SLOT.ARMOR,
        stackable = false,
        stats = { armor = 5, evasion = -10 },
        value = 150,
    },
    
    -- Potions
    health_potion = {
        id = "health_potion",
        name = "Health Potion",
        type = M.ITEM_TYPE.POTION,
        stackable = true,
        max_stack = 10,
        effect = { heal = 20 },
        value = 25,
    },
    mana_potion = {
        id = "mana_potion",
        name = "Mana Potion",
        type = M.ITEM_TYPE.POTION,
        stackable = true,
        max_stack = 10,
        effect = { restore_mp = 15 },
        value = 30,
    },
    
    -- Gold
    gold = {
        id = "gold",
        name = "Gold",
        type = M.ITEM_TYPE.GOLD,
        stackable = true,
        max_stack = 9999,
        value = 1,
    },
}

-- Item instance counter for unique IDs
local next_item_id = 1

--------------------------------------------------------------------------------
-- Item Creation
--------------------------------------------------------------------------------

--- Create an item instance from a template
--- @param template_id string Template ID
--- @param quantity number|nil Stack quantity (default 1)
--- @return table|nil Item instance or nil if template not found
function M.create_item(template_id, quantity)
    local template = item_templates[template_id]
    if not template then
        return nil
    end
    
    local item = {
        instance_id = next_item_id,
        template_id = template_id,
        name = template.name,
        type = template.type,
        slot = template.slot,
        stackable = template.stackable,
        max_stack = template.max_stack or 1,
        quantity = quantity or 1,
        stats = template.stats and M.copy_table(template.stats) or nil,
        effect = template.effect and M.copy_table(template.effect) or nil,
        value = template.value or 0,
        identified = template.type ~= M.ITEM_TYPE.SCROLL, -- Scrolls start unidentified
    }
    
    next_item_id = next_item_id + 1
    
    -- Clamp quantity
    if item.stackable then
        item.quantity = math.min(item.quantity, item.max_stack)
    else
        item.quantity = 1
    end
    
    return item
end

--- Get item template by ID
--- @param template_id string
--- @return table|nil
function M.get_template(template_id)
    return item_templates[template_id]
end

--- Register a new item template
--- @param template table Item template
function M.register_template(template)
    if template.id then
        item_templates[template.id] = template
    end
end

--------------------------------------------------------------------------------
-- Inventory Management
--------------------------------------------------------------------------------

--- Create a new inventory
--- @param capacity number|nil Override capacity (default from spec)
--- @return table Inventory
function M.create_inventory(capacity)
    return {
        items = {},  -- Array of item instances
        equipped = {
            [M.EQUIP_SLOT.WEAPON] = nil,
            [M.EQUIP_SLOT.ARMOR] = nil,
        },
        capacity = capacity or spec.inventory.capacity,
        gold = 0,
    }
end

--- Get inventory count (items, not stacks)
--- @param inventory table
--- @return number
function M.count(inventory)
    return #inventory.items
end

--- Check if inventory is full
--- @param inventory table
--- @return boolean
function M.is_full(inventory)
    return #inventory.items >= inventory.capacity
end

--- Get remaining capacity
--- @param inventory table
--- @return number
function M.remaining_capacity(inventory)
    return inventory.capacity - #inventory.items
end

--- Find item in inventory by instance_id
--- @param inventory table
--- @param instance_id number
--- @return number|nil Index in items array
function M.find_by_id(inventory, instance_id)
    for i, item in ipairs(inventory.items) do
        if item.instance_id == instance_id then
            return i
        end
    end
    return nil
end

--- Find stackable item in inventory
--- @param inventory table
--- @param template_id string
--- @return number|nil Index of stackable item with room
function M.find_stackable(inventory, template_id)
    for i, item in ipairs(inventory.items) do
        if item.template_id == template_id and 
           item.stackable and 
           item.quantity < item.max_stack then
            return i
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Pickup / Drop / Use / Equip
--------------------------------------------------------------------------------

--- Result codes for inventory operations
M.RESULT = {
    SUCCESS = "success",
    FULL = "full",
    NOT_FOUND = "not_found",
    ALREADY_EQUIPPED = "already_equipped",
    CANNOT_EQUIP = "cannot_equip",
    CANNOT_USE = "cannot_use",
}

--- Attempt to pick up an item
--- @param inventory table
--- @param item table Item instance
--- @return string Result code
--- @return number|nil Turn cost (0 if blocked)
function M.pickup(inventory, item)
    if not item then
        return M.RESULT.NOT_FOUND, 0
    end
    
    -- Handle gold separately
    if item.type == M.ITEM_TYPE.GOLD then
        inventory.gold = inventory.gold + (item.quantity * item.value)
        return M.RESULT.SUCCESS, spec.inventory.pickup.cost
    end
    
    -- Check for stackable
    if item.stackable then
        local stack_idx = M.find_stackable(inventory, item.template_id)
        if stack_idx then
            local stack = inventory.items[stack_idx]
            local can_add = stack.max_stack - stack.quantity
            local to_add = math.min(can_add, item.quantity)
            stack.quantity = stack.quantity + to_add
            item.quantity = item.quantity - to_add
            
            -- If fully absorbed, success
            if item.quantity <= 0 then
                return M.RESULT.SUCCESS, spec.inventory.pickup.cost
            end
            -- Otherwise, continue to try adding remainder as new stack
        end
    end
    
    -- Check capacity (block policy per spec)
    if M.is_full(inventory) then
        return M.RESULT.FULL, spec.inventory.pickup.full_cost
    end
    
    -- Add to inventory
    table.insert(inventory.items, item)
    return M.RESULT.SUCCESS, spec.inventory.pickup.cost
end

--- Drop an item from inventory
--- @param inventory table
--- @param instance_id number Item instance ID
--- @param quantity number|nil How many to drop (default all)
--- @return string Result code
--- @return table|nil Dropped item instance
--- @return number Turn cost
function M.drop(inventory, instance_id, quantity)
    local idx = M.find_by_id(inventory, instance_id)
    if not idx then
        return M.RESULT.NOT_FOUND, nil, 0
    end
    
    local item = inventory.items[idx]
    quantity = quantity or item.quantity
    
    local dropped
    if item.stackable and quantity < item.quantity then
        -- Split stack
        dropped = M.create_item(item.template_id, quantity)
        dropped.identified = item.identified
        item.quantity = item.quantity - quantity
    else
        -- Remove entire item
        dropped = table.remove(inventory.items, idx)
    end
    
    return M.RESULT.SUCCESS, dropped, spec.inventory.drop.cost
end

--- Use an item (consumable)
--- @param inventory table
--- @param instance_id number
--- @param player table|nil Player state for applying effects
--- @return string Result code
--- @return table|nil Effect applied
--- @return number Turn cost
function M.use(inventory, instance_id, player)
    local idx = M.find_by_id(inventory, instance_id)
    if not idx then
        return M.RESULT.NOT_FOUND, nil, 0
    end
    
    local item = inventory.items[idx]
    
    -- Check if usable
    if not item.effect then
        return M.RESULT.CANNOT_USE, nil, 0
    end
    
    -- Apply effect (actual application depends on player module)
    local effect = M.copy_table(item.effect)
    
    -- Mark scroll as identified on use
    if item.type == M.ITEM_TYPE.SCROLL then
        item.identified = true
    end
    
    -- Consume one from stack
    item.quantity = item.quantity - 1
    if item.quantity <= 0 then
        table.remove(inventory.items, idx)
    end
    
    return M.RESULT.SUCCESS, effect, spec.inventory.use.cost
end

--- Equip an item
--- @param inventory table
--- @param instance_id number
--- @return string Result code
--- @return table|nil Previously equipped item (if swapped)
--- @return number Turn cost (0 for equip, included in action)
function M.equip(inventory, instance_id)
    local idx = M.find_by_id(inventory, instance_id)
    if not idx then
        return M.RESULT.NOT_FOUND, nil, 0
    end
    
    local item = inventory.items[idx]
    
    -- Check if equippable
    if not item.slot then
        return M.RESULT.CANNOT_EQUIP, nil, 0
    end
    
    local slot = item.slot
    local old_equipped = inventory.equipped[slot]
    
    -- Remove from inventory
    table.remove(inventory.items, idx)
    
    -- If something was equipped, put it back in inventory
    if old_equipped then
        table.insert(inventory.items, old_equipped)
    end
    
    -- Equip new item
    inventory.equipped[slot] = item
    
    return M.RESULT.SUCCESS, old_equipped, 0
end

--- Unequip an item
--- @param inventory table
--- @param slot string Equipment slot
--- @return string Result code
--- @return table|nil Unequipped item
function M.unequip(inventory, slot)
    local item = inventory.equipped[slot]
    if not item then
        return M.RESULT.NOT_FOUND, nil
    end
    
    -- Check capacity
    if M.is_full(inventory) then
        return M.RESULT.FULL, nil
    end
    
    -- Unequip
    inventory.equipped[slot] = nil
    table.insert(inventory.items, item)
    
    return M.RESULT.SUCCESS, item
end

--- Get equipped item in slot
--- @param inventory table
--- @param slot string
--- @return table|nil
function M.get_equipped(inventory, slot)
    return inventory.equipped[slot]
end

--- Get total stat bonus from equipment
--- @param inventory table
--- @param stat_name string
--- @return number
function M.get_equipment_stat(inventory, stat_name)
    local total = 0
    for _, item in pairs(inventory.equipped) do
        if item and item.stats and item.stats[stat_name] then
            total = total + item.stats[stat_name]
        end
    end
    return total
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Deep copy a table
--- @param t table
--- @return table
function M.copy_table(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = M.copy_table(v)
    end
    return copy
end

--- Initialize items module
function M.init()
    rng = require("descent.rng")
    next_item_id = 1
end

--- Get all template IDs
--- @return table Array of template IDs
function M.get_all_templates()
    local ids = {}
    for id in pairs(item_templates) do
        table.insert(ids, id)
    end
    table.sort(ids)
    return ids
end

--- Generate random item from templates
--- @param allowed_types table|nil Array of allowed types
--- @return table|nil Item instance
function M.generate_random(allowed_types)
    if not rng then
        rng = require("descent.rng")
    end
    
    local candidates = {}
    for id, template in pairs(item_templates) do
        if not allowed_types or M.contains(allowed_types, template.type) then
            table.insert(candidates, id)
        end
    end
    
    if #candidates == 0 then
        return nil
    end
    
    local template_id = rng.choose(candidates)
    return M.create_item(template_id, 1)
end

--- Check if array contains value
--- @param array table
--- @param value any
--- @return boolean
function M.contains(array, value)
    for _, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

return M
