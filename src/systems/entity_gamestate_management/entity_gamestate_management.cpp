#include "entity_gamestate_management.hpp"
#include "spdlog/spdlog.h"
#include "systems/transform/transform.hpp"
#include "systems/ui/box.hpp"
#include "systems/ui/ui_data.hpp"

namespace entity_gamestate_management {

using namespace spring;

//-----------------------------------------------------------------------------
// StateTag implementation
//-----------------------------------------------------------------------------
StateTag::StateTag(const std::string &s) {
    add_tag(s);
}

void StateTag::add_tag(const std::string &s) {
    std::size_t h = std::hash<std::string>{}(s);
    if (std::find(hashes.begin(), hashes.end(), h) == hashes.end()) {
        names.push_back(s);
        hashes.push_back(h);
    }
}

void StateTag::clear() {
    names.clear();
    hashes.clear();
}

//-----------------------------------------------------------------------------
// ActiveStates implementation
//-----------------------------------------------------------------------------
void ActiveStates::activate(const std::string &state) {
    active_hashes.insert(std::hash<std::string>{}(state));
}

void ActiveStates::deactivate(const std::string &state) {
    active_hashes.erase(std::hash<std::string>{}(state));
}

void ActiveStates::clear() {
    active_hashes.clear();
}

bool ActiveStates::is_active(const StateTag &tag) const {
    for (auto h : tag.hashes) {
        if (active_hashes.contains(h))
            return true;
    }
    return false;
}

//-----------------------------------------------------------------------------
// Singleton accessor
//-----------------------------------------------------------------------------
ActiveStates &active_states_instance() {
    static ActiveStates instance{ .active_hashes = { std::hash<std::string>{}(DEFAULT_STATE_TAG), std::hash<std::string>{}(PLANNING_STATE_TAG) } };
    return instance;
}

bool isActiveState(StateTag &tag) {
    return active_states_instance().is_active(tag);
}

bool is_active(const StateTag &tag) {
    for (auto h : tag.hashes) {
        if (active_states_instance().active_hashes.contains(h))
            return true;
    }
    return false;
}

//-----------------------------------------------------------------------------
// Tag utilities
//-----------------------------------------------------------------------------
bool hasAnyTag(const StateTag& tag) {
    const auto& active = active_states_instance().active_hashes;
    for (auto h : tag.hashes) {
        if (active.contains(h)) return true;
    }
    return false;
}

bool hasAllTags(const StateTag& tag) {
    const auto& active = active_states_instance().active_hashes;
    for (auto h : tag.hashes) {
        if (!active.contains(h)) return false;
    }
    return !tag.hashes.empty();
}

bool hasAnyTagNames(const std::vector<std::string>& tags) {
    for (const auto& s : tags) {
        std::size_t h = std::hash<std::string>{}(s);
        if (active_states_instance().active_hashes.contains(h)) return true;
    }
    return false;
}

bool hasAllTagNames(const std::vector<std::string>& tags) {
    for (const auto& s : tags) {
        std::size_t h = std::hash<std::string>{}(s);
        if (!active_states_instance().active_hashes.contains(h)) return false;
    }
    return !tags.empty();
}

//-----------------------------------------------------------------------------
// Entity tag helpers
//-----------------------------------------------------------------------------
void emplaceOrReplaceStateTag(entt::entity entity, const std::string &name) {
    auto& registry = globals::getRegistry();
    registry.emplace_or_replace<StateTag>(entity, name);
    applyStateEffectsToEntity(registry, entity);
}

void assignDefaultStateTag(entt::entity entity) {
    assignDefaultStateTag(globals::getRegistry(), entity);
}

void assignDefaultStateTag(entt::registry& registry, entt::entity entity) {
    registry.emplace_or_replace<StateTag>(entity, DEFAULT_STATE_TAG);
    applyStateEffectsToEntity(registry, entity);
}

bool isEntityActive(entt::entity entity) {
    return isEntityActive(globals::getRegistry(), entity);
}

bool isEntityActive(entt::registry& registry, entt::entity entity) {
    if (!registry.all_of<StateTag>(entity)) return false;
    const auto &tag = registry.get<StateTag>(entity);
    return is_active(tag);
}

//-----------------------------------------------------------------------------
// State activation/deactivation
//-----------------------------------------------------------------------------
void activate_state(std::string_view s) { 
    active_states_instance().activate(std::string{s}); 
    auto& registry = globals::getRegistry();
    auto view = registry.view<StateTag>();
    for (auto entity : view)
        applyStateEffectsToEntity(registry, entity);
}

void deactivate_state(std::string_view s) { 
    active_states_instance().deactivate(std::string{s}); 
    auto& registry = globals::getRegistry();
    auto view = registry.view<StateTag>();
    for (auto entity : view)
        applyStateEffectsToEntity(registry, entity);
}

void clear_states() { 
    active_states_instance().clear(); 
    auto& registry = globals::getRegistry();
    auto view = registry.view<StateTag>();
    for (auto entity : view)
        applyStateEffectsToEntity(registry, entity);
}

bool is_state_active(const StateTag &t) { 
    return active_states_instance().is_active(t); 
}

bool is_state_active_name(std::string_view s) {
    StateTag tag{std::string{s}};
    return active_states_instance().is_active(tag);
}

//-----------------------------------------------------------------------------
// State effect application
//-----------------------------------------------------------------------------
void applyStateEffectsToEntity(entt::registry &registry, entt::entity entity)
{
    if (!registry.valid(entity)) return;

    bool active = false;
    if (registry.all_of<StateTag>(entity)) {
        auto &tag = registry.get<StateTag>(entity);
        active = is_active(tag);
    }

    if (registry.all_of<transform::Transform>(entity)) {
        auto &transform = registry.get<transform::Transform>(entity);
        
        if (!active) {
            registry.emplace_or_replace<InactiveTag>(entity);
        } else {
            if (registry.any_of<InactiveTag>(entity))
                registry.remove<InactiveTag>(entity);
        }

        // for (Spring* s : { &transform.getXSpring(), &transform.getYSpring(), &transform.getWSpring(),
        //                    &transform.getHSpring(), &transform.getRSpring(), &transform.getSSpring() })
        // {
        //     s->enabled = active;
        //     if (!active)
        //         s->velocity = 0.0f;
        // }
        
        // for (auto sEntity : { transform.x, transform.y, transform.w,
        //                    transform.h, transform.r, transform.s })
        // {
        //     using namespace spring;
        //     if (!active) {
        //         registry.emplace_or_replace<SpringDisabledTag>(sEntity);
        //         // SPDLOG_DEBUG("Added spring disabled tag to entity {}", static_cast<int>(sEntity));
        //     }
        //     else if (active && registry.any_of<SpringDisabledTag>(sEntity)) {
        //         registry.remove<SpringDisabledTag>(sEntity);
        //         // SPDLOG_DEBUG("Removed spring disabled tag from entity {}", static_cast<int>(sEntity));
        //     }
            
        //     auto &s = registry.get<Spring>(sEntity);
            
        //     s.enabled = active;
        //     if (!active)
        //         s.velocity = 0.0f;
            
        //     // SPDLOG_INFO("Entity {} active={} hasSpringX={} vel={}",
        //     // (int)entity, active, registry.all_of<Spring>(transform.x),
        //     // registry.get<Spring>(transform.x).velocity);
        // }
    }

    // spring component in the entity itself?
    // if (registry.all_of<Spring>(entity)) {
    //     auto &spring = registry.get<Spring>(entity);
    //     spring.enabled = active;
    //     if (!active)
    //         spring.velocity = 0.0f;
    // }
    
    // does it have a UIBox component?
    // if (registry.all_of<ui::UIBoxComponent>(entity)) {
    //     ui::box::SetTransformSpringsEnabledInUIBox(registry, entity, active);
        
    // }
}

//-----------------------------------------------------------------------------
// Recursively applies state effects to a UI box and all sub-elements
//-----------------------------------------------------------------------------
void PropagateStateEffectsToUIBox(entt::registry &registry, entt::entity uiBox)
{
    if (!registry.valid(uiBox)) return;

    using namespace ui;
    using namespace transform;

    std::stack<entt::entity> stack;
    auto uiBoxComp = registry.try_get<UIBoxComponent>(uiBox);
    if (!uiBoxComp) return;
    entt::entity uiRoot = uiBoxComp->uiRoot.value_or(entt::null);
    if (!registry.valid(uiRoot)) return;
    stack.push(uiRoot);

    while (!stack.empty())
    {
        entt::entity e = stack.top();
        stack.pop();

        if (!registry.valid(e))
            continue;

        // Apply state effects to this entity
        applyStateEffectsToEntity(registry, e);

        // If it has a UIConfig with an attached object, propagate there too
        if (auto cfg = registry.try_get<UIConfig>(e))
        {
            if (cfg->object && registry.valid(*cfg->object))
                applyStateEffectsToEntity(registry, *cfg->object);
        }

        // Traverse children (reverse for stable visual order)
        if (auto node = registry.try_get<GameObject>(e))
        {
            for (auto it = node->orderedChildren.rbegin();
                 it != node->orderedChildren.rend();
                 ++it)
            {
                if (registry.valid(*it))
                    stack.push(*it);
            }
        }
    }
}


//-----------------------------------------------------------------------------
// Lua exposure
//-----------------------------------------------------------------------------
void exposeToLua(sol::state &lua) {
    auto &registry = globals::getRegistry();
    auto &active_states = active_states_instance();

    lua.set_function("add_state_tag", [&registry](entt::entity e, const std::string &name) {
        if (registry.all_of<StateTag>(e)) {
            registry.get<StateTag>(e).add_tag(name);
        } else {
            registry.emplace<StateTag>(e, name);
        }
        applyStateEffectsToEntity(registry, e);
    });

    lua.set_function("remove_state_tag", [&registry](entt::entity e, std::string name) {
        if (registry.any_of<StateTag>(e)) {
            auto &tag = registry.get<StateTag>(e);
            auto it = std::find(tag.names.begin(), tag.names.end(), name);
            if (it != tag.names.end()) {
                std::size_t h = std::hash<std::string>{}(*it);
                tag.names.erase(it);
                auto hashIt = std::find(tag.hashes.begin(), tag.hashes.end(), h);
                if (hashIt != tag.hashes.end())
                    tag.hashes.erase(hashIt);
            }
            applyStateEffectsToEntity(registry, e);
        }
    });
     

    lua.set_function("clear_state_tags", [&registry](entt::entity e) {
        if (registry.all_of<StateTag>(e)) {
            registry.get<StateTag>(e).clear();
        }
        applyStateEffectsToEntity(registry, e);
    });

    lua.new_usertype<ActiveStates>("ActiveStates",
        "activate", &ActiveStates::activate,
        "deactivate", &ActiveStates::deactivate,
        "clear", &ActiveStates::clear,
        "is_active", &ActiveStates::is_active
    );

    lua["active_states"] = &active_states;

    lua.set_function("activate_state",   &activate_state);
    lua.set_function("deactivate_state", &deactivate_state);
    lua.set_function("clear_states",     &clear_states);
    lua.set_function("is_state_active",  sol::overload(
        &is_state_active,
        &is_state_active_name
    ));
    lua.set_function("is_entity_active", [](entt::entity e) { return isEntityActive(e); });
    
    lua.set_function("hasAnyTag", sol::overload(
        &hasAnyTag,
        &hasAnyTagNames
    ));
    lua.set_function("hasAllTags", sol::overload(
        &hasAllTags,
        &hasAllTagNames
    ));

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
        applyStateEffectsToEntity(registry, e);
    });

    auto &rec = BindingRecorder::instance();
    
    
    lua.set_function("propagate_state_effects_to_ui_box", [&registry](entt::entity uiBox) {
        PropagateStateEffectsToUIBox(registry, uiBox);
    });
    
   
    
    rec.record_free_function({}, {
        "propagate_state_effects_to_ui_box",
        "---@param uiBox Entity               # The UI box entity whose elements should have state effects applied\n"
        "---@return nil\n"
        "Recursively applies state effects to the given UI box and all its sub-elements based on their StateTag components and the global active states.",
        "Recursively applies state effects to all elements in the specified UI box.", 
        true, false
    });

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

    rec.record_free_function({}, { "add_state_tag",
        "---@param entity Entity             # The entity to tag\n"
        "---@param name string               # The name of the state tag\n"
        "---@return nil",
        "Adds or replaces a StateTag component on the specified entity.", true, false
    });

    rec.record_free_function({}, { "remove_state_tag",
        "---@param entity Entity             # The entity from which to remove its state tag\n"
        "---@param name string               # The name of the state tag to remove\n"
        "---@return nil",
        "Removes a specific state tag from the StateTag component on the specified entity.", true, false
    });

    rec.record_free_function({}, { "clear_state_tags",
        "---@param entity Entity             # The entity whose state tags you want to clear\n"
        "---@return nil",
        "Clears any and all StateTag components from the specified entity.", true, false
    });

    rec.record_property("ActiveStates", {
        "---@class ActiveStates            # A global registry of named states you can turn on/off"
    });

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

} // namespace entity_gamestate_management
