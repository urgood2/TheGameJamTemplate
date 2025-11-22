#pragma once

#include "util/common_headers.hpp"
#include "layer.hpp"

#include "systems/ui/box.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "systems/layer/layer_command_buffer_data.hpp"

namespace layer
{
    namespace layer_order_system
    {
        extern int newZIndex; // Global variable to hold the running Z-index value. 0 is the bottom, and higher values are on top.
        
        
        inline void SetToTopZIndex(entt::registry& registry, entt::entity entity, bool incrementIndexAfterwards = true) {
            if (registry.any_of<LayerOrderComponent>(entity)) {
                registry.get<LayerOrderComponent>(entity).zIndex = newZIndex;
            } else {
                registry.emplace<LayerOrderComponent>(entity, newZIndex);
            }
            if (incrementIndexAfterwards) {
                newZIndex++; // Increment the global Z-index counter
            }
        }

        inline void SetToTopZIndex(entt::entity entity, bool incrementIndexAfterwards = true) {
            SetToTopZIndex(globals::getRegistry(), entity, incrementIndexAfterwards);
        }
        
        inline int GetZIndex(entt::registry& registry, entt::entity entity)
        {
            if (registry.any_of<LayerOrderComponent>(entity))
            {
                return registry.get<LayerOrderComponent>(entity).zIndex;
            }
            else
            {
                // If no LayerOrderComponent exists, assign a new one at the top and return that.
                SetToTopZIndex(registry, entity);
                return registry.get<LayerOrderComponent>(entity).zIndex;
            }
        }

        inline int GetZIndex(entt::entity entity)
        {
            return GetZIndex(globals::getRegistry(), entity);
        }
        
        inline void PutAOverB(entt::registry& registry, entt::entity a, entt::entity b) {
            if (registry.any_of<LayerOrderComponent>(a) && registry.any_of<LayerOrderComponent>(b)) {
                auto &aLayer = registry.get<LayerOrderComponent>(a);
                auto &bLayer = registry.get<LayerOrderComponent>(b);
                
                if (aLayer.zIndex <= bLayer.zIndex) {
                    aLayer.zIndex = bLayer.zIndex + 1; // Ensure A is above B
                }
            } else {
                SetToTopZIndex(registry, a);
            }
        }

        inline void PutAOverB(entt::entity a, entt::entity b) {
            PutAOverB(globals::getRegistry(), a, b);
        }
        
        // call every frame to update the Z-indexes of all UIBoxComponents that do not have a LayerOrderComponent
        inline void UpdateLayerZIndexesAsNecessary(entt::registry& registry) {
            auto view = registry.view<ui::UIBoxComponent>(entt::exclude<LayerOrderComponent>);
            
            for (auto entity : view) {
                SetToTopZIndex(registry, entity, true);
            }
            
        }   

        inline void UpdateLayerZIndexesAsNecessary() {
            UpdateLayerZIndexesAsNecessary(globals::getRegistry());
        }
        
        inline void ResetRunningZIndex() {
            newZIndex = 0; // Reset the global Z-index counter
        }
        
        // if no z index is specified, assign the next available z index (top of the stack)
        inline void AssignZIndexToEntity(entt::registry& registry, entt::entity entity, int zIndex) {
            if (registry.any_of<LayerOrderComponent>(entity)) {
                registry.get<LayerOrderComponent>(entity).zIndex = zIndex;
            } else {
                registry.emplace<LayerOrderComponent>(entity, zIndex);
            }
        }

        inline void AssignZIndexToEntity(entt::entity entity, int zIndex) {
            AssignZIndexToEntity(globals::getRegistry(), entity, zIndex);
        }
        
        inline void exposeToLua(sol::state &lua) {
            BindingRecorder &rec = BindingRecorder::instance();
            
            // Create or grab the table
            sol::table sys = lua["layer_order_system"].get_or(
                sol::table(lua.lua_state(), sol::create) );
            lua["layer_order_system"] = sys;

            // setToTopZIndex(entity, incrementIndexAfterwards = true)
            sys.set_function("setToTopZIndex", static_cast<void(*)(entt::entity, bool)>(&SetToTopZIndex));
            rec.record_free_function(
                /* module path */ {"layer_order_system"},
                /* name + docs */ {
                    "setToTopZIndex",
                    "---@param e Entity\n"
                    "---@param incrementIndexAfterwards boolean Defaults to true\n"
                    "---@return nil",
                    "Assigns the given entity the current top Z-index and increments the counter."
                }
            );

            // putAOverB(a, b)
            sys.set_function("putAOverB", static_cast<void(*)(entt::entity, entt::entity)>(&PutAOverB));
            rec.record_free_function(
                { "layer_order_system"},
                {
                    "putAOverB",
                    "---@param a Entity The entity to move above b\n"
                    "---@param b Entity The reference entity\n"
                    "---@return nil",
                    "Ensures entity a’s zIndex is at least one above b’s."
                }
            );

            // updateLayerZIndexesAsNecessary()
            sys.set_function("updateLayerZIndexesAsNecessary", static_cast<void(*)()>(&UpdateLayerZIndexesAsNecessary));
            rec.record_free_function(
                {"layer_order_system"},
                {
                    "updateLayerZIndexesAsNecessary",
                    "---@return nil",
                    "Walks all UIBoxComponents without a LayerOrderComponent and pushes them to the top Z-stack."
                }
            );
            
            // getZIndex(entity)
            sys.set_function("getZIndex", static_cast<int(*)(entt::entity)>(&GetZIndex));
            rec.record_free_function(
                {"layer_order_system"},
                {
                    "getZIndex",
                    "---@param e Entity\n"
                    "---@return integer zIndex\n"
                    "Returns the current zIndex of the given entity, assigning one if missing."
                }
            );

            // resetRunningZIndex()
            sys.set_function("resetRunningZIndex", &ResetRunningZIndex);
            rec.record_free_function(
                {"layer_order_system"},
                {
                    "resetRunningZIndex",
                    "---@return nil",
                    "Resets the global Z-index counter back to zero."
                }
            );

            // assignZIndexToEntity(entity, zIndex)
            sys.set_function("assignZIndexToEntity", static_cast<void(*)(entt::entity, int)>(&AssignZIndexToEntity));
            rec.record_free_function(
                {"layer_order_system"},
                {
                    "assignZIndexToEntity",
                    "---@param e Entity\n"
                    "---@param zIndex number The exact zIndex to assign\n"
                    "---@return nil",
                    "Force-sets an entity’s zIndex to the given value."
            }
            );
        }


    } // namespace layer_order_system
}
