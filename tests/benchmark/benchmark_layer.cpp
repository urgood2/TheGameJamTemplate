#include <gtest/gtest.h>
#include "benchmark_common.hpp"

#include <vector>
#include <string>
#include <algorithm>
#include <variant>

/**
 * Layer/Rendering Performance Benchmarks
 *
 * Tests draw command data structure operations: creation, sorting, and buffer operations.
 * These benchmarks help identify regression in rendering pipelines.
 *
 * Note: Uses local structs to avoid complex layer system dependencies while still
 * measuring the performance characteristics of command buffer operations.
 */

namespace {

// Simplified command struct mimicking layer::DrawCommand
struct TestDrawCommand {
    std::string type;
    std::vector<std::variant<float, int, std::string>> args;
    int z = 0;
};

// Simplified V2 command struct mimicking layer::DrawCommandV2
struct TestDrawCommandV2 {
    int type = 0;  // Enum would be here
    void* data = nullptr;
    int z = 0;
    int space = 0;
    uint64_t uniqueID = 0;
};

} // namespace

class LayerBenchmark : public ::testing::Test {
protected:
    std::vector<TestDrawCommand> drawCommands;
    std::vector<TestDrawCommandV2> commandsV2;

    void SetUp() override {
        drawCommands.reserve(10000);
        commandsV2.reserve(10000);
    }

    void TearDown() override {
        drawCommands.clear();
        commandsV2.clear();
    }
};

// Benchmark: DrawCommand creation (string-based style)
TEST_F(LayerBenchmark, DrawCommandCreation_1k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        drawCommands.clear();
        drawCommands.reserve(1000);

        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 1000; ++i) {
            TestDrawCommand cmd;
            cmd.type = "rectangle";
            cmd.z = i;
            cmd.args.push_back(static_cast<float>(i));
            drawCommands.push_back(std::move(cmd));
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("DrawCommandCreation (1k commands)", result);
    EXPECT_LT(result.mean_ms, 20.0) << "Command creation should be fast";
}

