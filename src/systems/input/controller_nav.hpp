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
    sol::protected_function on_focus{};
    sol::protected_function on_unfocus{};
    sol::protected_function on_select{};
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
// Explicit neighbor overrides for per-element navigation
// -----------------------------------------------------------------------------
struct NavNeighbors {
    std::optional<entt::entity> up;
    std::optional<entt::entity> down;
    std::optional<entt::entity> left;
    std::optional<entt::entity> right;
};

// -----------------------------------------------------------------------------
// Input repeat configuration (for smooth held-direction navigation)
// -----------------------------------------------------------------------------
struct RepeatConfig {
    float initialDelay = 0.4f;      // Delay before first repeat (longer for first hold)
    float repeatRate = 0.08f;       // Time between repeats
    float minRepeatRate = 0.04f;    // Fastest repeat rate after acceleration
    float acceleration = 0.9f;      // Multiplier per repeat (< 1.0 = faster over time)
};

// -----------------------------------------------------------------------------
// Per-group repeat state tracking
// -----------------------------------------------------------------------------
struct RepeatState {
    std::string lastDirection;      // Last direction navigated
    float timeUntilRepeat = 0.0f;   // Time until next repeat is allowed
    int repeatCount = 0;            // Number of repeats in current sequence
    bool initialNavDone = false;    // Has the initial (non-repeat) navigation occurred?
};

// -----------------------------------------------------------------------------
// Focus restoration state (for modal scope handling)
// -----------------------------------------------------------------------------
struct SavedFocusState {
    entt::entity entity = entt::null;
    std::string group;
};

// -----------------------------------------------------------------------------
// Layer state (tracks focus per layer for restoration)
// -----------------------------------------------------------------------------
struct LayerFocusState {
    std::string layerName;
    entt::entity previousFocus = entt::null;
    std::string previousGroup;
};

// -----------------------------------------------------------------------------
// Manager singleton
// -----------------------------------------------------------------------------
struct NavManager {
    std::unordered_map<std::string, NavGroup> groups;
    std::unordered_map<std::string, NavLayer> layers;
    std::vector<std::string> layerStack;           // For layer push/pop (modal hierarchy)
    std::vector<std::string> focusGroupStack;      // For focus group push/pop (separate from layers)
    std::string activeLayer;
    std::unordered_set<entt::entity> disabledEntities; // dynamic disabling of specific entities
    std::unordered_map<std::string, std::string> groupToLayer;
    std::unordered_map<entt::entity, NavNeighbors> explicitNeighbors; // per-entity explicit neighbor overrides
    std::unordered_map<entt::entity, std::string> entityToGroup;      // O(1) lookup of entity's group
    NavCallbacks callbacks;
    std::unordered_map<std::string, float> groupCooldowns;
    float globalCooldown = 0.08f;
    RepeatConfig repeatConfig;                                  // Configuration for input repeat behavior
    std::unordered_map<std::string, RepeatState> repeatStates;  // Per-group repeat state tracking
    std::vector<LayerFocusState> layerFocusStack;               // Focus state per layer for restoration
    SavedFocusState lastRestoredFocus;                          // Last restored focus after pop_layer

    static NavManager& instance();

    // Core
    void update(float dt);
    std::string validate() const;  // Returns empty string if valid, error messages otherwise
    void reset();

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
    std::string get_group_for_entity(entt::entity e) const;

    // Explicit neighbors (per-element navigation overrides)
    void set_neighbors(entt::entity e, const NavNeighbors& neighbors);
    NavNeighbors get_neighbors(entt::entity e) const;
    void clear_neighbors(entt::entity e);


    // Navigation
    void navigate(entt::registry& reg, input::InputState& state, const std::string& group, std::string_view dir);
    void select_current(entt::registry& reg, const std::string& group);

    // Scroll support
    void scroll_into_view(entt::registry& reg, entt::entity e);
    void scroll_group(entt::registry& reg, const std::string& group, float deltaX, float deltaY);


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

    // Focus restoration (for modal scope handling)
    void record_focus_for_layer(entt::entity e, const std::string& group);
    SavedFocusState get_restored_focus() const;

    // Callbacks
    void notify_focus(entt::entity prev, entt::entity next, entt::registry& reg);
    void notify_select(entt::entity selected, entt::registry& reg);
    
    // debug
    void debug_print_state() const;
};

    extern void exposeToLua(sol::state& lua, EngineContext* ctx = globals::g_ctx);

} // namespace controller_nav
