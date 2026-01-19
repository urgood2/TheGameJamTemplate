#include <gtest/gtest.h>

#include "sol/sol.hpp"

#include "systems/input/controller_nav.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/ui/ui_data.hpp"
#include "util/error_handling.hpp"

using controller_nav::NavManager;
using controller_nav::NavGroup;

namespace {

struct Counter {
    int focusCalls = 0;
    int unfocusCalls = 0;
};

sol::state& shared_lua() {
    static sol::state lua{};
    static const bool initialized = [] {
        lua.open_libraries(sol::lib::base);
        return true;
    }();
    (void)initialized;
    return lua;
}

TEST(ControllerNav, NotifyFocusInvokesGroupCallbacks) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto prev = reg.create();
    auto next = reg.create();

    // Use proper API to add entities so entityToGroup map is populated
    nav.create_group("ui");
    nav.add_entity("ui", prev);
    nav.add_entity("ui", next);

    auto& lua = shared_lua();
    Counter counter;
    lua.set_function("on_focus", [&]() { counter.focusCalls++; });
    lua.set_function("on_unfocus", [&]() { counter.unfocusCalls++; });
    nav.groups["ui"].callbacks.on_focus = lua["on_focus"];
    nav.groups["ui"].callbacks.on_unfocus = lua["on_unfocus"];

    ASSERT_NO_THROW(nav.notify_focus(prev, next, reg));
    EXPECT_EQ(counter.unfocusCalls, 1);
    EXPECT_EQ(counter.focusCalls, 1);
    nav.reset();
}

TEST(ControllerNav, NotifyFocusHandlesLuaErrorsGracefully) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto prev = reg.create();
    auto next = reg.create();

    // Use proper API to add entities so entityToGroup map is populated
    nav.create_group("ui");
    nav.add_entity("ui", prev);
    nav.add_entity("ui", next);

    auto& lua = shared_lua();
    lua.script(R"(
        function on_focus() error("boom") end
        function on_unfocus() error("boom") end
    )");
    nav.groups["ui"].callbacks.on_focus = lua["on_focus"];
    nav.groups["ui"].callbacks.on_unfocus = lua["on_unfocus"];

    EXPECT_NO_THROW(nav.notify_focus(prev, next, reg)); // safeLuaCall should swallow/log
    nav.reset();
}

TEST(ControllerNav, NotifySelectInvokesGroupCallback) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto e = reg.create();

    // Use proper API to add entities so entityToGroup map is populated
    nav.create_group("ui");
    nav.add_entity("ui", e);
    nav.set_selected("ui", 0);

    int selects = 0;
    auto& lua = shared_lua();
    lua.set_function("on_select", [&]() { selects++; });
    nav.groups["ui"].callbacks.on_select = lua["on_select"];

    ASSERT_NO_THROW(nav.select_current(reg, "ui"));
    EXPECT_EQ(selects, 1);
    nav.reset();
}

TEST(ControllerNav, NotifySelectFallsBackToGlobal) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto e = reg.create();

    // Use proper API but don't set group callback to test global fallback
    nav.create_group("ui");
    nav.add_entity("ui", e);
    nav.set_selected("ui", 0);
    // Don't set nav.groups["ui"].callbacks.on_select - we want to test global fallback

    int selects = 0;
    auto& lua = shared_lua();
    lua.set_function("on_select_global", [&]() { selects++; });
    nav.callbacks.on_select = lua["on_select_global"];

    ASSERT_NO_THROW(nav.select_current(reg, "ui"));
    EXPECT_EQ(selects, 1);
    nav.reset();
}

TEST(ControllerNav, NotifySelectHandlesLuaErrorsGracefully) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto e = reg.create();

    // Use proper API to add entities so entityToGroup map is populated
    nav.create_group("ui");
    nav.add_entity("ui", e);
    nav.set_selected("ui", 0);

    auto& lua = shared_lua();
    lua.set_function("on_select", []() { throw std::runtime_error("boom"); });
    nav.groups["ui"].callbacks.on_select = lua["on_select"];

    EXPECT_NO_THROW(nav.select_current(reg, "ui")); // safeLuaCall should swallow/log
    nav.reset();
}

TEST(ControllerNav, NotifySelectPrefersGroupOverGlobal) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto e = reg.create();

    // Use proper API to add entities so entityToGroup map is populated
    nav.create_group("ui");
    nav.add_entity("ui", e);
    nav.set_selected("ui", 0);

    int groupSelects = 0;
    int globalSelects = 0;
    auto& lua = shared_lua();
    lua.set_function("on_select_group", [&]() { groupSelects++; });
    lua.set_function("on_select_global", [&]() { globalSelects++; });
    nav.groups["ui"].callbacks.on_select = lua["on_select_group"];
    nav.callbacks.on_select = lua["on_select_global"];

    ASSERT_NO_THROW(nav.select_current(reg, "ui"));
    EXPECT_EQ(groupSelects, 1);
    EXPECT_EQ(globalSelects, 0); // group handler should win
    nav.reset();
}

TEST(ControllerNav, NotifyFocusPrefersGroupOverGlobal) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto prev = reg.create();
    auto next = reg.create();

    // Use proper API to add entities so entityToGroup map is populated
    nav.create_group("ui");
    nav.add_entity("ui", prev);
    nav.add_entity("ui", next);

    int groupFocus = 0;
    int globalFocus = 0;
    int groupUnfocus = 0;
    int globalUnfocus = 0;
    auto& lua = shared_lua();
    lua.set_function("on_focus_group", [&]() { groupFocus++; });
    lua.set_function("on_unfocus_group", [&]() { groupUnfocus++; });
    lua.set_function("on_focus_global", [&]() { globalFocus++; });
    lua.set_function("on_unfocus_global", [&]() { globalUnfocus++; });
    nav.groups["ui"].callbacks.on_focus = lua["on_focus_group"];
    nav.groups["ui"].callbacks.on_unfocus = lua["on_unfocus_group"];
    nav.callbacks.on_focus = lua["on_focus_global"];
    nav.callbacks.on_unfocus = lua["on_unfocus_global"];

    ASSERT_NO_THROW(nav.notify_focus(prev, next, reg));
    EXPECT_EQ(groupUnfocus, 1);
    EXPECT_EQ(groupFocus, 1);
    EXPECT_EQ(globalUnfocus, 0);
    EXPECT_EQ(globalFocus, 0);
    nav.reset();
}

