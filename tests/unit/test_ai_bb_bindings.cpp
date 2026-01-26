#include <gtest/gtest.h>

#include <cmath>

#include "core/engine_context.hpp"
#include "core/globals.hpp"
#include "systems/ai/ai_system.hpp"
#include "components/components.hpp"
#include "sol/sol.hpp"

class AIBindingsBbTest : public ::testing::Test {
protected:
    void SetUp() override {
        savedCtx = globals::g_ctx;
        ctx = std::make_unique<EngineContext>(EngineConfig{std::string{"config.json"}});
        globals::setEngineContext(ctx.get());

        lua.open_libraries(sol::lib::base, sol::lib::table);
        ai_system::bind_ai_utilities(lua);
    }

    void TearDown() override {
        globals::setEngineContext(savedCtx);
        ctx.reset();
    }

    EngineContext* savedCtx{nullptr};
    std::unique_ptr<EngineContext> ctx;
    sol::state lua{};
};

TEST_F(AIBindingsBbTest, SetGetAndDefaultBehaviorsWork) {
    auto& registry = globals::getRegistry();
    entt::entity e = registry.create();
    registry.emplace<GOAPComponent>(e);
    int eid = static_cast<int>(e);

    sol::table bb = lua["ai"]["bb"];
    sol::protected_function setFn = bb["set"];
    sol::protected_function getFn = bb["get"];

    auto setRes = setFn(eid, "hunger", 0.5);
    ASSERT_TRUE(setRes.valid());

    sol::protected_function_result hungerRes = getFn(eid, "hunger", 1.0);
    ASSERT_TRUE(hungerRes.valid());
    double hunger = hungerRes.get<double>();
    EXPECT_NEAR(hunger, 0.5, 1e-4);

    sol::protected_function_result missingRes = getFn(eid, "missing");
    ASSERT_TRUE(missingRes.valid());
    sol::object missing = missingRes.get<sol::object>();
    EXPECT_EQ(missing.get_type(), sol::type::lua_nil);

    sol::protected_function_result defaultRes = getFn(eid, "missing", 42);
    ASSERT_TRUE(defaultRes.valid());
    sol::object missingWithDefault = defaultRes.get<sol::object>();
    ASSERT_EQ(missingWithDefault.get_type(), sol::type::number);
    EXPECT_EQ(missingWithDefault.as<int>(), 42);
}

TEST_F(AIBindingsBbTest, Vec2AndNumericHelpersWork) {
    auto& registry = globals::getRegistry();
    entt::entity e = registry.create();
    registry.emplace<GOAPComponent>(e);
    int eid = static_cast<int>(e);

    sol::table bb = lua["ai"]["bb"];
    sol::protected_function setFn = bb["set"];
    sol::protected_function getFn = bb["get"];
    sol::protected_function getVecFn = bb["get_vec2"];
    sol::protected_function hasFn = bb["has"];
    sol::protected_function clearFn = bb["clear"];

    sol::table pos = lua.create_table_with("x", 10.0, "y", 20.0);
    auto setRes = setFn(eid, "pos", pos);
    ASSERT_TRUE(setRes.valid());

    sol::protected_function_result posRes = getFn(eid, "pos");
    ASSERT_TRUE(posRes.valid());
    sol::table posOut = posRes.get<sol::table>();
    EXPECT_NEAR(posOut["x"], 10.0, 1e-4);
    EXPECT_NEAR(posOut["y"], 20.0, 1e-4);

    sol::protected_function_result vecRes = getVecFn(eid, "pos");
    ASSERT_TRUE(vecRes.valid());
    sol::table posVecOut = vecRes.get<sol::table>();
    EXPECT_NEAR(posVecOut["x"], 10.0, 1e-4);
    EXPECT_NEAR(posVecOut["y"], 20.0, 1e-4);

    sol::protected_function incFn = bb["inc"];
    sol::protected_function_result incRes = incFn(eid, "anger", 2.0, 1.0);
    ASSERT_TRUE(incRes.valid());
    double incVal = incRes.get<double>();
    EXPECT_NEAR(incVal, 3.0, 1e-4);

    sol::protected_function decayFn = bb["decay"];
    sol::protected_function_result decayRes = decayFn(eid, "anger", 1.0, 1.0, 1.0);
    ASSERT_TRUE(decayRes.valid());
    double decayVal = decayRes.get<double>();
    EXPECT_NEAR(decayVal, 3.0 * std::exp(-1.0), 1e-3);

    sol::protected_function_result hasRes = hasFn(eid, "anger");
    ASSERT_TRUE(hasRes.valid());
    EXPECT_TRUE(hasRes.get<bool>());

    auto clearRes = clearFn(eid);
    ASSERT_TRUE(clearRes.valid());

    sol::protected_function_result hasAfterRes = hasFn(eid, "anger");
    ASSERT_TRUE(hasAfterRes.valid());
    EXPECT_FALSE(hasAfterRes.get<bool>());
}
