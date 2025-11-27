#include <gtest/gtest.h>

#include "sol/sol.hpp"

#include "core/events.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/input/controller_nav.hpp"
#include "util/error_handling.hpp"

using controller_nav::NavManager;
using controller_nav::NavGroup;

namespace {

struct Counter {
    int focusCalls = 0;
    int unfocusCalls = 0;
};

sol::state& shared_lua() {
    static sol::state* lua = [] {
        auto* s = new sol::state();
        s->open_libraries(sol::lib::base);
        return s;
    }();
    return *lua;
}

TEST(ControllerNav, NotifyFocusInvokesGroupCallbacks) {
    auto& nav = NavManager::instance();
    nav.reset();

    entt::registry reg;
    auto prev = reg.create();
    auto next = reg.create();

    NavGroup g{};
    g.name = "ui";
    g.entries.push_back(prev);
    g.entries.push_back(next);

    auto& lua = shared_lua();
    Counter counter;
    lua.set_function("on_focus", [&]() { counter.focusCalls++; });
    lua.set_function("on_unfocus", [&]() { counter.unfocusCalls++; });
    g.callbacks.on_focus = lua["on_focus"];
    g.callbacks.on_unfocus = lua["on_unfocus"];

    nav.groups["ui"] = std::move(g);

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

    NavGroup g{};
    g.name = "ui";
    g.entries.push_back(prev);
    g.entries.push_back(next);

    auto& lua = shared_lua();
    lua.script(R"(
        function on_focus() error("boom") end
        function on_unfocus() error("boom") end
    )");
    g.callbacks.on_focus = lua["on_focus"];
    g.callbacks.on_unfocus = lua["on_unfocus"];

    nav.groups["ui"] = std::move(g);

    EXPECT_NO_THROW(nav.notify_focus(prev, next, reg)); // safeLuaCall should swallow/log
    nav.reset();
}

TEST(ControllerNav, NotifySelectInvokesGroupCallback) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto e = reg.create();

    NavGroup g{};
    g.name = "ui";
    g.entries.push_back(e);
    g.selectedIndex = 0;

    int selects = 0;
    auto& lua = shared_lua();
    lua.set_function("on_select", [&]() { selects++; });
    g.callbacks.on_select = lua["on_select"];

    nav.groups["ui"] = std::move(g);

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

    NavGroup g{};
    g.name = "ui";
    g.entries.push_back(e);
    nav.groups["ui"] = std::move(g);

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

    NavGroup g{};
    g.name = "ui";
    g.entries.push_back(e);
    auto& lua = shared_lua();
    lua.set_function("on_select", []() { throw std::runtime_error("boom"); });
    g.callbacks.on_select = lua["on_select"];

    nav.groups["ui"] = std::move(g);

    EXPECT_NO_THROW(nav.select_current(reg, "ui")); // safeLuaCall should swallow/log
    nav.reset();
}

TEST(ControllerNav, NotifySelectPrefersGroupOverGlobal) {
    auto& nav = NavManager::instance();
    nav.reset();
    nav.callbacks = {};

    entt::registry reg;
    auto e = reg.create();

    NavGroup g{};
    g.name = "ui";
    g.entries.push_back(e);
    g.selectedIndex = 0;

    int groupSelects = 0;
    int globalSelects = 0;
    auto& lua = shared_lua();
    lua.set_function("on_select_group", [&]() { groupSelects++; });
    lua.set_function("on_select_global", [&]() { globalSelects++; });
    g.callbacks.on_select = lua["on_select_group"];
    nav.callbacks.on_select = lua["on_select_global"];

    nav.groups["ui"] = std::move(g);

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

    NavGroup g{};
    g.name = "ui";
    g.entries.push_back(prev);
    g.entries.push_back(next);

    int groupFocus = 0;
    int globalFocus = 0;
    int groupUnfocus = 0;
    int globalUnfocus = 0;
    auto& lua = shared_lua();
    lua.set_function("on_focus_group", [&]() { groupFocus++; });
    lua.set_function("on_unfocus_group", [&]() { groupUnfocus++; });
    lua.set_function("on_focus_global", [&]() { globalFocus++; });
    lua.set_function("on_unfocus_global", [&]() { globalUnfocus++; });
    g.callbacks.on_focus = lua["on_focus_group"];
    g.callbacks.on_unfocus = lua["on_unfocus_group"];
    nav.callbacks.on_focus = lua["on_focus_global"];
    nav.callbacks.on_unfocus = lua["on_unfocus_global"];

    nav.groups["ui"] = std::move(g);

    ASSERT_NO_THROW(nav.notify_focus(prev, next, reg));
    EXPECT_EQ(groupUnfocus, 1);
    EXPECT_EQ(groupFocus, 1);
    EXPECT_EQ(globalUnfocus, 0);
    EXPECT_EQ(globalFocus, 0);
    nav.reset();
}

