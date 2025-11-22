#include <gtest/gtest.h>

#include "core/engine_context.hpp"

class EngineContextTest : public ::testing::Test {
protected:
    void TearDown() override {
        globals::g_ctx = nullptr;
    }
};

TEST_F(EngineContextTest, CreatesContextWithDefaults) {
    auto ctx = createEngineContext("test_config.json");
    ASSERT_NE(ctx, nullptr);

    EXPECT_EQ(ctx->currentGameState, GameState::LOADING_SCREEN);
    EXPECT_FLOAT_EQ(ctx->worldMousePosition.x, 0.0f);
    EXPECT_FLOAT_EQ(ctx->worldMousePosition.y, 0.0f);
}

TEST_F(EngineContextTest, RegistryCreatesEntities) {
    auto ctx = createEngineContext("test_config.json");

    const entt::entity e = ctx->registry.create();
    EXPECT_TRUE(e != entt::null);
    EXPECT_TRUE(ctx->registry.valid(e));
}
