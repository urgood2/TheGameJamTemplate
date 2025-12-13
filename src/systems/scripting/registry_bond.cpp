
#include "registry_bond.hpp"

#include "entt/entity/entity.hpp"
#include "entt/entity/registry.hpp"
#include "entt/entity/runtime_view.hpp"
#include "meta_helper.hpp"
#include "binding_recorder.hpp"
#include <set>

#include "scripting_system.hpp"


namespace scripting
{

    
    auto collect_types(const sol::variadic_args &va)
    {
        std::set<entt::id_type> types;
        std::transform(va.cbegin(), va.cend(), std::inserter(types, types.begin()),
                       [](const auto &obj)
                       { return scripting::deduce_type(obj); });
        return types;
    }
    
    // 1. Create the C++ helper function. Its job is simple: take a registry,
    //    an entity, and a Lua table, and emplace the component using the
    //    new constructor we just added.
    void add_script_component(entt::registry& registry, entt::entity entity, const sol::table& script_table) {
        if (!registry.valid(entity)) {
            SPDLOG_WARN("Lua attempted to add ScriptComponent to invalid entity {}", static_cast<std::uint32_t>(entity));
            return;
        }
        if (script_table.valid()) {
            registry.emplace<ScriptComponent>(entity, script_table);
        }
    }


