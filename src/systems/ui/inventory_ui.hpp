#pragma once

#include "entt/entt.hpp"

#include "systems/ui/ui_data.hpp"
#include "systems/transform/transform_functions.hpp"


namespace ui {

    struct InventoryGrid {
        int columns = 5;
        int rows = 3;
        // padding comes from uiConfig
        float cellW = 1.0f;
        float cellH = 1.0f;
    
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
        inventoryGrid.containerEntity = worldContainer;
        inventoryGrid.slots.resize(rows * columns);
        
        // init grid with entt::null
        for (int i = 0; i < rows * columns; ++i) {
            inventoryGrid.slots[i] = entt::null;
        }
        
        // populate with some dummy items
        
        for (int i = 0; i < rows * columns; ++i) {
            auto itemEntity = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, 0, 0, cellW, cellH);
            
            auto &itemGameObject = registry.get<transform::GameObject>(itemEntity);
            itemGameObject.state.clickEnabled = true;
            itemGameObject.state.dragEnabled = true;
            itemGameObject.state.hoverEnabled = true;
            itemGameObject.state.collisionEnabled = true;
        
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
        
        
        
        // add custom update function to align each entity to the grid, provided it isn't being dragged
        
        
        
        // auto &slotTransform = registry.get<transform::Transform>(itemEntity);
        // slotTransform.setPosition(
        //     padding + slot.col * (cellW + padding),
        //     padding + slot.row * (cellH + padding)
        // );

        
        return newAreaEntity;
    }
    

}