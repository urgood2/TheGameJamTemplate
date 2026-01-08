#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "systems/input/input_function_data.hpp"
#include "systems/shaders/shader_system.hpp"

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

TEST_F(EngineContextTest, RegistryBasicOperations) {
    auto ctx = createEngineContext("test_config.json");

    auto entity = ctx->registry.create();
    ASSERT_TRUE(ctx->registry.valid(entity));

    ctx->registry.destroy(entity);
    EXPECT_FALSE(ctx->registry.valid(entity));
}

TEST_F(EngineContextTest, ResourceCachesInitialized) {
    auto ctx = createEngineContext("test_config.json");

    EXPECT_TRUE(ctx->textureAtlas.empty());
    EXPECT_TRUE(ctx->animations.empty());
    EXPECT_TRUE(ctx->spriteFrames.empty());
    EXPECT_TRUE(ctx->colors.empty());
}

TEST_F(EngineContextTest, MutableStateDefaults) {
    auto ctx = createEngineContext("test_config.json");

    EXPECT_EQ(ctx->currentGameState, GameState::LOADING_SCREEN);
    EXPECT_FALSE(ctx->isGamePaused);
    EXPECT_TRUE(ctx->useImGUI);
    EXPECT_FALSE(ctx->drawDebugInfo);
    EXPECT_FALSE(ctx->drawPhysicsDebug);
    EXPECT_FALSE(ctx->releaseMode);
    EXPECT_FALSE(ctx->screenWipe);
    EXPECT_FALSE(ctx->underOverlay);
}

TEST_F(EngineContextTest, CameraDefaults) {
    auto ctx = createEngineContext("test_config.json");

    EXPECT_FLOAT_EQ(ctx->cameraDamping, 0.4f);
    EXPECT_FLOAT_EQ(ctx->cameraStiffness, 0.99f);
    EXPECT_FLOAT_EQ(ctx->cameraVelocity.x, 0.0f);
    EXPECT_FLOAT_EQ(ctx->cameraVelocity.y, 0.0f);
}

TEST_F(EngineContextTest, EntityHandlesDefault) {
    auto ctx = createEngineContext("test_config.json");

    EXPECT_TRUE(ctx->cursor == entt::null);
    EXPECT_TRUE(ctx->overlayMenu == entt::null);
    EXPECT_TRUE(ctx->gameWorldContainerEntity == entt::null);
    EXPECT_TRUE(ctx->lastUIFocus == entt::null);
    EXPECT_TRUE(ctx->lastUIButtonActivated == entt::null);
}

TEST_F(EngineContextTest, TimerDefaults) {
    auto ctx = createEngineContext("test_config.json");

    EXPECT_FLOAT_EQ(ctx->timerReal, 0.0f);
    EXPECT_FLOAT_EQ(ctx->timerTotal, 0.0f);
    EXPECT_EQ(ctx->framesMove, 0);
}

TEST_F(EngineContextTest, MouseStateDefaults) {
    auto ctx = createEngineContext("test_config.json");

    EXPECT_FALSE(ctx->hasLastMouseClick);
    EXPECT_EQ(ctx->lastMouseButton, -1);
    EXPECT_FALSE(ctx->hasLastMouseClickTarget);
}

TEST_F(EngineContextTest, SafeAccessorsThrowWhenNull) {
    auto ctx = createEngineContext("test_config.json");

    EXPECT_FALSE(ctx->hasInputState());
    EXPECT_FALSE(ctx->hasAudio());
    EXPECT_FALSE(ctx->hasShaderUniforms());

    EXPECT_THROW(ctx->getInputState(), std::runtime_error);
    EXPECT_THROW(ctx->getAudio(), std::runtime_error);
    EXPECT_THROW(ctx->getShaderUniforms(), std::runtime_error);
}

TEST_F(EngineContextTest, SafeAccessorsWorkWhenInitialized) {
    auto ctx = createEngineContext("test_config.json");

    input::InputState inputState;
    ctx->inputState = &inputState;
    EXPECT_TRUE(ctx->hasInputState());
    EXPECT_NO_THROW(ctx->getInputState());

    AudioContext audioCtx;
    ctx->audio = &audioCtx;
    EXPECT_TRUE(ctx->hasAudio());
    EXPECT_NO_THROW(ctx->getAudio());

    shaders::ShaderUniformComponent shaderUniforms;
    ctx->shaderUniformsPtr = &shaderUniforms;
    EXPECT_TRUE(ctx->hasShaderUniforms());
    EXPECT_NO_THROW(ctx->getShaderUniforms());
}
