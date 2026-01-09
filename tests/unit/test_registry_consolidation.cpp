#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "core/globals.hpp"
#include "systems/transform/transform.hpp"

class RegistryConsolidationTest : public ::testing::Test {
protected:
    void SetUp() override {
        savedCtx = globals::g_ctx;
        globals::setEngineContext(nullptr);
    }

    void TearDown() override {
        globals::setEngineContext(savedCtx);
    }

    EngineContext* savedCtx{nullptr};
};

TEST_F(RegistryConsolidationTest, GetRegistryReturnsContextRegistryWhenSet) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::setEngineContext(&ctx);

    entt::registry& fromGlobals = globals::getRegistry();
    EXPECT_EQ(&fromGlobals, &ctx.registry);
}

TEST_F(RegistryConsolidationTest, GetRegistryReturnsLegacyRegistryWhenContextNull) {
    globals::setEngineContext(nullptr);

    entt::registry& fromGlobals = globals::getRegistry();
    EXPECT_EQ(&fromGlobals, &globals::registry);
}

TEST_F(RegistryConsolidationTest, ContextRegistryAndLegacyRegistryAreDistinct) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};

    EXPECT_NE(&ctx.registry, &globals::registry);
}

TEST_F(RegistryConsolidationTest, EntityCreatedInContextIsValidInGetRegistry) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::setEngineContext(&ctx);

    entt::entity entityFromContext = ctx.registry.create();

    EXPECT_TRUE(globals::getRegistry().valid(entityFromContext));
}

TEST_F(RegistryConsolidationTest, ComponentsAccessibleViaEitherPath) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::setEngineContext(&ctx);

    entt::entity entity = ctx.registry.create();
    ctx.registry.emplace<transform::Transform>(entity, transform::Transform{});

    EXPECT_TRUE(globals::getRegistry().all_of<transform::Transform>(entity));

    auto& transformViaGlobals = globals::getRegistry().get<transform::Transform>(entity);
    auto& transformViaContext = ctx.registry.get<transform::Transform>(entity);
    EXPECT_EQ(&transformViaGlobals, &transformViaContext);
}

TEST_F(RegistryConsolidationTest, SetEngineContextUpdatesBridgePointer) {
    EngineContext ctx1{EngineConfig{std::string{"config.json"}}};
    EngineContext ctx2{EngineConfig{std::string{"config.json"}}};

    globals::setEngineContext(&ctx1);
    EXPECT_EQ(&globals::getRegistry(), &ctx1.registry);

    globals::setEngineContext(&ctx2);
    EXPECT_EQ(&globals::getRegistry(), &ctx2.registry);

    globals::setEngineContext(nullptr);
    EXPECT_EQ(&globals::getRegistry(), &globals::registry);
}
