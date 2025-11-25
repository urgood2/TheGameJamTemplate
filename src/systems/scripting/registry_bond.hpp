#pragma once

#include "entt/entity/registry.hpp"
#include "entt/entity/runtime_view.hpp"
#include "meta_helper.hpp"
#include "spdlog/spdlog.h"
#include <set>
#include <cstdint>

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
    inline sol::object emplace_component(entt::registry *registry, entt::entity entity,
                                const sol::table &instance, // This parameter is now ignored
                                sol::this_state s)
    {
        assert(registry);

        if (!registry->valid(entity)) {
            SPDLOG_WARN("Lua attempted to emplace component {} on invalid entity {}", entt::type_hash<Component>::value(), static_cast<std::uint32_t>(entity));
            return sol::make_object(s, sol::lua_nil);
        }

        // This version ONLY creates a default component on a valid entity.
        auto &comp = registry->emplace_or_replace<Component>(entity);

        return sol::make_object(s, std::ref(comp));
    }
    template <typename Component>
    inline sol::object get_component(entt::registry *registry, entt::entity entity,
                              sol::this_state s)
    {
        assert(registry);

        if (!registry->valid(entity)) {
            SPDLOG_WARN("Lua attempted to get component {} on invalid entity {}", entt::type_hash<Component>::value(), static_cast<std::uint32_t>(entity));
            return sol::make_object(s, sol::lua_nil);
        }

        // NOTE: an error can occur here if the entity get() called from lua doesn't exist or is invalid.
        auto &comp = registry->get_or_emplace<Component>(entity);
        return sol::make_object(s, std::ref(comp));
    }
    template <typename Component>
    inline bool has_component(entt::registry *registry, entt::entity entity)
    {
        assert(registry);
        if (!registry->valid(entity)) {
            SPDLOG_WARN("Lua attempted to check component {} on invalid entity {}", entt::type_hash<Component>::value(), static_cast<std::uint32_t>(entity));
            return false;
        }
        return registry->any_of<Component>(entity);
    }
    template <typename Component>
    inline auto remove_component(entt::registry *registry, entt::entity entity)
    {
        assert(registry);
        if (!registry->valid(entity)) {
            SPDLOG_WARN("Lua attempted to remove component {} on invalid entity {}", entt::type_hash<Component>::value(), static_cast<std::uint32_t>(entity));
            return std::size_t{0};
        }
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
