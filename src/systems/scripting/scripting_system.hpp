#include <thread>
#include <chrono>

#include "registry_bond.hpp"

#include "systems/ui/ui.hpp"
#include "systems/particles/particle.hpp"
#include "components/graphics.hpp"
#include "systems/shaders/shader_pipeline.hpp"
#include "systems/shaders/shader_system.hpp"
#include "components/components.hpp"

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
        
        // list of currently running Lua coroutines (tasks)
        std::vector<sol::coroutine> tasks;

        void add_task(sol::coroutine co) {
            if (co.valid()) {
                tasks.emplace_back(std::move(co));
            }
        }

        std::size_t count_tasks() const {
            return tasks.size();
        }

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
        script.self["__entity_id"] = static_cast<uint32_t>(entity);
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
            // 1. Run normal update
            assert(script.self.valid());
            script.hooks.update(script.self, delta_time);
            
            // 2. Resume coroutine tasks
            auto& tasks = script.tasks;
            for (auto it = tasks.begin(); it != tasks.end();) {
                if (it->valid() && it->status() == sol::call_status::yielded) {
                    sol::protected_function_result result = (*it)(script.self, delta_time);
                    if (!result.valid()) {
                        sol::error err = result;
                        std::cerr << "[Coroutine Error] " << err.what() << "\n";
                        it = tasks.erase(it);
                        continue;
                    }
                }

                if (!it->valid() || it->status() == sol::call_status::ok) {
                    it = tasks.erase(it);
                } else {
                    ++it;
                }
            }
            

        }
    }
    

    namespace monobehavior_system {
        
        inline auto generateBindingsToLua(sol::state &lua) -> void
        {
            auto& rec = BindingRecorder::instance();
            
            // Expose ScriptComponent to Lua
            lua.new_usertype<ScriptComponent>("ScriptComponent",
                "add_task", &ScriptComponent::add_task,
                "count_tasks", &ScriptComponent::count_tasks
            );

            // Global function to get ScriptComponent from entity ID
            lua["get_script_component"] = [&](uint32_t entity_id) -> ScriptComponent& {
                entt::entity ent = static_cast<entt::entity>(entity_id);
                return globals::registry.get<ScriptComponent>(ent);
            };
            
            rec.add_type("entt");
            
            // --- entt.runtime_view ---
            auto& view_type = rec.add_type("entt.runtime_view");
            view_type.doc = "An iterable view over a set of entities that have all the given components.";

            rec.record_method("entt.runtime_view", {
                "size_hint",
                "---@return integer",
                "Returns an estimated number of entities in the view."
            });

            rec.record_method("entt.runtime_view", {
                "contains",
                "---@param entity Entity\n"
                "---@return boolean",
                "Checks if an entity is present in the view."
            });

            rec.record_method("entt.runtime_view", {
                "each",
                "---@param callback fun(entity: Entity)\n"
                "---@return nil",
                "Iterates over all entities in the view and calls the provided function for each one."
            });

            // --- entt.registry ---
            auto& reg_type = rec.add_type("entt.registry");
            reg_type.doc = "The main container for all entities and components in the ECS world.";

            rec.record_method("entt.registry", {
                "new",
                "---@return entt.registry",
                "Creates a new, empty registry instance.",
                true // is_static
            });

            rec.record_method("entt.registry", {"size", "---@return integer", "Returns the number of entities created so far."});
            rec.record_method("entt.registry", {"alive", "---@return integer", "Returns the number of living entities."});
            rec.record_method("entt.registry", {"valid", "---@param entity Entity\n---@return boolean", "Checks if an entity handle is valid and still alive."});
            rec.record_method("entt.registry", {"current", "---@param entity Entity\n---@return integer", "Returns the current version of an entity handle."});

            rec.record_method("entt.registry", {
                "create",
                "---@return Entity",
                "Creates a new entity and returns its handle."
            });

            rec.record_method("entt.registry", {
                "destroy",
                "---@param entity Entity\n"
                "---@return nil",
                "Destroys an entity and all its components."
            });

            rec.record_method("entt.registry", {
                "emplace",
                "---@param entity Entity\n"
                "---@param component_table table # A Lua table representing the component, must contain a `__type` field.\n"
                "---@return any # The newly created component instance.",
                "Adds and initializes a component for an entity using a Lua table."
            });
            
            rec.record_method("entt.registry", {
                "remove",
                "---@param entity Entity\n"
                "---@param component_type ComponentType\n"
                "---@return integer # The number of components removed (0 or 1).",
                "Removes a component from an entity."
            });

            rec.record_method("entt.registry", {
                "has",
                "---@param entity Entity\n"
                "---@param component_type ComponentType\n"
                "---@return boolean",
                "Checks if an entity has a specific component."
            });
            
            rec.record_method("entt.registry", {
                "any_of",
                "---@param entity Entity\n"
                "---@param ... ComponentType\n"
                "---@return boolean",
                "Checks if an entity has any of the specified components."
            });

            rec.record_method("entt.registry", {
                "get",
                "---@param entity Entity\n"
                "---@param component_type ComponentType\n"
                "---@return any|nil # The component instance, or nil if not found.",
                "Retrieves a component from an entity."
            });

            // --- Overloaded clear() method ---
            rec.record_method("entt.registry", {
                "clear",
                "---@return nil",
                "Destroys all entities and clears all component pools.",
                false, false // Not an overload, this is the base signature
            });
            rec.record_method("entt.registry", {
                "clear",
                "---@overload fun(component_type: ComponentType):void",
                "Removes all components of a given type from all entities.",
                false, true // This is the overload
            });


            rec.record_method("entt.registry", {
                "orphan",
                "---@return nil",
                "Destroys all entities that have no components."
            });

            rec.record_method("entt.registry", {
                "runtime_view",
                "---@param ... ComponentType\n"
                "---@return entt.runtime_view",
                "Creates and returns a view for iterating over entities that have all specified components."
            });
            
            // --- 2. Document the structure of a Lua script component ---
            // This defines the "interface" that C++ expects from your Lua tables.
            
            auto& script_interface = rec.add_type("ScriptComponent", true);
            script_interface.doc = "The interface for a Lua script attached to an entity (like monobehavior). Your script table should implement these methods.";
            
            // --- Global Scripting Functions ---
            rec.record_free_function({}, {
                "get_script_component",
                "---@param entity_id integer\n"
                "---@return ScriptComponent",
                "Retrieves the ScriptComponent for a given entity ID."
            });
            
            // --- Added ScriptComponent Methods ---
            rec.record_method("ScriptComponent", {
                "add_task",
                "---@param task coroutine\n"
                "---@return nil",
                "Adds a new coroutine to this script's task list."
            });
            
            rec.record_method("ScriptComponent", {
                "count_tasks",
                "---@return integer",
                "Returns the number of active coroutines on this script."
            });
        
            rec.record_property("ScriptComponent", {"id", "nil", "Entity: (Read-only) The entity handle this script is attached to. Injected by the system."});
            rec.record_property("ScriptComponent", {"owner", "nil", "registry: (Read-only) A reference to the C++ registry. Injected by the system."});
            
            rec.record_property("ScriptComponent", {"init", "nil", "function(): Optional function called once when the script is attached to an entity."});
            rec.record_property("ScriptComponent", {"update", "nil", "function(dt: number): Function called every frame."});
            rec.record_property("ScriptComponent", {"destroy", "nil", "function(): Optional function called just before the entity is destroyed."});


        }
        
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
            //  call register_meta_component<Component>(); for all components that need to be usable within script with registry
            register_meta_component<ScriptComponent>();
            register_meta_component<layer::LayerOrderComponent>();
            register_meta_component<layer::Layer>();
            register_meta_component<transform::Transform>();
            register_meta_component<transform::InheritedProperties>();
            register_meta_component<transform::GameObject>();
            register_meta_component<transform::TreeOrderComponent>();
            register_meta_component<ui::ObjectAttachedToUITag>();
            register_meta_component<ui::UIElementComponent>();
            register_meta_component<ui::TextInput>();
            register_meta_component<ui::UIBoxComponent>();
            register_meta_component<ui::UIState>();
            register_meta_component<ui::Tooltip>();
            register_meta_component<ui::InventoryGridTileComponent>();
            register_meta_component<ui::UIConfig>();
            register_meta_component<ui::UIElementTemplateNode>();
            register_meta_component<particle::ParticleEmitter>();
            register_meta_component<particle::Particle>();
            register_meta_component<shaders::ShaderUniformSet>();
            register_meta_component<shaders::ShaderUniformComponent>();
            register_meta_component<shader_pipeline::ShaderPass>();
            register_meta_component<shader_pipeline::ShaderOverlayDraw>();
            register_meta_component<shader_pipeline::ShaderPipelineComponent>();
            register_meta_component<GOAPComponent>();
            register_meta_component<SpriteComponentASCII>();
            register_meta_component<AnimationObject>();
            register_meta_component<AnimationQueueComponent>();

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
