#pragma once

#include "entt/entity/registry.hpp"
#include "entt/entity/runtime_view.hpp"
#include "meta_helper.hpp"
#include <set>

namespace scripting
{
    struct ScriptComponent;

    template <typename Component>
    inline auto is_valid(const entt::registry *registry, entt::entity entity)
    {
        assert(registry);
        return registry->valid(entity);
    }
    template <typename Component>
    inline auto emplace_component(entt::registry *registry, entt::entity entity,
                                const sol::table &instance, // This parameter is now ignored
                                sol::this_state s)
    {
        assert(registry);

        // This version ONLY creates a default component.
        auto &comp = registry->emplace_or_replace<Component>(entity);

        return sol::make_reference(s, std::ref(comp));
    }
    template <typename Component>
    inline auto get_component(entt::registry *registry, entt::entity entity,
                              sol::this_state s)
    {
        assert(registry);
        auto &comp = registry->get_or_emplace<Component>(entity);
        return sol::make_reference(s, std::ref(comp));
    }
    template <typename Component>
    inline bool has_component(entt::registry *registry, entt::entity entity)
    {
        assert(registry);
        return registry->any_of<Component>(entity);
    }
    template <typename Component>
    inline auto remove_component(entt::registry *registry, entt::entity entity)
    {
        assert(registry);
        return registry->remove<Component>(entity);
    }
    template <typename Component>
    inline void clear_component(entt::registry *registry)
    {
        assert(registry);
        registry->clear<Component>();
    }

    template <typename Component>
    inline void register_meta_component()
    {
        using namespace entt::literals;

        entt::meta<Component>()
            .template func<&is_valid<Component>>("valid"_hs)
            .template func<&emplace_component<Component>>("emplace"_hs)
            .template func<&get_component<Component>>("get"_hs)
            .template func<&has_component<Component>>("has"_hs)
            .template func<&clear_component<Component>>("clear"_hs)
            .template func<&remove_component<Component>>("remove"_hs);
    }
    
    // 1. Create the C++ helper function. Its job is simple: take a registry,
    //    an entity, and a Lua table, and emplace the component using the
    //    new constructor we just added.
    extern void add_script_component(entt::registry& registry, entt::entity entity, const sol::table& script_table);

    extern auto collect_types(const sol::variadic_args &va);

    extern sol::table open_registry(sol::this_state s);

}