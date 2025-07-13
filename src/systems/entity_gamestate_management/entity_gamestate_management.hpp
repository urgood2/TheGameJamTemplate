// entity_gamestate_management.hpp
#pragma once

#include "core/globals.hpp"
#include "util/common_headers.hpp"
#include "systems/scripting/binding_recorder.hpp"

#include <string>
#include <unordered_set>
#include <functional>
#include <entt/entt.hpp>
#include <sol/sol.hpp>

namespace entity_gamestate_management {

    // all transform entities should have this tag by default, unless overridden
static const std::string DEFAULT_STATE_TAG = "default_state";

//-----------------------------------------------------------------------------
// Component: Attach to any entity you want to gate by state
//-----------------------------------------------------------------------------
struct StateTag {
    std::string name;
    std::size_t hash;

    StateTag() = default;
    explicit StateTag(const std::string &s)
        : name(s)
        , hash(std::hash<std::string>{}(s))
    {}
};

//-----------------------------------------------------------------------------
// Resource: Holds all currently active state hashes
//-----------------------------------------------------------------------------
struct ActiveStates {
    std::unordered_set<std::size_t> active_hashes;

    // Activate a state by name
    void activate(const std::string &state) {
        active_hashes.insert(std::hash<std::string>{}(state));
    }

    // Deactivate a state by name
    void deactivate(const std::string &state) {
        active_hashes.erase(std::hash<std::string>{}(state));
    }

    // Clear all active states
    void clear() {
        active_hashes.clear();
    }

    // Query if a tag is active
    bool is_active(const StateTag &tag) const {
        return active_hashes.find(tag.hash) != active_hashes.end();
    }
};

/**
 * @brief Provides a singleton instance of the ActiveStates class.
 * 
 * This function ensures that only one instance of the ActiveStates class
 * exists throughout the program's lifetime. The instance is created
 * the first time this function is called and is reused on subsequent calls.
 * 
 * @return A reference to the singleton instance of ActiveStates.
 */
inline ActiveStates &active_states_instance() {
    static ActiveStates instance{ .active_hashes = { std::hash<std::string>{}(DEFAULT_STATE_TAG) } };
    return instance;
}

inline bool isActiveState(StateTag &tag) {
    return active_states_instance().is_active(tag);
}

inline void emplaceOrReplaceStateTag(entt::entity entity, const std::string &name) {
    globals::registry.emplace_or_replace<StateTag>(entity, name);
}

inline void assignDefaultStateTag(entt::entity entity) {
    globals::registry.emplace_or_replace<StateTag>(entity, DEFAULT_STATE_TAG);
}

//-----------------------------------------------------------------------------
// Systems: Utilities to filter views based on ActiveStates
//-----------------------------------------------------------------------------
/*
Example usage in a render/collision system:
registry.view<Transform, StateTag>()
  .each([&](auto ent, Transform &t, StateTag &tag) {
      if (!active_states.is_active(tag)) return;
       ... process only active entities ...
  });
  
  */

//-----------------------------------------------------------------------------
// Lua Binding Helpers (using sol2)
//-----------------------------------------------------------------------------

// Registers the ActiveStates and StateTag component in Lua
inline void exposeToLua(sol::state &lua) {
    auto &registry = globals::registry;
    auto active_states = active_states_instance();
    // Expose add_state_tag(entity, "name")
    lua.set_function("add_state_tag", [&registry](entt::entity e, const std::string &name) {
        registry.emplace_or_replace<StateTag>(e, name);
    });

    // Expose remove_state_tag(entity)
    lua.set_function("remove_state_tag", [&registry](entt::entity e) {
        registry.remove<StateTag>(e);
    });

    // Expose clear_state_tags(entity)
    lua.set_function("clear_state_tags", [&registry](entt::entity e) {
        if (registry.all_of<StateTag>(e)) registry.remove<StateTag>(e);
    });

    // Expose ActiveStates methods
    lua.new_usertype<ActiveStates>("ActiveStates",
        "activate", &ActiveStates::activate,
        "deactivate", &ActiveStates::deactivate,
        "clear", &ActiveStates::clear,
        "is_active", &ActiveStates::is_active
    );

    // Make the global active_states instance available to Lua
    lua["active_states"] = &active_states;
    
    auto &rec = BindingRecorder::instance();
    
    // free functions
    rec.record_free_function({}, { "add_state_tag",
        "---@param entity Entity             # The entity to tag\n"
        "---@param name string               # The name of the state tag\n"
        "---@return nil",
        "Adds or replaces a StateTag component on the specified entity.", true, false
    });

    rec.record_free_function({}, { "remove_state_tag",
        "---@param entity Entity             # The entity from which to remove its state tag\n"
        "---@return nil",
        "Removes the StateTag component from the specified entity.", true, false
    });

    rec.record_free_function({}, { "clear_state_tags",
        "---@param entity Entity             # The entity whose state tags you want to clear\n"
        "---@return nil",
        "Clears any and all StateTag components from the specified entity.", true, false
    });

    // the ActiveStates usertype itself
    rec.record_property("ActiveStates", {
        "---@class ActiveStates            # A global registry of named states you can turn on/off"
    });

    // methods on ActiveStates
    rec.record_method("ActiveStates", { "activate",
        "---@param name string              # The state name to activate\n"
        "---@return nil",
        "Marks the given state as active.", false, false
    });

    rec.record_method("ActiveStates", { "deactivate",
        "---@param name string              # The state name to deactivate\n"
        "---@return nil",
        "Marks the given state as inactive.", false, false
    });

    rec.record_method("ActiveStates", { "clear",
        "---@return nil",
        "Clears all active states.", false, false
    });

    rec.record_method("ActiveStates", { "is_active",
        "---@param name string              # The state name to query\n"
        "---@return boolean                 # true if the state is currently active\n",
        "Returns whether the named state is currently active.", false, false
    });
}

//-----------------------------------------------------------------------------
// Example Initialization
//-----------------------------------------------------------------------------

// In your startup code:
// entity_gamestate_management::ActiveStates active_states;
// sol::state lua;
// entt::registry registry;
// entity_gamestate_management::bind_to_lua(lua, registry, active_states);

} // namespace entity_gamestate_management
