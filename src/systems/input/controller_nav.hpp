#pragma once

// Notes: arbitrary controller navigation system for UI and other in-game
// elements. Supports spatial and linear navigation modes, multiple groups
// and layers, hierarchical navigation, and Lua callbacks for focus and select
// events.
// Note that this will smartly exclude entities that are not "active" in the
// current game state, via the entity_gamestate_management system.

#include "entt/entt.hpp"
#include "sol/sol.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/input/input_function_data.hpp"
#include "systems/transform/transform.hpp"

namespace controller_nav {

// -----------------------------------------------------------------------------
// Component: mark entity as controller-selectable (UI or non-UI)
// -----------------------------------------------------------------------------
struct NavSelectable {
    bool selected = false;
    bool disabled = false;
    std::string group;
    std::string subgroup;
};

// -----------------------------------------------------------------------------
// Lua callback set
// -----------------------------------------------------------------------------
struct NavCallbacks {
    sol::protected_function on_focus;
    sol::protected_function on_unfocus;
    sol::protected_function on_select;
};

// -----------------------------------------------------------------------------
// Group definition
// -----------------------------------------------------------------------------
struct NavGroup {
    std::string name;
    bool active = true;
    bool linear = true;
    std::vector<entt::entity> entries;
    int selectedIndex = -1;
    bool spatial = true;
    bool wrap = true;
    NavCallbacks callbacks;
    std::string parent;

    // hierarchy links
    std::string upGroup, downGroup, leftGroup, rightGroup;
    bool pushOnEnter = false;
    bool popOnExit = false;
};

// -----------------------------------------------------------------------------
// Layer definition
// -----------------------------------------------------------------------------
struct NavLayer {
    std::string name;
    std::vector<std::string> groups;
    bool active = false;
    int focusGroupIndex = 0;
};

// -----------------------------------------------------------------------------
// Manager singleton
// -----------------------------------------------------------------------------
struct NavManager {
    std::unordered_map<std::string, NavGroup> groups;
    std::unordered_map<std::string, NavLayer> layers;
    std::vector<std::string> layerStack;
    std::string activeLayer;
    std::unordered_set<entt::entity> disabledEntities; // dynamic disabling of specific entities
    std::unordered_map<std::string, std::string> groupToLayer;
    NavCallbacks callbacks;
    std::unordered_map<std::string, float> groupCooldowns;
    float globalCooldown = 0.15f;

    static NavManager& instance();

    // Core
    void update(float dt);
    void validate() const;

    // Groups
    void create_group(const std::string& name);
    void add_entity(const std::string& group, entt::entity e);
    void remove_entity(const std::string& group, entt::entity e);
    void clear_group(const std::string& group);
    void set_active(const std::string& group, bool active);
    void set_selected(const std::string& group, int index);
    entt::entity get_selected(const std::string& group);
    void set_entity_enabled(entt::entity e, bool enabled);
    bool is_entity_enabled(entt::entity e) const;


    // Navigation
    void navigate(entt::registry& reg, input::InputState& state, const std::string& group, std::string_view dir);
    void select_current(entt::registry& reg, const std::string& group);


    // Layers
    void create_layer(const std::string& name);
    void add_group_to_layer(const std::string& layer, const std::string& group);
    void set_active_layer(const std::string& name);
    void push_layer(const std::string& name);
    void pop_layer();

    // Stack & focus
    void push_focus_group(const std::string& group);
    void pop_focus_group();
    std::string current_focus_group() const;

    // Callbacks
    void notify_focus(entt::entity prev, entt::entity next, entt::registry& reg);
    void notify_select(entt::entity selected, entt::registry& reg);
    
    // debug
    void debug_print_state() const;
};

    extern void exposeToLua(sol::state& lua);

} // namespace controller_nav