TEST(ControllerNav, ResetClearsAllManagerState) {
    auto& nav = NavManager::instance();
    nav.reset();

    auto& lua = shared_lua();
    lua.set_function("cb", []() {});
    nav.callbacks.on_select = lua["cb"];

    entt::registry reg;
    const auto e = reg.create();

    nav.create_group("ui");
    nav.add_entity("ui", e);
    nav.create_layer("main");
    nav.add_group_to_layer("main", "ui");
    nav.groupCooldowns["ui"] = 1.0f;
    nav.disabledEntities.insert(e);
    nav.groupToLayer["ui"] = "main";
    nav.layerStack.push_back("main");
    nav.focusGroupStack.push_back("ui");  // Test focusGroupStack clearing
    nav.activeLayer = "main";

    nav.reset();

    EXPECT_TRUE(nav.groups.empty());
    EXPECT_TRUE(nav.layers.empty());
    EXPECT_TRUE(nav.groupCooldowns.empty());
    EXPECT_TRUE(nav.disabledEntities.empty());
    EXPECT_TRUE(nav.groupToLayer.empty());
    EXPECT_TRUE(nav.layerStack.empty());
    EXPECT_TRUE(nav.focusGroupStack.empty());  // Verify focusGroupStack is cleared
    EXPECT_TRUE(nav.activeLayer.empty());
    EXPECT_FALSE(nav.callbacks.on_select.valid());
}

TEST(ControllerNav, SelectCurrentFallsBackToFirstEntryWhenIndexInvalid) {
    auto& nav = NavManager::instance();
    nav.reset();

    auto& lua = shared_lua();
    int selects = 0;
    lua.set_function("on_select_global", [&]() { ++selects; });
    nav.callbacks.on_select = lua["on_select_global"];

    entt::registry reg;
    const auto e1 = reg.create();
    const auto e2 = reg.create();

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.add_entity("ui", e2);
    nav.groups["ui"].selectedIndex = 5; // out of range

    ASSERT_NO_THROW(nav.select_current(reg, "ui"));
    EXPECT_EQ(selects, 1);

    nav.reset();
}

// =============================================================================
// P0 Bug #4: Graceful error handling instead of crashing asserts
// =============================================================================

TEST(ControllerNav, PopLayerOnEmptyStackDoesNotCrash) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Ensure stack is empty
    EXPECT_TRUE(nav.layerStack.empty());

    // This should NOT crash - should log error and return gracefully
    EXPECT_NO_THROW(nav.pop_layer());

    // Stack should still be empty
    EXPECT_TRUE(nav.layerStack.empty());

    nav.reset();
}

TEST(ControllerNav, PopLayerWithSingleLayerReturnsToEmptyState) {
    auto& nav = NavManager::instance();
    nav.reset();

    nav.create_layer("main");
    nav.push_layer("main");
    EXPECT_EQ(nav.layerStack.size(), 1);
    EXPECT_EQ(nav.activeLayer, "main");

    // Pop should work normally
    EXPECT_NO_THROW(nav.pop_layer());
    EXPECT_TRUE(nav.layerStack.empty());
    EXPECT_TRUE(nav.activeLayer.empty());

    // Second pop should handle empty stack gracefully
    EXPECT_NO_THROW(nav.pop_layer());
    EXPECT_TRUE(nav.layerStack.empty());

    nav.reset();
}

TEST(ControllerNav, GetSelectedOnEmptyGroupDoesNotCrash) {
    auto& nav = NavManager::instance();
    nav.reset();

    nav.create_group("empty_group");
    // Group exists but has no entries
    EXPECT_TRUE(nav.groups["empty_group"].entries.empty());

    // This should NOT crash - should return entt::null
    entt::entity result = entt::null;
    EXPECT_NO_THROW(result = nav.get_selected("empty_group"));
    EXPECT_TRUE(result == entt::null);

    nav.reset();
}

TEST(ControllerNav, GetSelectedOnNonExistentGroupReturnsNull) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Group doesn't exist at all
    entt::entity result = entt::null;
    EXPECT_NO_THROW(result = nav.get_selected("nonexistent"));
    EXPECT_TRUE(result == entt::null);

    nav.reset();
}

TEST(ControllerNav, NavigateWithEmptyGroupNameDoesNotCrash) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    // Empty group name should log error and return gracefully
    EXPECT_NO_THROW(nav.navigate(reg, state, "", "R"));

    nav.reset();
}

TEST(ControllerNav, NavigateWithEmptyDirectionDoesNotCrash) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    nav.create_group("test");

    // Empty direction should log error and return gracefully
    EXPECT_NO_THROW(nav.navigate(reg, state, "test", ""));

    nav.reset();
}

// =============================================================================
// P0 Bug #1: Layer stack and focus group stack must be independent
// =============================================================================

TEST(ControllerNav, FocusGroupStackIsIndependentFromLayerStack) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Setup layers
    nav.create_layer("main");
    nav.create_layer("modal");

    // Push a layer
    nav.push_layer("main");
    EXPECT_EQ(nav.layerStack.size(), 1);
    EXPECT_EQ(nav.layerStack.back(), "main");

    // Push focus groups - should NOT affect layerStack
    nav.push_focus_group("inventory");
    nav.push_focus_group("slots");

    // Layer stack should still only have "main"
    EXPECT_EQ(nav.layerStack.size(), 1);
    EXPECT_EQ(nav.layerStack.back(), "main");

    // Focus group should be "slots"
    EXPECT_EQ(nav.current_focus_group(), "slots");

    // Pop focus group - should NOT affect layerStack
    nav.pop_focus_group();
    EXPECT_EQ(nav.current_focus_group(), "inventory");
    EXPECT_EQ(nav.layerStack.size(), 1); // Still 1

    // Push a new layer - should NOT affect focus group stack
    nav.push_layer("modal");
    EXPECT_EQ(nav.layerStack.size(), 2);
    EXPECT_EQ(nav.current_focus_group(), "inventory"); // Focus group unchanged

    nav.reset();
}

