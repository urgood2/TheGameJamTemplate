#pragma once

#include <thread>
#include <chrono>

#include "registry_bond.hpp"

#include "systems/ui/ui.hpp"
#include "systems/particles/particle.hpp"
#include "components/graphics.hpp"
#include "systems/shaders/shader_pipeline.hpp"
#include "systems/shaders/shader_system.hpp"
#include "components/components.hpp"
#include "systems/ai/ai_system.hpp"

// pass both the type and value of an argument to a function
#define AUTO_ARG(x) decltype(x), x

struct EngineContext;

namespace scripting
{

    /**
     * @brief Holds Lua script table (`self`) and cached hooks.
     *
     * Each `ScriptComponent` represents a Lua-driven component that contains:
     * - A `self` table for storing arbitrary script data and methods.
     * - A `hooks` structure for caching performance-critical function references.
     */
    struct ScriptComponent
    {
        sol::table self;
        struct
        {
            sol::function update; ///< Update hook called every frame (if exists)
            sol::function on_collision; // called for collisions with other entities
        } hooks;
        
        // list of currently running Lua coroutines (tasks)
        std::vector<sol::coroutine> tasks;

        void add_task(sol::object obj) {
            try {
                if (obj.is<sol::function>()) {
                    sol::function fn = obj.as<sol::function>();
                    sol::thread thread = sol::thread::create(ai_system::masterStateLua);
                    sol::state_view ts = thread.state();
                    ts["__fn"] = fn;
                    sol::coroutine co = ts["__fn"];
                    tasks.emplace_back(std::move(co));
                    SPDLOG_DEBUG("Added coroutine from function via new thread.");
                }
                else if (obj.is<sol::coroutine>()) {
                    tasks.emplace_back(obj.as<sol::coroutine>());
                    SPDLOG_DEBUG("Added coroutine.");
                }
                else if (obj.get_type() == sol::type::thread) {
                    sol::thread th = obj;
                    tasks.emplace_back(sol::coroutine(th));
                    SPDLOG_DEBUG("Added coroutine from thread object.");
                }
                else {
                    spdlog::warn("Invalid coroutine object: type = {}", static_cast<int>(obj.get_type()));
                }
            }
            catch (const sol::error& e) {
                spdlog::error("Lua error in add_task: {}", e.what());
            }
            catch (const std::exception& e) {
                spdlog::error("Exception in add_task: {}", e.what());
            }
        }
        

        std::size_t count_tasks() const {
            return tasks.size();
        }
        
        // Keep the default constructor for other C++ systems.
        ScriptComponent() = default;    

        // The new constructor that takes a Lua table directly!
        // This is the key to initializing it with your PlayerLogic table.
        ScriptComponent(sol::table lua_table) : self(std::move(lua_table)) {}

    };

    /**
     * @brief Utility function for printing out all key-value pairs in a script table.
     *
     * Mainly used for debugging Lua table contents, e.g., to check what methods or properties
     * are exposed by a script.
     */
    extern void inspect_script(const ScriptComponent &script);

    /**
     * @brief Initializes a script after it has been constructed on an entity.
     *
     * - Caches important hooks (like `update`) from the script table.
     * - Adds read-only properties like `id` and a reference to the `registry` to the Lua table.
     * - Calls the Lua-side `init` function if it exists.
     *
     * @param registry The ECS registry containing the entity.
     * @param entity The entity ID for which the script is being initialized.
     */
    extern void init_script(entt::registry &registry, entt::entity entity);
    
    /**
     * @brief Cleans up a script when its associated entity is destroyed.
     *
     * - Calls the Lua-side `destroy` function if it exists.
     * - Abandons the Lua table (`self`) to properly release references.
     *
     * @param registry The ECS registry containing the entity.
     * @param entity The entity ID whose script is being released.
     */
    extern void release_script(entt::registry &registry, entt::entity entity);

    /**
     * @brief Updates all active script components in the registry.
     *
     * For each entity with a `ScriptComponent`, it calls the cached `update` hook
     * from the Lua table, passing the Lua `self` and the delta time.
     *
     * @param registry The ECS registry containing entities with scripts.
     * @param delta_time The time elapsed since the last frame.
     */
    extern void script_system_update(entt::registry &registry, float delta_time);
    

    namespace monobehavior_system {
        
        extern auto generateBindingsToLua(sol::state &lua) -> void;
        
        /**
         * @brief Initializes the scripting system.
         *
         * - Connects `ScriptComponent` construction to `init_script`.
         * - Connects `ScriptComponent` destruction to `release_script`.
         * - Registers the C++ `open_registry` function as a Lua module (`registry`).
         *
         * @param registry The ECS registry.
         * @param lua The Lua state to set up.
         */
        extern auto init(entt::registry &registry, sol::state &lua, EngineContext* ctx = nullptr) -> void;

        /**
         * @brief Updates all Lua scripts each frame.
         *
         * @param registry The ECS registry.
         * @param delta_time The time elapsed since the last frame.
         */
        extern auto update(entt::registry &registry, float delta_time) -> void;

        /**
         * @brief Cleanly disconnects scripting signals and drops Lua references before shutdown.
         *
         * Call this once during shutdown (while the Lua state is still alive) to avoid
         * touching an already-destroyed state inside on_destroy callbacks.
         */
        extern void shutdown(entt::registry &registry);
    }

} // namespace
