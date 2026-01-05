// tests/unit/test_replace_children.cpp
// Unit tests for box::ReplaceChildren function

#include <gtest/gtest.h>
#include <entt/entt.hpp>
#include "systems/ui/ui_data.hpp"
#include "systems/transform/transform.hpp"

namespace ui::box {
    bool ReplaceChildren(
        entt::registry& registry,
        entt::entity parent,
        UIElementTemplateNode& newDefinition
    );
}

class ReplaceChildrenTest : public ::testing::Test {
protected:
    entt::registry registry;

    void SetUp() override {}
    void TearDown() override {}

    ui::UIElementTemplateNode createTextDef(const std::string& text) {
        ui::UIElementTemplateNode node;
        node.type = ui::UITypeEnum::TEXT;
        node.config.text = text;
        return node;
    }
};

TEST_F(ReplaceChildrenTest, ReturnsFalse_OnInvalidEntity) {
    auto newDef = createTextDef("Test");
    bool result = ui::box::ReplaceChildren(registry, entt::null, newDef);
    EXPECT_FALSE(result);
}

TEST_F(ReplaceChildrenTest, ReturnsFalse_OnDestroyedEntity) {
    auto entity = registry.create();
    registry.destroy(entity);

    auto newDef = createTextDef("Test");
    bool result = ui::box::ReplaceChildren(registry, entity, newDef);
    EXPECT_FALSE(result);
}

TEST_F(ReplaceChildrenTest, ReturnsFalse_OnEntityWithoutUIElementComponent) {
    auto entity = registry.create();
    registry.emplace<transform::Transform>(entity);

    auto newDef = createTextDef("Test");
    bool result = ui::box::ReplaceChildren(registry, entity, newDef);
    EXPECT_FALSE(result);
}

TEST_F(ReplaceChildrenTest, ReturnsFalse_OnEntityWithoutGameObject) {
    auto entity = registry.create();
    auto& uiElement = registry.emplace<ui::UIElementComponent>(entity);
    uiElement.uiBox = entity;

    auto newDef = createTextDef("Test");
    bool result = ui::box::ReplaceChildren(registry, entity, newDef);
    EXPECT_FALSE(result);
}

TEST_F(ReplaceChildrenTest, ReturnsFalse_OnInvalidUIBox) {
    auto entity = registry.create();
    auto& uiElement = registry.emplace<ui::UIElementComponent>(entity);
    uiElement.uiBox = entt::null;
    registry.emplace<transform::GameObject>(entity);

    auto newDef = createTextDef("Test");
    bool result = ui::box::ReplaceChildren(registry, entity, newDef);
    EXPECT_FALSE(result);
}