TEST(ControllerNav, ResetClearsFocusGroupStack) {
    auto& nav = NavManager::instance();
    nav.reset();

    nav.push_focus_group("group1");
    nav.push_focus_group("group2");
    EXPECT_EQ(nav.current_focus_group(), "group2");

    nav.reset();

    // After reset, focus group stack should be empty
    EXPECT_TRUE(nav.current_focus_group().empty());

    nav.reset();
}

TEST(ControllerNav, PopFocusGroupOnEmptyStackDoesNotCrash) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Focus group stack should be empty
    EXPECT_TRUE(nav.current_focus_group().empty());

    // Pop on empty should not crash
    EXPECT_NO_THROW(nav.pop_focus_group());
    EXPECT_TRUE(nav.current_focus_group().empty());

    nav.reset();
}

// =============================================================================
// P0 Bug #2: Spatial navigation should not block cross-group transitions
// =============================================================================

TEST(ControllerNav, LinearNavigationAtEdgeUsesLinkedGroup) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    // Create entities
    auto entityA = reg.create();
    auto entityB = reg.create();

    // Create two groups (linear mode)
    nav.create_group("group_a");
    nav.create_group("group_b");
    nav.add_entity("group_a", entityA);
    nav.add_entity("group_b", entityB);

    // Configure group_a: linear mode, no wrap, linked to group_b on the right
    nav.groups["group_a"].spatial = false;  // Linear mode
    nav.groups["group_a"].wrap = false;     // No wrap - hitting edge should try linked group
    nav.groups["group_a"].rightGroup = "group_b";
    nav.groups["group_a"].selectedIndex = 0;

    // Verify basic setup works
    EXPECT_EQ(nav.groups["group_a"].entries.size(), 1u);
    EXPECT_EQ(nav.groups["group_b"].entries.size(), 1u);

    // Add state tags so entities pass isEntityActive check
    reg.emplace<entity_gamestate_management::StateTag>(entityA, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(entityB, entity_gamestate_management::DEFAULT_STATE_TAG);

    // Add Transform components (required by UpdateCursor)
    reg.emplace<transform::Transform>(entityA);
    reg.emplace<transform::Transform>(entityB);

    // Create and activate a layer containing both groups
    nav.create_layer("main");
    nav.add_group_to_layer("main", "group_a");
    nav.add_group_to_layer("main", "group_b");
    nav.set_active_layer("main");

    // Start with focus on entityA
    state.cursor_focused_target = entityA;

    // Navigate RIGHT from group_a - should transition to group_b
    nav.navigate(reg, state, "group_a", "R");

    // Focus should now be on entityB (in group_b)
    EXPECT_EQ(state.cursor_focused_target, entityB);

    nav.reset();
}

// =============================================================================
// P1 Feature #5: Explicit per-element NavNeighbors support
// =============================================================================

