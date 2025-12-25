#include <gtest/gtest.h>
#include "benchmark_common.hpp"

#include "entt/entt.hpp"

/**
 * ECS Performance Benchmarks
 *
 * Tests entity creation, component access patterns, and view iteration.
 * These benchmarks help identify regression in core ECS operations.
 *
 * Uses simple POD structs to isolate ECS performance from game component complexity.
 */

// Simple test-only components for benchmarking (not game components)
struct BenchPosition {
    float x = 0.0f;
    float y = 0.0f;
};

struct BenchVelocity {
    float vx = 0.0f;
    float vy = 0.0f;
};

struct BenchHealth {
    int current = 100;
    int max = 100;
};

class ECSBenchmark : public ::testing::Test {
protected:
    entt::registry registry;

    void SetUp() override {
        registry.clear();
    }

    void TearDown() override {
        registry.clear();
    }

    // Populate with N entities having Position + Velocity
    void populate(size_t n) {
        for (size_t i = 0; i < n; ++i) {
            auto entity = registry.create();
            registry.emplace<BenchPosition>(entity, BenchPosition{
                static_cast<float>(i % 100),
                static_cast<float>(i / 100)
            });
            registry.emplace<BenchVelocity>(entity, BenchVelocity{1.0f, 0.5f});
        }
    }
};

// Benchmark: Entity creation
TEST_F(ECSBenchmark, EntityCreation_1k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        registry.clear();
        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 1000; ++i) {
            auto entity = registry.create();
            registry.emplace<BenchPosition>(entity);
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("EntityCreation (1k entities)", result);
    EXPECT_LT(result.mean_ms, 50.0) << "Entity creation should be fast";
}

// Benchmark: Entity creation with multiple components
TEST_F(ECSBenchmark, EntityCreation_MultiComponent_1k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        registry.clear();
        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 1000; ++i) {
            auto entity = registry.create();
            registry.emplace<BenchPosition>(entity, BenchPosition{static_cast<float>(i), 0.0f});
            registry.emplace<BenchVelocity>(entity, BenchVelocity{1.0f, 0.5f});
            registry.emplace<BenchHealth>(entity);
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("EntityCreation_MultiComponent (1k entities, 3 components)", result);
    EXPECT_LT(result.mean_ms, 100.0) << "Multi-component creation should be reasonable";
}

// Benchmark: View iteration (single component)
TEST_F(ECSBenchmark, ViewIteration_SingleComponent_10k) {
    // Populate with position only
    for (size_t i = 0; i < 10000; ++i) {
        auto entity = registry.create();
        registry.emplace<BenchPosition>(entity);
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        int count = 0;
        benchmark::ScopedTimer timer(times);
        for (auto [entity, pos] : registry.view<BenchPosition>().each()) {
            pos.x += 1.0f;
            count++;
        }
        (void)count;
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("ViewIteration_SingleComponent (10k)", result);
    EXPECT_LT(result.mean_ms, 10.0) << "View iteration should be fast";
}

// Benchmark: View iteration (two components)
TEST_F(ECSBenchmark, ViewIteration_TwoComponents_10k) {
    populate(10000);

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        for (auto [entity, pos, vel] : registry.view<BenchPosition, BenchVelocity>().each()) {
            pos.x += vel.vx * 0.016f;
            pos.y += vel.vy * 0.016f;
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("ViewIteration_TwoComponents (10k)", result);
    EXPECT_LT(result.mean_ms, 15.0) << "Multi-component view should be reasonably fast";
}

// Benchmark: Random component access via registry.get()
TEST_F(ECSBenchmark, RandomComponentAccess_1k) {
    std::vector<entt::entity> entities;
    for (int i = 0; i < 1000; ++i) {
        auto entity = registry.create();
        registry.emplace<BenchPosition>(entity);
        entities.push_back(entity);
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        for (auto entity : entities) {
            auto& pos = registry.get<BenchPosition>(entity);
            pos.x += 1.0f;
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("RandomComponentAccess (1k)", result);
    EXPECT_LT(result.mean_ms, 5.0) << "Random access should be reasonable";
}

// Benchmark: Entity destruction
TEST_F(ECSBenchmark, EntityDestruction_1k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        std::vector<entt::entity> entities;
        for (int i = 0; i < 1000; ++i) {
            auto entity = registry.create();
            registry.emplace<BenchPosition>(entity);
            entities.push_back(entity);
        }

        benchmark::ScopedTimer timer(times);
        for (auto entity : entities) {
            registry.destroy(entity);
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("EntityDestruction (1k)", result);
    EXPECT_LT(result.mean_ms, 10.0) << "Destruction should be fast";
}

// Benchmark: Component has() check
TEST_F(ECSBenchmark, ComponentHasCheck_10k) {
    populate(10000);
    auto view = registry.view<BenchPosition>();

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        int has_count = 0;
        benchmark::ScopedTimer timer(times);
        for (auto entity : view) {
            if (registry.all_of<BenchPosition, BenchVelocity>(entity)) {
                has_count++;
            }
        }
        (void)has_count;
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("ComponentHasCheck (10k)", result);
    EXPECT_LT(result.mean_ms, 5.0) << "has() checks should be fast";
}

// Benchmark: Component add/remove
TEST_F(ECSBenchmark, ComponentAddRemove_1k) {
    std::vector<entt::entity> entities;
    for (int i = 0; i < 1000; ++i) {
        auto entity = registry.create();
        registry.emplace<BenchPosition>(entity);
        entities.push_back(entity);
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        benchmark::ScopedTimer timer(times);
        // Add Health component
        for (auto entity : entities) {
            registry.emplace<BenchHealth>(entity);
        }
        // Remove Health component
        for (auto entity : entities) {
            registry.remove<BenchHealth>(entity);
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("ComponentAddRemove (1k, 2 ops each)", result);
    EXPECT_LT(result.mean_ms, 20.0) << "Add/remove should be reasonable";
}

// Benchmark: Sparse component iteration (only 10% have the component)
TEST_F(ECSBenchmark, SparseComponentIteration_10k) {
    // Create 10k entities, only 10% have Health
    for (size_t i = 0; i < 10000; ++i) {
        auto entity = registry.create();
        registry.emplace<BenchPosition>(entity);
        if (i % 10 == 0) {
            registry.emplace<BenchHealth>(entity);
        }
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        int count = 0;
        benchmark::ScopedTimer timer(times);
        for (auto [entity, health] : registry.view<BenchHealth>().each()) {
            health.current -= 1;
            count++;
        }
        (void)count;
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SparseComponentIteration (1k of 10k have component)", result);
    EXPECT_LT(result.mean_ms, 3.0) << "Sparse iteration should be fast";
}
