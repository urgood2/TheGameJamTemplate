#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "core/globals.hpp"

class GlobalsCachesTest : public ::testing::Test {
protected:
    void SetUp() override {
        savedCtx = globals::g_ctx;
        legacyTextureAtlas = globals::textureAtlasMap;
        legacyAnimations = globals::animationsMap;
        legacyColorsJson = globals::colorsJSON;
        legacyUiStringsJson = globals::uiStringsJSON;
    }

    void TearDown() override {
        globals::textureAtlasMap = legacyTextureAtlas;
        globals::animationsMap = legacyAnimations;
        globals::colorsJSON = legacyColorsJson;
        globals::uiStringsJSON = legacyUiStringsJson;
        globals::setEngineContext(savedCtx);
    }

    EngineContext* savedCtx{nullptr};
    std::map<std::string, Texture2D> legacyTextureAtlas;
    std::map<std::string, AnimationObject> legacyAnimations;
    json legacyColorsJson;
    json legacyUiStringsJson;
};

TEST_F(GlobalsCachesTest, ResolveCtxOrLegacyPrefersContextMaps) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    ctx.textureAtlas["ctx-atlas"].id = 7;
    ctx.animations["ctx-anim"] = AnimationObject{};
    globals::textureAtlasMap["legacy-atlas"].id = 99;
    globals::animationsMap["legacy-anim"] = AnimationObject{};

    globals::setEngineContext(&ctx);

    auto& atlas = globals::getTextureAtlasMap();
    auto& anims = globals::getAnimationsMap();

    EXPECT_EQ(&atlas, &ctx.textureAtlas);
    EXPECT_EQ(&anims, &ctx.animations);
    EXPECT_TRUE(atlas.contains("ctx-atlas"));
    EXPECT_FALSE(atlas.contains("legacy-atlas")); // legacy not copied when context already populated
}

TEST_F(GlobalsCachesTest, ResolveCtxCopiesLegacyJsonWhenContextEmpty) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::colorsJSON["primary"] = "#ff00ff";
    globals::uiStringsJSON["title"] = "Hello";

    globals::setEngineContext(&ctx);

    auto& colors = globals::getColorsJson();
    auto& ui = globals::getUiStringsJson();

    EXPECT_EQ(&colors, &ctx.colorsJson);
    EXPECT_EQ(&ui, &ctx.uiStringsJson);
    ASSERT_TRUE(colors.contains("primary"));
    EXPECT_EQ(colors["primary"], "#ff00ff");
    ASSERT_TRUE(ui.contains("title"));
    EXPECT_EQ(ui["title"], "Hello");
}

TEST_F(GlobalsCachesTest, GlobalUIMapsReturnContextContainers) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::setEngineContext(&ctx);

    auto& instances = globals::getGlobalUIInstanceMap();
    auto& callbacks = globals::getButtonCallbacks();
    instances["menu"] = {entt::null};
    callbacks["click"] = [] {};

    EXPECT_EQ(&instances, &ctx.globalUIInstances);
    EXPECT_EQ(&callbacks, &ctx.buttonCallbacks);
    EXPECT_TRUE(ctx.globalUIInstances.contains("menu"));
    EXPECT_TRUE(ctx.buttonCallbacks.contains("click"));
}

TEST_F(GlobalsCachesTest, GlobalShaderUniformsFollowContextPointer) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::setEngineContext(&ctx);

    auto& uniforms = globals::getGlobalShaderUniforms();

    ASSERT_NE(ctx.shaderUniformsPtr, nullptr);
    EXPECT_EQ(&uniforms, ctx.shaderUniformsPtr);

    uniforms.set("ui", "resolution", Vector2{4.0f, 6.0f});
    const auto* stored = ctx.shaderUniformsPtr->get("ui", "resolution");
    ASSERT_NE(stored, nullptr);
    auto asVec = std::get<Vector2>(*stored);
    EXPECT_FLOAT_EQ(asVec.x, 4.0f);
    EXPECT_FLOAT_EQ(asVec.y, 6.0f);
}