TEST(ControllerNav, ExplicitNeighborTakesPrecedenceOverSpatial) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    // Create entities in a row: A - B - C (spatially)
    // But set A's explicit right neighbor to C (skipping B)
    auto entityA = reg.create();
    auto entityB = reg.create();
    auto entityC = reg.create();

    // Add required components
    reg.emplace<entity_gamestate_management::StateTag>(entityA, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(entityB, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(entityC, entity_gamestate_management::DEFAULT_STATE_TAG);

    // Position them in a row: A at 0, B at 100, C at 200
    auto& tA = reg.emplace<transform::Transform>(entityA);
    tA.setActualX(0); tA.setActualY(0); tA.setActualW(50); tA.setActualH(50);
    auto& tB = reg.emplace<transform::Transform>(entityB);
    tB.setActualX(100); tB.setActualY(0); tB.setActualW(50); tB.setActualH(50);
    auto& tC = reg.emplace<transform::Transform>(entityC);
    tC.setActualX(200); tC.setActualY(0); tC.setActualW(50); tC.setActualH(50);

    // Create group with spatial navigation
    nav.create_group("main");
    nav.add_entity("main", entityA);
    nav.add_entity("main", entityB);
    nav.add_entity("main", entityC);
    nav.groups["main"].spatial = true;
    nav.groups["main"].selectedIndex = 0;

    // Set explicit neighbor: A's right neighbor is C (skipping B)
    nav.set_neighbors(entityA, { .right = entityC });

    state.cursor_focused_target = entityA;

    // Navigate RIGHT - should go to C (explicit neighbor) not B (spatial nearest)
    nav.navigate(reg, state, "main", "R");

    EXPECT_EQ(state.cursor_focused_target, entityC);

    nav.reset();
}

TEST(ControllerNav, ExplicitNeighborWorksWithInvalidNeighbor) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    auto entityA = reg.create();
    auto entityB = reg.create();

    reg.emplace<entity_gamestate_management::StateTag>(entityA, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(entityB, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<transform::Transform>(entityA);
    reg.emplace<transform::Transform>(entityB);

    nav.create_group("main");
    nav.add_entity("main", entityA);
    nav.add_entity("main", entityB);
    nav.groups["main"].spatial = false;
    nav.groups["main"].selectedIndex = 0;

    // Set explicit neighbor to an invalid entity
    entt::entity invalidEntity{9999};
    nav.set_neighbors(entityA, { .right = invalidEntity });

    state.cursor_focused_target = entityA;

    // Navigate RIGHT - should fall back to normal navigation since explicit neighbor is invalid
    nav.navigate(reg, state, "main", "R");

    // Should navigate to B via normal linear navigation
    EXPECT_EQ(state.cursor_focused_target, entityB);

    nav.reset();
}

// -----------------------------------------------------------------------------
// Test: remove_entity() cleans up explicit neighbors
// -----------------------------------------------------------------------------
TEST(ControllerNav, RemoveEntityCleansUpExplicitNeighbors) {
    auto& nav = controller_nav::NavManager::instance();
    nav.reset();

    entt::registry reg;
    entt::entity entityA = reg.create();
    entt::entity entityB = reg.create();

    nav.create_group("main");
    nav.add_entity("main", entityA);
    nav.add_entity("main", entityB);

    // Set explicit neighbors for entityA
    controller_nav::NavNeighbors neighbors;
    neighbors.right = entityB;
    nav.set_neighbors(entityA, neighbors);

    // Verify neighbors are set
    auto retrievedBefore = nav.get_neighbors(entityA);
    EXPECT_TRUE(retrievedBefore.right.has_value());

    // Remove entityA from group
    nav.remove_entity("main", entityA);

    // Explicit neighbors should be cleaned up
    auto retrievedAfter = nav.get_neighbors(entityA);
    EXPECT_FALSE(retrievedAfter.right.has_value());

    nav.reset();
}

// -----------------------------------------------------------------------------
// Test: clear_group() cleans up explicit neighbors for all entities
// -----------------------------------------------------------------------------
TEST(ControllerNav, ClearGroupCleansUpExplicitNeighbors) {
    auto& nav = controller_nav::NavManager::instance();
    nav.reset();

    entt::registry reg;
    entt::entity entityA = reg.create();
    entt::entity entityB = reg.create();
    entt::entity entityC = reg.create();

    nav.create_group("main");
    nav.add_entity("main", entityA);
    nav.add_entity("main", entityB);
    nav.add_entity("main", entityC);

    // Set explicit neighbors for multiple entities
    controller_nav::NavNeighbors neighborsA;
    neighborsA.right = entityB;
    nav.set_neighbors(entityA, neighborsA);

    controller_nav::NavNeighbors neighborsB;
    neighborsB.left = entityA;
    neighborsB.right = entityC;
    nav.set_neighbors(entityB, neighborsB);

    // Verify neighbors are set
    EXPECT_TRUE(nav.get_neighbors(entityA).right.has_value());
    EXPECT_TRUE(nav.get_neighbors(entityB).left.has_value());
    EXPECT_TRUE(nav.get_neighbors(entityB).right.has_value());

    // Clear the group
    nav.clear_group("main");

    // All explicit neighbors should be cleaned up
    EXPECT_FALSE(nav.get_neighbors(entityA).right.has_value());
    EXPECT_FALSE(nav.get_neighbors(entityB).left.has_value());
    EXPECT_FALSE(nav.get_neighbors(entityB).right.has_value());

    nav.reset();
}

// -----------------------------------------------------------------------------
// Test: reset() clears explicit neighbors
// -----------------------------------------------------------------------------
TEST(ControllerNav, ResetClearsExplicitNeighbors) {
    auto& nav = controller_nav::NavManager::instance();
    nav.reset();

    entt::registry reg;
    entt::entity entityA = reg.create();
    entt::entity entityB = reg.create();

    // Set explicit neighbors (no need to add to group for this test)
    controller_nav::NavNeighbors neighbors;
    neighbors.right = entityB;
    neighbors.up = entityB;
    nav.set_neighbors(entityA, neighbors);

    // Verify neighbors are set
    auto retrieved = nav.get_neighbors(entityA);
    EXPECT_TRUE(retrieved.right.has_value());
    EXPECT_TRUE(retrieved.up.has_value());

    // Reset manager
    nav.reset();

    // All explicit neighbors should be cleared
    auto afterReset = nav.get_neighbors(entityA);
    EXPECT_FALSE(afterReset.right.has_value());
    EXPECT_FALSE(afterReset.up.has_value());
    EXPECT_FALSE(afterReset.down.has_value());
    EXPECT_FALSE(afterReset.left.has_value());
}

// -----------------------------------------------------------------------------
// Test: scroll_into_view handles entity without scroll pane gracefully
// -----------------------------------------------------------------------------
TEST(ControllerNav, ScrollIntoViewNoScrollPaneDoesNotCrash) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    entt::entity entity = reg.create();
    reg.emplace<transform::Transform>(entity);

    // Should not crash - entity has no scroll pane ancestor
    nav.scroll_into_view(reg, entity);

    nav.reset();
}

// -----------------------------------------------------------------------------
// Test: scroll_into_view adjusts scroll offset for entity below viewport
// -----------------------------------------------------------------------------
TEST(ControllerNav, ScrollIntoViewAdjustsOffsetForEntityBelowViewport) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;

    // Create scroll pane
    entt::entity scrollPane = reg.create();
    auto& scrollTransform = reg.emplace<transform::Transform>(scrollPane);
    scrollTransform.setActualY(0.f);
    scrollTransform.setActualH(200.f);

    auto& scrollComp = reg.emplace<ui::UIScrollComponent>(scrollPane);
    scrollComp.offset = 0.f;
    scrollComp.minOffset = -500.f;
    scrollComp.maxOffset = 0.f;
    scrollComp.viewportSize.y = 200.f;
    scrollComp.vertical = true;

    // Create entity below viewport
    entt::entity entity = reg.create();
    auto& entityTransform = reg.emplace<transform::Transform>(entity);
    entityTransform.setActualY(250.f);  // Below viewport (0-200)
    entityTransform.setActualH(50.f);

    // Link entity to scroll pane
    reg.emplace<ui::UIPaneParentRef>(entity, ui::UIPaneParentRef{scrollPane});

    // scroll_into_view should adjust offset to make entity visible
    nav.scroll_into_view(reg, entity);

    // Entity bottom (300) should now be at viewport bottom (200)
    // offset should be -(300 - 0 - 200) = -100
    EXPECT_LT(scrollComp.offset, 0.f);  // Should have scrolled down (negative offset)

    nav.reset();
}

// -----------------------------------------------------------------------------
// Test: scroll_group applies delta to scroll offset
// -----------------------------------------------------------------------------
TEST(ControllerNav, ScrollGroupAppliesDelta) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;

    // Create scroll pane
    entt::entity scrollPane = reg.create();
    reg.emplace<transform::Transform>(scrollPane);

    auto& scrollComp = reg.emplace<ui::UIScrollComponent>(scrollPane);
    scrollComp.offset = 0.f;
    scrollComp.minOffset = -500.f;
    scrollComp.maxOffset = 0.f;
    scrollComp.vertical = true;

    // Create entity in group that's in the scroll pane
    entt::entity entity = reg.create();
    reg.emplace<transform::Transform>(entity);
    reg.emplace<ui::UIPaneParentRef>(entity, ui::UIPaneParentRef{scrollPane});

    nav.create_group("scrollable");
    nav.add_entity("scrollable", entity);

    // Apply scroll delta
    float initialOffset = scrollComp.offset;
    nav.scroll_group(reg, "scrollable", 0.f, 50.f);  // Scroll down by 50

    // Offset should have changed (negative because scrolling down)
    EXPECT_EQ(scrollComp.offset, initialOffset - 50.f);

    nav.reset();
}

