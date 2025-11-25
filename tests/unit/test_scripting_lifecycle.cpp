#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "core/globals.hpp"
#include "systems/ai/ai_system.hpp"
#include "systems/scripting/registry_bond.hpp"
#include "systems/scripting/scripting_system.hpp"

class ScriptingLifecycleTest : public ::testing::Test {
protected:
    void SetUp() override {
        savedCtx = globals::g_ctx;
        globals::g_ctx = nullptr;
        ai_system::masterStateLua = sol::state{};
        ai_system::masterStateLua.open_libraries(sol::lib::base, sol::lib::package, sol::lib::coroutine, sol::lib::math);
    }

    void TearDown() override {
        globals::g_ctx = savedCtx;
    }

    EngineContext* savedCtx{nullptr};
};

TEST_F(ScriptingLifecycleTest, InitScriptCachesHooksAndCallsInit) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::package);
    entt::registry registry;

    int initCalls = 0;
    int updateCalls = 0;
    sol::table tbl = lua.create_table();
    tbl["init"] = [&]() { initCalls++; };
    tbl["update"] = [&](sol::table, float dt) { updateCalls++; return dt; };
    tbl["on_collision"] = []() {};

    const entt::entity e = registry.create();
    registry.emplace<scripting::ScriptComponent>(e, tbl);

    scripting::init_script(registry, e);

    auto& sc = registry.get<scripting::ScriptComponent>(e);
    EXPECT_TRUE(sc.hooks.update.valid());
    EXPECT_TRUE(sc.hooks.on_collision.valid());
    EXPECT_EQ(initCalls, 1);
    ASSERT_TRUE(sc.self["id"].valid());
    EXPECT_EQ(sc.self["id"].get<entt::entity>(), e);
    ASSERT_TRUE(sc.self["owner"].valid());
    auto& ownerRef = sc.self["owner"].get<entt::registry&>();
    EXPECT_EQ(&ownerRef, &registry);

    // Exercise cached update hook
    sc.hooks.update(sc.self, 0.5f);
    EXPECT_EQ(updateCalls, 1);
}

TEST_F(ScriptingLifecycleTest, ReleaseScriptCallsDestroyAndAbandonsSelf) {
    sol::state& lua = ai_system::masterStateLua;
    lua.script("function make_co() return coroutine.create(function() return 1 end) end");
    bool destroyed = false;
    sol::table tbl = lua.create_table();
    tbl["on_collision"] = []() {};
    tbl["destroy"] = [&]() { destroyed = true; };
    tbl["update"] = []() {};

    scripting::ScriptComponent sc{tbl};
    sc.tasks.push_back(lua["make_co"]());

    entt::registry registry;
    const entt::entity e = registry.create();
    registry.emplace<scripting::ScriptComponent>(e, sc);

    scripting::release_script(registry, e);

    EXPECT_TRUE(destroyed);
    auto& stored = registry.get<scripting::ScriptComponent>(e);
    EXPECT_TRUE(stored.tasks.empty());
    EXPECT_FALSE(stored.self.valid());
}

TEST_F(ScriptingLifecycleTest, AddScriptComponentAddsTableThroughHelper) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::package);
    entt::registry registry;
    const entt::entity e = registry.create();
    sol::table tbl = lua.create_table();
    tbl["on_collision"] = []() {};
    tbl["update"] = []() {};

    scripting::add_script_component(registry, e, tbl);

    ASSERT_TRUE(registry.all_of<scripting::ScriptComponent>(e));
    auto& sc = registry.get<scripting::ScriptComponent>(e);
    EXPECT_TRUE(sc.self.valid());
    EXPECT_EQ(sc.self.lua_state(), tbl.lua_state());
}

TEST_F(ScriptingLifecycleTest, AddTaskCreatesCoroutineInMasterState) {
    auto& lua = ai_system::masterStateLua;
    int calls = 0;
    lua.set_function("tick", [&]() { calls++; });

    scripting::ScriptComponent sc{};
    sc.add_task(lua["tick"]);

    ASSERT_EQ(sc.tasks.size(), 1u);
    sol::coroutine& co = sc.tasks.front();
    ASSERT_TRUE(co.valid());
    auto result = co();
    EXPECT_TRUE(result.valid());
    EXPECT_EQ(calls, 1);
}
