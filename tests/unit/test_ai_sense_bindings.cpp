#include <gtest/gtest.h>

#include <tuple>

#include "core/engine_context.hpp"
#include "core/globals.hpp"
#include "systems/ai/ai_system.hpp"
#include "components/components.hpp"
#include "sol/sol.hpp"

class AIBindingsSenseTest : public ::testing::Test {
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

TEST_F(AIBindingsSenseTest, PositionAndDistanceWorkForEntitiesAndTables) {
    auto& registry = globals::getRegistry();
    entt::entity self = registry.create();
    entt::entity other = registry.create();

    registry.emplace<LocationComponent>(self, LocationComponent{0.0f, 0.0f});
    registry.emplace<LocationComponent>(other, LocationComponent{3.0f, 4.0f});

    sol::table sense = lua["ai"]["sense"];

    sol::object posObj = sense["position"](self);
    ASSERT_EQ(posObj.get_type(), sol::type::table);
    sol::table pos = posObj.as<sol::table>();
    EXPECT_NEAR(pos["x"], 0.0, 1e-4);
    EXPECT_NEAR(pos["y"], 0.0, 1e-4);

    sol::object distObj = sense["distance"](self, other);
    ASSERT_EQ(distObj.get_type(), sol::type::number);
    EXPECT_NEAR(distObj.as<double>(), 5.0, 1e-4);

    sol::table target = lua.create_table_with("x", 6.0, "y", 8.0);
    sol::object distToTable = sense["distance"](self, target);
    ASSERT_EQ(distToTable.get_type(), sol::type::number);
    EXPECT_NEAR(distToTable.as<double>(), 10.0, 1e-4);
}

TEST_F(AIBindingsSenseTest, NearestAndRangeQueriesRespectFilters) {
    auto& registry = globals::getRegistry();
    entt::entity self = registry.create();
    entt::entity nearA = registry.create();
    entt::entity nearB = registry.create();
    entt::entity far = registry.create();

    registry.emplace<LocationComponent>(self, LocationComponent{0.0f, 0.0f});
    registry.emplace<LocationComponent>(nearA, LocationComponent{3.0f, 4.0f}); // dist 5
    registry.emplace<LocationComponent>(nearB, LocationComponent{4.0f, 0.0f}); // dist 4
    registry.emplace<LocationComponent>(far, LocationComponent{100.0f, 0.0f});

    sol::table sense = lua["ai"]["sense"];

    sol::table opts = lua.create_table();
    sol::function nearestFn = sense["nearest"];
    auto result = nearestFn.call<sol::object, sol::object>(self, 6.0, opts);
    sol::object nearestObj = std::get<0>(result);
    sol::object distObj = std::get<1>(result);

    ASSERT_EQ(nearestObj.get_type(), sol::type::number);
    EXPECT_EQ(nearestObj.as<entt::entity>(), nearB);
    ASSERT_EQ(distObj.get_type(), sol::type::number);
    EXPECT_NEAR(distObj.as<double>(), 4.0, 1e-4);

    lua.set_function("exclude_nearB", [nearB](entt::entity e) {
        return e != nearB;
    });
    opts["filter"] = lua["exclude_nearB"];

    result = nearestFn.call<sol::object, sol::object>(self, 6.0, opts);
    nearestObj = std::get<0>(result);
    distObj = std::get<1>(result);
    ASSERT_EQ(nearestObj.get_type(), sol::type::number);
    EXPECT_EQ(nearestObj.as<entt::entity>(), nearA);
    EXPECT_NEAR(distObj.as<double>(), 5.0, 1e-4);

    sol::table rangeOpts = lua.create_table_with("max", 4);
    sol::table results = sense["all_in_range"](self, 6.0, rangeOpts);
    bool foundA = false;
    bool foundB = false;
    for (auto& [k, v] : results) {
        if (v.is<entt::entity>()) {
            entt::entity e = v.as<entt::entity>();
            if (e == nearA) foundA = true;
            if (e == nearB) foundB = true;
        }
    }
    EXPECT_TRUE(foundA);
    EXPECT_TRUE(foundB);
}