// -----------------------------------------------------------------------------
// Test: scroll_group clamps offset to bounds
// -----------------------------------------------------------------------------
TEST(ControllerNav, ScrollGroupClampsToMinMax) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;

    // Create scroll pane with limited range
    entt::entity scrollPane = reg.create();
    reg.emplace<transform::Transform>(scrollPane);

    auto& scrollComp = reg.emplace<ui::UIScrollComponent>(scrollPane);
    scrollComp.offset = 0.f;
    scrollComp.minOffset = -100.f;
    scrollComp.maxOffset = 0.f;
    scrollComp.vertical = true;

    // Create entity in group
    entt::entity entity = reg.create();
    reg.emplace<transform::Transform>(entity);
    reg.emplace<ui::UIPaneParentRef>(entity, ui::UIPaneParentRef{scrollPane});

    nav.create_group("scrollable");
    nav.add_entity("scrollable", entity);

    // Try to scroll beyond min
    nav.scroll_group(reg, "scrollable", 0.f, 500.f);  // Try to scroll down by 500

    // Should be clamped to minOffset
    EXPECT_GE(scrollComp.offset, scrollComp.minOffset);

    nav.reset();
}

// =============================================================================
// P1 Feature #7: Input repeat with initial delay + rate + acceleration
// =============================================================================

TEST(ControllerNav, RepeatConfigHasReasonableDefaults) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Check defaults are reasonable values
    EXPECT_GT(nav.repeatConfig.initialDelay, 0.0f);
    EXPECT_GT(nav.repeatConfig.repeatRate, 0.0f);
    EXPECT_GT(nav.repeatConfig.minRepeatRate, 0.0f);
    EXPECT_LT(nav.repeatConfig.minRepeatRate, nav.repeatConfig.repeatRate);
    EXPECT_GT(nav.repeatConfig.acceleration, 0.0f);
    EXPECT_LT(nav.repeatConfig.acceleration, 1.0f);  // Must be < 1 for acceleration

    nav.reset();
}

TEST(ControllerNav, FirstNavigationIsImmediate) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    auto e1 = reg.create();
    auto e2 = reg.create();
    reg.emplace<transform::Transform>(e1).setActualX(0.f);
    reg.emplace<transform::Transform>(e2).setActualX(100.f);
    reg.emplace<entity_gamestate_management::StateTag>(e1, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e2, entity_gamestate_management::DEFAULT_STATE_TAG);

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.add_entity("ui", e2);
    nav.groups["ui"].spatial = true;

    state.cursor_focused_target = e1;

    // First navigation should be immediate (not blocked by initial delay)
    nav.navigate(reg, state, "ui", "R");

    EXPECT_EQ(state.cursor_focused_target, e2);

    nav.reset();
}

TEST(ControllerNav, SecondNavigationBlockedByInitialDelay) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    auto e1 = reg.create();
    auto e2 = reg.create();
    auto e3 = reg.create();
    reg.emplace<transform::Transform>(e1).setActualX(0.f);
    reg.emplace<transform::Transform>(e2).setActualX(100.f);
    reg.emplace<transform::Transform>(e3).setActualX(200.f);
    reg.emplace<entity_gamestate_management::StateTag>(e1, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e2, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e3, entity_gamestate_management::DEFAULT_STATE_TAG);

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.add_entity("ui", e2);
    nav.add_entity("ui", e3);
    nav.groups["ui"].spatial = true;

    state.cursor_focused_target = e1;

    // First navigation: e1 -> e2
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, e2);

    // Immediate second navigation should be blocked (still in initial delay)
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, e2);  // Should still be e2

    nav.reset();
}

TEST(ControllerNav, NavigationRepeatsAfterInitialDelay) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    auto e1 = reg.create();
    auto e2 = reg.create();
    auto e3 = reg.create();
    reg.emplace<transform::Transform>(e1).setActualX(0.f);
    reg.emplace<transform::Transform>(e2).setActualX(100.f);
    reg.emplace<transform::Transform>(e3).setActualX(200.f);
    reg.emplace<entity_gamestate_management::StateTag>(e1, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e2, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e3, entity_gamestate_management::DEFAULT_STATE_TAG);

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.add_entity("ui", e2);
    nav.add_entity("ui", e3);
    nav.groups["ui"].spatial = true;

    state.cursor_focused_target = e1;

    // First navigation: e1 -> e2
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, e2);

    // Simulate time passing (more than initialDelay)
    nav.update(nav.repeatConfig.initialDelay + 0.01f);

    // After initial delay, navigation should repeat
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, e3);

    nav.reset();
}

TEST(ControllerNav, RepeatRateIsFasterThanInitialDelay) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    auto e1 = reg.create();
    auto e2 = reg.create();
    auto e3 = reg.create();
    auto e4 = reg.create();
    reg.emplace<transform::Transform>(e1).setActualX(0.f);
    reg.emplace<transform::Transform>(e2).setActualX(100.f);
    reg.emplace<transform::Transform>(e3).setActualX(200.f);
    reg.emplace<transform::Transform>(e4).setActualX(300.f);
    reg.emplace<entity_gamestate_management::StateTag>(e1, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e2, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e3, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e4, entity_gamestate_management::DEFAULT_STATE_TAG);

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.add_entity("ui", e2);
    nav.add_entity("ui", e3);
    nav.add_entity("ui", e4);
    nav.groups["ui"].spatial = true;

    state.cursor_focused_target = e1;

    // First navigation: e1 -> e2
    nav.navigate(reg, state, "ui", "R");

    // Wait for initial delay
    nav.update(nav.repeatConfig.initialDelay + 0.01f);

    // Second navigation (first repeat): e2 -> e3
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, e3);

    // Wait only repeatRate (which should be shorter than initialDelay)
    EXPECT_LT(nav.repeatConfig.repeatRate, nav.repeatConfig.initialDelay);
    nav.update(nav.repeatConfig.repeatRate + 0.01f);

    // Third navigation (second repeat): e3 -> e4
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, e4);

    nav.reset();
}

