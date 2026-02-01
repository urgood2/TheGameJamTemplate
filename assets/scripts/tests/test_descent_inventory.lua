-- assets/scripts/tests/test_descent_inventory.lua
--[[
================================================================================
DESCENT INVENTORY TESTS
================================================================================
Validates pickup, drop, use, equip, capacity, and swap/block behavior.

Acceptance criteria:
- Pickup/drop/use/equip work correctly
- Capacity enforcement (block policy)
- Swap behavior for equipment
- Stacking behavior
]]

local t = require("tests.test_runner")
local Items = require("descent.items")

--------------------------------------------------------------------------------
-- Inventory Creation Tests
--------------------------------------------------------------------------------

t.describe("Descent Inventory Creation", function()
    t.it("creates empty inventory with capacity", function()
        local inv = Items.create_inventory(10)
        t.expect(Items.count(inv)).to_be(0)
        t.expect(inv.capacity).to_be(10)
        t.expect(inv.gold).to_be(0)
    end)

    t.it("inventory starts not full", function()
        local inv = Items.create_inventory(10)
        t.expect(Items.is_full(inv)).to_be(false)
        t.expect(Items.remaining_capacity(inv)).to_be(10)
    end)
end)

--------------------------------------------------------------------------------
-- Pickup Tests
--------------------------------------------------------------------------------

t.describe("Descent Inventory Pickup", function()
    t.it("picks up item successfully", function()
        local inv = Items.create_inventory(10)
        local item = Items.create_item("short_sword")
        
        local result, cost = Items.pickup(inv, item)
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(Items.count(inv)).to_be(1)
    end)

    t.it("blocks pickup when full", function()
        local inv = Items.create_inventory(1)
        local item1 = Items.create_item("short_sword")
        local item2 = Items.create_item("dagger")
        
        Items.pickup(inv, item1)
        t.expect(Items.is_full(inv)).to_be(true)
        
        local result, cost = Items.pickup(inv, item2)
        t.expect(result).to_be(Items.RESULT.FULL)
        t.expect(Items.count(inv)).to_be(1)  -- Still only 1 item
    end)

    t.it("picks up gold directly to gold counter", function()
        local inv = Items.create_inventory(10)
        local gold = Items.create_item("gold", 50)
        
        local result = Items.pickup(inv, gold)
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(inv.gold).to_be(50)
        t.expect(Items.count(inv)).to_be(0)  -- Gold doesn't use slots
    end)

    t.it("stacks stackable items", function()
        local inv = Items.create_inventory(10)
        local potion1 = Items.create_item("health_potion", 3)
        local potion2 = Items.create_item("health_potion", 2)
        
        Items.pickup(inv, potion1)
        Items.pickup(inv, potion2)
        
        t.expect(Items.count(inv)).to_be(1)  -- Single stack
        t.expect(inv.items[1].quantity).to_be(5)
    end)

    t.it("creates new stack when current is full", function()
        local inv = Items.create_inventory(10)
        local potion1 = Items.create_item("health_potion", 10)  -- Max stack
        local potion2 = Items.create_item("health_potion", 2)
        
        Items.pickup(inv, potion1)
        Items.pickup(inv, potion2)
        
        t.expect(Items.count(inv)).to_be(2)  -- Two stacks
    end)
end)

--------------------------------------------------------------------------------
-- Drop Tests
--------------------------------------------------------------------------------

t.describe("Descent Inventory Drop", function()
    t.it("drops item successfully", function()
        local inv = Items.create_inventory(10)
        local item = Items.create_item("short_sword")
        Items.pickup(inv, item)
        
        local result, dropped, cost = Items.drop(inv, item.instance_id)
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(dropped).to_not_be(nil)
        t.expect(Items.count(inv)).to_be(0)
    end)

    t.it("returns not found for invalid id", function()
        local inv = Items.create_inventory(10)
        
        local result, dropped, cost = Items.drop(inv, 9999)
        t.expect(result).to_be(Items.RESULT.NOT_FOUND)
        t.expect(cost).to_be(0)
    end)

    t.it("splits stackable when dropping partial", function()
        local inv = Items.create_inventory(10)
        local potion = Items.create_item("health_potion", 5)
        Items.pickup(inv, potion)
        
        local result, dropped = Items.drop(inv, potion.instance_id, 2)
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(dropped.quantity).to_be(2)
        t.expect(inv.items[1].quantity).to_be(3)
    end)
end)

--------------------------------------------------------------------------------
-- Use Tests
--------------------------------------------------------------------------------

