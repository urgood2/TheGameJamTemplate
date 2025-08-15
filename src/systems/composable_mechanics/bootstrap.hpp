#pragma once
#include <sol/sol.hpp>
#include "events.hpp"
#include "ability.hpp"
#include "loader_lua.hpp"

struct EngineBootstrap {
    EventBus bus;               // shared event bus
    AbilityDatabase abilityDb;  // content

    // Attach core systems to bus
    void wireCore(entt::registry& world) {
        // Make EventBus available via registry context for pipeline emission
        world.set<EventBus>(bus);

        // Ability system listens to relevant events. You can attach many.
        static AbilitySystem abilities(bus, abilityDb);
        abilities.attachTo(EventType::UnitDied, /*lane*/0, /*priority*/100);
        abilities.attachTo(EventType::SpellCastResolved, 0, 100);
    }

    // Load Lua content from a sol::state that already executed your scripts
    void loadContentFromLua(sol::state& lua) {
        LuaContentLoader loader(abilityDb);
        if (auto traits = lua["traits"]; traits.valid() && traits.get_type() == sol::type::table) {
            loader.load_traits(traits);
        }
        if (auto spells = lua["spells"]; spells.valid() && spells.get_type() == sol::type::table) {
            loader.load_spells(spells);
        }
    }
};