
#include "registry_bond.hpp"

#include "entt/entity/entity.hpp"
#include "entt/entity/registry.hpp"
#include "entt/entity/runtime_view.hpp"
#include "meta_helper.hpp"
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

            // In open_registry, inside the entt::registry usertype
            "emplace",
            [](entt::registry &self, entt::entity entity, const sol::table &comp_type, sol::this_state s) -> sol::object {
                if (!comp_type.valid()) return sol::lua_nil_t{};

                const auto type_id = scripting::get_type_id(comp_type);

                // We no longer pass the 'instance' table. We can pass an empty one.
                const auto maybe_any = scripting::invoke_meta_func(type_id, "emplace"_hs, &self, entity, sol::table{}, s);

                return maybe_any ? maybe_any.cast<sol::reference>() : sol::lua_nil_t{};
            },
            
            // --- ADD THE NEW DEDICATED FUNCTION BINDING ---
            // This is the function your Lua script will now call.
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
                sol::this_state s) {
            const auto maybe_any =
                scripting::invoke_meta_func(scripting::deduce_type(type_or_id), "get"_hs,
                &self, entity, s);
            return maybe_any ? maybe_any.cast<sol::reference>() : sol::lua_nil_t{};
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
        // clang-format on

        return entt_module;
    }

}