    sol::table open_registry(sol::this_state s)
    {
        // To create a registry inside a script: entt.registry.new()

        sol::state_view lua{s};
        auto entt_module = lua["entt"].get_or_create<sol::table>();

        // clang-format off
        entt_module.new_usertype<entt::runtime_view>("runtime_view",
            sol::no_constructor,

            "size_hint", &entt::runtime_view::size_hint,
            "contains", &entt::runtime_view::contains,
            "each",
            [](const entt::runtime_view &self, const sol::function &callback) {
                if (callback.valid()) {
                for (auto entity : self) callback(entity);
                }
            }
        );

        auto& rec = BindingRecorder::instance();
        rec.add_type("entt.runtime_view").doc = "A runtime view for iterating entities with specific components";
        rec.record_property("entt.runtime_view", {"size_hint", "---@param self runtime_view\n---@return integer", "Returns the number of entities in the view"});
        rec.record_property("entt.runtime_view", {"contains", "---@param self runtime_view\n---@param entity Entity\n---@return boolean", "Checks if entity is in the view"});
        rec.record_property("entt.runtime_view", {"each", "---@param self runtime_view\n---@param callback fun(entity: Entity)", "Iterates all entities in the view"});

        using namespace entt::literals;

        entt_module.new_usertype<entt::registry>("registry",
            sol::meta_function::construct,
            sol::factories([]{ return entt::registry{}; }),

            "size", [](const entt::registry &self) {
            return self.storage<entt::entity>()->size();
            },
            "alive", [](const entt::registry &self) {
            return self.storage<entt::entity>()->free_list();
            },

            "valid", &entt::registry::valid,
            "current", &entt::registry::current,

            "create", [](entt::registry &self) { return self.create(); },
            "destroy",
            [](entt::registry &self, entt::entity entity) {
                if (self.valid(entity))
                    return self.destroy(entity);
                else
                    return entt::to_version(entity);
            },

            "emplace",
            [](entt::registry &self, entt::entity entity, const sol::table &comp_type, sol::this_state s) -> sol::object {
                if (!comp_type.valid()) return sol::make_object(s, sol::lua_nil);

                const auto type_id = scripting::get_type_id(comp_type);

                // We no longer pass the 'instance' table. We can pass an empty one.
                const auto maybe_any = scripting::invoke_meta_func(type_id, "emplace"_hs, &self, entity, sol::table{}, s);
                if (!maybe_any) return sol::make_object(s, sol::lua_nil);

                if (auto *obj = maybe_any.try_cast<sol::object>()) {
                    return (obj->valid()) ? *obj : sol::make_object(s, sol::lua_nil);
                }

                return sol::make_object(s, sol::lua_nil);
            },

            "add_script", &add_script_component,

            "remove",
            [](entt::registry &self, entt::entity entity, const sol::object &type_or_id) {
                const auto maybe_any =
                scripting::invoke_meta_func(scripting::deduce_type(type_or_id), "remove"_hs, &self, entity);
                return maybe_any ? maybe_any.cast<size_t>() : 0;
            },
            "has",
            [](entt::registry &self, entt::entity entity, const sol::object &type_or_id) {
                const auto maybe_any =
                scripting::invoke_meta_func(scripting::deduce_type(type_or_id), "has"_hs, &self, entity);
                return maybe_any ? maybe_any.cast<bool>() : false;
            },
            "any_of",
            [](const sol::table &self, entt::entity entity, const sol::variadic_args &va) {
                const auto types = collect_types(va);
                const auto has = self["has"].get<sol::function>();
                return std::any_of(types.cbegin(), types.cend(),
                [&](auto type_id) { return has(self, entity, type_id).template get<bool>(); }
                );
            },
            "get",
            [](entt::registry &self, entt::entity entity, const sol::object &type_or_id,
                sol::this_state s) -> sol::object {
            const auto maybe_any =
                scripting::invoke_meta_func(scripting::deduce_type(type_or_id), "get"_hs,
                &self, entity, s);
            if (!maybe_any) return sol::make_object(s, sol::lua_nil);
            if (auto *obj = maybe_any.try_cast<sol::object>()) {
                return (obj->valid()) ? *obj : sol::make_object(s, sol::lua_nil);
            }
            return sol::make_object(s, sol::lua_nil);
            },
            "clear",
            sol::overload(
                &entt::registry::clear<>,
                [](entt::registry &self, sol::object type_or_id) {
                scripting::invoke_meta_func(scripting::deduce_type(type_or_id), "clear"_hs, &self);
                }
            ),

            "orphan", &entt::registry::orphan,

            "runtime_view",
            [](entt::registry &self, const sol::variadic_args &va) {
                const auto types = collect_types(va);

                auto view = entt::runtime_view{};
                for (auto &&[componentId, storage]: self.storage()) {
                if (types.find(componentId) != types.cend()) {
                    view.iterate(storage);
                }
                }
                return view;
            }
        );

        // Document registry methods
        rec.add_type("entt.registry").doc = "The main entity-component registry";
        rec.record_property("entt.registry", {"new", "---@return registry", "Creates a new registry"});
        rec.record_property("entt.registry", {"size", "---@param self entt.registry\n---@return integer # Total count of entities (alive + dead)", "Returns the total number of entities in the registry"});
        rec.record_property("entt.registry", {"alive", "---@param self entt.registry\n---@return integer # Count of alive entities", "Returns the number of alive entities in the registry"});
        rec.record_property("entt.registry", {"valid", "---@param self registry\n---@param entity Entity\n---@return boolean # True if entity is valid", "Checks if an entity is valid"});
        rec.record_property("entt.registry", {"current", "---@param self registry\n---@param entity Entity\n---@return integer # Current version of the entity", "Gets the current version of an entity"});
        rec.record_property("entt.registry", {"create", "---@param self entt.registry\n---@return Entity # Newly created entity", "Creates a new entity"});
        rec.record_property("entt.registry", {"destroy", "---@param self registry\n---@param entity Entity\n---@return integer # Version of destroyed entity", "Destroys an entity"});
        rec.record_property("entt.registry", {"emplace", "---@param self registry\n---@param entity Entity\n---@param comp_type table\n---@return table|nil # The emplaced component or nil if failed", "Emplaces a component on an entity"});
        rec.record_property("entt.registry", {"add_script", "---@param self registry\n---@param entity Entity\n---@param script_table table\n---@return nil", "Adds a script component to an entity"});
        rec.record_property("entt.registry", {"remove", "---@param self registry\n---@param entity Entity\n---@param type_or_id table|integer\n---@return integer # Number of components removed", "Removes a component from an entity"});
        rec.record_property("entt.registry", {"has", "---@param self registry\n---@param entity Entity\n---@param type_or_id table|integer\n---@return boolean # True if entity has the component", "Checks if an entity has a component"});
        rec.record_property("entt.registry", {"any_of", "---@param self registry\n---@param entity Entity\n---@vararg table|integer\n---@return boolean # True if entity has any of the components", "Checks if an entity has any of the specified components"});
        rec.record_property("entt.registry", {"get", "---@param self registry\n---@param entity Entity\n---@param type_or_id table|integer\n---@return table|nil # The component or nil if not found", "Gets a component from an entity"});
        rec.record_property("entt.registry", {"clear", "---@param self entt.registry\n---@overload fun(self: entt.registry): nil\n---@param type_or_id? table|integer\n---@return nil", "Clears all entities or components of a specific type"});
        rec.record_property("entt.registry", {"orphan", "---@param self entt.registry\n---@param entity Entity\n---@return boolean # True if entity has no components", "Checks if an entity has no components (is an orphan)"});
        rec.record_property("entt.registry", {"runtime_view", "---@param self registry\n---@vararg table|integer\n---@return runtime_view # A view containing matching entities", "Creates a runtime view for iterating entities with specific components"});
        // clang-format on

        return entt_module;
    }

}
