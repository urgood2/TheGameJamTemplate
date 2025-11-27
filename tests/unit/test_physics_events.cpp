#define private public
#include "systems/physics/physics_world.hpp"
#undef private

#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "core/events.hpp"
#include "core/globals.hpp"

class PhysicsEventBusTest : public ::testing::Test {
protected:
    void SetUp() override {
        savedCtx = globals::g_ctx;
        globals::g_ctx = nullptr;
        globals::getEventBus().clear();
    }
    void TearDown() override {
        globals::g_ctx = savedCtx;
        globals::getEventBus().clear();
    }
    EngineContext* savedCtx{nullptr};
};

static void pushCollision(physics::PhysicsWorld& world,
                          entt::entity a,
                          entt::entity b,
                          float x = 1.0f,
                          float y = 2.0f) {
    physics::CollisionEvent evt{};
    evt.objectA = reinterpret_cast<void*>(static_cast<uintptr_t>(a));
    evt.objectB = reinterpret_cast<void*>(static_cast<uintptr_t>(b));
    evt.x1 = x;
    evt.y1 = y;
    world.collisionEnter["a:b"].push_back(evt);

    physics::CollisionEvent exit{};
    exit.objectA = reinterpret_cast<void*>(static_cast<uintptr_t>(a));
    exit.objectB = reinterpret_cast<void*>(static_cast<uintptr_t>(b));
    world.collisionExit["a:b"].push_back(exit);
}

TEST_F(PhysicsEventBusTest, PublishesCollisionEventsToContextBus) {
    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    globals::setEngineContext(&ctx);

    entt::registry registry;
    physics::PhysicsWorld world(&registry, 64.0f, 0.0f, 0.0f, &ctx.eventBus);

    auto e1 = registry.create();
    auto e2 = registry.create();
    pushCollision(world, e1, e2, 3.0f, 4.0f);

    int started = 0;
    int ended = 0;
    events::CollisionStarted last{};
    ctx.eventBus.subscribe<events::CollisionStarted>(
        [&](const events::CollisionStarted& ev) {
            ++started;
            last = ev;
        });
    ctx.eventBus.subscribe<events::CollisionEnded>(
        [&](const events::CollisionEnded&) { ++ended; });

    world.PostUpdate();

    EXPECT_EQ(started, 1);
    EXPECT_EQ(ended, 1);
    EXPECT_EQ(last.entityA, e1);
    EXPECT_EQ(last.entityB, e2);
    EXPECT_FLOAT_EQ(last.point.x, 3.0f);
    EXPECT_FLOAT_EQ(last.point.y, 4.0f);
    EXPECT_TRUE(world.collisionEnter.empty());
    EXPECT_TRUE(world.collisionExit.empty());
}

TEST_F(PhysicsEventBusTest, FallsBackToGlobalBusWhenNoContext) {
    globals::setEngineContext(nullptr);

    entt::registry registry;
    physics::PhysicsWorld world(&registry, 64.0f, 0.0f, 0.0f);

    auto e1 = registry.create();
    auto e2 = registry.create();
    pushCollision(world, e1, e2, 5.0f, 6.0f);

    int started = 0;
    events::CollisionStarted last{};
    globals::getEventBus().subscribe<events::CollisionStarted>(
        [&](const events::CollisionStarted& ev) {
            ++started;
            last = ev;
        });

    world.PostUpdate();

    EXPECT_EQ(started, 1);
    EXPECT_EQ(last.entityA, e1);
    EXPECT_EQ(last.entityB, e2);
    EXPECT_FLOAT_EQ(last.point.x, 5.0f);
    EXPECT_FLOAT_EQ(last.point.y, 6.0f);
}
