#pragma once

#include "entt/entt.hpp"




namespace ui {

    struct InventoryGrid {
        int columns = 5;
        int rows = 3;
        float spacingX = 0.1f;
        float spacingY = 0.1f;
        float cellW = 1.0f;
        float cellH = 1.0f;
    
        std::vector<entt::entity> slots;
        bool allowOverflow = false; // can exceed capacity?
        bool allowMultiRow = true;
    
        std::optional<entt::entity> containerEntity; // where inventory is located
    };


    struct InventorySlot {
        int row = 0;
        int col = 0;
        std::optional<entt::entity> heldItem;
        bool enabled = true;
    };

    struct ItemData {
        std::string id;
        int width = 1;  // for grid-fitting (e.g., 2x2 items)
        int height = 1;
        bool draggable = true;
        bool stackable = false;
        int stackCount = 1;
    };

    void align_inventory_items(entt::registry&, entt::entity inventoryGrid);

//     For each slot:

//     Calculate slot.T.x = inventoryOrigin.x + col * (cellW + spacingX)

//     Calculate slot.T.y = inventoryOrigin.y + row * (cellH + spacingY)

//     If there's an item in the slot, align it to the slot (as a child or synced position)

// You can reuse your existing ConfigureAlignment or SyncPerfectlyToMaster to do this.





// StartDrag, StopDragging, GetObjectToDrag: 

// While dragging an item:

//     Update item position to mouse cursor (free transform)

//     On release, check for overlapping slot

//     If valid: snap into that slot, reassign parent transform

    bool insertItem(entt::entity inventory, entt::entity item);

    bool removeItem(entt::entity inventory, entt::entity item);

    bool swapItems(entt::entity a, entt::entity b);

    std::optional<entt::entity> findSlotForItem(...);

    void sortInventory(...);

    
    // 🎨 Optional Extras

    // Slot rendering: draw slot backgrounds even when empty

    // Tooltips: highlight or show info when hovering a slot or item

    // Hotkeys: allow use/equip from keyboard (bind slots to keys)

    // Split stacks: handle right-click logic for stackable items

    // Overflow area: when dragged beyond bounds, send to another inventory (trash, stash, etc.)


}