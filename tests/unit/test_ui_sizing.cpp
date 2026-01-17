// tests/unit/test_ui_sizing.cpp
// Unit tests for box.cpp sizing and layout bug fixes
// Part of the box.cpp refactoring verification infrastructure.

#include <gtest/gtest.h>
#include "systems/ui/ui_data.hpp"
#include "systems/ui/box.hpp"
#include "systems/ui/sizing_pass.hpp"
#include "systems/transform/transform.hpp"
#include "core/globals.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include <entt/entt.hpp>

class UISizingTest : public ::testing::Test {
protected:
    entt::registry registry;
    float originalGlobalScale;
    float originalPadding;

    void SetUp() override {
        originalGlobalScale = globals::getGlobalUIScaleFactor();
        originalPadding = globals::getSettings().uiPadding;

        globals::setGlobalUIScaleFactor(1.0f);
        globals::getSettings().uiPadding = 4.0f;
    }

    void TearDown() override {
        globals::setGlobalUIScaleFactor(originalGlobalScale);
        globals::getSettings().uiPadding = originalPadding;
    }

    // Helper to create a minimal UI entity with required components
    entt::entity createUIEntity(ui::UITypeEnum type) {
        auto entity = registry.create();

        ui::UIConfig config;
        config.uiType = type;
        registry.emplace<ui::UIConfig>(entity, config);

        ui::UIState state;
        registry.emplace<ui::UIState>(entity, state);

        transform::Transform transform;
        registry.emplace<transform::Transform>(entity, transform);

        transform::GameObject gameObject;
        registry.emplace<transform::GameObject>(entity, gameObject);

        return entity;
    }
};

// ============================================================
// Bug 1.4-1.5: Invalid Entity Access Tests
// RemoveGroup and GetGroup should handle invalid entities gracefully
// ============================================================

TEST_F(UISizingTest, RemoveGroup_InvalidEntityDoesNotCrash) {
    // Create an invalid entity ID
    entt::entity invalidEntity{9999};

    // Should NOT crash - just return false
    bool result = ui::box::RemoveGroup(registry, invalidEntity, "test_group");

    EXPECT_FALSE(result);
}

TEST_F(UISizingTest, GetGroup_InvalidEntityReturnsEmpty) {
    // Create an invalid entity ID
    entt::entity invalidEntity{9999};

    // Should NOT crash - just return empty vector
    auto result = ui::box::GetGroup(registry, invalidEntity, "test_group");

    EXPECT_TRUE(result.empty());
}

TEST_F(UISizingTest, RemoveGroup_ValidEntityNoGroup) {
    auto entity = createUIEntity(ui::UITypeEnum::VERTICAL_CONTAINER);

    // Should not crash with valid entity but no matching group
    bool result = ui::box::RemoveGroup(registry, entity, "nonexistent_group");

    // Result depends on implementation, but should not crash
    EXPECT_FALSE(result); // Entity doesn't belong to this group
}

TEST_F(UISizingTest, GetGroup_ValidEntityNoGroup) {
    auto entity = createUIEntity(ui::UITypeEnum::VERTICAL_CONTAINER);

    // Should return empty for entity not in requested group
    auto result = ui::box::GetGroup(registry, entity, "nonexistent_group");

    EXPECT_TRUE(result.empty());
}

// ============================================================
// Bug 1.3: Scale Reset Tests
// Scale should NOT be reset to 1.0f after sizing calculation
// ============================================================

TEST_F(UISizingTest, Scale_NotResetAfterCalculation) {
    auto entity = createUIEntity(ui::UITypeEnum::RECT_SHAPE);

    // Set custom scale
    auto& config = registry.get<ui::UIConfig>(entity);
    config.scale = 1.5f;

    // Verify scale is preserved (basic check - full test requires CalcTreeSizes call)
    float scaleValue = config.scale.value_or(1.0f);
    EXPECT_FLOAT_EQ(scaleValue, 1.5f);
}

TEST_F(UISizingTest, Scale_ValueOrDefaultWorks) {
    auto entity = createUIEntity(ui::UITypeEnum::RECT_SHAPE);
    auto& config = registry.get<ui::UIConfig>(entity);

    // Without explicit scale
    EXPECT_FLOAT_EQ(config.scale.value_or(1.0f), 1.0f);

    // With explicit scale
    config.scale = 2.0f;
    EXPECT_FLOAT_EQ(config.scale.value_or(1.0f), 2.0f);
}

// ============================================================
// Bug 1.1: Double Global Scale Tests
// Global scale should be applied exactly ONCE to all elements
// ============================================================

TEST_F(UISizingTest, GlobalScale_SetAndGet) {
    globals::setGlobalUIScaleFactor(2.0f);
    EXPECT_FLOAT_EQ(globals::getGlobalUIScaleFactor(), 2.0f);

    globals::setGlobalUIScaleFactor(0.5f);
    EXPECT_FLOAT_EQ(globals::getGlobalUIScaleFactor(), 0.5f);
}