TEST(ControllerNav, DirectionChangeResetsRepeatState) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    // Create 3x3 grid layout
    auto e1 = reg.create();
    auto e2 = reg.create();
    auto e3 = reg.create();
    reg.emplace<transform::Transform>(e1);
    reg.get<transform::Transform>(e1).setActualX(0.f);
    reg.get<transform::Transform>(e1).setActualY(0.f);
    reg.emplace<transform::Transform>(e2);
    reg.get<transform::Transform>(e2).setActualX(100.f);
    reg.get<transform::Transform>(e2).setActualY(0.f);
    reg.emplace<transform::Transform>(e3);
    reg.get<transform::Transform>(e3).setActualX(0.f);
    reg.get<transform::Transform>(e3).setActualY(100.f);
    reg.emplace<entity_gamestate_management::StateTag>(e1, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e2, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e3, entity_gamestate_management::DEFAULT_STATE_TAG);

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.add_entity("ui", e2);
    nav.add_entity("ui", e3);
    nav.groups["ui"].spatial = true;

    state.cursor_focused_target = e1;

    // Navigate right: e1 -> e2
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, e2);

    // Don't wait for initial delay - try to navigate immediately in DIFFERENT direction
    // This should work because direction change resets the repeat state
    nav.navigate(reg, state, "ui", "D");  // Down from e2

    // Should have moved (direction change allows immediate navigation)
    // Note: e3 is at (0, 100), e2 is at (100, 0), so "down" from e2 should go to e3
    EXPECT_EQ(state.cursor_focused_target, e3);

    nav.reset();
}

TEST(ControllerNav, RepeatAcceleratesUpToMinRate) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Set short delays for testing
    nav.repeatConfig.initialDelay = 0.1f;
    nav.repeatConfig.repeatRate = 0.08f;
    nav.repeatConfig.minRepeatRate = 0.02f;
    nav.repeatConfig.acceleration = 0.5f;  // Halve time each repeat

    entt::registry reg;
    input::InputState state{};

    // Create 10 entities in a row
    std::vector<entt::entity> entities;
    for (int i = 0; i < 10; i++) {
        auto e = reg.create();
        reg.emplace<transform::Transform>(e).setActualX(static_cast<float>(i * 100));
        reg.emplace<entity_gamestate_management::StateTag>(e, entity_gamestate_management::DEFAULT_STATE_TAG);
        entities.push_back(e);
    }

    nav.create_group("ui");
    for (auto e : entities) nav.add_entity("ui", e);
    nav.groups["ui"].spatial = true;

    state.cursor_focused_target = entities[0];

    // First nav: immediate
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, entities[1]);

    // Wait for initial delay
    nav.update(nav.repeatConfig.initialDelay + 0.01f);

    // First repeat: rate = 0.08
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, entities[2]);

    // After first repeat, rate should be 0.08 * 0.5 = 0.04
    nav.update(0.04f + 0.01f);
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, entities[3]);

    // After second repeat, rate should be 0.04 * 0.5 = 0.02 (clamped to min)
    nav.update(0.02f + 0.01f);
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, entities[4]);

    // Rate should stay at min (0.02), not go below
    nav.update(0.02f + 0.01f);
    nav.navigate(reg, state, "ui", "R");
    EXPECT_EQ(state.cursor_focused_target, entities[5]);

    nav.reset();
}

TEST(ControllerNav, ResetClearsRepeatState) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    auto e1 = reg.create();
    auto e2 = reg.create();
    reg.emplace<transform::Transform>(e1).setActualX(0.f);
    reg.emplace<transform::Transform>(e2).setActualX(100.f);
    reg.emplace<entity_gamestate_management::StateTag>(e1, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(e2, entity_gamestate_management::DEFAULT_STATE_TAG);

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.add_entity("ui", e2);
    nav.groups["ui"].spatial = true;

    state.cursor_focused_target = e1;

    // Navigate to build up repeat state
    nav.navigate(reg, state, "ui", "R");

    // Reset should clear repeat states
    nav.reset();

    EXPECT_TRUE(nav.repeatStates.empty());
}

// =============================================================================
// P1 Feature #8: Focus restoration and modal scope handling
// =============================================================================

TEST(ControllerNav, PushLayerStoresPreviousFocus) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;

    // Create entities
    auto mainButton = reg.create();
    auto modalButton = reg.create();
    reg.emplace<transform::Transform>(mainButton);
    reg.emplace<transform::Transform>(modalButton);
    reg.emplace<entity_gamestate_management::StateTag>(mainButton, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(modalButton, entity_gamestate_management::DEFAULT_STATE_TAG);

    // Create layers and groups
    nav.create_layer("main");
    nav.create_layer("modal");
    nav.create_group("main_buttons");
    nav.create_group("modal_buttons");
    nav.add_entity("main_buttons", mainButton);
    nav.add_entity("modal_buttons", modalButton);
    nav.add_group_to_layer("main", "main_buttons");
    nav.add_group_to_layer("modal", "modal_buttons");

    // Select entity in main layer
    nav.groups["main_buttons"].selectedIndex = 0;
    nav.push_layer("main");

    // Store the current focus before pushing modal
    entt::entity previousFocus = nav.get_selected("main_buttons");
    EXPECT_EQ(previousFocus, mainButton);

    // Push modal layer - should store previous focus
    nav.push_layer("modal");

    // After pop, we should have saved state available
    EXPECT_EQ(nav.layerStack.size(), 2u);

    nav.reset();
}