TEST(ControllerNav, PublishesEventBusOnFocusAndSelect) {
    auto& nav = NavManager::instance();
    nav.reset();

    EngineContext* savedCtx = globals::g_ctx;
    globals::setEngineContext(nullptr);

    auto& bus = globals::getEventBus();
    bus.clear();

    bool focusReceived = false;
    entt::entity focused{entt::null};
    int activations = 0;
    entt::entity activated{entt::null};
    bus.subscribe<events::UIElementFocused>([&](const auto& ev) {
        focusReceived = true;
        focused = ev.element;
    });
    bus.subscribe<events::UIButtonActivated>([&](const auto& ev) {
        ++activations;
        activated = ev.element;
    });

    auto& reg = globals::getRegistry();
    reg.clear();
    auto e = reg.create();
    reg.emplace<transform::Transform>(e);
    entity_gamestate_management::assignDefaultStateTag(e);

    nav.notify_focus(entt::null, e, reg);
    nav.notify_select(e, reg);

    EXPECT_TRUE(focusReceived);
    EXPECT_EQ(focused, e);
    EXPECT_EQ(activations, 1);
    EXPECT_EQ(activated, e);

    bus.clear();
    nav.reset();
    reg.clear();
    globals::setEngineContext(savedCtx);
}

TEST(ControllerNav, RespondsToGamepadEventsViaBus) {
    auto& nav = NavManager::instance();
    nav.reset();

    EngineContext* savedCtx = globals::g_ctx;
    globals::setEngineContext(nullptr);

    auto& bus = globals::getEventBus();
    bus.clear();

    auto& reg = globals::getRegistry();
    reg.clear();

    auto e1 = reg.create();
    auto e2 = reg.create();
    reg.emplace<transform::Transform>(e1);
    reg.emplace<transform::Transform>(e2);
    auto& t1 = reg.get<transform::Transform>(e1);
    t1.setActualX(0.0f);
    t1.setActualY(0.0f);
    t1.setActualW(10.0f);
    t1.setActualH(10.0f);
    auto& t2 = reg.get<transform::Transform>(e2);
    t2.setActualX(50.0f);
    t2.setActualY(0.0f);
    t2.setActualW(10.0f);
    t2.setActualH(10.0f);
    entity_gamestate_management::assignDefaultStateTag(e1);
    entity_gamestate_management::assignDefaultStateTag(e2);

    nav.create_group("ui");
    nav.groups["ui"].entries = {e1, e2};
    nav.groups["ui"].spatial = true;
    nav.create_layer("root");
    nav.add_group_to_layer("root", "ui");
    nav.set_active_layer("root");

    auto& state = globals::getInputState();
    state = input::InputState{};
    state.cursor_focused_target = e1;
    state.hid.controller_enabled = true;

    int focusEvents = 0;
    entt::entity lastFocus{entt::null};
    int activations = 0;
    entt::entity lastActivated{entt::null};
    bus.subscribe<events::UIElementFocused>([&](const auto& ev) {
        ++focusEvents;
        lastFocus = ev.element;
    });
    bus.subscribe<events::UIButtonActivated>([&](const auto& ev) {
        ++activations;
        lastActivated = ev.element;
    });

    controller_nav::install_event_subscribers(bus, reg, state, true);

    bus.publish(events::GamepadButtonPressed{state.gamepad.id, GAMEPAD_BUTTON_LEFT_FACE_RIGHT});
    EXPECT_EQ(state.cursor_focused_target, e2);
    EXPECT_EQ(focusEvents, 1);
    EXPECT_EQ(lastFocus, e2);

    bus.publish(events::GamepadButtonPressed{state.gamepad.id, GAMEPAD_BUTTON_RIGHT_FACE_DOWN});
    EXPECT_EQ(activations, 1);
    EXPECT_EQ(lastActivated, e2);

    bus.clear();
    nav.reset();
    reg.clear();
    globals::setEngineContext(savedCtx);
}

} // namespace
