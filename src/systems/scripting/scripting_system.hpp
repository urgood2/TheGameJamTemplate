#include <thread>
#include <chrono>

#include "registry_bond.hpp"

// pass both the type and value of an argument to a function
#define AUTO_ARG(x) decltype(x), x

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
        } hooks;
    };

    /**
     * @brief Utility function for printing out all key-value pairs in a script table.
     *
     * Mainly used for debugging Lua table contents, e.g., to check what methods or properties
     * are exposed by a script.
     */
    inline void inspect_script(const ScriptComponent &script)
    {
        script.self.for_each([](const sol::object &key, const sol::object &value)
                             { std::cout << key.as<std::string>() << ": "
                                         << sol::type_name(value.lua_state(), value.get_type())
                                         << std::endl; });
    }

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
    inline void init_script(entt::registry &registry, entt::entity entity)
    {
        auto &script = registry.get<ScriptComponent>(entity);
        assert(script.self.valid());
        script.hooks.update = script.self["update"];
        assert(script.hooks.update.valid());

        script.self["id"] = sol::readonly_property([entity]
                                                   { return entity; });
        script.self["owner"] = std::ref(registry);
        if (auto &&f = script.self["init"]; f.valid())
            f(script.self);
        // inspect_script(script);
    }

    /**
     * @brief Cleans up a script when its associated entity is destroyed.
     *
     * - Calls the Lua-side `destroy` function if it exists.
     * - Abandons the Lua table (`self`) to properly release references.
     *
     * @param registry The ECS registry containing the entity.
     * @param entity The entity ID whose script is being released.
     */
    inline void release_script(entt::registry &registry, entt::entity entity)
    {
        auto &script = registry.get<ScriptComponent>(entity);
        if (auto &&f = script.self["destroy"]; f.valid())
            f(script.self);
        script.self.abandon();
    }

    /**
     * @brief Updates all active script components in the registry.
     *
     * For each entity with a `ScriptComponent`, it calls the cached `update` hook
     * from the Lua table, passing the Lua `self` and the delta time.
     *
     * @param registry The ECS registry containing entities with scripts.
     * @param delta_time The time elapsed since the last frame.
     */
    inline void script_system_update(entt::registry &registry, float delta_time)
    {
        auto view = registry.view<ScriptComponent>();
        for (auto entity : view)
        {
            auto &script = view.get<ScriptComponent>(entity);
            assert(script.self.valid());
            script.hooks.update(script.self, delta_time);
        }
    }
    

    namespace scripting_system {
        
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
        inline auto init(entt::registry &registry, sol::state &lua) -> void
        {
            //TODO: call register_meta_component<Component>(); for all components that need to be usable within script with registry

            registry.on_construct<ScriptComponent>().connect<&init_script>();
            registry.on_destroy<ScriptComponent>().connect<&release_script>();
        
            /*
            When Lua does:

            local registry = require("registry")

            …it will call your open_registry function (a C++ function that likely registers some Lua tables or bindings), and the returned Lua table becomes the result of require("registry").
            */
            lua.require("registry", sol::c_call<AUTO_ARG(&open_registry)>, false);
        }

        /**
         * @brief Updates all Lua scripts each frame.
         *
         * @param registry The ECS registry.
         * @param delta_time The time elapsed since the last frame.
         */
        inline auto update(entt::registry &registry, float delta_time) -> void
        {
            script_system_update(registry, delta_time);
        }
    }

} // namespace