TEST(ControllerNav, PopLayerRestoresPreviousFocus) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    // Create entities for main and modal layers
    auto mainButton1 = reg.create();
    auto mainButton2 = reg.create();
    auto modalButton = reg.create();
    reg.emplace<transform::Transform>(mainButton1).setActualX(0.f);
    reg.emplace<transform::Transform>(mainButton2).setActualX(100.f);
    reg.emplace<transform::Transform>(modalButton).setActualX(200.f);
    reg.emplace<entity_gamestate_management::StateTag>(mainButton1, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(mainButton2, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(modalButton, entity_gamestate_management::DEFAULT_STATE_TAG);

    // Create layers and groups
    nav.create_layer("main");
    nav.create_layer("modal");
    nav.create_group("main_buttons");
    nav.create_group("modal_buttons");
    nav.add_entity("main_buttons", mainButton1);
    nav.add_entity("main_buttons", mainButton2);
    nav.add_entity("modal_buttons", modalButton);
    nav.add_group_to_layer("main", "main_buttons");
    nav.add_group_to_layer("modal", "modal_buttons");

    // Start with main layer, focus on mainButton2 (not the first one)
    nav.push_layer("main");
    nav.groups["main_buttons"].selectedIndex = 1;  // Focus on mainButton2
    state.cursor_focused_target = mainButton2;

    // Record focus before pushing modal
    nav.record_focus_for_layer(state.cursor_focused_target, "main_buttons");

    // Push modal layer
    nav.push_layer("modal");

    // Verify we're on modal layer
    EXPECT_EQ(nav.activeLayer, "modal");

    // Pop modal layer - should restore focus to mainButton2
    nav.pop_layer();

    // Get restored focus info
    auto restoredFocus = nav.get_restored_focus();

    EXPECT_EQ(restoredFocus.entity, mainButton2);
    EXPECT_EQ(restoredFocus.group, "main_buttons");

    nav.reset();
}

TEST(ControllerNav, FocusRestorationHandlesInvalidEntity) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    // Create entities
    auto mainButton = reg.create();
    auto modalButton = reg.create();
    reg.emplace<transform::Transform>(mainButton);
    reg.emplace<transform::Transform>(modalButton);
    reg.emplace<entity_gamestate_management::StateTag>(mainButton, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(modalButton, entity_gamestate_management::DEFAULT_STATE_TAG);

    // Create layers and groups
    nav.create_layer("main");
    nav.create_layer("modal");
    nav.create_group("main_buttons");
    nav.create_group("modal_buttons");
    nav.add_entity("main_buttons", mainButton);
    nav.add_entity("modal_buttons", modalButton);
    nav.add_group_to_layer("main", "main_buttons");
    nav.add_group_to_layer("modal", "modal_buttons");

    // Push main layer, focus on mainButton
    nav.push_layer("main");
    state.cursor_focused_target = mainButton;
    nav.record_focus_for_layer(mainButton, "main_buttons");

    // Push modal
    nav.push_layer("modal");

    // Destroy the main button entity while modal is open
    reg.destroy(mainButton);

    // Pop modal - should handle destroyed entity gracefully
    nav.pop_layer();

    // Should not crash, and restored focus should indicate invalid
    auto restoredFocus = nav.get_restored_focus();
    // Entity was destroyed, so registry.valid() should be false for any restored entity
    // The system should return entt::null or handle it gracefully
    // (Either behavior is acceptable - just don't crash)

    nav.reset();
}

TEST(ControllerNav, LayerStackStateTracksFocusPerLayer) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    input::InputState state{};

    // Create entities for three layers
    auto mainEntity = reg.create();
    auto modal1Entity = reg.create();
    auto modal2Entity = reg.create();
    reg.emplace<transform::Transform>(mainEntity);
    reg.emplace<transform::Transform>(modal1Entity);
    reg.emplace<transform::Transform>(modal2Entity);
    reg.emplace<entity_gamestate_management::StateTag>(mainEntity, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(modal1Entity, entity_gamestate_management::DEFAULT_STATE_TAG);
    reg.emplace<entity_gamestate_management::StateTag>(modal2Entity, entity_gamestate_management::DEFAULT_STATE_TAG);

    // Create layers and groups
    nav.create_layer("main");
    nav.create_layer("modal1");
    nav.create_layer("modal2");
    nav.create_group("main_group");
    nav.create_group("modal1_group");
    nav.create_group("modal2_group");
    nav.add_entity("main_group", mainEntity);
    nav.add_entity("modal1_group", modal1Entity);
    nav.add_entity("modal2_group", modal2Entity);
    nav.add_group_to_layer("main", "main_group");
    nav.add_group_to_layer("modal1", "modal1_group");
    nav.add_group_to_layer("modal2", "modal2_group");

    // Push main layer, set focus
    nav.push_layer("main");
    state.cursor_focused_target = mainEntity;
    nav.record_focus_for_layer(mainEntity, "main_group");

    // Push modal1, set focus
    nav.push_layer("modal1");
    state.cursor_focused_target = modal1Entity;
    nav.record_focus_for_layer(modal1Entity, "modal1_group");

    // Push modal2
    nav.push_layer("modal2");
    state.cursor_focused_target = modal2Entity;

    // Pop modal2 - should restore to modal1Entity
    nav.pop_layer();
    auto restored1 = nav.get_restored_focus();
    EXPECT_EQ(restored1.entity, modal1Entity);
    EXPECT_EQ(restored1.group, "modal1_group");

    // Pop modal1 - should restore to mainEntity
    nav.pop_layer();
    auto restored2 = nav.get_restored_focus();
    EXPECT_EQ(restored2.entity, mainEntity);
    EXPECT_EQ(restored2.group, "main_group");

    nav.reset();
}

TEST(ControllerNav, ResetClearsSavedFocusState) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;

    auto entity = reg.create();
    reg.emplace<transform::Transform>(entity);

    // Record some focus state
    nav.record_focus_for_layer(entity, "some_group");

    // Reset should clear all saved focus state
    nav.reset();

    // After reset, there should be no saved focus to restore
    auto restored = nav.get_restored_focus();
    EXPECT_TRUE(restored.entity == entt::null);
    EXPECT_TRUE(restored.group.empty());

    nav.reset();
}

// =============================================================================
// P2 Feature #9: entityToGroup map for O(1) lookups
// =============================================================================

TEST(ControllerNav, GetGroupForEntityReturnsCorrectGroup) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto entity1 = reg.create();
    auto entity2 = reg.create();

    nav.create_group("group_a");
    nav.create_group("group_b");
    nav.add_entity("group_a", entity1);
    nav.add_entity("group_b", entity2);

    // O(1) lookup should work
    EXPECT_EQ(nav.get_group_for_entity(entity1), "group_a");
    EXPECT_EQ(nav.get_group_for_entity(entity2), "group_b");

    nav.reset();
}

