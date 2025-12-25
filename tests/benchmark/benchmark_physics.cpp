#include <gtest/gtest.h>
#include "benchmark_common.hpp"

#include "entt/entt.hpp"
#include "systems/physics/physics_world.hpp"

/**
 * Physics Performance Benchmarks
 *
 * Tests Chipmunk physics operations: body creation, stepping, queries.
 * These benchmarks help identify regression in physics-heavy scenarios.
 *
 * Note: Uses physics world directly without game Transform (which has
 * spring-based complexity). Physics bodies track their own positions.
 */

class PhysicsBenchmark : public ::testing::Test {
protected:
    entt::registry registry;
    std::shared_ptr<physics::PhysicsWorld> world;

    void SetUp() override {
        registry.clear();
        world = physics::InitPhysicsWorld(&registry, 64.0f, 0.0f, 0.0f);
        world->AddCollisionTag("default");
        world->AddCollisionTag("dynamic");
    }

    void TearDown() override {
        world.reset();
        registry.clear();
    }

    // Create N dynamic bodies with colliders
    // Physics bodies track their own position - no Transform needed
    // AddCollider signature: entity, tag, shapeType, a, b, c, d, isSensor
    // For circle: a=radius, b/c/d=0
    void createBodies(size_t n) {
        for (size_t i = 0; i < n; ++i) {
            auto entity = registry.create();
            float x = static_cast<float>(i % 100) * 10.0f;
            float y = static_cast<float>(i / 100) * 10.0f;

            world->AddCollider(entity, "dynamic", "circle", 8.0f, 0.0f, 0.0f, 0.0f, false);
            world->SetPosition(entity, x, y);
        }
    }
};

// Benchmark: Physics world step with no bodies
TEST_F(PhysicsBenchmark, EmptyWorldStep) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 100; ++i) {
            world->Update(1.0f / 60.0f);
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("EmptyWorldStep (100 steps)", result);
    EXPECT_LT(result.mean_ms, 5.0) << "Empty physics step should be very fast";
}

// Benchmark: Physics step with 100 bodies
TEST_F(PhysicsBenchmark, WorldStep_100Bodies) {
    createBodies(100);

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        world->Update(1.0f / 60.0f);
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("WorldStep (100 bodies)", result);
    EXPECT_LT(result.mean_ms, 10.0) << "100 body step should be fast";
}

// Benchmark: Physics step with 500 bodies
TEST_F(PhysicsBenchmark, WorldStep_500Bodies) {
    createBodies(500);

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        world->Update(1.0f / 60.0f);
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("WorldStep (500 bodies)", result);
    EXPECT_LT(result.mean_ms, 50.0) << "500 body step should be reasonable";
}

// Benchmark: Body creation
TEST_F(PhysicsBenchmark, BodyCreation_100) {
    std::vector<double> times;

    for (int run = 0; run < 50; ++run) {
        // Clear and recreate
        world.reset();
        registry.clear();
        world = physics::InitPhysicsWorld(&registry, 64.0f, 0.0f, 0.0f);
        world->AddCollisionTag("dynamic");

        benchmark::ScopedTimer timer(times);
        createBodies(100);
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("BodyCreation (100 bodies)", result);
    EXPECT_LT(result.mean_ms, 50.0) << "Body creation should be reasonably fast";
}

// Benchmark: Velocity updates
TEST_F(PhysicsBenchmark, VelocityUpdate_100Bodies) {
    createBodies(100);

    // Get all entities with colliders
    std::vector<entt::entity> entities;
    auto view = registry.view<physics::ColliderComponent>();
    for (auto entity : view) {
        entities.push_back(entity);
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        for (auto entity : entities) {
            world->SetVelocity(entity, 100.0f, 50.0f);
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("VelocityUpdate (100 bodies)", result);
    EXPECT_LT(result.mean_ms, 5.0) << "Velocity updates should be fast";
}

// Benchmark: Position queries
TEST_F(PhysicsBenchmark, PositionQuery_100Bodies) {
    createBodies(100);

    std::vector<entt::entity> entities;
    auto view = registry.view<physics::ColliderComponent>();
    for (auto entity : view) {
        entities.push_back(entity);
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        float sum = 0;
        benchmark::ScopedTimer timer(times);
        for (auto entity : entities) {
            auto [x, y] = world->GetPosition(entity);
            sum += x + y;
        }
        (void)sum;
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("PositionQuery (100 bodies)", result);
    EXPECT_LT(result.mean_ms, 2.0) << "Position queries should be very fast";
}

// Benchmark: Collision mask updates
TEST_F(PhysicsBenchmark, CollisionMaskUpdate) {
    world->AddCollisionTag("player");
    world->AddCollisionTag("enemy");
    world->AddCollisionTag("projectile");

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 100; ++i) {
            world->EnableCollisionBetween("player", {"enemy", "projectile"});
            world->EnableCollisionBetween("enemy", {"player", "projectile"});
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CollisionMaskUpdate (100 updates)", result);
    EXPECT_LT(result.mean_ms, 20.0) << "Collision mask updates should be reasonable";
}
