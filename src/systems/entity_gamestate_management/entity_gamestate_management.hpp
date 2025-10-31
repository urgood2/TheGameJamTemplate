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
    std::vector<std::string> names;
    std::vector<std::size_t> hashes;

    StateTag() = default;
    explicit StateTag(const std::string &s) {
        add_tag(s);
    }

    void add_tag(const std::string &s) {
        std::size_t h = std::hash<std::string>{}(s);
        // avoid duplicates
        if (std::find(hashes.begin(), hashes.end(), h) == hashes.end()) {
            names.push_back(s);
            hashes.push_back(h);
        }
    }

    void clear() {
        names.clear();
        hashes.clear();
    }
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
        for (auto h : tag.hashes) {
            if (active_hashes.contains(h))
                return true;
        }
        return false;

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

inline bool is_active(const StateTag &tag) {
    for (auto h : tag.hashes) {
        if (active_states_instance().active_hashes.contains(h))
            return true;
    }
    return false;
}

enum class TagMode { Any, All };



// Returns true if any of the entity's tags are active.
inline bool hasAnyTag(const StateTag& tag) {
    const auto& active = active_states_instance().active_hashes;
    for (auto h : tag.hashes) {
        if (active.contains(h)) return true;
    }
    return false;
}

// Returns true if all of the entity's tags are active.
inline bool hasAllTags(const StateTag& tag) {
    const auto& active = active_states_instance().active_hashes;
    for (auto h : tag.hashes) {
        if (!active.contains(h)) return false;
    }
    return !tag.hashes.empty();
}

// Lua overloads for string name arrays (for convenience)
inline bool hasAnyTagNames(const std::vector<std::string>& tags) {
    for (const auto& s : tags) {
        std::size_t h = std::hash<std::string>{}(s);
        if (active_states_instance().active_hashes.contains(h)) return true;
    }
    return false;
}

inline bool hasAllTagNames(const std::vector<std::string>& tags) {
    for (const auto& s : tags) {
        std::size_t h = std::hash<std::string>{}(s);
        if (!active_states_instance().active_hashes.contains(h)) return false;
    }
    return !tags.empty();
}


inline void emplaceOrReplaceStateTag(entt::entity entity, const std::string &name) {
    globals::registry.emplace_or_replace<StateTag>(entity, name);
}

inline void assignDefaultStateTag(entt::entity entity) {
    globals::registry.emplace_or_replace<StateTag>(entity, DEFAULT_STATE_TAG);
}

inline bool isEntityActive(entt::entity entity) {
    auto &registry = globals::registry;
    if (!registry.all_of<StateTag>(entity)) return false;
    const auto &tag = registry.get<StateTag>(entity);
    return is_active(tag);
}

inline void activate_state(std::string_view s)   { active_states_instance().activate(std::string{s}); }
inline void deactivate_state(std::string_view s) { active_states_instance().deactivate(std::string{s}); }
inline void clear_states()                       { active_states_instance().clear(); }
inline bool is_state_active(const StateTag &t)   { return active_states_instance().is_active(t); }

