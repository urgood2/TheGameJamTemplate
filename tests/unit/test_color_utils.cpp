#include <gtest/gtest.h>

#include "core/globals.hpp"
#include "systems/uuid/uuid.hpp"

#include "mocks/mock_engine_context.hpp"

class ColorBridgeTest : public ::testing::Test {
protected:
    EngineContext* previousCtx{nullptr};

    void SetUp() override {
        previousCtx = globals::g_ctx;
        uuid::map.clear();
        globals::getColorsMap().clear();
    }

    void TearDown() override {
        globals::g_ctx = previousCtx;
        if (globals::g_ctx) {
            globals::g_ctx->colors.clear();
        } else {
            globals::getColorsMap().clear();
        }
        uuid::map.clear();
    }
};

TEST_F(ColorBridgeTest, PrefersContextColorMap) {
    auto ctx = std::make_unique<MockEngineContext>();
    globals::g_ctx = ctx.get();

    const auto key = uuid::add("HOT_PINK");
    const Color hotPink = PINK;
    ctx->colors[key] = hotPink;

    auto& colors = globals::getColorsMap();
    EXPECT_EQ(&colors, &ctx->colors);
    ASSERT_NE(colors.find(key), colors.end());
    EXPECT_EQ(colors[key].r, hotPink.r);
    EXPECT_EQ(colors[key].g, hotPink.g);
    EXPECT_EQ(colors[key].b, hotPink.b);
}

TEST_F(ColorBridgeTest, FallsBackToLegacyColors) {
    globals::g_ctx = nullptr;

    auto& colors = globals::getColorsMap();
    colors.clear();
    const auto key = uuid::add("CERULEAN");
    const Color blue = BLUE;
    colors[key] = blue;

    const auto& resolved = globals::getColorsMap();
    ASSERT_NE(resolved.find(key), resolved.end());
    EXPECT_EQ(resolved.at(key).r, blue.r);
    EXPECT_EQ(resolved.at(key).g, blue.g);
    EXPECT_EQ(resolved.at(key).b, blue.b);
}
