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
        
        
        inline void SetToTopZIndex(entt::entity entity, bool incrementIndexAfterwards = true) {
            if (globals::registry.any_of<LayerOrderComponent>(entity)) {
                globals::registry.get<LayerOrderComponent>(entity).zIndex = newZIndex;
            } else {
                globals::registry.emplace<LayerOrderComponent>(entity, newZIndex);
            }
            newZIndex++; // Increment the global Z-index counter
        }
        
        inline void PutAOverB(entt::entity a, entt::entity b) {
            if (globals::registry.any_of<LayerOrderComponent>(a) && globals::registry.any_of<LayerOrderComponent>(b)) {
                auto &aLayer = globals::registry.get<LayerOrderComponent>(a);
                auto &bLayer = globals::registry.get<LayerOrderComponent>(b);
                
                if (aLayer.zIndex <= bLayer.zIndex) {
                    aLayer.zIndex = bLayer.zIndex + 1; // Ensure A is above B
                }
            } else {
                SetToTopZIndex(a);
            }
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
        
        inline void exposeToLua(sol::state &lua) {
            BindingRecorder &rec = BindingRecorder::instance();
            
            // Create or grab the table
            sol::table sys = lua["layer_order_system"].get_or(
                sol::table(lua.lua_state(), sol::create) );
            lua["layer_order_system"] = sys;

            // setToTopZIndex(entity, incrementIndexAfterwards = true)
            sys.set_function("setToTopZIndex", &SetToTopZIndex);
            rec.record_free_function(
                /* module path */ {"layer_order_system"},
                /* name + docs */ {
                    "setToTopZIndex",
                    "---@param registry registry\n"
                    "---@param e Entity\n"
                    "---@param incrementIndexAfterwards boolean Defaults to true\n"
                    "---@return nil",
                    "Assigns the given entity the current top Z-index and increments the counter."
                }
            );

            // putAOverB(a, b)
            sys.set_function("putAOverB", &PutAOverB);
            rec.record_free_function(
                { "layer_order_system"},
                {
                    "putAOverB",
                    "---@param registry registry\n"
                    "---@param a Entity The entity to move above b\n"
                    "---@param b Entity The reference entity\n"
                    "---@return nil",
                    "Ensures entity a’s zIndex is at least one above b’s."
                }
            );

            // updateLayerZIndexesAsNecessary()
            sys.set_function("updateLayerZIndexesAsNecessary", &UpdateLayerZIndexesAsNecessary);
            rec.record_free_function(
                {"layer_order_system"},
                {
                    "updateLayerZIndexesAsNecessary",
                    "---@param registry registry\n"
                    "---@return nil",
                    "Walks all UIBoxComponents without a LayerOrderComponent and pushes them to the top Z-stack."
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
            sys.set_function("assignZIndexToEntity", &AssignZIndexToEntity);
            rec.record_free_function(
                {"layer_order_system"},
                {
                    "assignZIndexToEntity",
                    "---@param registry registry\n"
                    "---@param e Entity\n"
                    "---@param zIndex number The exact zIndex to assign\n"
                    "---@return nil",
                    "Force-sets an entity’s zIndex to the given value."
            }
            );
        }


    } // namespace layer_order_system
}
