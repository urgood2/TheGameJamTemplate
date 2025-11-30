#include <gtest/gtest.h>

#include "systems/telemetry/telemetry.hpp"

#include "sol/sol.hpp"

class TelemetryBindingTest : public ::testing::Test {
protected:
    telemetry::Config saved{};

    void SetUp() override { saved = telemetry::GetConfig(); }
    void TearDown() override { telemetry::Configure(saved); }
};

TEST_F(TelemetryBindingTest, LuaRecordFunctionIsExposedAndCallable) {
    sol::state lua;
    lua.open_libraries(sol::lib::base);

    telemetry::Config cfg{};
    cfg.enabled = true;
    cfg.apiKey = "test-key";
    cfg.posthogHost = "http://example.com";
    cfg.distinctId = "lua-test";
    telemetry::Configure(cfg);

    telemetry::exposeToLua(lua);
    auto result = lua.safe_script(
        "telemetry.record('lua_unit_test', { level = 2, flag = true, name = 'hero' })");

    ASSERT_TRUE(result.valid());

    const auto &active = telemetry::GetConfig();
    EXPECT_TRUE(active.enabled);
    EXPECT_EQ(active.distinctId, "lua-test");
    EXPECT_EQ(active.apiKey, "test-key");
}

TEST_F(TelemetryBindingTest, RecordEventNoopWhenDisabled) {
    telemetry::Config cfg{};
    cfg.enabled = false;
    cfg.distinctId = "noop";
    telemetry::Configure(cfg);

    EXPECT_FALSE(telemetry::GetConfig().enabled);
    EXPECT_NO_THROW(telemetry::RecordEvent("should_not_send", {{"n", 1}}));
}