// Benchmark: Command sorting by Z
TEST_F(LayerBenchmark, CommandSorting_1k) {
    // Pre-populate with unsorted commands
    drawCommands.reserve(1000);
    for (int i = 0; i < 1000; ++i) {
        TestDrawCommand cmd;
        cmd.type = "sprite";
        cmd.z = (i * 7) % 1000;  // Scramble order
        drawCommands.push_back(std::move(cmd));
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        // Copy for each run
        auto copy = drawCommands;

        benchmark::ScopedTimer timer(times);
        std::sort(copy.begin(), copy.end(),
            [](const TestDrawCommand& a, const TestDrawCommand& b) {
                return a.z < b.z;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CommandSorting (1k commands)", result);
    EXPECT_LT(result.mean_ms, 5.0) << "Sorting should be fast";
}

// Benchmark: Command sorting by Z with 5k commands
TEST_F(LayerBenchmark, CommandSorting_5k) {
    drawCommands.reserve(5000);
    for (int i = 0; i < 5000; ++i) {
        TestDrawCommand cmd;
        cmd.type = "sprite";
        cmd.z = (i * 7) % 5000;
        drawCommands.push_back(std::move(cmd));
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        auto copy = drawCommands;

        benchmark::ScopedTimer timer(times);
        std::sort(copy.begin(), copy.end(),
            [](const TestDrawCommand& a, const TestDrawCommand& b) {
                return a.z < b.z;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CommandSorting (5k commands)", result);
    EXPECT_LT(result.mean_ms, 30.0) << "5k sort should be reasonable";
}

// Benchmark: Command buffer clear
TEST_F(LayerBenchmark, CommandBufferClear_5k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        // Fill with commands
        drawCommands.reserve(5000);
        for (int i = 0; i < 5000; ++i) {
            TestDrawCommand cmd;
            cmd.type = "sprite";
            cmd.z = i;
            drawCommands.push_back(std::move(cmd));
        }

        benchmark::ScopedTimer timer(times);
        drawCommands.clear();
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CommandBufferClear (5k commands)", result);
    EXPECT_LT(result.mean_ms, 1.0) << "Clear should be very fast";
}

// Benchmark: DrawCommandV2 creation (optimized POD-like struct)
TEST_F(LayerBenchmark, DrawCommandV2Creation_1k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        commandsV2.clear();
        commandsV2.reserve(1000);

        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 1000; ++i) {
            TestDrawCommandV2 cmd;
            cmd.type = 1;  // Circle
            cmd.z = i;
            cmd.data = nullptr;
            commandsV2.push_back(cmd);
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("DrawCommandV2Creation (1k commands)", result);
    EXPECT_LT(result.mean_ms, 5.0) << "V2 command creation should be faster than V1";
}

// Benchmark: DrawCommandV2 sorting
TEST_F(LayerBenchmark, DrawCommandV2Sorting_5k) {
    // Pre-populate with unsorted V2 commands
    commandsV2.reserve(5000);
    for (int i = 0; i < 5000; ++i) {
        TestDrawCommandV2 cmd;
        cmd.type = 2;  // Rectangle
        cmd.z = (i * 7) % 5000;  // Scramble order
        cmd.data = nullptr;
        commandsV2.push_back(cmd);
    }

    std::vector<double> times;
    for (int run = 0; run < 100; ++run) {
        auto copy = commandsV2;

        benchmark::ScopedTimer timer(times);
        std::sort(copy.begin(), copy.end(),
            [](const TestDrawCommandV2& a, const TestDrawCommandV2& b) {
                return a.z < b.z;
            });
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("DrawCommandV2Sorting (5k commands)", result);
    EXPECT_LT(result.mean_ms, 10.0) << "V2 sort should be faster (smaller struct)";
}

// Benchmark: Mixed command types (string allocation pattern)
TEST_F(LayerBenchmark, MixedCommandTypes_1k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        drawCommands.clear();
        drawCommands.reserve(1000);

        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 1000; ++i) {
            TestDrawCommand cmd;
            switch (i % 4) {
                case 0: cmd.type = "sprite"; break;
                case 1: cmd.type = "rectangle"; break;
                case 2: cmd.type = "circle"; break;
                case 3: cmd.type = "text"; break;
            }
            cmd.z = i;
            drawCommands.push_back(std::move(cmd));
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("MixedCommandTypes (1k commands)", result);
    EXPECT_LT(result.mean_ms, 20.0) << "Mixed types shouldn't be much slower";
}

// Benchmark: Reserve then fill (optimal pattern)
TEST_F(LayerBenchmark, ReserveThenFill_5k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        drawCommands.clear();

        benchmark::ScopedTimer timer(times);
        drawCommands.reserve(5000);
        for (int i = 0; i < 5000; ++i) {
            TestDrawCommand cmd;
            cmd.type = "sprite";
            cmd.z = i;
            drawCommands.push_back(std::move(cmd));
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("ReserveThenFill (5k commands)", result);
    EXPECT_LT(result.mean_ms, 100.0) << "Pre-reserved fill should be efficient";
}

// Benchmark: No reserve (worst case allocations)
TEST_F(LayerBenchmark, NoReserveFill_5k) {
    std::vector<double> times;

    for (int run = 0; run < 100; ++run) {
        std::vector<TestDrawCommand> commands;  // Fresh vector, no reserve

        benchmark::ScopedTimer timer(times);
        for (int i = 0; i < 5000; ++i) {
            TestDrawCommand cmd;
            cmd.type = "sprite";
            cmd.z = i;
            commands.push_back(std::move(cmd));
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("NoReserveFill (5k commands)", result);
    // This will be slower - just document the cost
    std::cout << "  (Compare with ReserveThenFill to see allocation overhead)\n";
}

// Benchmark: V1 vs V2 struct size comparison
TEST_F(LayerBenchmark, StructSizeComparison) {
    std::cout << "\n  Struct sizes for reference:\n";
    std::cout << "    TestDrawCommand (V1-like): " << sizeof(TestDrawCommand) << " bytes\n";
    std::cout << "    TestDrawCommandV2:         " << sizeof(TestDrawCommandV2) << " bytes\n";
    std::cout << "    Ratio: " << static_cast<float>(sizeof(TestDrawCommand)) / sizeof(TestDrawCommandV2) << "x\n";
    SUCCEED();
}