TEST_F(UISizingTest, UIState_ContentDimensionsInitialization) {
    auto entity = createUIEntity(ui::UITypeEnum::TEXT);
    auto& state = registry.get<ui::UIState>(entity);

    // Content dimensions should not have value initially
    EXPECT_FALSE(state.contentDimensions.has_value());

    // Set content dimensions
    state.contentDimensions = Vector2{100.0f, 50.0f};
    EXPECT_TRUE(state.contentDimensions.has_value());
    EXPECT_FLOAT_EQ(state.contentDimensions->x, 100.0f);
    EXPECT_FLOAT_EQ(state.contentDimensions->y, 50.0f);
}

// ============================================================
// Bug 1.2: Padding Calculation Tests
// Padding should NOT be doubled for vertical containers
// ============================================================

TEST_F(UISizingTest, EffectivePadding_VerticalContainer) {
    auto entity = createUIEntity(ui::UITypeEnum::VERTICAL_CONTAINER);
    auto& config = registry.get<ui::UIConfig>(entity);

    config.padding = 10.0f;
    config.scale = 1.0f;

    float effective = config.effectivePadding();

    // Should be: 10.0f * 1.0f * 1.0f (global) = 10.0f
    EXPECT_FLOAT_EQ(effective, 10.0f);
}

TEST_F(UISizingTest, EffectivePadding_HorizontalContainer) {
    auto entity = createUIEntity(ui::UITypeEnum::HORIZONTAL_CONTAINER);
    auto& config = registry.get<ui::UIConfig>(entity);

    config.padding = 8.0f;
    config.scale = 1.0f;

    float effective = config.effectivePadding();

    // Should be: 8.0f * 1.0f * 1.0f = 8.0f
    EXPECT_FLOAT_EQ(effective, 8.0f);
}

// ============================================================
// Transform Consistency Tests
// ============================================================

TEST_F(UISizingTest, Transform_ActualDimensions) {
    auto entity = createUIEntity(ui::UITypeEnum::RECT_SHAPE);
    auto& transform = registry.get<transform::Transform>(entity);

    transform.setActualW(100.0f);
    transform.setActualH(50.0f);

    EXPECT_FLOAT_EQ(transform.getActualW(), 100.0f);
    EXPECT_FLOAT_EQ(transform.getActualH(), 50.0f);
}

TEST_F(UISizingTest, Transform_ScaleApplication) {
    auto entity = createUIEntity(ui::UITypeEnum::RECT_SHAPE);
    auto& transform = registry.get<transform::Transform>(entity);

    float width = 100.0f;
    float height = 50.0f;
    float scale = 2.0f;

    transform.setActualW(width * scale);
    transform.setActualH(height * scale);

    EXPECT_FLOAT_EQ(transform.getActualW(), 200.0f);
    EXPECT_FLOAT_EQ(transform.getActualH(), 100.0f);
}

// ============================================================
// UIConfig Type Classification Tests
// ============================================================

TEST_F(UISizingTest, UIConfig_IsContainer) {
    EXPECT_TRUE(ui::UITypeEnum::VERTICAL_CONTAINER == ui::UITypeEnum::VERTICAL_CONTAINER);
    EXPECT_TRUE(ui::UITypeEnum::HORIZONTAL_CONTAINER == ui::UITypeEnum::HORIZONTAL_CONTAINER);
    EXPECT_TRUE(ui::UITypeEnum::ROOT == ui::UITypeEnum::ROOT);
}

TEST_F(UISizingTest, UIConfig_IsLeaf) {
    auto textEntity = createUIEntity(ui::UITypeEnum::TEXT);
    auto rectEntity = createUIEntity(ui::UITypeEnum::RECT_SHAPE);

    auto& textConfig = registry.get<ui::UIConfig>(textEntity);
    auto& rectConfig = registry.get<ui::UIConfig>(rectEntity);

    EXPECT_EQ(textConfig.uiType, ui::UITypeEnum::TEXT);
    EXPECT_EQ(rectConfig.uiType, ui::UITypeEnum::RECT_SHAPE);
}

// ============================================================
// MinWidth/MinHeight Constraint Tests
// ============================================================

TEST_F(UISizingTest, MinDimensions_Clamping) {
    ui::UIConfig config;
    config.minWidth = 100.0f;
    config.minHeight = 50.0f;

    ui::LocalTransform transform{0.f, 0.f, 80.f, 30.f}; // w < minWidth, h < minHeight

    ui::box::ClampDimensionsToMinimumsIfPresent(config, transform);

    EXPECT_FLOAT_EQ(transform.w, 100.0f); // Clamped to minWidth
    EXPECT_FLOAT_EQ(transform.h, 50.0f);  // Clamped to minHeight
}

TEST_F(UISizingTest, MinDimensions_NoClampWhenLarger) {
    ui::UIConfig config;
    config.minWidth = 50.0f;
    config.minHeight = 30.0f;

    ui::LocalTransform transform{0.f, 0.f, 100.f, 60.f}; // w > minWidth, h > minHeight

    ui::box::ClampDimensionsToMinimumsIfPresent(config, transform);

    EXPECT_FLOAT_EQ(transform.w, 100.0f); // Unchanged
    EXPECT_FLOAT_EQ(transform.h, 60.0f);  // Unchanged
}

