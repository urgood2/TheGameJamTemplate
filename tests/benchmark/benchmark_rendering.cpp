#include <gtest/gtest.h>
#include "benchmark_common.hpp"

#include <vector>
#include <algorithm>
#include <random>

// Mock draw command for benchmarking sort performance
struct MockDrawCommand {
    int z;
    int space;  // 0 = World, 1 = Screen
    int shader_id;
    int texture_id;
    void* data;
};

class RenderingBenchmark : public ::testing::Test {
protected:
    std::vector<MockDrawCommand> commands;
    std::mt19937 rng{42};  // Fixed seed for reproducibility

    void SetUp() override {
        commands.clear();
    }

    void generateCommands(size_t count, int z_range = 100, int shader_count = 10, int texture_count = 50) {
        commands.reserve(count);
        std::uniform_int_distribution<int> z_dist(0, z_range);
        std::uniform_int_distribution<int> space_dist(0, 1);
        std::uniform_int_distribution<int> shader_dist(0, shader_count - 1);
        std::uniform_int_distribution<int> texture_dist(0, texture_count - 1);

        for (size_t i = 0; i < count; ++i) {
            commands.push_back({
                z_dist(rng),
                space_dist(rng),
                shader_dist(rng),
                texture_dist(rng),
                nullptr
            });
        }
    }
};

TEST_F(RenderingBenchmark, SortByZOnly) {
    generateCommands(5000);
    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        auto cmds = commands;
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                return a.z < b.z;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SortByZOnly (5k commands)", result);
    EXPECT_LT(result.mean_ms, 10.0) << "Sort should be fast";
}

TEST_F(RenderingBenchmark, SortByZAndSpace) {
    generateCommands(5000);
    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        auto cmds = commands;
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                if (a.z != b.z) return a.z < b.z;
                if (a.space != b.space) return a.space < b.space;
                return false;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SortByZAndSpace (5k commands)", result);
    EXPECT_LT(result.mean_ms, 10.0);
}

TEST_F(RenderingBenchmark, SortByFullBatchKey) {
    generateCommands(5000);
    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        auto cmds = commands;
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                if (a.z != b.z) return a.z < b.z;
                if (a.space != b.space) return a.space < b.space;
                if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
                if (a.texture_id != b.texture_id) return a.texture_id < b.texture_id;
                return false;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SortByFullBatchKey (5k commands)", result);
    EXPECT_LT(result.mean_ms, 15.0);
}

TEST_F(RenderingBenchmark, CountStateChanges) {
    generateCommands(5000);

    // Sort by z only
    std::stable_sort(commands.begin(), commands.end(),
        [](const MockDrawCommand& a, const MockDrawCommand& b) { return a.z < b.z; });

    int space_changes = 0, shader_changes = 0, texture_changes = 0;
    for (size_t i = 1; i < commands.size(); ++i) {
        if (commands[i].space != commands[i-1].space) ++space_changes;
        if (commands[i].shader_id != commands[i-1].shader_id) ++shader_changes;
        if (commands[i].texture_id != commands[i-1].texture_id) ++texture_changes;
    }

    std::cout << "[STATE CHANGES] z-only sort:\n"
              << "  space changes:   " << space_changes << "\n"
              << "  shader changes:  " << shader_changes << "\n"
              << "  texture changes: " << texture_changes << "\n";

    // Sort by full key
    std::stable_sort(commands.begin(), commands.end(),
        [](const MockDrawCommand& a, const MockDrawCommand& b) {
            if (a.z != b.z) return a.z < b.z;
            if (a.space != b.space) return a.space < b.space;
            if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
            if (a.texture_id != b.texture_id) return a.texture_id < b.texture_id;
            return false;
        });

    int space_changes_opt = 0, shader_changes_opt = 0, texture_changes_opt = 0;
    for (size_t i = 1; i < commands.size(); ++i) {
        if (commands[i].space != commands[i-1].space) ++space_changes_opt;
        if (commands[i].shader_id != commands[i-1].shader_id) ++shader_changes_opt;
        if (commands[i].texture_id != commands[i-1].texture_id) ++texture_changes_opt;
    }

    std::cout << "[STATE CHANGES] full-key sort:\n"
              << "  space changes:   " << space_changes_opt << "\n"
              << "  shader changes:  " << shader_changes_opt << "\n"
              << "  texture changes: " << texture_changes_opt << "\n";

    EXPECT_LE(space_changes_opt, space_changes);
    EXPECT_LE(shader_changes_opt, shader_changes);
    EXPECT_LE(texture_changes_opt, texture_changes);
}

TEST_F(RenderingBenchmark, LargeScaleSort) {
    generateCommands(20000);
    std::vector<double> times;

    for (int i = 0; i < 50; ++i) {
        auto cmds = commands;
        benchmark::ScopedTimer timer(times);
        std::stable_sort(cmds.begin(), cmds.end(),
            [](const MockDrawCommand& a, const MockDrawCommand& b) {
                if (a.z != b.z) return a.z < b.z;
                if (a.space != b.space) return a.space < b.space;
                if (a.shader_id != b.shader_id) return a.shader_id < b.shader_id;
                return false;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("LargeScaleSort (20k commands)", result);
    EXPECT_LT(result.p99_ms, 50.0);
}
