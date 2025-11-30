#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "core/globals.hpp"

class GlobalsBridgeTest : public ::testing::Test {
protected:
    void SetUp() override {
        savedCtx = globals::g_ctx;
        savedGameState = globals::currentGameState;
        savedPaused = globals::isGamePaused;
        savedUseImGUI = globals::useImGUI;
        savedRenderScale = globals::finalRenderScale;
        savedLetterboxX = globals::finalLetterboxOffsetX;
        savedLetterboxY = globals::finalLetterboxOffsetY;
        savedUiScale = globals::globalUIScaleFactor;
        savedUiPadding = globals::uiPadding;
        savedWorldWidth = globals::worldWidth;
        savedWorldHeight = globals::worldHeight;
        savedVibration = globals::vibration;
        savedScreenWipe = globals::screenWipe;
        savedUnderOverlay = globals::under_overlay;
        savedCameraDamping = globals::cameraDamping;
        savedCameraStiffness = globals::cameraStiffness;
        savedCameraVelocity = globals::cameraVelocity;
        savedNextCameraTarget = globals::nextCameraTarget;

        globals::setEngineContext(nullptr);
    }

    void TearDown() override {
        globals::setEngineContext(savedCtx);
        globals::currentGameState = savedGameState;
        globals::isGamePaused = savedPaused;
        globals::useImGUI = savedUseImGUI;
        globals::finalRenderScale = savedRenderScale;
        globals::finalLetterboxOffsetX = savedLetterboxX;
        globals::finalLetterboxOffsetY = savedLetterboxY;
        globals::globalUIScaleFactor = savedUiScale;
        globals::uiPadding = savedUiPadding;
        globals::worldWidth = savedWorldWidth;
        globals::worldHeight = savedWorldHeight;
        globals::vibration = savedVibration;
        globals::screenWipe = savedScreenWipe;
        globals::under_overlay = savedUnderOverlay;
        globals::cameraDamping = savedCameraDamping;
        globals::cameraStiffness = savedCameraStiffness;
        globals::cameraVelocity = savedCameraVelocity;
        globals::nextCameraTarget = savedNextCameraTarget;
    }

    EngineContext* savedCtx{nullptr};
    GameState savedGameState{};
    bool savedPaused{};
    bool savedUseImGUI{};
    float savedRenderScale{};
    float savedLetterboxX{};
    float savedLetterboxY{};
    float savedUiScale{};
    float savedUiPadding{};
    int savedWorldWidth{};
    int savedWorldHeight{};
    float savedVibration{};
    bool savedScreenWipe{};
    bool savedUnderOverlay{};
    float savedCameraDamping{};
    float savedCameraStiffness{};
    Vector2 savedCameraVelocity{};
    Vector2 savedNextCameraTarget{};
};

TEST_F(GlobalsBridgeTest, SetEngineContextMirrorsLegacyStateIntoContext) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};

    globals::currentGameState = GameState::MAIN_GAME;
    globals::isGamePaused = true;
    globals::useImGUI = false;
    globals::finalRenderScale = 1.25f;
    globals::finalLetterboxOffsetX = 4.0f;
    globals::finalLetterboxOffsetY = 2.0f;
    globals::globalUIScaleFactor = 1.6f;
    globals::uiPadding = 6.0f;
    globals::worldWidth = 1920;
    globals::worldHeight = 1080;
    globals::vibration = 0.3f;
    globals::screenWipe = true;
    globals::under_overlay = true;
    globals::cameraDamping = 0.8f;
    globals::cameraStiffness = 0.6f;
    globals::cameraVelocity = {1.0f, 2.0f};
    globals::nextCameraTarget = {3.0f, 4.0f};

    globals::setEngineContext(&ctx);

    EXPECT_EQ(globals::g_ctx, &ctx);
    EXPECT_EQ(ctx.currentGameState, GameState::MAIN_GAME);
    EXPECT_TRUE(ctx.isGamePaused);
    EXPECT_FALSE(ctx.useImGUI);
    EXPECT_FLOAT_EQ(ctx.finalRenderScale, 1.25f);
    EXPECT_FLOAT_EQ(ctx.finalLetterboxOffsetX, 4.0f);
    EXPECT_FLOAT_EQ(ctx.finalLetterboxOffsetY, 2.0f);
    EXPECT_FLOAT_EQ(ctx.globalUIScaleFactor, 1.6f);
    EXPECT_FLOAT_EQ(ctx.uiScaleFactor, 1.6f);
    EXPECT_FLOAT_EQ(ctx.uiPadding, 6.0f);
    EXPECT_EQ(ctx.worldWidth, 1920);
    EXPECT_EQ(ctx.worldHeight, 1080);
    EXPECT_FLOAT_EQ(ctx.vibration, 0.3f);
    EXPECT_TRUE(ctx.screenWipe);
    EXPECT_TRUE(ctx.underOverlay);
    EXPECT_FLOAT_EQ(ctx.baseShadowExaggeration, globals::BASE_SHADOW_EXAGGERATION);
    EXPECT_FLOAT_EQ(ctx.cameraDamping, 0.8f);
    EXPECT_FLOAT_EQ(ctx.cameraStiffness, 0.6f);
    EXPECT_FLOAT_EQ(ctx.cameraVelocity.x, 1.0f);
    EXPECT_FLOAT_EQ(ctx.cameraVelocity.y, 2.0f);
    EXPECT_FLOAT_EQ(ctx.nextCameraTarget.x, 3.0f);
    EXPECT_FLOAT_EQ(ctx.nextCameraTarget.y, 4.0f);
    EXPECT_EQ(ctx.inputState, &globals::inputState);
    ASSERT_NE(ctx.shaderUniformsPtr, nullptr);
    EXPECT_EQ(ctx.shaderUniformsOwned.get(), ctx.shaderUniformsPtr);

    globals::setEngineContext(nullptr);
}

