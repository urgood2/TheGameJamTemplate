#pragma once

#include "entt/entt.hpp"

#include "systems/ui/ui_data.hpp"
#include "systems/transform/transform_functions.hpp"


namespace ui {

    struct InventoryGrid {
        int columns = 5;
        int rows = 3;
        float cellW = 1.0f;
        float cellH = 1.0f;
        float padding = 5.0f; // padding between slots
    
        std::vector<entt::entity> slots;
    
        std::optional<entt::entity> containerEntity; // where inventory is located
    };


    struct InventorySlot {
        int row = 0;
        int col = 0;
        entt::entity itemEntity{entt::null}; // the item in this slot
    };
    
    inline auto createNewObjectArea(entt::registry &registry, entt::entity worldContainer, int rows, int columns, float cellW, float cellH, const float padding = 5.0f) -> entt::entity {
        auto areaWidth = columns * cellW + (columns + 1) * padding;
        auto areaHeight = rows * cellH + (rows + 1) * padding;  
        
        auto newAreaEntity = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, 0, 0, areaWidth, areaHeight);
        
        auto &inventoryGrid = registry.emplace<InventoryGrid>(newAreaEntity);
        inventoryGrid.columns = columns;
        inventoryGrid.rows = rows;
        inventoryGrid.cellW = cellW;
        inventoryGrid.cellH = cellH;
        inventoryGrid.padding = padding;
        inventoryGrid.containerEntity = worldContainer;
        inventoryGrid.slots.resize(rows * columns);
        
        
        // populate with some dummy items
        
        for (int i = 0; i < rows * columns; ++i) {
            auto itemEntity = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, 0, 0, cellW, cellH);
            
            auto &itemGameObject = registry.get<transform::GameObject>(itemEntity);
            itemGameObject.state.clickEnabled = true;
            itemGameObject.state.dragEnabled = true;
            itemGameObject.state.hoverEnabled = true;
            itemGameObject.state.collisionEnabled = true;
            
            // add detection on drag release
            itemGameObject.methods->onRelease = [newAreaEntity, itemEntity](entt::registry &registry, entt::entity entity, entt::entity entity2) { // REVIEW: not sure what the second one is?
                
                SPDLOG_DEBUG("Item {} released in inventory", static_cast<int>(itemEntity));
                
                auto &gridTransform = registry.get<transform::Transform>(newAreaEntity);
                auto &grid = registry.get<InventoryGrid>(newAreaEntity);
                
                // check all items
                float baseX = gridTransform.getVisualX();
                float baseY = gridTransform.getVisualY();
                
                entt::entity hoveredSlotEntity = entt::null;
                entt::entity originSlotEntity = entt::null;

                for (int i = 0; i < grid.rows * grid.columns; ++i) {
                    auto slotEntity = grid.slots[i];
                    auto& slot = registry.get<ui::InventorySlot>(slotEntity);
                    if (!registry.valid(slotEntity)) continue;
                    
                    if (slot.itemEntity == itemEntity) {
                        originSlotEntity = grid.slots[i];
                    }
                    
                    float x = baseX + grid.padding + slot.col * (grid.cellW + grid.padding);
                    float y = baseY + grid.padding + slot.row * (grid.cellH + grid.padding);
                    Rectangle slotRect = { x, y, grid.cellW, grid.cellH };

                    if (CheckCollisionPointRec(GetMousePosition(), slotRect)) {
                        hoveredSlotEntity = slotEntity;
                    }
                }
                
                if (hoveredSlotEntity != entt::null && hoveredSlotEntity != originSlotEntity) {
                    auto& originSlot = registry.get<ui::InventorySlot>(originSlotEntity);
                    auto& targetSlot = registry.get<ui::InventorySlot>(hoveredSlotEntity);
            
                    // Swap the item entities
                    std::swap(originSlot.itemEntity, targetSlot.itemEntity);
                }
            
                
            };
        
            inventoryGrid.slots[i] = registry.create();
            auto &slot = registry.emplace<ui::InventorySlot>(inventoryGrid.slots[i]);
            slot.row = i / columns;
            slot.col = i % columns;
            slot.itemEntity = itemEntity;

        }
        
        // add custom draw function to draw a debug grid
        
        auto &gameObjectArea = registry.get<transform::GameObject>(newAreaEntity);
        gameObjectArea.drawFunction = [areaWidth, areaHeight, cellW, cellH, rows, columns, padding](std::shared_ptr<layer::Layer> layerPtr, entt::registry &registry, entt::entity entity) {
            auto &transform = registry.get<transform::Transform>(entity);
        
            float baseX = transform.getVisualX();
            float baseY = transform.getVisualY();
        
            // Horizontal lines
            for (int i = 0; i <= rows; ++i) {
                float y = baseY + padding + i * (cellH + padding);
                layer::AddLine(layerPtr, baseX + padding, y, baseX + areaWidth - padding, y, PINK, 2.0f);
            }
        
            // Vertical lines
            for (int j = 0; j <= columns; ++j) {
                float x = baseX + padding + j * (cellW + padding);
                layer::AddLine(layerPtr, x, baseY + padding, x, baseY + areaHeight - padding, PINK, 2.0f);
            }
            
            //TODO: move this to update function later. Also, only update when not dragging
            for (int i = 0; i < rows * columns; ++i) {
                auto &inventoryGrid = registry.get<InventoryGrid>(entity);
                auto itemSlot = registry.get<ui::InventorySlot>(inventoryGrid.slots[i]);
                if (registry.valid(itemSlot.itemEntity)) {
                    auto &slotTransform = registry.get<transform::Transform>(itemSlot.itemEntity);
                    slotTransform.setActualX(
                        baseX + padding + itemSlot.col * (cellW + padding)
                    );
                    slotTransform.setActualY(
                        baseY + padding + itemSlot.row * (cellH + padding)
                    );
                }
    
            }
        };
        
    

        
        return newAreaEntity;
    }
    

}