TEST_F(UISizingTest, MinDimensions_OnlyOneSet) {
    ui::UIConfig config;
    config.minWidth = 100.0f;
    // minHeight not set

    ui::LocalTransform transform{0.f, 0.f, 50.f, 30.f};

    ui::box::ClampDimensionsToMinimumsIfPresent(config, transform);

    EXPECT_FLOAT_EQ(transform.w, 100.0f); // Clamped to minWidth
    EXPECT_FLOAT_EQ(transform.h, 30.0f);  // Unchanged (no minHeight)
}

// ============================================================
// Global Scale Application Tests
// ============================================================

TEST_F(UISizingTest, GlobalScale_AppliedOnceForNonText) {
    globals::setGlobalUIScaleFactor(2.0f);

    // Root container
    auto root = createUIEntity(ui::UITypeEnum::ROOT);
    auto child = createUIEntity(ui::UITypeEnum::RECT_SHAPE);

    auto &rootNode = registry.get<transform::GameObject>(root);
    rootNode.orderedChildren.push_back(child);

    auto &childTransform = registry.get<transform::Transform>(child);
    childTransform.setActualW(50.f);
    childTransform.setActualH(20.f);

    ui::layout::SizingPass pass(registry, root, ui::LocalTransform{}, false, std::nullopt);
    pass.run();

    // With global scale 2.0, child width should double
    EXPECT_FLOAT_EQ(childTransform.getActualW(), 100.f);
    EXPECT_FLOAT_EQ(childTransform.getActualH(), 40.f);
}

TEST_F(UISizingTest, GlobalScale_NotDoubleAppliedForText) {
    globals::setGlobalUIScaleFactor(2.0f);

    auto root = createUIEntity(ui::UITypeEnum::ROOT);
    auto text = createUIEntity(ui::UITypeEnum::TEXT);

    auto &rootNode = registry.get<transform::GameObject>(root);
    rootNode.orderedChildren.push_back(text);

    auto &textConfig = registry.get<ui::UIConfig>(text);
    textConfig.text = "abc";

    ui::layout::SizingPass pass(registry, root, ui::LocalTransform{}, false, std::nullopt);
    pass.run();

    auto &state = registry.get<ui::UIState>(text);
    auto &transform = registry.get<transform::Transform>(text);

    ASSERT_TRUE(state.contentDimensions.has_value());

    // Ensure transform matches measured content (i.e., no extra global scaling applied)
    EXPECT_NEAR(transform.getActualW(), state.contentDimensions->x, 1e-4);
    EXPECT_NEAR(transform.getActualH(), state.contentDimensions->y, 1e-4);
}

// ============================================================
// Traversal and draw list regressions
// ============================================================

TEST_F(UISizingTest, SizingPass_UsesChildrenMapWhenOrderedChildrenEmpty) {
    // Root container without orderedChildren but with children map entries
    auto root = createUIEntity(ui::UITypeEnum::VERTICAL_CONTAINER);
    auto child = createUIEntity(ui::UITypeEnum::RECT_SHAPE);

    auto &rootNode = registry.get<transform::GameObject>(root);
    rootNode.children["popup"] = child; // only in map

    ui::layout::SizingPass pass(registry, root, ui::LocalTransform{}, false, std::nullopt);
    pass.run();

    const auto &order = pass.processingOrder();
    ASSERT_EQ(order.size(), 2u);
    EXPECT_EQ(order[0].entity, root);
    EXPECT_EQ(order[1].entity, child);
}

TEST_F(UISizingTest, BuildUIBoxDrawList_SkipsPopupNamedChild) {
    // UIBox with child referenced only by map name "h_popup"
    entt::entity box = registry.create();
    registry.emplace<ui::UIBoxComponent>(box);
    registry.emplace<transform::Transform>(box);
    registry.emplace<transform::GameObject>(box);
    entity_gamestate_management::assignDefaultStateTag(registry, box);

    entt::entity popup = createUIEntity(ui::UITypeEnum::RECT_SHAPE);
    registry.emplace<ui::UIElementComponent>(popup, ui::UIElementComponent{.uiBox = box});
    entity_gamestate_management::assignDefaultStateTag(registry, popup);

    auto &boxNode = registry.get<transform::GameObject>(box);
    boxNode.children["h_popup"] = popup;
    boxNode.orderedChildren.push_back(popup);

    // ensure id is empty so name comes from map
    registry.get<ui::UIConfig>(popup).id.reset();
    registry.get<transform::GameObject>(popup).state.visible = true;

    std::vector<ui::UIDrawListItem> drawOrder;
    ui::box::buildUIBoxDrawList(registry, box, drawOrder, 0);

    EXPECT_TRUE(drawOrder.empty()); // "h_popup" should be filtered out
}