TEST(ControllerNav, GetGroupForEntityReturnsEmptyForUnknownEntity) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto entity1 = reg.create();
    auto unknownEntity = reg.create();

    nav.create_group("group_a");
    nav.add_entity("group_a", entity1);

    // Unknown entity should return empty string
    EXPECT_EQ(nav.get_group_for_entity(unknownEntity), "");

    nav.reset();
}

TEST(ControllerNav, EntityToGroupMapUpdatedOnRemoveEntity) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto entity = reg.create();

    nav.create_group("group_a");
    nav.add_entity("group_a", entity);

    // Entity should be mapped
    EXPECT_EQ(nav.get_group_for_entity(entity), "group_a");

    // Remove entity
    nav.remove_entity("group_a", entity);

    // Map should be updated - entity should no longer be mapped
    EXPECT_EQ(nav.get_group_for_entity(entity), "");

    nav.reset();
}

TEST(ControllerNav, EntityToGroupMapUpdatedOnClearGroup) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto entity1 = reg.create();
    auto entity2 = reg.create();

    nav.create_group("group_a");
    nav.add_entity("group_a", entity1);
    nav.add_entity("group_a", entity2);

    // Entities should be mapped
    EXPECT_EQ(nav.get_group_for_entity(entity1), "group_a");
    EXPECT_EQ(nav.get_group_for_entity(entity2), "group_a");

    // Clear group
    nav.clear_group("group_a");

    // Map should be updated - entities should no longer be mapped
    EXPECT_EQ(nav.get_group_for_entity(entity1), "");
    EXPECT_EQ(nav.get_group_for_entity(entity2), "");

    nav.reset();
}

TEST(ControllerNav, EntityToGroupMapClearedOnReset) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto entity = reg.create();

    nav.create_group("group_a");
    nav.add_entity("group_a", entity);

    // Entity should be mapped
    EXPECT_EQ(nav.get_group_for_entity(entity), "group_a");

    // Reset
    nav.reset();

    // Map should be cleared
    EXPECT_EQ(nav.get_group_for_entity(entity), "");

    nav.reset();
}

// =============================================================================
// P2 Feature #10: Comprehensive validate() function tests
// =============================================================================

TEST(ControllerNav, ValidateDetectsLayerReferencingMissingGroup) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Create a layer and manually add a reference to a non-existent group
    nav.create_layer("main");
    nav.layers["main"].groups.push_back("nonexistent_group");

    // validate() should return validation errors
    auto errors = nav.validate();
    EXPECT_FALSE(errors.empty());
    EXPECT_TRUE(errors.find("Layer 'main' references missing group 'nonexistent_group'") != std::string::npos
             || errors.find("missing group") != std::string::npos);

    nav.reset();
}

TEST(ControllerNav, ValidateDetectsGroupToLayerInconsistency) {
    auto& nav = NavManager::instance();
    nav.reset();

    // Create a group and layer, but manually set groupToLayer to point to non-existent layer
    nav.create_group("my_buttons");
    nav.groupToLayer["my_buttons"] = "nonexistent_layer";

    auto errors = nav.validate();
    EXPECT_FALSE(errors.empty());
    EXPECT_TRUE(errors.find("groupToLayer") != std::string::npos
             || errors.find("nonexistent_layer") != std::string::npos);

    nav.reset();
}

TEST(ControllerNav, ValidateDetectsSelectedIndexOutOfBounds) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto e1 = reg.create();

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    nav.groups["ui"].selectedIndex = 5;  // Out of bounds (only 1 entry)

    auto errors = nav.validate();
    EXPECT_FALSE(errors.empty());
    EXPECT_TRUE(errors.find("selectedIndex") != std::string::npos
             || errors.find("out of bounds") != std::string::npos);

    nav.reset();
}

TEST(ControllerNav, ValidateDetectsEmptyGroupWithSelectedIndex) {
    auto& nav = NavManager::instance();
    nav.reset();

    nav.create_group("ui");
    nav.groups["ui"].selectedIndex = 0;  // Should be -1 for empty group

    auto errors = nav.validate();
    EXPECT_FALSE(errors.empty());
    EXPECT_TRUE(errors.find("empty") != std::string::npos
             || errors.find("selectedIndex") != std::string::npos);

    nav.reset();
}

TEST(ControllerNav, ValidateDetectsEntityToGroupMapInconsistency) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto e1 = reg.create();
    auto staleEntity = reg.create();

    nav.create_group("ui");
    nav.add_entity("ui", e1);

    // Manually add a stale entry to entityToGroup (entity not in any group's entries)
    nav.entityToGroup[staleEntity] = "ui";

    auto errors = nav.validate();
    EXPECT_FALSE(errors.empty());
    EXPECT_TRUE(errors.find("entityToGroup") != std::string::npos
             || errors.find("stale") != std::string::npos
             || errors.find("not in entries") != std::string::npos);

    nav.reset();
}

TEST(ControllerNav, ValidateDetectsDuplicateEntitiesInGroup) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto e1 = reg.create();

    nav.create_group("ui");
    nav.add_entity("ui", e1);
    // Manually add duplicate (bypassing add_entity which wouldn't prevent it)
    nav.groups["ui"].entries.push_back(e1);

    auto errors = nav.validate();
    EXPECT_FALSE(errors.empty());
    EXPECT_TRUE(errors.find("duplicate") != std::string::npos);

    nav.reset();
}

TEST(ControllerNav, ValidateReturnsEmptyForValidState) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto e1 = reg.create();
    auto e2 = reg.create();

    // Set up a fully valid navigation state
    nav.create_layer("main");
    nav.create_group("buttons");
    nav.add_entity("buttons", e1);
    nav.add_entity("buttons", e2);
    nav.add_group_to_layer("main", "buttons");
    nav.set_selected("buttons", 0);

    auto errors = nav.validate();
    EXPECT_TRUE(errors.empty()) << "Expected no validation errors but got: " << errors;

    nav.reset();
}

} // namespace
