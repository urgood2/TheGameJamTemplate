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
    
    struct InactiveTag {}; // tag to indicate entity is inactive for updates.

inline void applyStateEffectsToEntity(entt::registry &registry, entt::entity entity);

// all transform entities should have this tag by default, unless overridden
static const std::string DEFAULT_STATE_TAG = "default_state";
static const std::string PLANNING_STATE_TAG = "PLANNING";

//-----------------------------------------------------------------------------
// Component: Attach to any entity you want to gate by state
//-----------------------------------------------------------------------------
struct StateTag {
    std::vector<std::string> names;
    std::vector<std::size_t> hashes;

    StateTag() = default;
    explicit StateTag(const std::string &s);
    void add_tag(const std::string &s);
    void clear();
};

//-----------------------------------------------------------------------------
// Resource: Holds all currently active state hashes
//-----------------------------------------------------------------------------
struct ActiveStates {
    std::unordered_set<std::size_t> active_hashes;

    void activate(const std::string &state);
    void deactivate(const std::string &state);
    void clear();
    bool is_active(const StateTag &tag) const;
};

// Singleton instance
ActiveStates &active_states_instance();

bool isActiveState(StateTag &tag);
bool is_active(const StateTag &tag);

enum class TagMode { Any, All };

bool hasAnyTag(const StateTag& tag);
bool hasAllTags(const StateTag& tag);

bool hasAnyTagNames(const std::vector<std::string>& tags);
bool hasAllTagNames(const std::vector<std::string>& tags);

void emplaceOrReplaceStateTag(entt::entity entity, const std::string &name);
void assignDefaultStateTag(entt::entity entity);
bool isEntityActive(entt::entity entity);

void activate_state(std::string_view s);
void deactivate_state(std::string_view s);
void clear_states();
bool is_state_active(const StateTag &t);
bool is_state_active_name(std::string_view s);

void applyStateEffectsToEntity(entt::registry &registry, entt::entity entity);

void exposeToLua(sol::state &lua);

} // namespace entity_gamestate_management
