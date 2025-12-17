#include <gtest/gtest.h>
#include "benchmark_common.hpp"

#include "sol/sol.hpp"

class LuaBoundaryBenchmark : public ::testing::Test {
protected:
    sol::state lua;

    void SetUp() override {
        lua.open_libraries(sol::lib::base, sol::lib::math, sol::lib::table);
    }
};

// Test 1: SingleFunctionCall - measure boundary crossing cost
TEST_F(LuaBoundaryBenchmark, SingleFunctionCall) {
    lua.set_function("cpp_add", [](int a, int b) { return a + b; });

    std::vector<double> times;
    const int ITERATIONS = 10000;

    for (int i = 0; i < 100; ++i) {
        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < ITERATIONS; ++j) {
            lua.script("local result = cpp_add(1, 2)");
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("SingleFunctionCall (10k calls)", result);
    EXPECT_LT(result.mean_ms, 1000.0) << "Baseline measurement";
}

// Test 2: TableCreationInLoop
TEST_F(LuaBoundaryBenchmark, TableCreationInLoop) {
    lua.script(R"(
        function create_tables(n)
            local results = {}
            for i = 1, n do
                results[i] = { x = i, y = i * 2, z = i * 3 }
            end
            return results
        end
    )");

    std::vector<double> times;
    for (int i = 0; i < 100; ++i) {
        benchmark::ScopedTimer timer(times);
        sol::table result = lua["create_tables"](1000);
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("TableCreationInLoop (1k tables)", result);
    EXPECT_LT(result.mean_ms, 100.0) << "Baseline measurement";
}

// Test 3: RepeatedPropertyAccess
TEST_F(LuaBoundaryBenchmark, RepeatedPropertyAccess) {
    struct FakeTransform {
        float x = 0, y = 0, w = 32, h = 32;
    };

    FakeTransform transform;
    lua.new_usertype<FakeTransform>("Transform",
        "x", &FakeTransform::x,
        "y", &FakeTransform::y,
        "w", &FakeTransform::w,
        "h", &FakeTransform::h
    );
    lua["transform"] = &transform;

    lua.script(R"(
        function update_transform(n)
            for i = 1, n do
                transform.x = transform.x + 1
                transform.y = transform.y + 1
            end
        end
    )");

    std::vector<double> times;
    for (int i = 0; i < 100; ++i) {
        transform.x = 0;
        transform.y = 0;
        benchmark::ScopedTimer timer(times);
        lua["update_transform"](10000);
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("RepeatedPropertyAccess (10k accesses)", result);
    EXPECT_LT(result.mean_ms, 500.0) << "Baseline measurement";
}

// Test 4: CallbackFromCpp
TEST_F(LuaBoundaryBenchmark, CallbackFromCpp) {
    lua.script(R"(
        callback_count = 0
        function on_event(entity_id, event_type)
            callback_count = callback_count + 1
        end
    )");

    sol::function callback = lua["on_event"];
    std::vector<double> times;

    for (int i = 0; i < 100; ++i) {
        lua["callback_count"] = 0;
        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < 1000; ++j) {
            callback(j, "damage");
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CallbackFromCpp (1k callbacks)", result);
    EXPECT_LT(result.mean_ms, 200.0) << "Baseline measurement";
}