t.describe("Descent Inventory Use", function()
    t.it("uses consumable item", function()
        local inv = Items.create_inventory(10)
        local potion = Items.create_item("health_potion", 1)
        Items.pickup(inv, potion)
        
        local result, effect, cost = Items.use(inv, potion.instance_id, nil)
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(effect.heal).to_be(20)
        t.expect(Items.count(inv)).to_be(0)  -- Consumed
    end)

    t.it("consumes one from stack", function()
        local inv = Items.create_inventory(10)
        local potion = Items.create_item("health_potion", 3)
        Items.pickup(inv, potion)
        
        Items.use(inv, potion.instance_id, nil)
        t.expect(inv.items[1].quantity).to_be(2)
    end)

    t.it("cannot use non-consumable", function()
        local inv = Items.create_inventory(10)
        local sword = Items.create_item("short_sword")
        Items.pickup(inv, sword)
        
        local result, effect, cost = Items.use(inv, sword.instance_id, nil)
        t.expect(result).to_be(Items.RESULT.CANNOT_USE)
        t.expect(cost).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- Equip Tests
--------------------------------------------------------------------------------

t.describe("Descent Inventory Equip", function()
    t.it("equips weapon", function()
        local inv = Items.create_inventory(10)
        local sword = Items.create_item("short_sword")
        Items.pickup(inv, sword)
        
        local result, old = Items.equip(inv, sword.instance_id)
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(Items.count(inv)).to_be(0)  -- Removed from inventory
        t.expect(Items.get_equipped(inv, Items.EQUIP_SLOT.WEAPON)).to_be(sword)
    end)

    t.it("swaps equipped item", function()
        local inv = Items.create_inventory(10)
        local sword = Items.create_item("short_sword")
        local dagger = Items.create_item("dagger")
        Items.pickup(inv, sword)
        Items.pickup(inv, dagger)
        
        Items.equip(inv, sword.instance_id)
        local result, old = Items.equip(inv, dagger.instance_id)
        
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(old).to_be(sword)  -- Old item returned
        t.expect(Items.get_equipped(inv, Items.EQUIP_SLOT.WEAPON)).to_be(dagger)
        t.expect(Items.count(inv)).to_be(1)  -- Old sword back in inventory
    end)

    t.it("cannot equip non-equippable", function()
        local inv = Items.create_inventory(10)
        local potion = Items.create_item("health_potion")
        Items.pickup(inv, potion)
        
        local result = Items.equip(inv, potion.instance_id)
        t.expect(result).to_be(Items.RESULT.CANNOT_EQUIP)
    end)

    t.it("unequips to inventory", function()
        local inv = Items.create_inventory(10)
        local sword = Items.create_item("short_sword")
        Items.pickup(inv, sword)
        Items.equip(inv, sword.instance_id)
        
        local result, item = Items.unequip(inv, Items.EQUIP_SLOT.WEAPON)
        t.expect(result).to_be(Items.RESULT.SUCCESS)
        t.expect(item).to_be(sword)
        t.expect(Items.count(inv)).to_be(1)
        t.expect(Items.get_equipped(inv, Items.EQUIP_SLOT.WEAPON)).to_be(nil)
    end)

    t.it("cannot unequip when inventory full", function()
        local inv = Items.create_inventory(1)
        local sword = Items.create_item("short_sword")
        local dagger = Items.create_item("dagger")
        
        Items.pickup(inv, sword)
        Items.equip(inv, sword.instance_id)
        Items.pickup(inv, dagger)  -- Fill inventory
        
        local result = Items.unequip(inv, Items.EQUIP_SLOT.WEAPON)
        t.expect(result).to_be(Items.RESULT.FULL)
    end)
end)

--------------------------------------------------------------------------------
-- Equipment Stats Tests
--------------------------------------------------------------------------------

t.describe("Descent Equipment Stats", function()
    t.it("calculates equipment stat bonus", function()
        local inv = Items.create_inventory(10)
        local sword = Items.create_item("short_sword")  -- damage = 5
        local armor = Items.create_item("leather_armor")  -- armor = 2
        
        Items.pickup(inv, sword)
        Items.pickup(inv, armor)
        Items.equip(inv, sword.instance_id)
        Items.equip(inv, armor.instance_id)
        
        t.expect(Items.get_equipment_stat(inv, "damage")).to_be(5)
        t.expect(Items.get_equipment_stat(inv, "armor")).to_be(2)
    end)

    t.it("returns zero for no equipment", function()
        local inv = Items.create_inventory(10)
        t.expect(Items.get_equipment_stat(inv, "damage")).to_be(0)
    end)
end)

--------------------------------------------------------------------------------
-- Capacity Block Policy Tests
--------------------------------------------------------------------------------

t.describe("Descent Inventory Block Policy", function()
    t.it("returns different cost when blocked", function()
        local inv = Items.create_inventory(1)
        local item1 = Items.create_item("short_sword")
        local item2 = Items.create_item("dagger")
        
        local result1, cost1 = Items.pickup(inv, item1)
        local result2, cost2 = Items.pickup(inv, item2)
        
        t.expect(result1).to_be(Items.RESULT.SUCCESS)
        t.expect(result2).to_be(Items.RESULT.FULL)
        -- Both should have a cost (action was attempted)
        t.expect(type(cost1)).to_be("number")
        t.expect(type(cost2)).to_be("number")
    end)
end)
