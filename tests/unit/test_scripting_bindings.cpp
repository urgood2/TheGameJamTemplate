#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "core/globals.hpp"
#include "systems/scripting/scripting_system.hpp"

class ScriptingBindingsTest : public ::testing::Test {
protected:
    void SetUp() override {
        savedCtx = globals::g_ctx;
    }

    void TearDown() override {
        globals::g_ctx = savedCtx;
        globals::textureAtlasMap.erase("atlas-prefers-context");
        globals::textureAtlasMap.erase("atlas-legacy-only");
    }

    EngineContext* savedCtx{nullptr};
};

TEST_F(ScriptingBindingsTest, InitBindsContextIntoLuaWhenProvided) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::package);
    entt::registry registry;

    globals::g_ctx = nullptr;
    scripting::monobehavior_system::init(registry, lua, &ctx);

    sol::object ctxObj = lua["ctx"];
    ASSERT_NE(ctxObj.get_type(), sol::type::lua_nil);
    auto* ctxFromLua = ctxObj.as<EngineContext*>();
    ASSERT_NE(ctxFromLua, nullptr);
    EXPECT_EQ(ctxFromLua, &ctx);

    auto& registryFromLua = lua["registry"].get<entt::registry&>();
    EXPECT_EQ(&registryFromLua, &registry);
}

TEST_F(ScriptingBindingsTest, InitLeavesCtxNilWhenNotProvided) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::package);
    entt::registry registry;

    scripting::monobehavior_system::init(registry, lua, nullptr);

    sol::object ctxObj = lua["ctx"];
    EXPECT_EQ(ctxObj.get_type(), sol::type::lua_nil);

    auto& registryFromLua = lua["registry"].get<entt::registry&>();
    EXPECT_EQ(&registryFromLua, &registry);
}

TEST_F(ScriptingBindingsTest, AtlasHelperPrefersContextOverGlobals) {
    auto ctx = std::make_unique<EngineContext>(EngineConfig{std::string{"config.json"}});
    globals::g_ctx = ctx.get();

    const std::string key = "atlas-prefers-context";
    auto& ctxTex = ctx->textureAtlas[key];
    ctxTex.id = 101;
    ctxTex.width = 64;

    Texture2D globalTex{};
    globalTex.id = 202;
    globalTex.width = 128;
    globals::textureAtlasMap[key] = globalTex;

    Texture2D* resolved = getAtlasTexture(key);
    ASSERT_NE(resolved, nullptr);
    EXPECT_EQ(resolved, &ctx->textureAtlas[key]);
    EXPECT_EQ(resolved->id, 101);
    EXPECT_EQ(resolved->width, 64);
}

TEST_F(ScriptingBindingsTest, AtlasHelperFallsBackToGlobalsWhenContextMissingEntry) {
    auto ctx = std::make_unique<EngineContext>(EngineConfig{std::string{"config.json"}});
    globals::g_ctx = ctx.get();

    const std::string key = "atlas-legacy-only";
    Texture2D globalTex{};
    globalTex.id = 303;
    globalTex.width = 256;
    globals::textureAtlasMap[key] = globalTex;

    Texture2D* resolved = getAtlasTexture(key);
    ASSERT_NE(resolved, nullptr);
    EXPECT_EQ(resolved, &globals::textureAtlasMap[key]);
    EXPECT_EQ(resolved->id, 303);
    EXPECT_EQ(resolved->width, 256);
}