// Convenience overload so Lua/docs can pass a name instead of a StateTag
inline bool is_state_active_name(std::string_view s) {
    StateTag tag{std::string{s}};
    return active_states_instance().is_active(tag);
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
    auto &active_states = active_states_instance();
    // Expose add_state_tag(entity, "name")
    lua.set_function("add_state_tag", [&registry](entt::entity e, const std::string &name) {
        if (registry.all_of<StateTag>(e)) {
            registry.get<StateTag>(e).add_tag(name);
        } else {
            registry.emplace<StateTag>(e, name);
        }
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
    
    lua.set_function("activate_state",   &activate_state);
    lua.set_function("deactivate_state", &deactivate_state);
    lua.set_function("clear_states",     &clear_states);
    lua.set_function("is_state_active",  sol::overload(
        &is_state_active,        // StateTag&
        &is_state_active_name    // string name
    ));
    lua.set_function("is_entity_active", &isEntityActive);
    
    lua.set_function("hasAnyTag", sol::overload(
        &hasAnyTag,       // StateTag&
        &hasAnyTagNames   // vector<string>
    ));

    lua.set_function("hasAllTags", sol::overload(
        &hasAllTags,      // StateTag&
        &hasAllTagNames   // vector<string>
    ));
    
    
    // Expose remove_default_state_tag(entity)
    lua.set_function("remove_default_state_tag", [&registry](entt::entity e) {
        if (!registry.all_of<StateTag>(e)) return;
        auto &tag = registry.get<StateTag>(e);
        auto it = std::find(tag.names.begin(), tag.names.end(), DEFAULT_STATE_TAG);
        if (it != tag.names.end()) {
            std::size_t h = std::hash<std::string>{}(*it);
            tag.names.erase(it);
            auto hashIt = std::find(tag.hashes.begin(), tag.hashes.end(), h);
            if (hashIt != tag.hashes.end())
                tag.hashes.erase(hashIt);
        }
    });

    

    auto &rec = BindingRecorder::instance();
    
    rec.record_free_function({}, {
        "remove_default_state_tag",
        "---@param entity Entity             # The entity whose 'default_state' tag should be removed\n"
        "---@return nil\n"
        "Removes the `'default_state'` tag from the entity’s StateTag list, if present.",
        "Removes the default state tag from the specified entity, if it exists.",
        true, false
    });
    
    rec.record_free_function({}, {
        "hasAnyTag",
        "---@overload fun(tag: StateTag): boolean\n"
        "---@overload fun(names: string[]): boolean\n"
        "---@return boolean\n"
        "Returns `true` if **any** of the given state tags or names are currently active.\n"
        "You can pass either a `StateTag` component or an array of strings.\n"
        "Example:\n"
        "```lua\n"
        "if hasAnyTag({ 'SHOP_STATE', 'PLANNING_STATE' }) then\n"
        "  print('At least one of these states is active.')\n"
        "end\n"
        "```",
        "Checks whether any of the given tags or state names are active in the global ActiveStates instance.",
        true, false
    });

    rec.record_free_function({}, {
        "hasAllTags",
        "---@overload fun(tag: StateTag): boolean\n"
        "---@overload fun(names: string[]): boolean\n"
        "---@return boolean\n"
        "Returns `true` if **all** of the given state tags or names are currently active.\n"
        "You can pass either a `StateTag` component or an array of strings.\n"
        "Example:\n"
        "```lua\n"
        "if hasAllTags({ 'ACTION_STATE', 'PLANNING_STATE' }) then\n"
        "  print('Both states are active at once.')\n"
        "end\n"
        "```",
        "Checks whether all of the given tags or state names are active in the global ActiveStates instance.",
        true, false
    });

    
    rec.record_free_function({}, {
        "activate_state",
        "---@param name string\n"
        "---@return nil\n"
        "Activates (enables) the given state name globally.\n"
        "Equivalent to `active_states:activate(name)` on the singleton instance.",
        "Activates the given named state globally, using the shared ActiveStates instance.",
        true, false
    });
    
    rec.record_free_function({}, {
        "is_entity_active",
        "---@param entity Entity\n"
        "---@return boolean\n"
        "Checks whether the given entity is currently active based on its StateTag component and the global active states.\n"
        "Returns `true` if the entity's StateTag is active in the global ActiveStates set.",
        "Checks whether the specified entity is active using the shared ActiveStates instance.",
        true, false
    });

    rec.record_free_function({}, {
        "deactivate_state",
        "---@param name string\n"
        "---@return nil\n"
        "Deactivates (disables) the given state name globally.\n"
        "Equivalent to `active_states:deactivate(name)` on the singleton instance.",
        "Deactivates the given named state globally, using the shared ActiveStates instance.",
        true, false
    });

    rec.record_free_function({}, {
        "clear_states",
        "---@return nil\n"
        "Clears **all** currently active global states.\n"
        "Equivalent to `active_states:clear()` on the singleton instance.",
        "Clears all currently active global states in the shared ActiveStates instance.",
        true, false
    });

    rec.record_free_function({}, {
        "is_state_active",
        "---@overload fun(tag: StateTag): boolean\n"
        "---@overload fun(name: string): boolean\n"
        "---@return boolean\n"
        "Checks whether a given state (by tag or name) is currently active.\n"
        "Returns `true` if the state exists in the global ActiveStates set.",
        "Checks whether a state tag or state name is active in the global ActiveStates instance.",
        true, false
    });
    
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
