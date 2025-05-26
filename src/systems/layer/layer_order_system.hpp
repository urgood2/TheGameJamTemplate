#pragma once

#include "util/common_headers.hpp"
#include "layer.hpp"

#include "systems/ui/box.hpp"


namespace layer
{
    namespace layer_order_system
    {
        int newZIndex = 0; // Global variable to hold the running Z-index value. 0 is the bottom, and higher values are on top.
        
        
        inline void SetToTopZIndex(entt::entity entity, bool incrementIndexAfterwards = true) {
            if (globals::registry.any_of<LayerOrderComponent>(entity)) {
                globals::registry.get<LayerOrderComponent>(entity).zIndex = newZIndex;
            } else {
                globals::registry.emplace<LayerOrderComponent>(entity, newZIndex);
            }
            newZIndex++; // Increment the global Z-index counter
        }
        
        // call every frame to update the Z-indexes of all UIBoxComponents that do not have a LayerOrderComponent
        inline void UpdateLayerZIndexesAsNecessary() {
            
            auto view = globals::registry.view<ui::UIBoxComponent>(entt::exclude<LayerOrderComponent>);
            
            for (auto entity : view) {
                SetToTopZIndex(entity, true);
            }
            
        }   
        
        inline void ResetRunningZIndex() {
            newZIndex = 0; // Reset the global Z-index counter
        }
        
        // if no z index is specified, assign the next available z index (top of the stack)
        inline void AssignZIndexToEntity(entt::entity entity, int zIndex) {
            if (globals::registry.any_of<LayerOrderComponent>(entity)) {
                globals::registry.get<LayerOrderComponent>(entity).zIndex = zIndex;
            } else {
                globals::registry.emplace<LayerOrderComponent>(entity, zIndex);
            }
        }

    } // namespace layer_order_system
}