TEST_F(GlobalsBridgeTest, SetterMirrorsIntoContext) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::setEngineContext(&ctx);

    globals::setFinalRenderScale(2.0f);
    globals::setLetterboxOffsetX(10.0f);
    globals::setLetterboxOffsetY(5.0f);
    globals::setGlobalUIScaleFactor(1.3f);
    globals::getUiPadding() = 8.0f;
    globals::getCameraDamping() = 0.25f;
    globals::getCameraStiffness() = 0.75f;
    globals::getCameraVelocity() = {7.0f, 9.0f};
    globals::getNextCameraTarget() = {11.0f, 13.0f};

    EXPECT_FLOAT_EQ(ctx.finalRenderScale, 2.0f);
    EXPECT_FLOAT_EQ(ctx.finalLetterboxOffsetX, 10.0f);
    EXPECT_FLOAT_EQ(ctx.finalLetterboxOffsetY, 5.0f);
    EXPECT_FLOAT_EQ(ctx.globalUIScaleFactor, 1.3f);
    EXPECT_FLOAT_EQ(ctx.uiScaleFactor, 1.3f);
    EXPECT_FLOAT_EQ(ctx.uiPadding, 8.0f);
    EXPECT_FLOAT_EQ(ctx.cameraDamping, 0.25f);
    EXPECT_FLOAT_EQ(ctx.cameraStiffness, 0.75f);
    EXPECT_FLOAT_EQ(ctx.cameraVelocity.x, 7.0f);
    EXPECT_FLOAT_EQ(ctx.cameraVelocity.y, 9.0f);
    EXPECT_FLOAT_EQ(ctx.nextCameraTarget.x, 11.0f);
    EXPECT_FLOAT_EQ(ctx.nextCameraTarget.y, 13.0f);

    globals::setEngineContext(nullptr);
}

TEST_F(GlobalsBridgeTest, GetEventBusResolvesToContextWhenPresent) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};

    globals::setEngineContext(&ctx);
    auto& busFromCtx = globals::getEventBus();
    EXPECT_EQ(&busFromCtx, &ctx.eventBus);

    globals::setEngineContext(nullptr);
    auto& fallback1 = globals::getEventBus();
    auto& fallback2 = globals::getEventBus();
    EXPECT_EQ(&fallback1, &fallback2); // stable fallback bus
}

TEST_F(GlobalsBridgeTest, ExternalShaderUniformPointerIsRespected) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    shaders::ShaderUniformComponent external{};
    ctx.shaderUniformsPtr = &external;

    // Seed legacy global uniforms so they mirror into the external buffer.
    globals::getGlobalShaderUniforms().set("example_shader", "uValue", 3.14f);

    globals::setEngineContext(&ctx);

    EXPECT_EQ(ctx.shaderUniformsPtr, &external);
    EXPECT_EQ(ctx.shaderUniformsOwned, nullptr);

    const auto* set = ctx.shaderUniformsPtr->getSet("example_shader");
    ASSERT_NE(set, nullptr);
    const auto* value = set->get("uValue");
    ASSERT_NE(value, nullptr);
    EXPECT_TRUE(std::holds_alternative<float>(*value));
    EXPECT_FLOAT_EQ(std::get<float>(*value), 3.14f);
}
