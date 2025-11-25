#include <gtest/gtest.h>

#include "core/events.hpp"
#include "core/globals.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/transform/transform.hpp"
#include "systems/ui/element.hpp"
#include "tests/mocks/mock_engine_context.hpp"

class InputEventBusTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Start with a clean bridge so tests don't leak shared state.
        globals::setEngineContext(nullptr);
        globals::getEventBus().clear();
    }

    void TearDown() override {
        globals::setEngineContext(nullptr);
        globals::getEventBus().clear();
    }
};

TEST_F(InputEventBusTest, PublishesMouseClickToProvidedContextBus) {
    MockEngineContext ctx;

    bool fallbackReceived = false;
    globals::getEventBus().subscribe<events::MouseClicked>(
        [&](const events::MouseClicked&) { fallbackReceived = true; });

    int clicksOnCtx = 0;
    events::MouseClicked last{};
    ctx.eventBus.subscribe<events::MouseClicked>(
        [&](const events::MouseClicked& evt) {
            ++clicksOnCtx;
            last = evt;
        });

    entt::registry registry;
    auto hovered = registry.create();

    input::InputState state{};
    state.current_designated_hover_target = hovered;
    globals::setGameWorldContainer(registry.create());

    input::ProcessLeftMouseButtonRelease(registry, state, 12.0f, 34.0f, &ctx);

    EXPECT_EQ(clicksOnCtx, 1);
    EXPECT_EQ(last.target, hovered);
    EXPECT_FLOAT_EQ(last.position.x, 12.0f);
    EXPECT_FLOAT_EQ(last.position.y, 34.0f);
    EXPECT_FALSE(fallbackReceived);
}

TEST_F(InputEventBusTest, FocusInterruptClearsFocusAndPublishesEvent) {
    MockEngineContext ctx;
    globals::setEngineContext(&ctx);

    int focusEvents = 0;
    entt::entity last{entt::null};
    ctx.eventBus.subscribe<events::UIElementFocused>(
        [&](const events::UIElementFocused& evt) {
            ++focusEvents;
            last = evt.element;
        });

    entt::registry registry;
    auto focused = registry.create();
    auto& go = registry.emplace<transform::GameObject>(focused);
    go.state.isBeingFocused = true;
    registry.emplace<transform::Transform>(focused);
    registry.emplace<ui::UIConfig>(focused);

    input::InputState state{};
    state.cursor_focused_target = focused;
    state.hid.controller_enabled = true;
    state.focus_interrupt = true;

    input::UpdateFocusForRelevantNodes(registry, state, std::nullopt, &ctx);

    EXPECT_EQ(focusEvents, 1);
    EXPECT_EQ(last, entt::entity{entt::null});
    EXPECT_EQ(state.cursor_focused_target, entt::entity{entt::null});
    EXPECT_FALSE(go.state.isBeingFocused);
}

TEST_F(InputEventBusTest, PublishesUIButtonActivatedForUiTargets) {
    MockEngineContext ctx;

    int clickCount = 0;
    int activatedCount = 0;
    events::UIButtonActivated lastActivation{};

    ctx.eventBus.subscribe<events::MouseClicked>(
        [&](const events::MouseClicked&) { ++clickCount; });
    ctx.eventBus.subscribe<events::UIButtonActivated>(
        [&](const events::UIButtonActivated& evt) {
            ++activatedCount;
            lastActivation = evt;
        });

    entt::registry registry;
    auto uiEntity = registry.create();
    registry.emplace<ui::UIElementComponent>(uiEntity);

    input::InputState state{};
    state.current_designated_hover_target = uiEntity;
    globals::setGameWorldContainer(registry.create());

    input::ProcessLeftMouseButtonRelease(registry, state, 5.0f, 6.0f, &ctx);

    EXPECT_EQ(clickCount, 1);
    EXPECT_EQ(activatedCount, 1);
    EXPECT_EQ(lastActivation.element, uiEntity);
    EXPECT_EQ(lastActivation.button, MOUSE_LEFT_BUTTON);
}

TEST_F(InputEventBusTest, FallsBackToGlobalBusWhenContextAbsent) {
    int fallbackClicks = 0;
    events::MouseClicked last{};
    globals::getEventBus().subscribe<events::MouseClicked>(
        [&](const events::MouseClicked& evt) {
            ++fallbackClicks;
            last = evt;
        });

    entt::registry registry;
    auto target = registry.create();

    input::InputState state{};
    state.current_designated_hover_target = target;
    globals::setGameWorldContainer(registry.create());

    input::ProcessLeftMouseButtonRelease(registry, state, 1.0f, 2.0f);

    EXPECT_EQ(fallbackClicks, 1);
    EXPECT_EQ(last.target, target);
    EXPECT_FLOAT_EQ(last.position.x, 1.0f);
    EXPECT_FLOAT_EQ(last.position.y, 2.0f);
}
